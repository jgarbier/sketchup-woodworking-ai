# frozen_string_literal: true
require 'json'
require_relative 'geometry'
module WoodworkingAI
  def self.verify_tabletop
    part = WoodworkingAI.create_board(id: 'top', name: 'Checkpoint Tabletop 48 × 18 × 1',
      length: 48, width: 18, thickness: 1, position: {x: 0, y: 0, z: 0})
    bounds = part.bounds
    measured = [bounds.width.to_f, bounds.height.to_f, bounds.depth.to_f]
    raise "Unexpected bounds: #{measured.inspect}" unless measured.zip([48, 18, 1]).all? { |a, b| (a-b).abs < 0.0001 }
    raise 'Board is not a closed solid' unless part.manifold?
    count = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).count do |e|
      e.get_attribute('woodworking_ai', 'project_id') == 'tabletop-checkpoint' &&
        e.get_attribute('woodworking_ai', 'part_id') == 'top'
    end
    raise "Expected one owned part, found #{count}" unless count == 1
    Sketchup.active_model.active_view.zoom(part)
    return Hash[success: true, affected_part_ids: ['top'],
      resulting_dimensions: {length: measured[0], width: measured[1], thickness: measured[2]}, warnings: []]
  end
end
