# frozen_string_literal: true
module WoodworkingAI
  module Units
    def self.number(value, label, positive: false)
      unless value.is_a?(Numeric) && value.to_f.finite? && (!positive || value > 0)
        raise ArgumentError, "#{label} must be a finite #{positive ? 'positive ' : ''}number in inches"
      end
      value.to_f
    end

    def self.position(value)
      unless value.is_a?(Hash) && value.keys.sort == [:x, :y, :z]
        raise ArgumentError, 'position must contain exactly x, y, z in inches'
      end
      [:x, :y, :z].map { |axis| number(value.fetch(axis), "position.#{axis}") }
    end
  end
end
