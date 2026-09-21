# frozen_string_literal: true
require_relative 'projects'
module WoodworkingAI
  module Scenes
    VIEWS = %w[perspective front right top exploded].freeze unless const_defined?(:VIEWS, false)

    def self.bounds(parts)
      box = Geom::BoundingBox.new
      parts.each { |part| box.add(part.bounds) }
      box
    end

    def self.camera(parts, name)
      box = bounds(parts)
      center = box.center
      distance = [box.diagonal.to_f * 2.0, 20.0].max
      direction = case name
                  when 'front' then [0,-1,0]
                  when 'right' then [1,0,0]
                  when 'top' then [0,0,1]
                  else [1,-1.5,1]
                  end
      vector = Geom::Vector3d.new(direction)
      vector.length = distance
      eye = center + vector
      camera = Sketchup::Camera.new(eye, center, name == 'top' ? [0,1,0] : [0,0,1], %w[perspective exploded].include?(name))
      unless camera.perspective?
        projected_width = name == 'right' ? box.height : box.width
        projected_height = name == 'top' ? box.height : box.depth
        camera.height = [projected_height.to_f, projected_width.to_f / 1.6, 1.0].max * 1.3
      end
      camera
    end

    def self.preview(model, id, parts)
      existing = model.entities.grep(Sketchup::Group).select { |e| e.get_attribute(DICTIONARY, 'preview_project_id') == id }
      raise 'Exploded preview is locked' if existing.any?(&:locked?)
      existing.each(&:erase!)
      group = model.entities.add_group
      group.name = "#{id} — Exploded Preview (not physical parts)"
      group.set_attribute(DICTIONARY, 'preview_project_id', id)
      box = bounds(parts)
      center = box.center
      spacing = [box.diagonal.to_f * 0.18, 6.0].max
      parts.each_with_index do |part, index|
        c = part.bounds.center
        offset = [:x,:y,:z].map do |axis|
          delta = c.send(axis) - center.send(axis)
          delta.abs < 0.01 ? 0 : (delta < 0 ? -spacing : spacing)
        end
        offset[2] += index * 0.35
        copy = group.entities.add_instance(part.definition, Geom::Transformation.translation(offset) * part.transformation)
        copy.name = part.name
        copy.material = part.material
        copy.set_attribute(DICTIONARY, 'preview_part_id', part.get_attribute(DICTIONARY, 'part_id'))
      end
      group.hidden = true
      group
    end

    def self.fit(id, name = 'perspective')
      parts = Projects.instances(Sketchup.active_model, id)
      raise ArgumentError, 'Project has no parts' if parts.empty?
      Sketchup.active_model.active_view.camera = camera(parts, name)
      {success: true, affected_part_ids: [], resulting_dimensions: Projects.read(id)['definition']['overall'], warnings: []}
    end

    def self.render(id, directory, names = VIEWS, transparent_operation: false)
      model = Sketchup.active_model
      raise 'Close active editing context before rendering' if model.active_path
      parts = Projects.instances(model, id)
      raise ArgumentError, 'Project has no parts' if parts.empty?
      names.each { |name| raise ArgumentError, 'Unknown view' unless VIEWS.include?(name) }
      FileUtils.mkdir_p(directory)
      raise 'Render directory cannot be symlinked' if File.symlink?(directory)
      view = model.active_view
      old_camera = view.camera
      old_visibility = model.entities.select { |e| e.respond_to?(:hidden?) }.to_h { |e| [e,e.hidden?] }
      old_options = {}
      desired_options = {'DrawGround'=>false, 'DrawHorizon'=>false, 'DisplaySketchAxes'=>false, 'BackgroundColor'=>Sketchup::Color.new(245,243,239)}
      options = model.rendering_options
      desired_options.each_key { |key| old_options[key] = options[key] if options.keys.include?(key) }
      started = false
      begin
        model.start_operation('Woodworking AI — Project Views', true, false, transparent_operation)
        started = true
        exploded = preview(model, id, parts) if names.include?('exploded')
        old_options.each_key { |key| options[key] = desired_options[key] }
        names.each do |name|
          model.entities.each do |entity|
            next unless entity.respond_to?(:hidden=)
            entity.hidden = name == 'exploded' ? entity != exploded : !parts.include?(entity)
          end
          visible = name == 'exploded' ? [exploded] : parts
          view.camera = camera(visible, name)
          view.refresh
          pages = model.pages.select { |page| page.get_attribute(DICTIONARY, 'project_id') == id && page.get_attribute(DICTIONARY, 'view') == name }
          raise 'Duplicate owned scenes' if pages.size > 1
          page = pages.first || model.pages.add("#{id} — #{name.capitalize}")
          page.set_attribute(DICTIONARY, 'project_id', id)
          page.set_attribute(DICTIONARY, 'view', name)
          page.use_camera = true
          page.use_hidden_objects = true
          page.use_hidden_geometry = true
          page.update
          file = File.join(directory, "#{name}.png")
          raise 'Render file cannot be symlinked' if File.symlink?(file)
          raise "PNG export failed: #{name}" unless view.write_image(filename: file, width: 1600, height: 1000, antialias: true)
        end
        old_visibility.each { |entity, hidden| entity.hidden = hidden if entity.valid? }
        exploded.hidden = true if exploded
        old_options.each { |key, value| options[key] = value }
        view.camera = camera(parts, 'perspective')
        model.commit_operation
        started = false
      rescue StandardError
        model.abort_operation if started
        view.camera = old_camera
        raise
      ensure
        old_visibility.each { |entity, hidden| entity.hidden = hidden if entity.valid? }
        old_options.each { |key, value| options[key] = value }
      end
      FileUtils.cp(File.join(directory, 'right.png'), File.join(directory, 'side.png')) if names.include?('right')
      names.map { |name| File.join(directory, "#{name}.png") }
    end
  end
end
