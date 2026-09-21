# frozen_string_literal: true
require 'csv'
module WoodworkingAI
  module Reports
    def self.csv_cell(value)
      value.is_a?(String) && value.match?(/\A[=+@\-\t\r]/) ? "'#{value}" : value
    end
    def self.csv(rows)
      CSV.generate { |csv| rows.each { |row| csv << row.map { |cell| csv_cell(cell) } } }
    end
    def self.cut_list(project)
      rows = [%w[part quantity material length width thickness]]
      project['parts'].each do |part|
        d = part['dimensions']
        rows << [part['name'],part['quantity'],part['material'],d['length'],d['width'],d['thickness']]
      end
      csv(rows)
    end
    def self.bom(project)
      rows = [%w[material stock_type quantity net_cubic_inches net_board_feet net_square_feet]]
      project['parts'].group_by { |part| [part['material'],part['stock_type']] }.each do |(material, stock), parts|
        volume = parts.sum { |p| d=p['dimensions']; p['quantity'] * d['length'] * d['width'] * d['thickness'] }
        area = parts.sum { |p| d=p['dimensions']; p['quantity'] * d['length'] * d['width'] / 144.0 }
        sheet = %w[plywood sheet_good].include?(stock)
        rows << [material,stock,parts.sum { |p| p['quantity'] },volume.round(4),sheet ? '' : (volume/144.0).round(4),sheet ? area.round(4) : '']
      end
      csv(rows)
    end
    def self.md(value)
      value.to_s.gsub('|','\\|').gsub(/[\r\n]+/,' ')
    end
    def self.build_plan(project)
      overall = project['overall']
      lines = ["# #{md(project['project']['name'])}", '',
        "#{overall['width']}\" W × #{overall['depth']}\" D × #{overall['height']}\" H", '',
        '## Materials', '', 'Net quantities only; allow separately for milling, kerf, defects and waste. No pricing or stock optimization.', '']
      project['materials'].each { |m| lines << "- #{md(m['id'])}: #{md(m['species'])}, #{md(m['type'])}" }
      lines += ['', '## Cut List', '', '| Part | Qty | Material | Length | Width | Thickness |', '|---|---:|---|---:|---:|---:|']
      project['parts'].each do |p|
        d=p['dimensions']; lines << "| #{md(p['name'])} | #{p['quantity']} | #{md(p['material'])} | #{d['length']} | #{d['width']} | #{d['thickness']} |"
      end
      lines += ['', 'All cut dimensions are finished inches in each part’s local axes.', '', '## Parts', '']
      project['parts'].each { |p| lines << "- `#{p['id']}`: #{md(p['name'])}; grain #{p['grain_direction']}; position #{p['position'].values.join(', ')}; rotation XYZ #{p['rotation'].values.join(', ')} degrees. #{p['notes'].map { |n| md(n) }.join(' ')}" }
      lines += ['', '## Assembly Overview', '', '1. Confirm the layout and finished dimensions against the views.', '2. Select joinery and fasteners, then mill and cut the listed parts.', '3. Dry-fit the frame square; fit shelf supports before installing the shelf.', '4. Attach panels with allowance for seasonal wood movement.', '', 'Relationships from the design:', '']
      project['relationships'].each { |r| lines << "- #{md(r['part_id'])}: #{md(r['description'])}" }
      lines += ['', '## Assumptions', '', '- Rectangular-part model; joinery, fastener schedules and load capacity are not engineered here.']
      project['notes'].each { |note| lines << "- #{md(note)}" }
      lines += ['', '## Files', '', 'project.yaml', 'bench.skp', 'cut-list.csv', 'bill-of-materials.csv', 'renders/perspective.png', 'renders/front.png', 'renders/right.png', 'renders/side.png', 'renders/top.png', 'renders/exploded.png', '', 'The saved model preserves unrelated geometry from the active document. Exported views isolate this project.']
      lines.join("\n") + "\n"
    end
  end
end
