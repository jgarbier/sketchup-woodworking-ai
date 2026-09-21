# macOS setup — checkpoint 3
SketchUp Pro 2026, Node/npm and Git were detected on this Mac.
No extension installation or account credentials are needed for this direct Ruby test.

1. In SketchUp 2026 open an empty model, then **Extensions → Developer → Ruby Console**.
2. Paste this single line and press Return:

```ruby
load '/Users/jamesgarbier/Documents/Codex/2026-09-21/ple/outputs/sketchup-woodworking-ai/scripts/tabletop-checkpoint.rb'
```

A 48 × 18 × 1 inch component should appear, and the console should print
`"success":true` with measured dimensions 48, 18, 1.
Run the same line a second time: only one tabletop should remain.
Use Edit → Undo once to undo the update and a second time to remove the initial tabletop.
Report the console result and whether the visible tabletop/Undo checks passed.

## Checkpoint 4: development extension
Run `./scripts/install-extension.sh` from the repository. This creates two symlinks in
`~/Library/Application Support/SketchUp 2026/SketchUp/Plugins` and refuses to replace
an existing unrelated installation. Repeating it is safe. Keep the repository in place.

Restart SketchUp and choose **Extensions → Woodworking AI → Verify 48 × 18 × 1 Tabletop**.
Allow this locally developed extension if SketchUp prompts. The verification should
show a success dialog. Running it twice should leave one tabletop. Each run has one
Undo operation; Undo twice in an initially empty model removes the tabletop.

`./scripts/package-extension.sh` generates `dist/woodworking-ai-0.1.0.rbz` for distribution.
The RBZ is an alternative to development symlinks; do not install both.
Registration follows the [official SketchupExtension API](https://ruby.sketchup.com/SketchupExtension.html).

Bridge and MCP setup follow after the extension loads successfully.

## Checkpoints 5–6: load and test the bridge
Dismiss any modal success dialog. In SketchUp's Ruby Console run:

```ruby
load '/Users/jamesgarbier/Documents/Codex/2026-09-21/ple/outputs/sketchup-woodworking-ai/scripts/start-bridge.rb'
```

The console should report `Woodworking AI bridge listening on 127.0.0.1:48763`.
Keep SketchUp open with dialogs dismissed. Codex can then run `./scripts/test-bridge.sh`.
That test checks status, rejection of arbitrary Ruby, repeated board creation without
 duplication, and measured 48/18/1-inch dimensions of one solid component.
Alternatively restart SketchUp to load the updated extension and start the bridge automatically.
If the port is occupied, the extension logs an error; it never takes over another listener.

## MCP checkpoints 7–11
The official MCP SDK and Zod are installed with a lockfile. Node 24 LTS is a local
development dependency; the configured server launches its absolute executable path.
Run `npm ci`, `npm run build`, `npm test` and `npm run test:live` after a fresh checkout.
The live test modifies only the tagged checkpoint tabletop in the active SketchUp model.

`docs/codex-mcp.toml` contains the exact local stdio configuration. Register using
`codex mcp add woodworking -- /absolute/path/to/node /absolute/path/to/dist/index.js`.
The setup here uses the repository's `node_modules/node/bin/node` executable.
Codex registration is separate from verifying an SDK client. If the current task does not
see the new tools, reload Codex, return to this task, and ask it to verify sketchup_status.
Keep SketchUp open and its bridge running. No application OpenAI API calls are involved.

Reference: [official Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

## Project editing checkpoint
Load the trusted `scripts/reload-extension.rb` file in SketchUp's Ruby Console to update
the running extension. Wait for bridge version 2 confirmation. Then run
`node scripts/test-project.mjs` for the create/update/move/quantity/rotation/delete loop.
The test uses only the project-checkpoint project, leaving a 48 × 18 × 1 panel at Z=40.
Reload Codex afterwards to expose the additional native MCP tools.

## Output and final acceptance checkpoints
Reload scripts/reload-extension.rb and confirm bridge version 3. Then run
`node scripts/test-acceptance.mjs` to export the initial bench, resize to 72 inches,
raise the shelf from 6 to 9 inches, change legs from 2 to 2.5 inches square, and verify
that persistent instance IDs remain unchanged and all output files regenerate.
The fixed output folder is projects/acceptance-bench/.

To expose the added native tools in the existing Codex task, reload Codex once more.
The SDK integration tests can already invoke the complete server without that reload.
