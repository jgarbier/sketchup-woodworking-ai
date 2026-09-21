# frozen_string_literal: true
require_relative 'units'
require_relative 'metadata'

module WoodworkingAI
  def self.create_board(id:, name:, length:, width:, thickness:, position:, project_id: 'tabletop-checkpoint', manage_operation: true, instance_index: 0)
    identifier(id, 'id')
    identifier(project_id, 'project_id')
    raise ArgumentError, 'name must be a nonempty string' unless name.is_a?(String) && !name.strip.empty?
    l, w, t = [[:length, length], [:width, width], [:thickness, thickness]].map do |key, value|
      Units.number(value, key, positive: true)
    end
    xyz = Units.position(position)
    model = Sketchup.active_model
    raise 'No active SketchUp model' unless model
    raise 'Close the active component editing context first' if model.active_path
    matches = model.entities.grep(Sketchup::ComponentInstance).select do |entity|
      entity.get_attribute(DICTIONARY, 'project_id') == project_id &&
        entity.get_attribute(DICTIONARY, 'part_id') == id &&
        entity.get_attribute(DICTIONARY, 'instance_index', 0) == instance_index
    end
    raise 'Duplicate owned part IDs; resolve before updating' if matches.length > 1
    existing = matches.first
    raise 'Owned part is locked' if existing && existing.locked?
    started = false
    begin
      if manage_operation
        model.start_operation('Woodworking AI — Create or Update Board', true)
        started = true
      end
      group = model.entities.add_group
      face = group.entities.add_face([0, 0, 0], [l, 0, 0], [l, w, 0], [0, w, 0])
      raise 'SketchUp could not create the board face' unless face
      face.reverse! if face.normal.z < 0
      face.pushpull(t)
      fresh = group.to_component
      if existing
        existing.definition = fresh.definition
        fresh.erase!
        part = existing
      else
        part = fresh
      end
      part.name = name
      part.definition.name = "#{project_id}/#{id}"
      part.transformation = Geom::Transformation.translation(xyz)
      {'project_id' => project_id, 'part_id' => id, 'part_type' => 'board',
       'material' => 'unspecified', 'units' => 'inches', 'instance_index' => instance_index,
       'length' => l, 'width' => w, 'thickness' => t}.each do |key, value|
        part.set_attribute(DICTIONARY, key, value)
      end
      model.commit_operation if manage_operation
      started = false
      part
    rescue StandardError
      model.abort_operation if started
      raise
    end
  end
end
