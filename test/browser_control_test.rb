# frozen_string_literal: true

require "test_helper"

class TidewaveBrowserControlTest < Minitest::Test
  def setup
    @control = Tidewave::BrowserControl.new(cable: { "adapter" => "async" }, ack_timeout: 0.2)
  end

  def test_run_with_invalid_sid
    assert_equal [ :error, :invalid_sid ], @control.run("nosuffix", "browser_eval", {}, 1_000)
    assert_equal [ :error, :invalid_sid ], @control.run("#1", "browser_eval", {}, 1_000)
    assert_equal [ :error, :invalid_sid ], @control.run("name#", "browser_eval", {}, 1_000)
  end

  def test_run_with_no_connected_client_returns_unknown_client_quickly
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = @control.run("ghost#1", "browser_eval", {}, 30_000)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    assert_equal [ :error, :unknown_client ], result
    assert_operator elapsed, :<, 5
  end

  def test_run_returns_the_client_reply
    fake_client("nice-cactus") do |message, reply_stream|
      @control.server.broadcast(reply_stream, { "type" => "ack" })
      @control.server.broadcast(reply_stream, {
        "type" => "tool_reply",
        "ref" => message["ref"],
        "reply" => { "result" => { "content" => [ { "type" => "text", "text" => "hi" } ] } }
      })
    end

    # A nil timeout waits on the client indefinitely
    result = @control.run("nice-cactus#1", "browser_eval", { "action" => "eval" }, nil)

    assert_equal [ :ok, { "result" => { "content" => [ { "type" => "text", "text" => "hi" } ] } } ], result
  end

  def test_run_forwards_the_command_with_sid_and_input
    commands = Queue.new

    fake_client("nice-cactus") do |message, reply_stream|
      commands << message
      @control.server.broadcast(reply_stream, { "type" => "ack" })
      @control.server.broadcast(reply_stream, { "type" => "tool_reply", "ref" => message["ref"], "reply" => {} })
    end

    @control.run("nice-cactus#2", "browser_eval", { "action" => "eval" }, 5_000)

    command = commands.pop(timeout: 2)
    assert_equal "run_tool", command["type"]
    assert_equal "browser_eval", command["name"]
    assert_equal "nice-cactus#2", command["sid"]
    assert_equal({ "action" => "eval" }, command["input"])
  end

  def test_run_times_out_when_the_client_does_not_reply
    fake_client("nice-cactus") do |_message, reply_stream|
      @control.server.broadcast(reply_stream, { "type" => "ack" })
    end

    result = @control.run("nice-cactus#1", "browser_eval", {}, 300)

    assert_equal [ :error, :timeout ], result
  end

  def test_run_reports_a_disconnected_client
    fake_client("nice-cactus") do |_message, reply_stream|
      @control.server.broadcast(reply_stream, { "type" => "ack" })
      @control.server.broadcast(reply_stream, { "type" => "disconnected" })
    end

    result = @control.run("nice-cactus#1", "browser_eval", {}, 5_000)

    assert_equal [ :error, :disconnected ], result
  end

  def test_broadcast_run_returns_the_first_reply
    fake_client("nice-cactus", stream: Tidewave::BrowserControl::CLIENTS_STREAM) do |message, reply_stream|
      @control.server.broadcast(reply_stream, {
        "type" => "tool_reply",
        "ref" => message["ref"],
        "reply" => { "result" => { "content" => [] } }
      })
    end

    result = @control.broadcast_run("browser_eval", { "action" => "help" }, 5_000)

    assert_equal [ :ok, { "result" => { "content" => [] } } ], result
  end

  def test_broadcast_run_times_out_with_no_clients
    result = @control.broadcast_run("browser_eval", { "action" => "help" }, 300)

    assert_equal [ :error, :timeout ], result
  end

  private

  # Simulates a connected page at the pub/sub level: subscribes to the
  # client (or clients) stream and lets the block reply.
  def fake_client(name, stream: nil, &block)
    stream ||= Tidewave::BrowserControl.client_stream(name)
    ready = Queue.new

    on_command = lambda do |payload|
      message = JSON.parse(payload)
      block.call(message, Tidewave::BrowserControl.reply_stream(message["ref"]))
    end

    @control.server.pubsub.subscribe(stream, on_command, -> { ready << :ok })
    assert_equal :ok, ready.pop(timeout: 2)
  end
