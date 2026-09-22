# frozen_string_literal: true
require 'json'
require 'yaml'
require 'securerandom'
require 'fileutils'
require_relative 'project_validation'
require_relative 'geometry'
require_relative 'drawers'
module WoodworkingAI
  module Projects
    DICT = 'woodworking_ai_projects' unless const_defined?(:DICT, false)
    ROOT = File.expand_path('../../projects', File.dirname(File.realpath(__FILE__))) unless const_defined?(:ROOT, false)

    def self.read(id)
      WoodworkingAI.identifier(id, 'project_id')
      value = Sketchup.active_model.get_attribute(DICT, id)
      raise ArgumentError, 'Project not found in active model' unless value
      WoodworkingAI.watch_projects(Sketchup.active_model) if WoodworkingAI.respond_to?(:watch_projects)
      JSON.parse(value)
    end

    def self.path(id)
      WoodworkingAI.identifier(id, 'project_id')
      directory = File.join(ROOT, id)
      raise 'Project root cannot be a symlink' if File.symlink?(ROOT)
      raise 'Project directory cannot be a symlink' if File.symlink?(directory)
      FileUtils.mkdir_p(directory)
      %w[project.yaml state.json].each do |file|
        raise 'Project output cannot be a symlink' if File.symlink?(File.join(directory, file))
      end
      directory
    end

    def self.write(id, state)
      directory = path(id)
      # State is the recovery authority; YAML is a human-readable mirror.
      values = {'state.json' => JSON.pretty_generate(state), 'project.yaml' => YAML.dump(state['definition'])}
      values.each do |name, content|
        temp = File.join(directory, ".#{name}.#{SecureRandom.hex(6)}.tmp")
        begin
          File.write(temp, content)
          File.rename(temp, File.join(directory, name))
        ensure
          File.delete(temp) if File.exist?(temp)
        end
      end
    end

    def self.door_assembly_groups(model, id)
      model.entities.grep(Sketchup::Group).select do |g|
        g.get_attribute(DICTIONARY, 'project_id') == id && g.get_attribute(DICTIONARY, 'door_assembly_id')
      end
    end

    def self.drawer_assembly_groups(model, id)
      model.entities.grep(Sketchup::Group).select do |g|
        g.get_attribute(DICTIONARY, 'project_id') == id && g.get_attribute(DICTIONARY, 'drawer_assembly_id')
      end
    end

    def self.instances(model, id)
      flat = model.entities.grep(Sketchup::ComponentInstance).select { |e| e.get_attribute(DICTIONARY, 'project_id') == id }
      nested = (door_assembly_groups(model, id) + drawer_assembly_groups(model, id)).flat_map do |g|
        g.entities.grep(Sketchup::ComponentInstance).select { |e| e.get_attribute(DICTIONARY, 'project_id') == id }
      end
      flat + nested
    end

    def self.transform(part, spec, position)
      rotation = spec['rotation']
      rx = Geom::Transformation.rotation([0,0,0], [1,0,0], rotation['x'] * Math::PI / 180)
      ry = Geom::Transformation.rotation([0,0,0], [0,1,0], rotation['y'] * Math::PI / 180)
      rz = Geom::Transformation.rotation([0,0,0], [0,0,1], rotation['z'] * Math::PI / 180)
      rotation_matrix = rz * ry * rx
      bounds = part.definition.bounds
      corners = (0..7).map { |i| bounds.corner(i).transform(rotation_matrix) }
      minimum = [:x,:y,:z].map { |axis| corners.map { |point| point.send(axis) }.min }
      target = %w[x y z].each_with_index.map { |axis, index| position[axis] - minimum[index] }
      part.transformation = Geom::Transformation.translation(target) * rotation_matrix
    end

    def self.apply(definition, expected_revision)
      ProjectValidation.validate(definition)
      model = Sketchup.active_model
      raise 'Close the active component editing context first' if model.active_path
      id = definition['project']['id']
      old_json = model.get_attribute(DICT, id)
      old = old_json && JSON.parse(old_json)
      raise ArgumentError, 'Revision conflict; read project before editing' unless (old && old['revision']) == expected_revision
      directory = path(id)
      disk_path = File.join(directory, 'state.json')
      if File.exist?(disk_path)
        disk = JSON.parse(File.read(disk_path))
        raise 'Project files differ from active model; resolve before editing' unless old && disk['revision'] == old['revision']
      end
      # Remove door/drawer assembly groups for assemblies no longer in the definition before
      # collecting owned instances, so stale nested instances don't pollute the owned set.
      current_da_keys  = (definition['door_assemblies']   || []).map { |da| "#{id}/#{da['id']}" }
      current_dra_keys = (definition['drawer_assemblies'] || []).map { |da| "#{id}/#{da['id']}" }
      model.entities.grep(Sketchup::Group).each do |g|
        next unless g.get_attribute(DICTIONARY, 'project_id') == id
        da_key  = g.get_attribute(DICTIONARY, 'door_assembly_id').to_s
        dra_key = g.get_attribute(DICTIONARY, 'drawer_assembly_id').to_s
        g.erase! if (!da_key.empty?  && !current_da_keys.include?(da_key)) ||
                    (!dra_key.empty? && !current_dra_keys.include?(dra_key))
      end
      owned = instances(model, id)
      raise 'Owned component is locked' if owned.any?(&:locked?)
      keys = owned.map { |e| [e.get_attribute(DICTIONARY, 'part_id'), e.get_attribute(DICTIONARY, 'instance_index', 0)] }
      raise 'Duplicate owned instance IDs' unless keys.uniq == keys
      state = {'revision' => SecureRandom.uuid, 'definition' => definition}
      previous_files = %w[project.yaml state.json].to_h { |name| [name, File.exist?(File.join(directory, name)) ? File.binread(File.join(directory, name)) : nil] }
      started = false
      begin
        write(id, state) # Persist design intent before touching geometry.
        model.start_operation('Woodworking AI — Update Project', true)
        started = true
        model.set_attribute(DICT, id, JSON.generate(state))
        keep = []
        definition['parts'].each do |spec|
          ([spec['position']] + spec['additional_positions']).each_with_index do |position, index|
            dimensions = spec['dimensions']
            part = WoodworkingAI.create_board(id: spec['id'], project_id: id, name: spec['name'],
              length: dimensions['length'], width: dimensions['width'], thickness: dimensions['thickness'],
              position: {x:0,y:0,z:0}, manage_operation: false, instance_index: index)
            transform(part, spec, position)
            part.set_attribute(DICTIONARY, 'material', spec['material'])
            part.set_attribute(DICTIONARY, 'part_type', spec['type'])
            part.set_attribute(DICTIONARY, 'specification', JSON.generate(spec))
            keep << part
          end
        end
        # Move door assembly parts into named SketchUp groups.
        (definition['door_assemblies'] || []).each do |da|
          da_key = "#{id}/#{da['id']}"
          group = model.entities.grep(Sketchup::Group).find { |g| g.get_attribute(DICTIONARY, 'door_assembly_id') == da_key }
          unless group
            group = model.entities.add_group
            group.name = da['name']
            group.set_attribute(DICTIONARY, 'door_assembly_id', da_key)
            group.set_attribute(DICTIONARY, 'project_id', id)
            group.set_attribute(DICTIONARY, 'door_swing', da['swing'])
          end
          da['parts'].each do |pid|
            keep.select { |inst| inst.valid? && inst.get_attribute(DICTIONARY, 'part_id') == pid }.each do |inst|
              new_inst = group.entities.add_instance(inst.definition, inst.transformation)
              inst.attribute_dictionaries&.each { |dict| dict.each_pair { |k, v| new_inst.set_attribute(dict.name, k, v) } }
              new_inst.set_attribute(DICTIONARY, 'door_assembly_id', da_key)
              keep << new_inst
              keep.delete(inst)
              inst.erase!
            end
          end
        end
        # Move drawer assembly parts into named SketchUp groups.
        (definition['drawer_assemblies'] || []).each do |da|
          dra_key = "#{id}/#{da['id']}"
          group = model.entities.grep(Sketchup::Group).find { |g| g.get_attribute(DICTIONARY, 'drawer_assembly_id') == dra_key }
          unless group
            group = model.entities.add_group
            group.name = "Drawer — #{da['name']}"
            group.set_attribute(DICTIONARY, 'drawer_assembly_id', dra_key)
            group.set_attribute(DICTIONARY, 'project_id', id)
            group.set_attribute(DICTIONARY, 'drawer_slide_type', da['slide_type'])
            group.set_attribute(DICTIONARY, 'drawer_extension', da['extension'] || 'full')
          end
          da['parts'].each do |pid|
            keep.select { |inst| inst.valid? && inst.get_attribute(DICTIONARY, 'part_id') == pid }.each do |inst|
              new_inst = group.entities.add_instance(inst.definition, inst.transformation)
              inst.attribute_dictionaries&.each { |dict| dict.each_pair { |k, v| new_inst.set_attribute(dict.name, k, v) } }
              new_inst.set_attribute(DICTIONARY, 'drawer_assembly_id', dra_key)
              keep << new_inst
              keep.delete(inst)
              inst.erase!
            end
          end
        end
        owned.each { |part| part.erase! if part.valid? && !keep.include?(part) }
        Joinery.render(model, id, definition) if defined?(Joinery)
        model.commit_operation
        started = false
      rescue StandardError
        model.abort_operation if started
        previous_files.each do |name, data|
          target = File.join(directory, name)
          data ? File.binwrite(target, data) : (File.delete(target) if File.exist?(target))
        end
        raise
      end
      WoodworkingAI.watch_projects(model) if WoodworkingAI.respond_to?(:watch_projects)
      result = {success: true, affected_part_ids: (keys.map(&:first) + definition['parts'].map { |p| p['id'] }).uniq,
       resulting_dimensions: definition['overall'], revision: state['revision'],
       warnings: ['Run export_project to generate the first output set.'],
       project_file: File.join(directory, 'project.yaml')}
      if defined?(Exporter) && File.exist?(File.join(directory, 'export-status.json'))
        begin
          result[:export] = Exporter.export(id, transparent_operation: true)
          result[:warnings] = result[:export][:warnings]
        rescue StandardError => e
          # Geometry is committed. Report partial export explicitly; never pretend rollback.
          result[:warnings] = ["Geometry updated, but outputs need regeneration: #{e.message}"]
          result[:export_complete] = false
        end
      end
      result
    end

    def self.edit(params, command)
      state = read(params['project_id'])
      raise ArgumentError, 'Revision conflict' unless state['revision'] == params['expected_revision']
      definition = state['definition']
      part = definition['parts'].find { |p| p['id'] == params['id'] }
      raise ArgumentError, 'Part not found' unless part
      case command
      when 'update_part'
        params['changes'].each { |key, value| part[key] = value }
      when 'move_part'
        part['position'] = params['position']
        part['additional_positions'] = params['additional_positions']
      when 'delete_part'
        definition['parts'].delete(part)
        definition['relationships'].reject! { |r| r['part_id'] == part['id'] }
        definition['relationships'].each { |r| r['depends_on'].delete(part['id']) }
      end
      apply(definition, params['expected_revision'])
    end
  end
end
