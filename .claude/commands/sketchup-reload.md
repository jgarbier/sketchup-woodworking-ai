Reload the SketchUp extension and verify the bridge is running.

## Steps

1. **Check if the bridge is already running:**
   ```
   curl -s http://127.0.0.1:7654/status
   ```
   If it responds with `{"status":"ok"}`, the bridge is already live — report version and skip to step 4.

2. **Provide the reload command.** Tell the user to open SketchUp's Ruby Console (`Extensions > Developer > Ruby Console`) and run:
   ```ruby
   load '/Users/jamesgarbier/Desktop/projects/sketchup-woodworking-ai/scripts/reload-extension.rb'
   ```
   Wait for them to confirm they see: `Woodworking AI project tools loaded (bridge version 3).`

3. **Verify connectivity** after reload:
   ```
   curl -s http://127.0.0.1:7654/status
   ```
   If this fails, check:
   - Is SketchUp open?
   - Is the extension enabled? (`Extensions > Extension Manager`)
   - Are the symlinks intact?
     ```
     ls -la "$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins/" | grep woodworking
     ```
   - Do the symlinks point to the current repo (not the old Codex directory)?

4. **Confirm bridge version.** Run a `sketchup_status` call via the MCP and report the SketchUp version and bridge version number.

5. **Report:** bridge status, SketchUp version, and whether the extension is loaded correctly. If symlinks are wrong, run `scripts/install-extension.sh` to fix them.
