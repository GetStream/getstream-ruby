# frozen_string_literal: true

module GetStreamRuby
  class StreamResponse
    def initialize(data)
      @data = data
    end

    def method_missing(method_name, *args, &block)
      key = method_name.to_s
      
      if @data.is_a?(Hash) && @data.key?(key)
        value = @data[key]
        # Recursively wrap nested hashes
        if value.is_a?(Hash)
          StreamResponse.new(value)
        elsif value.is_a?(Array)
          value.map { |item| item.is_a?(Hash) ? StreamResponse.new(item) : item }
        else
          value
        end
      elsif @data.is_a?(Hash) && @data.key?(key.to_sym)
        value = @data[key.to_sym]
        if value.is_a?(Hash)
          StreamResponse.new(value)
        elsif value.is_a?(Array)
          value.map { |item| item.is_a?(Hash) ? StreamResponse.new(item) : item }
        else
          value
        end
      else
        nil
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      key = method_name.to_s
      (@data.is_a?(Hash) && (@data.key?(key) || @data.key?(key.to_sym))) || super
    end

    def to_h
      @data
    end

    def to_json(*args)
      @data.to_json(*args)
    end

    def inspect
      "#<GetStreamRuby::StreamResponse:0x#{object_id.to_s(16)} @data=#{@data.inspect}>"
    end
  end
end
