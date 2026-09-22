# SketchUp Woodworking AI

An MCP server that lets any AI agent design, edit, and export woodworking projects directly in SketchUp Pro. The agent works with a structured project schema — parts, materials, joints, door assemblies — and the SketchUp extension handles all geometry, rendering, and file export.

## How it works

```
AI agent (MCP client) → TypeScript MCP server → TCP bridge → Ruby extension → SketchUp Pro API
```

The MCP server exposes tools the agent calls over stdio. The Ruby extension runs on SketchUp's main thread and owns all geometry mutations. No SketchUp account or API key is required — it's entirely local.

## Prerequisites

- **SketchUp Pro 2026** (macOS)
- **Node.js 18+** (`node_modules/node` is bundled as a locked dev dependency)
- An **MCP-compatible AI agent** — Claude Code, Claude Desktop, or any client that supports the [Model Context Protocol](https://modelcontextprotocol.io)

## Setup

### 1. Clone and build

```sh
git clone https://github.com/jgarbier/sketchup-woodworking-ai.git
cd sketchup-woodworking-ai
npm ci
npm run build
```

### 2. Install the SketchUp extension

```sh
./scripts/install-extension.sh
```

This symlinks the extension into SketchUp's plugins directory. Restart SketchUp after running it. To verify it loaded: **Extensions → Woodworking AI → Verify 48 × 18 × 1 Tabletop**.

### 3. Start the bridge

The extension starts the bridge automatically on load. It listens on `127.0.0.1:48763`.

To reload the extension during development, paste this into SketchUp's Ruby Console (**Extensions → Developer → Ruby Console**), using the actual path to your clone:

```ruby
load '/path/to/sketchup-woodworking-ai/scripts/reload-extension.rb'
```

Expected output: `Woodworking AI project tools loaded (bridge version 3).`

### 4. Register the MCP server with your agent

**Claude Code:**
```sh
claude mcp add woodworking \
  /path/to/sketchup-woodworking-ai/node_modules/node/bin/node \
  /path/to/sketchup-woodworking-ai/dist/index.js
```

**Claude Desktop** — add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "woodworking": {
      "command": "/path/to/sketchup-woodworking-ai/node_modules/node/bin/node",
      "args": ["/path/to/sketchup-woodworking-ai/dist/index.js"]
    }
  }
}
```

Any MCP-compatible client follows the same pattern: run `node dist/index.js` as a stdio server.

## Usage

With SketchUp open and the bridge running, ask your agent to design a piece of furniture:

> "Design a white oak bookshelf — 36" wide, 12" deep, 72" tall, 4 fixed shelves with dado joints into the sides, 1/4" birch plywood back panel in a rabbet."

The agent calls `create_project` with a full project definition. SketchUp renders the piece in the active model. On first export, or whenever dimensions change, it regenerates:

```
projects/{id}/
  state.json             — project state and revision
  project.yaml           — human-readable definition
  cut-list.csv           — finished dimensions for every part
  bill-of-materials.csv  — net board-feet and sheet area by material
  joinery-schedule.csv   — joint types, dimensions, and counts
  build-plan.md          — full construction document
  bench.skp              — SketchUp model
  renders/
    perspective.png
    front.png / right.png / top.png / exploded.png
```

## MCP tools

| Tool | Description |
|---|---|
| `create_project` | Create or fully replace a furniture project |
| `get_model` | Read current project state and revision |
| `get_model_summary` | Bounding box and physical part count |
| `export_project` | Write all output files and PNG renders |
| `fit_camera` | Set the SketchUp camera (perspective, front, right, top) |
| `update_part` | Edit one part's dimensions, position, or material |
| `move_part` | Reposition a part |
| `delete_part` | Remove a part |
| `render_views` | Re-render PNG views without a full export |
| `sketchup_status` | Report bridge and SketchUp versions |
| `create_board` | Low-level: add a single board component |

## Project schema

Projects are defined as JSON validated against `schema/woodworking-project.schema.json`. Key fields:

- **`parts`** — rectangular boards and panels with dimensions, position, rotation, material, and quantity
- **`materials`** — hardwood and sheet-good declarations
- **`relationships`** — dependency graph between parts
- **`door_assemblies`** — hinged or sliding door groups, rendered as SketchUp groups
- **`joints`** — dado, rabbet, mortise-tenon, dovetail, and other joinery with visual tenon-box markers

See `schema/example-bench.json` for a complete worked example.

## Development

```sh
npm test            # TypeScript build + Ruby unit tests
npm run test:live   # Full MCP → SketchUp integration test (bridge must be running)
```

See [`docs/setup-macos.md`](docs/setup-macos.md) for detailed setup steps and [`docs/architecture.md`](docs/architecture.md) for the bridge protocol and extension internals.
