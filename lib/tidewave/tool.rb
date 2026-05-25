# frozen_string_literal: true

class Tidewave
  class Tool
    class << self
      def descendants
        @descendants ||= []
      end

      def inherited(subclass)
        descendants << subclass
        super
      end
    end

    def definition
      raise NotImplementedError, "#{self.class} must implement #definition"
    end

    def call(_arguments = {})
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    def validate_and_call(arguments)
      arguments ||= {}

      unless arguments.is_a?(Hash)
        raise ArgumentError, "Invalid arguments: expected an object"
      end

      validate_schema(arguments, definition.fetch("inputSchema", {}))
      call(arguments)
    end

    private

    def validate_schema(value, schema, path = nil)
      return unless schema.is_a?(Hash)

      validate_type(value, schema["type"], path) if schema["type"]

      case schema["type"]
      when "object"
        validate_object(value, schema, path)
      when "array"
        validate_array(value, schema, path)
      end
    end

    def validate_object(value, schema, path)
      properties = schema.fetch("properties", {})

      properties.each do |name, property_schema|
        if !value.key?(name) && property_schema.is_a?(Hash) && property_schema.key?("default")
          validate_default(property_schema["default"], property_path(path, name))
          value[name] = property_schema["default"]
        end

        next unless value.key?(name)

        validate_schema(value[name], property_schema, property_path(path, name))
      end

      validate_required_properties(value, schema.fetch("required", []), path)
    end

    def validate_array(value, schema, path)
      item_schema = schema["items"]
      return unless item_schema.is_a?(Hash) && !item_schema.empty?

      value.each_with_index do |item, index|
        validate_schema(item, item_schema, "#{path || 'value'}[#{index}]")
      end
    end

    def validate_required_properties(value, required_properties, path)
      required_properties.each do |name|
        next if value.key?(name)

        raise ArgumentError, "Invalid arguments: missing required property '#{property_path(path, name)}'"
      end
    end

    def validate_type(value, type, path)
      return if value_matches_type?(value, type)

      raise ArgumentError, "Invalid arguments: property '#{path || 'value'}' must be #{article_for(type)} #{type}"
    end

    def value_matches_type?(value, type)
      case type
      when "object"
        value.is_a?(Hash)
      when "array"
        value.is_a?(Array)
      when "string"
        value.is_a?(String)
      when "integer"
        value.is_a?(Integer)
      when "boolean"
        value == true || value == false
      else
        true
      end
    end

    def property_path(path, name)
      path ? "#{path}.#{name}" : name
    end

    def article_for(type)
      %w[array integer object].include?(type) ? "an" : "a"
    end

    def validate_default(value, path)
      return unless value.is_a?(Hash) || value.is_a?(Array)

      raise ArgumentError, "Invalid tool definition: property '#{path}' cannot use an object or array default"
    end
  end
end
