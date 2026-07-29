# frozen_string_literal: true

require "action_cable"
# Action Cable's event loop uses concurrent-ruby without requiring it,
# so we load it explicitly.
require "concurrent"
require "json"
require "logger"
require "securerandom"

class Tidewave
  # Server side of Tidewave browser control.
  #
  # The WebSocket endpoint is a dedicated Action Cable server, since the user
  # app may not have one, and if it does it likely has auth. Commands/replies
  # are routed between MCP request threads and browser connections over Action
  # Cable pub/sub streams:
  #
  #   * tidewave:clients      - all connected pages (used for discovery)
  #   * tidewave:client:name  - the page registered under name
  #   * tidewave:reply:ref    - replies to a single run_tool command
  #
  # Consequently the routing works across processes whenever the configured
  # cable adapter does, such as "solid_cable", whereas the default "async"
  # adapter is single-process.
  #
  # The pub/sub bus cannot tell whether a stream has any subscribers, so
  # the channel broadcasts an "ack" on the reply stream as soon as it picks
  # up a command, letting the caller fail fast when no client is connected.
  # Similarly, when a page disconnects, its channel broadcasts "disconnected"
  # for every command still awaiting a reply, so the caller does not wait
  # out the full timeout.
  class BrowserControl
    CLIENTS_STREAM = "tidewave:clients"

    def self.client_stream(name)
      "tidewave:client:#{name}"
    end

    def self.reply_stream(ref)
      "tidewave:reply:#{ref}"
    end

    attr_reader :server

    def initialize(cable: nil, logger: nil, ack_timeout: 1.0)
      cable = { "adapter" => "async" } if cable.nil? || cable.empty?
      @ack_timeout = ack_timeout
      @server = Server.new(cable: cable, logger: logger || ::Logger.new(IO::NULL))
    end

    # Rack entrypoint for the WebSocket endpoint.
    def call(env)
      @server.call(env)
    end

    # Runs the tool against the client owning `sid` and waits for the reply.
    # `timeout_ms` may be nil to wait indefinitely.
    #
    # Returns `[ :ok, reply ]` (the page's response) or `[ :error, reason ]`,
    # where reason is :invalid_sid, :unknown_client, :timeout, or :disconnected.
    def run(sid, tool_name, input, timeout_ms)
      name = parse_sid(sid)
      return [ :error, :invalid_sid ] unless name

      call_tool(self.class.client_stream(name), tool_name, sid, input, timeout_ms, await_ack: true)
    end

    # Sends the tool to every connected client and returns the first reply.
    #
    # Used for the discovery handshake (a browser_eval call with no sid).
    # Returns `[ :ok, reply ]` or `[ :error, :timeout ]` when no client
    # answered in time (the bus cannot tell whether anyone is connected).
    def broadcast_run(tool_name, input, timeout_ms)
      call_tool(CLIENTS_STREAM, tool_name, nil, input, timeout_ms, await_ack: false)
    end

    private

    def parse_sid(sid)
      name, suffix = sid.split("#", 2)
      name if name && suffix && !name.empty? && !suffix.empty?
    end

    def call_tool(stream, tool_name, sid, input, timeout_ms, await_ack:)
      # The reply stream is derived from the ref, so it must be unique
      # across processes (unlike a per-process counter).
      ref = SecureRandom.random_number(2**53)
      reply_stream = self.class.reply_stream(ref)
      queue = Queue.new
      on_message = ->(payload) { queue << decode(payload) }
      on_subscribed = -> { queue << :subscribed }

      @server.pubsub.subscribe(reply_stream, on_message, on_subscribed)

      # Waiting on the browser can trigger requests back into the app (the
      # page evaluating code issues requests of its own); if such a request
      # needs to reload code, the exclusive reload would wait on this
      # thread's share of the reload interlock, deadlocking until timeout.
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        # Adapters confirm subscriptions asynchronously; broadcasting
        # before the confirmation could lose the reply.
        if queue.pop(timeout: 5) == :subscribed
          message = { "type" => "run_tool", "ref" => ref, "name" => tool_name, "sid" => sid, "input" => input }
          @server.broadcast(stream, message)
          await_reply(queue, timeout_ms && timeout_ms / 1000.0, await_ack)
        else
          [ :error, :timeout ]
        end
      end
    ensure
      @server.pubsub.unsubscribe(reply_stream, on_message)
    end

    def await_reply(queue, timeout, await_ack)
      deadline = timeout && now + timeout
      ack_deadline = await_ack ? now + @ack_timeout : nil

      loop do
        wait_until = [ deadline, ack_deadline ].compact.min
        message = queue.pop(timeout: wait_until && [ wait_until - now, 0 ].max)

        case message.is_a?(Hash) && message["type"]
        when "tool_reply"
          return [ :ok, message["reply"] ]
        when "disconnected"
          return [ :error, :disconnected ]
        when "ack"
          ack_deadline = nil
        else
          # No ack means no connected client picked the command up,
          # so that client is likely already disconnected.
          return [ :error, :unknown_client ] if ack_deadline && now >= ack_deadline
          return [ :error, :timeout ] if deadline && now >= deadline
        end
      end
    end

    def decode(payload)
      JSON.parse(payload)
    rescue JSON::ParserError
      nil
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    class Server < ActionCable::Server::Base
      # Registry of client names owned by connections in this process,
      # backing the "hello" name-uniqueness check.
      attr_reader :client_registry

      def initialize(cable:, logger:)
        config = ActionCable::Server::Configuration.new
        config.cable = cable
        config.connection_class = -> { Tidewave::BrowserControl::Connection }
        # The origin is validated by the Tidewave middleware before the
        # request reaches this server.
        config.disable_request_forgery_protection = true
        config.logger = logger
        super(config: config)
        @client_registry = ClientRegistry.new
      end
    end

    class Connection < ActionCable::Connection::Base
    end

    # Handles a single control page connection.
    class Channel < ActionCable::Channel::Base
      def initialize(connection, identifier, params = {})
        super
        @mutex = Mutex.new
        @name = nil
        @pending_refs = {}
      end

      def subscribed
        stream_from(CLIENTS_STREAM, coder: ActiveSupport::JSON) do |message|
          handle_command(message)
        end
      end

      def receive(data)
        case data["type"]
        when "hello"
          hello(data["name"])
        when "tool_reply"
          tool_reply(data)
        end

        # "ping" and unknown messages are ignored; the page pings to keep
        # the socket alive through proxies
      end

      def unsubscribed
        server.client_registry.unregister(@name, self) if @name

        refs = @mutex.synchronize do
          @pending_refs.keys.tap { @pending_refs.clear }
        end

        refs.each do |ref|
          server.broadcast(BrowserControl.reply_stream(ref), { "type" => "disconnected" })
        end
      end

      private

      def hello(name)
        return unless name.is_a?(String)

        if server.client_registry.register(name, self)
          @name = name

          stream_from(BrowserControl.client_stream(name), coder: ActiveSupport::JSON) do |message|
            handle_command(message)
          end

          transmit({ "type" => "hello_ok", "name" => name })
        else
          transmit({ "type" => "hello_error", "reason" => "name_taken" })
        end
      end

      def handle_command(message)
        return unless message.is_a?(Hash) && message["type"] == "run_tool"

        ref = message["ref"]
        return unless ref.is_a?(Integer)

        @mutex.synchronize { @pending_refs[ref] = true }
        # The ack tells the caller the command reached a connected page
        # (the pub/sub bus cannot tell whether anyone is subscribed).
        server.broadcast(BrowserControl.reply_stream(ref), { "type" => "ack" })
        transmit(message)
      end

      def tool_reply(data)
        ref = data["ref"]
        return unless @mutex.synchronize { @pending_refs.delete(ref) }

        server.broadcast(BrowserControl.reply_stream(ref), data)
      end

      def server
        connection.server
      end
    end

    class ClientRegistry
      def initialize
        @mutex = Mutex.new
        @clients = {}
      end

      # Registers `owner` under `name`. Returns false when a different live
      # owner already holds the name.
      #
      # The registry is per-process, so with a multi-process cable adapter
      # the uniqueness check is best-effort (client-generated names carry
      # enough entropy for collisions to be negligible).
      def register(name, owner)
        @mutex.synchronize do
          current = @clients[name]

          if current.nil? || current.equal?(owner)
            @clients[name] = owner
            true
          else
            false
          end
        end
      end

      def unregister(name, owner)
        @mutex.synchronize do
          @clients.delete(name) if @clients[name].equal?(owner)
        end
      end
    end
  end
end