end

class TidewaveBrowserControlChannelTest < Minitest::Test
  def setup
    @control = Tidewave::BrowserControl.new(cable: { "adapter" => "async" }, ack_timeout: 0.2)
  end

  def test_hello_registers_the_client_and_confirms
    channel, connection = subscribe_channel

    channel.perform_action({ "type" => "hello", "name" => "pretty-fox" })

    assert_equal({ "type" => "hello_ok", "name" => "pretty-fox" }, next_message(connection))
  end

  def test_hello_rejects_a_taken_name
    channel1, connection1 = subscribe_channel
    channel1.perform_action({ "type" => "hello", "name" => "pretty-fox" })
    next_message(connection1)

    channel2, connection2 = subscribe_channel
    channel2.perform_action({ "type" => "hello", "name" => "pretty-fox" })

    assert_equal({ "type" => "hello_error", "reason" => "name_taken" }, next_message(connection2))
  end

  def test_the_name_is_freed_on_unsubscribe
    channel1, connection1 = subscribe_channel
    channel1.perform_action({ "type" => "hello", "name" => "pretty-fox" })
    next_message(connection1)
    channel1.unsubscribe_from_channel

    channel2, connection2 = subscribe_channel
    channel2.perform_action({ "type" => "hello", "name" => "pretty-fox" })

    assert_equal({ "type" => "hello_ok", "name" => "pretty-fox" }, next_message(connection2))
  end

  def test_run_round_trip_through_the_channel
    channel, connection = subscribe_channel
    channel.perform_action({ "type" => "hello", "name" => "pretty-fox" })
    next_message(connection)
    await_client_stream("pretty-fox")

    responder = Thread.new do
      run_tool = next_message(connection)
      channel.perform_action({
        "type" => "tool_reply",
        "ref" => run_tool["ref"],
        "reply" => { "result" => { "content" => [ { "type" => "text", "text" => "done" } ] } }
      })
      run_tool
    end

    result = @control.run("pretty-fox#1", "browser_eval", { "action" => "eval" }, 5_000)
    run_tool = responder.value

    assert_equal "run_tool", run_tool["type"]
    assert_equal "pretty-fox#1", run_tool["sid"]
    assert_equal [ :ok, { "result" => { "content" => [ { "type" => "text", "text" => "done" } ] } } ], result
  end

  def test_pending_commands_fail_as_disconnected_when_the_client_unsubscribes
    channel, connection = subscribe_channel
    channel.perform_action({ "type" => "hello", "name" => "pretty-fox" })
    next_message(connection)
    await_client_stream("pretty-fox")

    waiter = Thread.new { @control.run("pretty-fox#1", "browser_eval", {}, 5_000) }
    next_message(connection) # the command reached the page
    channel.unsubscribe_from_channel

    assert_equal [ :error, :disconnected ], waiter.value
  end

  def test_ping_messages_are_ignored
    channel, connection = subscribe_channel

    channel.perform_action({ "type" => "ping" })
    channel.perform_action({ "type" => "hello", "name" => "pretty-fox" })

    assert_equal({ "type" => "hello_ok", "name" => "pretty-fox" }, next_message(connection))
  end

  private

  # Stands in for ActionCable::Connection::Base, implementing the surface
  # the channel uses, so channel logic can be exercised without a socket.
  class StubConnection
    attr_reader :server, :transmissions

    def initialize(server)
      @server = server
      @transmissions = Queue.new
    end

    def identifiers = []
    def pubsub = server.pubsub
    def worker_pool = server.worker_pool
    def config = server.config

    # The worker pool tags the connection logger around handlers, so it
    # must be a TaggedLoggerProxy like on a real connection.
    def logger
      @logger ||= ActionCable::Connection::TaggedLoggerProxy.new(server.logger, tags: [])
    end

    def transmit(cable_message)
      @transmissions << cable_message
    end
  end

  def subscribe_channel
    connection = StubConnection.new(@control.server)
    channel = Tidewave::BrowserControl::Channel.new(connection, "{}")
    channel.subscribe_to_channel
    confirmation = connection.transmissions.pop(timeout: 2)
    assert_equal "confirm_subscription", confirmation&.fetch(:type)
    [ channel, connection ]
  end

  def next_message(connection)
    while (transmission = connection.transmissions.pop(timeout: 2))
      message = transmission.fetch(:message)
      return message unless message.is_a?(Hash) && message["name"] == PROBE_NAME
    end
  end

  PROBE_NAME = "__await_client_stream_probe__"

  # Waits until the channel's client-stream subscription is active, so a
  # subsequent run cannot race it. The channel registers the stream
  # asynchronously with no public signal, so we broadcast probe commands
  # until the channel acks one (next_message discards the probes).
  def await_client_stream(name)
    stream = Tidewave::BrowserControl.client_stream(name)
    ref = SecureRandom.random_number(2**53)
    replies = Queue.new
    on_reply = ->(payload) { replies << JSON.parse(payload) }

    @control.server.pubsub.subscribe(Tidewave::BrowserControl.reply_stream(ref), on_reply, -> { replies << :subscribed })
    assert_equal :subscribed, replies.pop(timeout: 2)

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2

    loop do
      @control.server.broadcast(stream, { "type" => "run_tool", "ref" => ref, "name" => PROBE_NAME })
      break if replies.pop(timeout: 0.05)
      flunk "timed out waiting for the client stream subscription" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    end
  ensure
    @control.server.pubsub.unsubscribe(Tidewave::BrowserControl.reply_stream(ref), on_reply)
  end
