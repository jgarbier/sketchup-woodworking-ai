# frozen_string_literal: true
require_relative 'geometry'
require_relative 'projects'
require_relative 'exporter'
require_relative 'drawers'
module WoodworkingAI
  module CommandRouter
    def self.exact_keys(value, required, optional = [])
      raise ArgumentError, 'Expected a JSON object' unless value.is_a?(Hash)
      raise ArgumentError, 'Missing required fields' unless (required - value.keys).empty?
      raise ArgumentError, 'Unknown fields' unless (value.keys - required - optional).empty?
    end

    def self.validate(request)
      exact_keys(request, %w[request_id command params])
      WoodworkingAI.identifier(request['request_id'], 'request_id')
      params = request['params']
      case request['command']
      when 'sketchup_status'
        exact_keys(params, [])
      when 'create_board'
        exact_keys(params, %w[project_id id name length width thickness position])
        WoodworkingAI.identifier(params['project_id'], 'project_id')
        WoodworkingAI.identifier(params['id'], 'id')
        raise ArgumentError, 'Invalid name' unless params['name'].is_a?(String) && params['name'].size.between?(1, 256) && !params['name'].strip.empty?
        %w[length width thickness].each { |key| Units.number(params[key], key, positive: true) }
        exact_keys(params['position'], %w[x y z])
        Units.position(params['position'].transform_keys(&:to_sym))
      when 'create_project'
        exact_keys(params, %w[definition expected_revision])
        raise ArgumentError, 'Invalid revision' unless params['expected_revision'].nil? || params['expected_revision'].is_a?(String)
        ProjectValidation.validate(params['definition'])
      when 'fit_camera', 'render_view'
        exact_keys(params, %w[project_id view])
        WoodworkingAI.identifier(params['project_id'], 'project_id')
        allowed = request['command'] == 'fit_camera' ? %w[perspective front right top] : Scenes::VIEWS
        raise ArgumentError, 'Invalid view' unless allowed.include?(params['view'])
      when 'get_model', 'get_parts', 'get_model_summary', 'save_model', 'export_project'
        exact_keys(params, %w[project_id])
        WoodworkingAI.identifier(params['project_id'], 'project_id')
      when 'update_part', 'move_part', 'delete_part'
        extra = {'update_part' => %w[changes], 'move_part' => %w[position additional_positions], 'delete_part' => []}.fetch(request['command'])
        exact_keys(params, %w[project_id id expected_revision] + extra)
        WoodworkingAI.identifier(params['project_id'], 'project_id')
        WoodworkingAI.identifier(params['id'], 'id')
        raise ArgumentError, 'Invalid revision' unless params['expected_revision'].is_a?(String)
        if request['command'] == 'update_part'
          raise ArgumentError, 'Empty changes' unless params['changes'].is_a?(Hash) && !params['changes'].empty?
          allowed = %w[name type material quantity dimensions position rotation additional_positions stock_type grain_direction notes]
          raise ArgumentError, 'Unknown changes' unless (params['changes'].keys - allowed).empty?
        end
      when 'get_part'
        exact_keys(params, %w[project_id id])
        WoodworkingAI.identifier(params['project_id'], 'project_id')
        WoodworkingAI.identifier(params['id'], 'id')
      when 'calculate_drawer'
        exact_keys(params, %w[opening_width opening_height opening_depth drawer_count slide_type face_style],
                           %w[gap_between box_thickness face_thickness])
        %w[opening_width opening_height opening_depth].each { |k| Units.number(params[k], k, positive: true) }
        unless params['drawer_count'].is_a?(Numeric) && params['drawer_count'] == params['drawer_count'].to_i &&
               params['drawer_count'].between?(1, 20)
          raise ArgumentError, 'drawer_count must be an integer between 1 and 20'
        end
        raise ArgumentError, "slide_type must be one of: #{Drawers::SLIDE_CLEARANCES.keys.join(', ')}" unless Drawers::SLIDE_CLEARANCES.key?(params['slide_type'])
        raise ArgumentError, "face_style must be one of: #{Drawers::OVERLAY_AMOUNTS.keys.join(', ')}" unless Drawers::OVERLAY_AMOUNTS.key?(params['face_style'])
        %w[gap_between box_thickness face_thickness].each { |k| Units.number(params[k], k, positive: true) if params.key?(k) }
      when 'add_cutout'
        base = %w[project_id part_id shape face x y depth]
        optional = %w[radius width height]
        exact_keys(params, base, optional)
        WoodworkingAI.identifier(params['project_id'], 'project_id')
        WoodworkingAI.identifier(params['part_id'], 'part_id')
        raise ArgumentError, "shape must be 'circle' or 'rectangle'" unless %w[circle rectangle].include?(params['shape'])
        raise ArgumentError, "face must be one of: #{WoodworkingAI::FACE_NORMALS.keys.join(', ')}" unless WoodworkingAI::FACE_NORMALS.key?(params['face'])
        %w[x y depth].each { |k| Units.number(params[k], k) }
        Units.number(params['depth'], 'depth', positive: true)
        if params['shape'] == 'circle'
          raise ArgumentError, 'radius is required for circle cutouts' unless params['radius']
          Units.number(params['radius'], 'radius', positive: true)
        else
          raise ArgumentError, 'width and height are required for rectangle cutouts' unless params['width'] && params['height']
          Units.number(params['width'], 'width', positive: true)
          Units.number(params['height'], 'height', positive: true)
        end
      else
        raise ArgumentError, 'Unknown command'
      end
      request
    end

    def self.describe(part)
      bounds = part.bounds
      local = part.definition.bounds
      {instance_index: part.get_attribute(DICTIONARY, 'instance_index', 0),
       cut_dimensions: {length: local.width.to_f, width: local.height.to_f, thickness: local.depth.to_f},
       part_id: part.get_attribute(DICTIONARY, 'part_id'),
       project_id: part.get_attribute(DICTIONARY, 'project_id'), name: part.name,
       dimensions: {length: bounds.width.to_f, width: bounds.height.to_f, thickness: bounds.depth.to_f},
       units: 'inches', solid: part.manifold?}
    end

    def self.call(request)
      validate(request)
      params = request['params']
      result = case request['command']
      when 'sketchup_status'
        {connected: true, sketchup_version: Sketchup.version, units: 'inches',
         bridge_version: 3, commands: %w[sketchup_status create_board get_part create_project get_model get_parts update_part move_part delete_part fit_camera render_view save_model export_project get_model_summary add_cutout calculate_drawer]}
      when 'create_board'
        raise ArgumentError, 'Use project tools to modify managed projects' if Sketchup.active_model.get_attribute(Projects::DICT, params['project_id'])
        args = params.transform_keys(&:to_sym)
        args[:position] = args[:position].transform_keys(&:to_sym)
        part = WoodworkingAI.create_board(**args)
        {success: true, affected_part_ids: [params['id']],
         resulting_dimensions: describe(part)[:dimensions], warnings: []}
      when 'create_project'
        Projects.apply(params['definition'], params['expected_revision'])
      when 'fit_camera'
        Scenes.fit(params['project_id'], params['view'])
      when 'render_view'
        id = params['project_id']
        files = Scenes.render(id, File.join(Projects.path(id),'renders'), [params['view']])
        {success: true, affected_part_ids: [], resulting_dimensions: Projects.read(id)['definition']['overall'], warnings: [], files: files}
      when 'save_model'
        id = params['project_id']
        state = Projects.read(id)
        {success: true, affected_part_ids: [], resulting_dimensions: state['definition']['overall'], warnings: ['Active document includes unrelated geometry.'], model_file: Exporter.save_model(id)}
      when 'export_project'
        Exporter.export(params['project_id'])
      when 'get_model_summary'
        id = params['project_id']
        parts = Projects.instances(Sketchup.active_model,id)
        box = Scenes.bounds(parts)
        {revision: Projects.read(id)['revision'], physical_part_count: parts.size,
         persistent_ids: parts.map(&:persistent_id),
         bounds: parts.empty? ? nil : {width: box.width.to_f, depth: box.height.to_f, height: box.depth.to_f},
         owned_scene_count: Sketchup.active_model.pages.count { |page| page.get_attribute(DICTIONARY,'project_id') == id },
         total_root_entities: Sketchup.active_model.entities.length}
      when 'get_model'
        value = Sketchup.active_model.get_attribute(Projects::DICT, params['project_id'])
        value ? JSON.parse(value) : {'revision' => nil, 'definition' => nil}
      when 'get_parts'
        {parts: Projects.instances(Sketchup.active_model, params['project_id']).map { |part| describe(part) }}
      when 'update_part', 'move_part', 'delete_part'
        Projects.edit(params, request['command'])
      when 'get_part'
        matches = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select do |part|
          part.get_attribute(DICTIONARY, 'project_id') == params['project_id'] &&
            part.get_attribute(DICTIONARY, 'part_id') == params['id']
        end
        raise ArgumentError, 'Part not found' if matches.empty?
        matches.size == 1 ? describe(matches.first) : {instances: matches.map { |part| describe(part) }}
      when 'calculate_drawer'
        args = params.transform_keys(&:to_sym)
        args[:drawer_count] = args[:drawer_count].to_i
        Drawers.calculate(**args)
      when 'add_cutout'
        WoodworkingAI.add_cutout(**params.transform_keys(&:to_sym))
      end
      {request_id: request['request_id'], success: true, result: result}
    rescue StandardError => e
      {request_id: request.is_a?(Hash) ? request['request_id'] : nil,
       success: false, error: {code: e.is_a?(ArgumentError) ? 'INVALID_REQUEST' : 'SKETCHUP_ERROR', message: e.message}}
    end
  end
end
