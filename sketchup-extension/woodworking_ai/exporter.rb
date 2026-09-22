# frozen_string_literal: true
require_relative 'scenes'
require_relative 'reports'
module WoodworkingAI
  module Exporter
    def self.safe_file(directory, name)
      path = File.join(directory, name)
      raise 'Output cannot be symlinked' if File.symlink?(path)
      path
    end
    def self.save_model(id)
      path = safe_file(Projects.path(id), 'bench.skp')
      model = Sketchup.active_model
      saved = (model.path.empty? || File.expand_path(model.path) == File.expand_path(path)) ? model.save(path) : model.save_copy(path)
      raise 'SketchUp model save failed' unless saved
      path
    end
    def self.export(id, transparent_operation: false)
      state = Projects.read(id)
      definition = state['definition']
      directory = Projects.path(id)
      manifest = safe_file(directory, 'export-status.json')
      File.write(manifest, JSON.pretty_generate(revision: state['revision'], complete: false))
      File.write(safe_file(directory,'cut-list.csv'), Reports.cut_list(definition))
      File.write(safe_file(directory,'bill-of-materials.csv'), Reports.bom(definition))
      File.write(safe_file(directory,'joinery-schedule.csv'), Reports.joinery_schedule(definition))
      File.write(safe_file(directory,'build-plan.md'), Reports.build_plan(definition))
      files = []
      if definition['parts'].empty?
        # An empty project cannot produce meaningful cameras; invalidate prior outputs.
        warnings = ['Project has no parts; views were not rendered. Previous renders are stale.']
      else
        files = Scenes.render(id, File.join(directory,'renders'), Scenes::VIEWS, transparent_operation: transparent_operation)
        warnings = ['SKP preserves unrelated geometry in the active model; PNG views isolate this project.']
      end
      model_path = save_model(id)
      complete = !definition['parts'].empty?
      File.write(manifest, JSON.pretty_generate(revision: state['revision'], complete: complete, files: files + [model_path]))
      {success: true, affected_part_ids: [], resulting_dimensions: definition['overall'], warnings: warnings,
       revision: state['revision'], directory: directory, model_file: model_path, render_files: files, complete: complete}
    end
  end
end