end

class TidewaveBrowserControlEndpointTest < Minitest::Test
  def setup
    downstream = ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "demo" ] ] }
    @app = Tidewave.new(
      downstream,
      allow_remote_access: true,
      project_name: "test-app",
      browser_control: Tidewave::BrowserControl.new(cable: { "adapter" => "async" })
    )
  end

  def test_ws_rejects_cross_site_requests
    status, _headers, body = perform_request(@app, path: "/tidewave/ws", fetch_site: "cross-site")

    assert_equal 403, status
    assert_includes body, "same origin"
  end

  def test_ws_allows_same_origin_requests
    status, _headers, _body = perform_request(@app, path: "/tidewave/ws", fetch_site: "same-origin")

    # Not an upgrade request, so Action Cable responds with 404 rather
    # than 403 from the fetch site check.
    assert_equal 404, status
  end

  def test_ws_allows_requests_without_fetch_metadata
    status, _headers, _body = perform_request(@app, path: "/tidewave/ws")

    assert_equal 404, status
  end

  def test_ws_rejects_remote_clients
    app = Tidewave.new(->(_env) { [ 200, {}, [] ] }, project_name: "test-app")

    status, _headers, _body = perform_request(app, path: "/tidewave/ws", remote_addr: "10.0.0.1")

    assert_equal 403, status
  end

  def test_ws_without_browser_control_raises
    app = Tidewave.new(->(_env) { [ 200, {}, [] ] }, allow_remote_access: true, project_name: "test-app")

    error = assert_raises(RuntimeError) { perform_request(app, path: "/tidewave/ws") }
    assert_includes error.message, "only supported for Rails"
  end

  private

  def perform_request(app, path:, fetch_site: nil, remote_addr: "127.0.0.1")
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => remote_addr)
    env["HTTP_SEC_FETCH_SITE"] = fetch_site if fetch_site

    status, headers, response = app.call(env)
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    [ status, headers, body ]
  end
end
