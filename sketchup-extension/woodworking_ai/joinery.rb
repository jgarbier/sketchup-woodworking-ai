# frozen_string_literal: true
require_relative 'projects'
module WoodworkingAI
  module Joinery
    JOINT_GROUP_KEY = 'joint_group'

    def self.joint_groups(model, id)
      model.entities.grep(Sketchup::Group).select do |g|
        g.get_attribute(DICTIONARY, 'project_id') == id &&
          g.get_attribute(DICTIONARY, JOINT_GROUP_KEY)
      end
    end

    def self.clear(model, id)
      joint_groups(model, id).each { |g| g.erase! if g.valid? }
    end

    def self.render(model, id, project)
      joints = project['joints'] || []
      clear(model, id)
      return if joints.empty?

      all_instances = Projects.instances(model, id)
      inst_map = all_instances.each_with_object({}) do |inst, map|
        pid = inst.get_attribute(DICTIONARY, 'part_id')
        map[pid] ||= inst
      end

      group = model.entities.add_group
      group.name = "Joints — #{id}"
      group.set_attribute(DICTIONARY, 'project_id', id)
      group.set_attribute(DICTIONARY, JOINT_GROUP_KEY, true)

      joints.each do |joint|
        inst_a = inst_map[joint['part_a']]
        inst_b = inst_map[joint['part_b']]
        next unless inst_a && inst_b

        depth     = (joint['depth']     || 1.5).to_f
        width     = (joint['width']     || 1.5).to_f
        thickness = (joint['thickness'] || width / 4.0).to_f
        count     = (joint['count']     || 1).to_i

        face = nearest_face(inst_a.bounds, inst_b.bounds.center)
        t1, t2 = face_tangents(face[:normal])
        draw_tenons(group.entities, face[:center], face[:normal], t1, t2, depth, width, thickness, count)
      end
    end

    def self.nearest_face(box, target)
      cx = (box.min.x + box.max.x) / 2.0
      cy = (box.min.y + box.max.y) / 2.0
      cz = (box.min.z + box.max.z) / 2.0
      candidates = [
        {center: Geom::Point3d.new(box.min.x, cy, cz), normal: Geom::Vector3d.new(-1, 0, 0)},
        {center: Geom::Point3d.new(box.max.x, cy, cz), normal: Geom::Vector3d.new(1, 0, 0)},
        {center: Geom::Point3d.new(cx, box.min.y, cz), normal: Geom::Vector3d.new(0, -1, 0)},
        {center: Geom::Point3d.new(cx, box.max.y, cz), normal: Geom::Vector3d.new(0, 1, 0)},
        {center: Geom::Point3d.new(cx, cy, box.min.z), normal: Geom::Vector3d.new(0, 0, -1)},
        {center: Geom::Point3d.new(cx, cy, box.max.z), normal: Geom::Vector3d.new(0, 0, 1)}
      ]
      candidates.min_by { |f| f[:center].distance(target) }
    end

    def self.face_tangents(normal)
      ref = normal.z.abs < 0.9 ? Geom::Vector3d.new(0, 0, 1) : Geom::Vector3d.new(1, 0, 0)
      t1 = ref.cross(normal).normalize
      t2 = normal.cross(t1).normalize
      [t1, t2]
    end

    def self.draw_tenons(entities, face_center, normal, t1, t2, depth, width, thickness, count)
      spacing = width * 2.0
      offset_start = count > 1 ? -spacing * (count - 1) / 2.0 : 0.0
      count.times do |i|
        center = face_center + t1 * (offset_start + i * spacing)
        draw_tenon_box(entities, center, normal, t1, t2, depth, width, thickness)
      end
    end

    def self.draw_tenon_box(entities, center, normal, t1, t2, depth, width, thickness)
      hw = width / 2.0
      ht = thickness / 2.0
      pts = [
        center + t1 * hw + t2 * ht,
        center + t1 * hw - t2 * ht,
        center - t1 * hw - t2 * ht,
        center - t1 * hw + t2 * ht
      ]
      face = entities.add_face(pts)
      push_depth = face.normal.dot(normal) > 0 ? depth : -depth
      face.pushpull(push_depth)
    rescue StandardError
      # Skip malformed tenon boxes rather than aborting the whole render.
    end
  end
end
