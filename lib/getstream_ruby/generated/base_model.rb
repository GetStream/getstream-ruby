# frozen_string_literal: true

module GetStream
  # Base model class for all generated models
  class BaseModel
    def initialize(attributes = {})
      # Set attributes from hash
      attributes.each do |key, value|
        method_name = "#{key}="
        if respond_to?(method_name)
          send(method_name, value)
        end
      end
    end

    # Class method to define which fields should be omitted when empty (like Go's omitempty)
    # Override this in subclasses to specify fields that should be excluded from JSON serialization when empty
    # @return [Array<Symbol>] Array of field names to omit when empty
    def self.omit_empty_fields
      []
    end

    # Convert to hash (used for equality, inspect, etc.)
    def to_h
      instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete('@').to_sym
        value = instance_variable_get(var)
        hash[key] = value
      end
    end

    # Convert to JSON with optional field filtering
    # This is the Ruby-idiomatic way: filter only for JSON, keep to_h clean
    # Automatically omits nil values (optional fields default to nil, like Go pointers)
    def to_json(*args)
      hash = to_h
      omit_fields = self.class.omit_empty_fields
      
      # Filter out nil values and empty fields for JSON serialization
      hash = hash.reject do |key, value|
        # Always omit nil values (optional fields default to nil)
        next true if value.nil?
        
        # For fields in omit_empty_fields, also omit empty strings/arrays/hashes
        if omit_fields.include?(key)
          value == "" || (value.respond_to?(:empty?) && value.empty?)
        else
          false
        end
      end
      
      hash.to_json(*args)
    end

    # Equality comparison
    def ==(other)
      return false unless other.is_a?(self.class)
      to_h == other.to_h
    end

    # String representation
    def inspect
      "#<#{self.class.name} #{to_h.inspect}>"
    end
  end
end
