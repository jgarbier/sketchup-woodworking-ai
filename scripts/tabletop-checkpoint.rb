# frozen_string_literal: true
require_relative '../sketchup-extension/woodworking_ai/checkpoint'
begin
  puts JSON.generate(WoodworkingAI.verify_tabletop)
rescue StandardError => e
  puts JSON.generate(success: false, error: {type: e.class.name, message: e.message})
  raise
end
