# frozen_string_literal: true
require_relative 'projects'
module WoodworkingAI
  # Public part lookup helpers; all mutations flow through Projects for synchronization.
  module Parts
    def self.all(project_id)
      WoodworkingAI.identifier(project_id, 'project_id')
      Projects.instances(Sketchup.active_model, project_id)
    end
    def self.find(project_id, part_id)
      WoodworkingAI.identifier(part_id, 'part_id')
      all(project_id).select { |part| part.get_attribute(DICTIONARY, 'part_id') == part_id }
    end
  end
end
