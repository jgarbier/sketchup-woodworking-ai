Reload the SketchUp extension and verify the bridge is running.

## Steps

1. **Provide the reload command.** Tell the user to open SketchUp's Ruby Console (`Extensions > Developer > Ruby Console`) and run:
   ```ruby
   load '/Users/jamesgarbier/Desktop/projects/sketchup-woodworking-ai/scripts/reload-extension.rb'
   ```
   Wait for them to confirm they see: `Woodworking AI project tools loaded (bridge version 3).`

2. **Verify connectivity.** Run a `sketchup_status` MCP tool call and confirm `bridge_version` is 3.

3. **If the bridge isn't responding**, check:
   - Is SketchUp open?
   - Is the extension enabled? (`Extensions > Extension Manager`)
   - Are the symlinks intact?
     ```
     ls -la "$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins/" | grep woodworking
     ```
   - Run `scripts/install-extension.sh` to recreate symlinks if they're missing or stale.

4. **Report:** bridge status, SketchUp version, and whether the extension is loaded correctly.
