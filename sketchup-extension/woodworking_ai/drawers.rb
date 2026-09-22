# frozen_string_literal: true
module WoodworkingAI
  module Drawers
    SLIDE_CLEARANCES = {
      'side-mount'   => { each_side: 0.5,    min_height: 3.0,  top_clear: 0.0625, bottom_clear: 0.0625 },
      'undermount'   => { each_side: 0.5625, min_height: 3.5,  top_clear: 0.0625, bottom_clear: 0.0    },
      'center-mount' => { each_side: 0.0,    min_height: 3.0,  top_clear: 0.0625, bottom_clear: 0.75   }
    }.freeze

    OVERLAY_AMOUNTS = {
      'full-overlay' => 0.5,
      'half-overlay' => 0.25,
      'inset'        => nil
    }.freeze

    DADO_DEPTH = 0.25

    def self.calculate(opening_width:, opening_height:, opening_depth:,
                       drawer_count:, slide_type:, face_style:,
                       gap_between: 0.125, box_thickness: 0.5, face_thickness: 0.75)
      slide = SLIDE_CLEARANCES[slide_type] or raise ArgumentError, "slide_type must be one of: #{SLIDE_CLEARANCES.keys.join(', ')}"
      raise ArgumentError, "face_style must be one of: #{OVERLAY_AMOUNTS.keys.join(', ')}" unless OVERLAY_AMOUNTS.key?(face_style)

      box_width  = opening_width - slide[:each_side] * 2
      box_depth  = opening_depth - 1.5
      raise ArgumentError, "Box depth #{box_depth.round(3)}\" is too shallow (minimum 6\")" if box_depth < 6.0

      total_gaps = gap_between * (drawer_count - 1)
      per_drawer_h = (opening_height - total_gaps).to_f / drawer_count
      box_height = per_drawer_h - slide[:top_clear] - slide[:bottom_clear]
      if box_height < slide[:min_height]
        raise ArgumentError, "Box height #{box_height.round(3)}\" is below minimum #{slide[:min_height]}\" for #{slide_type} slides"
      end

      bottom_thickness = slide_type == 'undermount' ? 0.5 : 0.25
      inner_width  = box_width  - 2 * box_thickness
      bottom_width = inner_width + 2 * DADO_DEPTH
      bottom_depth = box_depth  - box_thickness - DADO_DEPTH
      # Back sits above the bottom dado, so it is shorter
      back_height  = box_height - bottom_thickness - DADO_DEPTH

      face_w, face_h = face_dimensions(face_style, opening_width, opening_height,
                                       drawer_count, gap_between)

      r = ->(v) { v.round(4) }
      slides = [12, 14, 16, 18, 20, 22, 24].select { |s| s <= box_depth }.last

      drawers = Array.new(drawer_count) do |i|
        {
          'index'       => i + 1,
          'box_width'   => r.(box_width),
          'box_height'  => r.(box_height),
          'box_depth'   => r.(box_depth),
          'face_width'  => r.(face_w),
          'face_height' => r.(face_h),
          'parts' => {
            'sides'  => { 'length' => r.(box_depth),    'width' => r.(box_height),  'thickness' => box_thickness,    'quantity' => 2 },
            'front'  => { 'length' => r.(inner_width),  'width' => r.(box_height),  'thickness' => box_thickness,    'quantity' => 1 },
            'back'   => { 'length' => r.(inner_width),  'width' => r.(back_height), 'thickness' => box_thickness,    'quantity' => 1 },
            'bottom' => { 'length' => r.(bottom_width), 'width' => r.(bottom_depth),'thickness' => bottom_thickness, 'quantity' => 1 },
            'face'   => { 'length' => r.(face_w),       'width' => r.(face_h),      'thickness' => face_thickness,   'quantity' => 1 }
          }
        }
      end

      {
        'slide_type'              => slide_type,
        'face_style'              => face_style,
        'drawer_count'            => drawer_count,
        'box_material_thickness'  => box_thickness,
        'bottom_panel_thickness'  => bottom_thickness,
        'face_thickness'          => face_thickness,
        'recommended_slide_length'=> slides,
        'drawers'                 => drawers,
        'notes'                   => build_notes(slide_type, box_depth, slides, box_height, slide[:min_height])
      }
    end

    def self.face_dimensions(face_style, opening_width, opening_height, drawer_count, gap_between)
      case face_style
      when 'full-overlay', 'half-overlay'
        overlay = OVERLAY_AMOUNTS[face_style]
        face_w = opening_width + 2 * overlay
        face_h = (opening_height + 2 * overlay - (drawer_count - 1) * gap_between).to_f / drawer_count
        [face_w, face_h]
      when 'inset'
        gap = 0.0625
        total_gaps = gap_between * (drawer_count - 1)
        per_h = (opening_height - total_gaps).to_f / drawer_count
        [opening_width - 2 * gap, per_h - 2 * gap]
      end
    end

    def self.build_notes(slide_type, box_depth, slide_len, box_height, min_height)
      notes = []
      notes << "Recommended slide length: #{slide_len}\" (box depth #{box_depth.round(3)}\")" if slide_len
      if slide_type == 'undermount'
        notes << 'Undermount slides require 1/2" × 1/2" rear corner notches on box sides for mounting clips'
        notes << 'Install a rear nailer board in the cabinet for slide rear attachment'
        notes << 'Box bottom panel is 1/2" (not standard 1/4") to support undermount cradle'
      end
      notes << "Box height #{box_height.round(3)}\" is close to slide minimum — verify manufacturer specs" if box_height < min_height + 0.25
      notes
    end
  end
end
