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

## Diagnosing stale extension code

**Before assuming the extension is current, check `sketchup_status`.** The `commands` array it returns reveals exactly which version of `command_router.rb` is running. If a recently-added command is absent, the running code predates that change and a reload is required even if the user hasn't touched SketchUp.

### Common failure modes after adding new Ruby files

**Symptom:** `create_project` returns `$: unknown fields` at the Ruby level (code `INVALID_REQUEST`).  
**Cause:** `ProjectValidation.@schema` was cached from before the JSON schema was updated. The reload script clears it via `instance_variable_set(:@schema, nil)`, but only if the reload ran *after* the schema file was written.  
**Fix:** Ask the user to reload again.

**Symptom:** A new MCP command is missing from `sketchup_status` even after reload.  
**Cause:** The reload script (`scripts/reload-extension.rb`) has an explicit list of files to `load`:
```ruby
%w[geometry project_validation projects joinery project_observer scenes reports exporter command_router]
```
New `.rb` files added to the extension are **not** in this list. They only reach SketchUp via `require_relative` inside an already-listed file. But `require` is a no-op if the file was previously loaded under any path — so the new file's updated code is never evaluated.  
**Fix:** Add the new file to the explicit list in `reload-extension.rb` *before* the file that `require_relative`s it. For example, if `drawers.rb` was added and is required by `command_router.rb`, add `drawers` before `command_router` in the list.

### Checklist when `create_project` or a new command fails unexpectedly

1. Call `sketchup_status` — verify the command exists in the `commands` array.
2. If a command is missing → reload and retry.
3. If `$: unknown fields` → reload (clears stale `@schema`) and retry.
4. If `Revision conflict` → call `get_model` to read the live revision; don't rely solely on `state.json` which may lag behind the model.
5. If `Project files differ from active model` → the wrong SketchUp model is open. Open `projects/{id}/bench.skp`.
6. If `Close the active component editing context first` → user is double-clicked into a component in SketchUp. Press Escape to exit, then retry.
