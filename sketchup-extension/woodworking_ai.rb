# frozen_string_literal: true
require 'sketchup.rb'
require 'extensions.rb'
module WoodworkingAI
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('Woodworking AI', 'woodworking_ai/loader')
    extension.description = 'Local woodworking automation: rectangular board checkpoint.'
    extension.version = '0.1.0'
    extension.creator = 'Woodworking AI Project'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
