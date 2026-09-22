# frozen_string_literal: true
# Trusted local development reload; never exposed as a network command.
WoodworkingAI.stop_bridge if defined?(WoodworkingAI) && WoodworkingAI.respond_to?(:stop_bridge)
# Clear cached schema so the updated project.schema.json is re-read after reload.
WoodworkingAI::ProjectValidation.instance_variable_set(:@schema, nil) if defined?(WoodworkingAI::ProjectValidation)
root = File.expand_path('../sketchup-extension/woodworking_ai', __dir__)
# Require new files before reloading to avoid load/require double evaluation.
%w[geometry project_validation projects joinery project_observer scenes reports exporter command_router].each { |name| require File.join(root, name) }
%w[geometry project_validation projects joinery project_observer scenes reports exporter command_router].each { |name| load File.join(root, "#{name}.rb") }
WoodworkingAI.watch_projects(Sketchup.active_model)
WoodworkingAI.start_bridge
puts 'Woodworking AI project tools loaded (bridge version 3).'
