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

    # Convert to hash
    def to_h
      instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete('@').to_sym
        value = instance_variable_get(var)
        hash[key] = value
      end
    end

    # Convert to JSON
    def to_json(*args)
      to_h.to_json(*args)
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
