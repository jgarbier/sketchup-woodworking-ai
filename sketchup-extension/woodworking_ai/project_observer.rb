# frozen_string_literal: true
require_relative 'projects'
module WoodworkingAI
  class ProjectObserver < Sketchup::ModelObserver
    def initialize(model)
      @model = model
      @known = {}
      refresh
    end

    def refresh
      dictionary = @model.attribute_dictionary(Projects::DICT)
      dictionary.each_pair { |id, value| @known[id] = JSON.parse(value)['revision'] } if dictionary
    end

    def sync
      @known.each do |id, revision|
        directory = Projects.path(id)
        disk_path = File.join(directory, 'state.json')
        disk = File.exist?(disk_path) && JSON.parse(File.read(disk_path))
        # Never overwrite a project claimed by another model or external edit.
        raise "Cannot synchronize #{id}: project files changed externally" if disk && disk['revision'] != revision
        value = @model.get_attribute(Projects::DICT, id)
        if value
          state = JSON.parse(value)
          Projects.write(id, state)
          @known[id] = state['revision']
          manifest = File.join(directory, 'export-status.json')
          if File.exist?(manifest) && !File.symlink?(manifest)
            File.write(manifest, JSON.pretty_generate(revision: state['revision'], complete: false, reason: 'Undo/Redo changed the project. Run export_project to refresh outputs.'))
          end
        else
          %w[state.json project.yaml].each do |name|
            file = File.join(directory, name)
            File.delete(file) if File.exist?(file)
          end
        end
      end
    rescue StandardError => e
      warn "Woodworking AI project synchronization failed: #{e.message}"
    end

    def onTransactionUndo(model)
      sync
    end

    def onTransactionRedo(model)
      sync
    end
  end

  def self.watch_projects(model)
    @project_observers ||= {}
    unless @project_observers[model]
      observer = ProjectObserver.new(model)
      model.add_observer(observer)
      @project_observers[model] = observer
    end
    @project_observers[model].refresh
  end
end
