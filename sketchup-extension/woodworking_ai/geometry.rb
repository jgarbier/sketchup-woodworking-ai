# frozen_string_literal: true
require_relative 'units'
require_relative 'metadata'

module WoodworkingAI
  FACE_NORMALS = {
    'top'    => [0,  0,  1],
    'bottom' => [0,  0, -1],
    'front'  => [0,  1,  0],
    'back'   => [0, -1,  0],
    'right'  => [1,  0,  0],
    'left'   => [-1, 0,  0]
  }.freeze
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

  def self.add_cutout(project_id:, part_id:, shape:, face:, x:, y:, depth:, radius: nil, width: nil, height: nil, manage_operation: true)
    identifier(project_id, 'project_id')
    identifier(part_id, 'part_id')
    x_val = Units.number(x, :x)
    y_val = Units.number(y, :y)
    d_val = Units.number(depth, :depth, positive: true)
    normal_arr = FACE_NORMALS[face]
    raise ArgumentError, "face must be one of: #{FACE_NORMALS.keys.join(', ')}" unless normal_arr
    normal_vec = Geom::Vector3d.new(*normal_arr)

    model = Sketchup.active_model
    raise 'No active SketchUp model' unless model
    raise 'Close the active component editing context first' if model.active_path

    instances = model.entities.grep(Sketchup::ComponentInstance).select do |e|
      e.get_attribute(DICTIONARY, 'project_id') == project_id &&
        e.get_attribute(DICTIONARY, 'part_id') == part_id
    end
    raise ArgumentError, "Part '#{part_id}' not found in project '#{project_id}'" if instances.empty?

    instance = instances.first
    raise 'Part is locked' if instance.locked?

    defn = instance.definition
    target_face = defn.entities.grep(Sketchup::Face).find { |f| f.normal.samedirection?(normal_vec) }
    raise ArgumentError, "No #{face} face found on part '#{part_id}'" unless target_face

    # Build center point in component-local space. x/y are coordinates along the
    # two axes of the named face; the third coordinate is inferred from the face plane.
    fc = target_face.bounds.center
    center = case face
    when 'top',    'bottom' then Geom::Point3d.new(x_val, y_val, fc.z)
    when 'front',  'back'   then Geom::Point3d.new(x_val, fc.y,  y_val)
    when 'right',  'left'   then Geom::Point3d.new(fc.x,  x_val, y_val)
    end
    center = center.project_to_plane(target_face.plane)

    started = false
    begin
      if manage_operation
        model.start_operation('Woodworking AI — Add Cutout', true)
        started = true
      end

      before_ids = defn.entities.grep(Sketchup::Face).map(&:object_id).to_set

      case shape
      when 'circle'
        raise ArgumentError, 'radius is required for circle cutouts' unless radius
        r = Units.number(radius, :radius, positive: true)
        defn.entities.add_circle(center, normal_vec, r, 64)
      when 'rectangle'
        raise ArgumentError, 'width and height are required for rectangle cutouts' unless width && height
        rw = Units.number(width, :width, positive: true)
        rh = Units.number(height, :height, positive: true)
        hw = rw / 2.0
        hh = rh / 2.0
        pts = case face
        when 'top',   'bottom' then [[center.x - hw, center.y - hh, center.z], [center.x + hw, center.y - hh, center.z],
                                     [center.x + hw, center.y + hh, center.z], [center.x - hw, center.y + hh, center.z]]
        when 'front', 'back'   then [[center.x - hw, center.y, center.z - hh], [center.x + hw, center.y, center.z - hh],
                                     [center.x + hw, center.y, center.z + hh], [center.x - hw, center.y, center.z + hh]]
        when 'right', 'left'   then [[center.x, center.y - hw, center.z - hh], [center.x, center.y + hw, center.z - hh],
                                     [center.x, center.y + hw, center.z + hh], [center.x, center.y - hw, center.z + hh]]
        end.map { |c| Geom::Point3d.new(*c).project_to_plane(target_face.plane) }
        defn.entities.add_edges(*pts, pts[0])
      else
        raise ArgumentError, "shape must be 'circle' or 'rectangle'"
      end

      new_faces = defn.entities.grep(Sketchup::Face).reject { |f| before_ids.include?(f.object_id) }
      raise 'Cutout shape did not intersect the face — verify the position is within the part bounds' if new_faces.empty?

      inner_face = new_faces.min_by(&:area)
      inner_face.pushpull(-d_val)

      model.commit_operation if manage_operation
      started = false
      {cutout_applied: true, shape: shape, face: face, instance_count: instances.length}
    rescue StandardError
      model.abort_operation if started
      raise
    end
  end
end
