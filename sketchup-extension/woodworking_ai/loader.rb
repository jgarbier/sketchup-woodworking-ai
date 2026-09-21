# frozen_string_literal: true
require 'sketchup.rb'
require_relative 'geometry'
require_relative 'checkpoint'
require_relative 'server'
require_relative 'project_observer'
WoodworkingAI.watch_projects(Sketchup.active_model)
module WoodworkingAI
  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins').add_submenu('Woodworking AI')
    menu.add_item('Verify 48 × 18 × 1 Tabletop') do
      begin
        result = WoodworkingAI.verify_tabletop
        puts JSON.generate(result)
        UI.messagebox('Tabletop verified: 48 × 18 × 1 inches. One owned solid component.')
      rescue StandardError => e
        puts JSON.generate(success: false, error: {type: e.class.name, message: e.message})
        UI.messagebox("Tabletop verification failed: #{e.message}")
      end
    end
    menu.add_item('Start Local Bridge') { WoodworkingAI.start_bridge }
    menu.add_item('Stop Local Bridge') { WoodworkingAI.stop_bridge }
    file_loaded(__FILE__)
  end
end

begin
  WoodworkingAI.start_bridge
rescue StandardError => e
  warn "Woodworking AI bridge could not start: #{e.message}"
end
