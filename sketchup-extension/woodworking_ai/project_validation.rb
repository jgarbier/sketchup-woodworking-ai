# frozen_string_literal: true
require 'json'
require_relative 'units'
require_relative 'metadata'
module WoodworkingAI
  module ProjectValidation
    # Validate the generated JSON Schema subset without third-party runtime gems.
    def self.schema
      @schema ||= JSON.parse(File.read(File.join(File.dirname(__FILE__), 'project.schema.json')))
    end

    def self.validate_value(value, rule, path = '$')
      case rule['type']
      when 'object'
        raise ArgumentError, "#{path} must be an object" unless value.is_a?(Hash)
        properties = rule.fetch('properties', {})
        raise ArgumentError, "#{path}: missing fields" unless (rule.fetch('required', []) - value.keys).empty?
        if rule['additionalProperties'] == false && !(value.keys - properties.keys).empty?
          raise ArgumentError, "#{path}: unknown fields"
        end
        value.each { |key, child| validate_value(child, properties[key], "#{path}.#{key}") if properties[key] }
      when 'array'
        raise ArgumentError, "#{path} must be an array" unless value.is_a?(Array)
        raise ArgumentError, "#{path}: too few items" if rule['minItems'] && value.length < rule['minItems']
        raise ArgumentError, "#{path}: too many items" if rule['maxItems'] && value.length > rule['maxItems']
        value.each_with_index { |child, index| validate_value(child, rule['items'], "#{path}[#{index}]") }
      when 'string'
        raise ArgumentError, "#{path} must be a string" unless value.is_a?(String)
        raise ArgumentError, "#{path}: too short" if rule['minLength'] && value.length < rule['minLength']
        raise ArgumentError, "#{path}: too long" if rule['maxLength'] && value.length > rule['maxLength']
        raise ArgumentError, "#{path}: invalid identifier" if rule['pattern'] && !value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}\z/)
      when 'number', 'integer'
        raise ArgumentError, "#{path} must be finite numeric inches" unless value.is_a?(Numeric) && value.to_f.finite?
        raise ArgumentError, "#{path} must be integer" if rule['type'] == 'integer' && value != value.to_i
        raise ArgumentError, "#{path} below minimum" if rule['minimum'] && value < rule['minimum']
        raise ArgumentError, "#{path} above maximum" if rule['maximum'] && value > rule['maximum']
        raise ArgumentError, "#{path} must be positive" if rule['exclusiveMinimum'] && value <= rule['exclusiveMinimum']
      else
        raise ArgumentError, "Unsupported schema type at #{path}"
      end
      raise ArgumentError, "#{path}: invalid choice" if rule['enum'] && !rule['enum'].include?(value)
      raise ArgumentError, "#{path}: expected #{rule['const']}" if rule.key?('const') && rule['const'] != value
    end

    def self.validate(project)
      validate_value(project, schema)
      ids = project['parts'].map { |part| part['id'] }
      materials = project['materials'].map { |material| material['id'] }
      raise ArgumentError, 'Duplicate IDs' if ids.uniq != ids || materials.uniq != materials
      project['parts'].each do |part|
        raise ArgumentError, 'Unknown material' unless materials.include?(part['material'])
        raise ArgumentError, 'Quantity needs explicit additional_positions' unless part['additional_positions'].size == part['quantity'] - 1
      end
      project['relationships'].each do |rel|
        raise ArgumentError, 'Unknown relationship part' unless ([rel['part_id']] + rel['depends_on'] - ids).empty?
      end
      raise ArgumentError, 'Maximum 500 physical parts' if project['parts'].sum { |part| part['quantity'] } > 500
      if (door_assemblies = project['door_assemblies'])
        da_ids = door_assemblies.map { |da| da['id'] }
        raise ArgumentError, 'Duplicate door assembly IDs' if da_ids.uniq != da_ids
        door_assemblies.each do |da|
          unknown = da['parts'] - ids
          raise ArgumentError, "Door assembly #{da['id']} references unknown parts: #{unknown.join(', ')}" unless unknown.empty?
        end
      end
      if (joints = project['joints'])
        joint_ids = joints.map { |j| j['id'] }
        raise ArgumentError, 'Duplicate joint IDs' if joint_ids.uniq != joint_ids
        joints.each do |j|
          raise ArgumentError, "Joint #{j['id']} references unknown part_a: #{j['part_a']}" unless ids.include?(j['part_a'])
          raise ArgumentError, "Joint #{j['id']} references unknown part_b: #{j['part_b']}" unless ids.include?(j['part_b'])
          raise ArgumentError, "Joint #{j['id']}: part_a and part_b must be different" if j['part_a'] == j['part_b']
        end
      end
      project
    end
  end
end
