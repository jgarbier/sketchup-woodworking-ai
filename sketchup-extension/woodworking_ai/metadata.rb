# frozen_string_literal: true
module WoodworkingAI
  DICTIONARY = 'woodworking_ai' unless const_defined?(:DICTIONARY)
  def self.identifier(value, label)
    unless value.is_a?(String) && value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}\z/)
      raise ArgumentError, "#{label} must be a stable alphanumeric identifier"
    end
    value
  end
end
