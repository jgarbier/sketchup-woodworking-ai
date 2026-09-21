# SketchUp Woodworking AI
Local, constrained SketchUp automation for rectangular woodworking parts.

## Current status
Checkpoints 1–15 are verified, including native Codex calls, project editing, and a live
60 × 18 × 30-inch bench with 14 solid parts. Scenes, PNG export, model saving, cut list,
BOM and build-plan outputs are implemented and awaiting live verification after reload.
Once exported, project edits automatically regenerate outputs; failures are reported as
partial completion with geometry retained. export-status.json records the output revision.
No OpenAI API key is required.

See [macOS setup](docs/setup-macos.md) for the single-command live test,
[checkpoint status](docs/checkpoints.md), and [the full plan](IMPLEMENTATION_PLAN.md).

Run `npm run build` and `npm test` for local checks. With SketchUp and the bridge running,
`npm run test:live` exercises the full MCP-to-SketchUp chain.
