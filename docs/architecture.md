# Architecture
Codex → official TypeScript MCP SDK → localhost JSON bridge → Ruby extension → SketchUp API.
The extension exclusively owns SketchUp mutations on SketchUp's main thread.
The bridge must bind 127.0.0.1, whitelist commands and validate parameters; never evaluate code.
Project YAML will record design intent; SketchUp components will carry stable project/part IDs.
One logical agent edit should be one undo operation. Future exports derive from structured parts.

## Current implementation
Ruby primitive and installed extension are verified live. The JSON bridge is implemented;
MCP remains gated by live bridge verification. UI.start_timer polls nonblocking TCP sockets
on the SketchUp main thread. There is no worker-thread access to the SketchUp API.
See the [official main-thread requirement](https://ruby.sketchup.com/).

## Bridge protocol
127.0.0.1:48763; one newline-delimited JSON request and response per connection.
Envelope: request_id, command, params. Commands: sketchup_status, create_board, get_part.
Strict field validation rejects unknown commands and fields. Requests are limited to 64 KiB,
16 simultaneous clients and a 10-second lifetime. No HTTP or arbitrary code execution.
This local V1 endpoint trusts local OS processes; there is no network authentication token.
Do not forward its port. Start/stop controls are in the extension menu.
Validated command parameters, results, request IDs, timestamps and durations go to logs/bridge.jsonl.
Invalid request bodies are excluded from logging. MCP-side logging comes with that layer.
Geometry uses the supported [SketchUp API](https://ruby.sketchup.com/file.generating_geometry.html).

## Export behavior
The extension owns all cameras, scenes, preview geometry, PNG export and .skp saving.
Exports use official View.write_image and Model.save_copy APIs. Scenes are scoped by
project metadata. An exploded preview uses a separate tagged group, excluded from
physical part queries and cut lists. Original part transforms remain unchanged.
Unrelated entities are temporarily hidden for rendering and restored afterward.
The saved model preserves unrelated geometry; scene views isolate the project.

Cut lists use local structured dimensions, not rotated world bounds. BOM totals are
net finished volume/area without waste, cost, or stock optimization. After the first
export, subsequent project mutations regenerate outputs automatically. The manifest's
revision must match get_model and complete must be true before treating outputs as current.
Undo/Redo restores the project definition and marks exports stale for explicit refresh.
