# Troubleshooting
Run the live test inside SketchUp's Ruby Console, not system Ruby.
Close any active component editing context first. Locked owned components are rejected.
An existing manually created model is preserved; the test only upserts its own tagged component.
A failed mutation aborts its SketchUp operation. Test failures are printed as structured JSON.
If the console reports an error, copy the full output for diagnosis before continuing checkpoints.
The bridge listens on 127.0.0.1:48763. If shell tests report EPERM, the Codex sandbox
needs localhost network access. If the bridge times out, dismiss modal SketchUp dialogs.
After changing extension code, load scripts/reload-extension.rb in its Ruby Console.
After adding MCP tools, reload Codex to refresh its native tool catalog.

An untitled document is saved once before subsequent copies. If the active document is
already the project bench.skp, it is saved in place; a separately named document is copied.
On export failures, model edits may already be committed. Read get_model and the
export-status.json revision before retrying export_project. Do not blindly repeat edits.
Undo/Redo marks exports stale; export_project regenerates them.
A file/model revision mismatch blocks edits and needs deliberate recovery from one side.
Local rendering never deletes unrelated model geometry; save copies retain it.
