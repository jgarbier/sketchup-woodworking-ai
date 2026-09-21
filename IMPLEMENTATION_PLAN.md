# SketchUp AI Woodworking --- Codex Implementation Plan

## 1. Objective

Build a local system that allows an AI agent to receive a
natural-language woodworking request such as:

> Build a 72" × 18" × 30" entry bench using 2×2 legs, a 1" hardwood top,
> aprons, and a lower shelf.

The system must then:

1.  Interpret the request.
2.  Create a structured woodworking project definition.
3.  Generate the corresponding model in SketchUp Pro 2026.
4.  Organize every physical part as a named SketchUp component/group.
5.  Attach woodworking metadata to those parts.
6.  Save the `.skp` model.
7.  Produce useful visualizations.
8.  Generate a cut list and bill of materials.
9.  Allow subsequent natural-language modifications.
10. Keep the SketchUp model and project definition synchronized.

The user must be able to say:

> Make the bench 6 inches wider and move the shelf up 3 inches.

and have the existing design update without manually rebuilding it.

The MVP should optimize for **simple furniture constructed primarily
from rectangular lumber and sheet goods**.

Do not attempt complex joinery, CNC paths, curved furniture, structural
engineering, or photorealistic rendering in V1.

------------------------------------------------------------------------

## 2. System Architecture

Implement this architecture:

``` text
                  CODEX / AI AGENT
                         │
                         │ MCP
                         ▼
              ┌─────────────────────┐
              │ Woodworking MCP     │
              │ TypeScript          │
              │                     │
              │ create_project      │
              │ create_board        │
              │ update_part         │
              │ get_model           │
              │ render_views        │
              │ export_project      │
              └──────────┬──────────┘
                         │
                 localhost only
                         │
              ┌──────────▼──────────┐
              │ SketchUp Extension  │
              │ Ruby                │
              │                     │
              │ command router      │
              │ geometry engine     │
              │ metadata            │
              │ exporter            │
              └──────────┬──────────┘
                         │
                 SketchUp Ruby API
                         │
              ┌──────────▼──────────┐
              │ SketchUp Pro 2026   │
              │                     │
              │ 3D model            │
              │ components          │
              │ scenes              │
              │ dimensions          │
              └─────────────────────┘
                         │
                         ▼
                   PROJECT OUTPUT

              project.yaml
              project.skp
              cut-list.csv
              bill-of-materials.csv
              build-plan.md
              renders/
                perspective.png
                front.png
                side.png
                top.png
                exploded.png
```

The SketchUp Ruby API is the authoritative interface for manipulating
the active SketchUp model. The SketchUp extension---not the MCP
server---must own actual SketchUp manipulation.

------------------------------------------------------------------------

## 3. Technology Decisions

Use:

``` text
MCP server:       TypeScript
MCP SDK:          Official Model Context Protocol TypeScript SDK
Validation:       Zod
SketchUp plugin:  Ruby
Serialization:    JSON
Project schema:   YAML + JSON Schema
Testing:          Vitest + Ruby tests where practical
Package manager:  npm
Version control:  Git
Runtime:          Node.js LTS
CAD:              SketchUp Pro 2026
Platform:         macOS
```

Use the official MCP SDK rather than implementing MCP manually.

Do not use a community SketchUp MCP as a runtime dependency. Community
implementations may be consulted for architectural ideas only.

------------------------------------------------------------------------

## 4. Repository

Create:

``` text
sketchup-woodworking-ai/
│
├── README.md
├── AGENTS.md
├── package.json
├── tsconfig.json
├── .gitignore
│
├── docs/
│   ├── architecture.md
│   ├── setup-macos.md
│   ├── woodworking-schema.md
│   └── troubleshooting.md
│
├── mcp/
│   ├── src/
│   │   ├── index.ts
│   │   ├── server.ts
│   │   ├── sketchup-client.ts
│   │   ├── schemas.ts
│   │   └── tools/
│   │       ├── create-project.ts
│   │       ├── create-board.ts
│   │       ├── update-part.ts
│   │       ├── delete-part.ts
│   │       ├── get-model.ts
│   │       ├── render-views.ts
│   │       └── export-project.ts
│   └── tests/
│
├── sketchup-extension/
│   ├── woodworking_ai.rb
│   └── woodworking_ai/
│       ├── loader.rb
│       ├── server.rb
│       ├── command_router.rb
│       ├── geometry.rb
│       ├── parts.rb
│       ├── metadata.rb
│       ├── scenes.rb
│       ├── exporter.rb
│       └── units.rb
│
├── schema/
│   ├── woodworking-project.schema.json
│   └── example-bench.yaml
│
├── scripts/
│   ├── install-extension.sh
│   ├── dev.sh
│   ├── test-bridge.sh
│   └── package-extension.sh
│
└── projects/
    └── .gitkeep
```

Codex should create this entire structure.

------------------------------------------------------------------------

## 5. Woodworking Project Definition

SketchUp must **not** be the only source of design information.

Every project gets a human-readable structured definition.

Example:

``` yaml
project:
  id: entry-bench-001
  name: Entry Bench
  units: inches

overall:
  width: 72
  depth: 18
  height: 30

materials:
  - id: white_oak
    species: white_oak
    type: hardwood

parts:
  - id: top
    name: Bench Top
    type: panel
    material: white_oak
    quantity: 1
    dimensions:
      length: 72
      width: 18
      thickness: 1
    position:
      x: 0
      y: 0
      z: 29

  - id: front_left_leg
    name: Front Left Leg
    type: board
    material: white_oak
    quantity: 1
    dimensions:
      length: 29
      width: 2
      thickness: 2

  - id: front_apron
    name: Front Apron
    type: board
    material: white_oak
    quantity: 1
    dimensions:
      length: 68
      width: 4
      thickness: 0.75
```

The schema should support at minimum:

-   project
-   overall dimensions
-   materials
-   parts
-   part dimensions
-   part position
-   part rotation
-   quantity
-   stock type
-   grain direction
-   notes
-   relationships

Every SketchUp component created from this definition must store its
`part_id`.

This allows the agent to find and modify the same object later.

------------------------------------------------------------------------

## 6. Coordinate Convention

Establish and document one coordinate convention:

``` text
X = project width
Y = project depth
Z = vertical / height

Origin = front-left-bottom corner of project's bounding box
```

Use inches as the canonical V1 unit internally.

Normalize units at the integration boundary. Do not let individual tools
invent their own unit assumptions.

------------------------------------------------------------------------

## 7. First SketchUp Milestone

Before MCP exists, prove SketchUp automation independently.

Create a Ruby method:

``` ruby
create_board(
  id:,
  name:,
  length:,
  width:,
  thickness:,
  position:
)
```

It must:

1.  Get `Sketchup.active_model`.
2.  Start an undoable model operation.
3.  Create rectangular geometry.
4.  Extrude to the requested thickness.
5.  Convert the geometry into a component/group.
6.  Name it.
7.  Attach `part_id` metadata.
8.  Position it.
9.  Commit the operation.

### Initial acceptance test

A:

``` text
48 × 18 × 1 inch tabletop
```

must appear correctly in SketchUp.

Do not proceed to MCP until this works.

------------------------------------------------------------------------

## 8. Do Not Expose Arbitrary Ruby Execution

Do **not** implement an MCP tool such as:

``` text
eval_ruby(code)
```

Expose constrained commands instead.

Example:

``` json
{
  "command": "create_board",
  "id": "top",
  "length": 48,
  "width": 18,
  "thickness": 1
}
```

The AI must never be allowed to send arbitrary Ruby for execution inside
SketchUp.

------------------------------------------------------------------------

## 9. Build the Local SketchUp Bridge

The Ruby extension needs to receive structured commands from the MCP
process.

The bridge must:

-   bind to `127.0.0.1` only;
-   never expose a public network interface;
-   accept JSON commands;
-   validate command type;
-   validate required parameters;
-   reject unknown commands;
-   return structured JSON;
-   serialize SketchUp operations onto SketchUp's main thread;
-   provide useful errors.

Use a protocol such as:

``` json
{
  "request_id": "abc123",
  "command": "create_board",
  "params": {
    "id": "top",
    "name": "Bench Top",
    "length": 72,
    "width": 18,
    "thickness": 1,
    "x": 0,
    "y": 0,
    "z": 29
  }
}
```

Response:

``` json
{
  "request_id": "abc123",
  "success": true,
  "result": {
    "part_id": "top"
  }
}
```

------------------------------------------------------------------------

## 10. MCP V1 Tools

Do not build dozens of tools initially.

Start with:

``` text
sketchup_status
create_project
create_board
update_part
move_part
delete_part
get_part
get_parts
get_model_summary
fit_camera
render_view
save_model
export_project
```

Every mutating tool returns:

``` text
success
affected part IDs
resulting dimensions
warnings
```

All MCP inputs must have explicit schemas and validation.

------------------------------------------------------------------------

## 11. Agent-Level Furniture Generation

Once the primitive API works, support semantic furniture generation.

A request such as:

> Create a bench.

should result in:

``` text
AI determines design
        ↓
structured project definition
        ↓
individual parts
        ↓
validated geometry commands
        ↓
SketchUp
```

Do not implement `create_bench` as one giant Ruby function.

The LLM owns design reasoning.

Deterministic application code owns geometry.

------------------------------------------------------------------------

## 12. Visualization

A successful build must not merely leave a `.skp` file behind.

Generate these scenes/views:

``` text
Perspective
Front
Right
Top
Exploded
```

Export PNGs into:

``` text
projects/<project-id>/renders/
```

The perspective view should be the default visual confirmation.

Use official SketchUp export mechanisms rather than screen scraping
wherever possible.

------------------------------------------------------------------------

## 13. Cut-List Engine

Do not derive cut lists from screenshots.

Derive them from structured project parts.

Output:

``` csv
part,quantity,material,length,width,thickness
Bench Top,1,White Oak,72,18,1
Front Leg,2,White Oak,29,2,2
Rear Leg,2,White Oak,29,2,2
Front Apron,1,White Oak,68,4,0.75
Rear Apron,1,White Oak,68,4,0.75
```

Generate:

``` text
cut-list.csv
bill-of-materials.csv
```

Keep V1 conservative. Do not attempt pricing or sophisticated stock
optimization.

------------------------------------------------------------------------

## 14. Build-Plan Output

Generate:

``` text
build-plan.md
```

It should contain:

``` text
# Entry Bench

Overall dimensions
72" W × 18" D × 30" H

## Materials

...

## Cut List

...

## Parts

...

## Assembly Overview

...

## Assumptions

...

## Files

entry-bench.skp
renders/perspective.png
renders/front.png
renders/right.png
renders/top.png
cut-list.csv
bill-of-materials.csv
```

PDF generation is not required for V1.

------------------------------------------------------------------------

## 15. Modification Workflow

This is a mandatory acceptance requirement.

Starting model:

``` text
72 × 18 × 30 bench
```

User says:

> Make it 78 inches wide.

The agent must:

1.  Read the project definition.
2.  Determine affected parts.
3.  Update overall width.
4.  Resize the top.
5.  Resize front/rear aprons.
6.  Reposition right-side legs.
7.  Preserve unaffected dimensions.
8.  Update SketchUp.
9.  Regenerate renders.
10. Regenerate cut list.
11. Save project.

The agent must **not** simply scale the entire SketchUp model.

------------------------------------------------------------------------

## 16. Idempotency

Running the same project twice must not create duplicate furniture.

Every generated SketchUp component must have stable metadata:

``` text
woodworking_ai.project_id
woodworking_ai.part_id
woodworking_ai.part_type
woodworking_ai.material
```

Before creating a part:

``` text
find(part_id)
```

If present, update it.

If absent, create it.

This is essential for iterative AI editing.

------------------------------------------------------------------------

## 17. Undo Behavior

Each agent instruction should ideally correspond to one logical SketchUp
undo operation.

Example:

``` text
Woodworking AI — Resize Bench
```

rather than many individual operations.

------------------------------------------------------------------------

## 18. Logging

Create logs under:

``` text
logs/
```

Capture:

``` text
timestamp
MCP tool
request ID
SketchUp command
parameters
duration
result
error
```

Never log secrets or API keys.

------------------------------------------------------------------------

## 19. Testing

Implement three levels of tests.

### Unit tests

Test:

-   schemas
-   dimensional calculations
-   validation
-   cut-list generation
-   serialization
-   command generation

### Bridge tests

Verify the TypeScript client can communicate with the SketchUp
extension.

### End-to-end tests

Require SketchUp to be running.

Golden test:

``` text
Create 48 × 18 × 1 panel.
```

Then query it.

Expected:

``` text
length = 48
width = 18
thickness = 1
```

------------------------------------------------------------------------

## 20. macOS Installation

Create:

``` text
scripts/install-extension.sh
```

The script should locate the SketchUp Pro 2026 macOS plugin directory
and symlink the development extension into it rather than repeatedly
copying files.

Also create:

``` text
scripts/package-extension.sh
```

for packaging the extension as an `.rbz`.

Document all macOS-specific setup in:

``` text
docs/setup-macos.md
```

------------------------------------------------------------------------

## 21. AGENTS.md Requirements

Create an `AGENTS.md` telling all future agents:

``` text
This repository controls SketchUp.

NEVER:

- execute arbitrary Ruby received from an MCP client
- bind the bridge to a public interface
- delete unknown SketchUp geometry
- modify components without woodworking_ai metadata
- silently change units
- scale the complete furniture model to satisfy dimension changes
- commit secrets
- place API keys in source files

ALWAYS:

- preserve stable part IDs
- validate tool inputs
- make SketchUp operations undoable
- update project definition before geometry
- regenerate outputs after dimensional changes
- preserve manually-created SketchUp geometry
- return structured errors
```

------------------------------------------------------------------------

## 22. Human Setup / Work Outside Codex

The human user should perform only setup that requires account access,
GUI interaction, credentials, or operating-system approval.

### Already completed

-   SketchUp Pro 2026 is installed on macOS.

### User must do

1.  Install/open Codex and sign in with the user's ChatGPT account.
2.  Keep SketchUp Pro 2026 available for integration testing.
3.  Allow installation/loading of the locally developed SketchUp
    extension if SketchUp or macOS prompts.
4.  Restart SketchUp when requested after extension installation.
5.  Approve the local MCP configuration when required.
6.  Keep SketchUp open during end-to-end tests.

### Codex should handle where possible

Codex should detect and, where permitted, install/configure:

-   Git repository
-   Node.js/npm dependencies
-   TypeScript dependencies
-   MCP SDK
-   Zod
-   test dependencies
-   project directories
-   SketchUp development extension symlink
-   MCP configuration
-   scripts
-   documentation

If a dependency cannot safely be installed automatically, Codex should
stop and give the user one precise manual action rather than providing a
long generic setup guide.

------------------------------------------------------------------------

## 23. API Keys and Authentication

### V1

Do **not** require an OpenAI API key merely to make this project work.

The intended V1 architecture is:

``` text
ChatGPT/Codex account
        ↓
      Codex
        ↓
  Woodworking MCP
        ↓
SketchUp Extension
        ↓
     SketchUp
```

Codex is the AI host and invokes the MCP tools.

No application-level OpenAI API call is required.

Do not ask the user to create an API key unless implementation proves
one is actually necessary.

### Future standalone application

An API key becomes relevant if the project later evolves into its own
application:

``` text
Woodworking AI application
          ↓
      OpenAI API
          ↓
   application tools
          ↓
       SketchUp
```

At that point:

1.  User creates an OpenAI API project/key.
2.  Key is stored in an environment variable or secure credential store.
3.  Key is never committed to Git.
4.  `.env` must be ignored by Git.
5.  API usage/cost is separate from ordinary ChatGPT usage.

This is explicitly outside V1.

------------------------------------------------------------------------

## 24. Codex Implementation Sequence

Do not attempt the entire system at once.

Complete and verify these checkpoints in order:

1.  Scaffold repository and documentation.
2.  Create Ruby `create_board`.
3.  Verify Ruby code manually creates a tabletop in SketchUp.
4.  Package/install the SketchUp extension.
5.  Build localhost JSON bridge.
6.  Verify a local test command can create a tabletop.
7.  Build TypeScript MCP server.
8.  Expose `sketchup_status`.
9.  Expose `create_board`.
10. Connect MCP to Codex.
11. Verify Codex can create a tabletop.
12. Implement persistent part IDs.
13. Implement project YAML/schema.
14. Implement update/move/delete/read tools.
15. Implement bench project generation.
16. Implement scene generation.
17. Implement PNG export.
18. Implement `.skp` save.
19. Implement cut-list generation.
20. Implement BOM generation.
21. Implement modification workflow.
22. Run final acceptance test.

**Do not proceed to the next major layer until the previous checkpoint
passes.**

When a checkpoint requires human GUI interaction, tell the user exactly
what action is required and wait for confirmation before continuing.

------------------------------------------------------------------------

## 25. Final Acceptance Test

The implementation is complete when the user can open an empty SketchUp
document and tell Codex:

> Build me a 60-inch-wide entry bench, 18 inches deep and 30 inches
> tall. Use four 2-inch-square legs, a 1-inch-thick top, 4-inch aprons,
> and a lower shelf 6 inches above the floor.

Without the user writing code, Codex should:

``` text
✓ create project definition
✓ create all SketchUp geometry
✓ name all components
✓ attach part metadata
✓ arrange components correctly
✓ zoom camera to the bench
✓ save bench.skp
✓ save perspective.png
✓ save front.png
✓ save side.png
✓ save top.png
✓ generate cut-list.csv
✓ generate bill-of-materials.csv
✓ generate build-plan.md
```

Then the user says:

> Make it 72 inches wide, make the shelf 3 inches higher, and change the
> legs to 2½ inches square.

The system must:

``` text
✓ update the existing model rather than create a second bench
✓ update dependent dimensions
✓ reposition dependent parts
✓ preserve unaffected dimensions
✓ regenerate visualizations
✓ regenerate cut list
✓ regenerate BOM
✓ update build plan
✓ save the revised SketchUp model
```

V1 is successful only when this full loop works reliably.

------------------------------------------------------------------------

## 26. Explicitly Out of Scope for V1

Do not allow these features to distract from the acceptance test:

-   voice input
-   custom graphical UI
-   cloud hosting
-   database
-   user accounts
-   mobile app
-   complex joinery
-   mortise/tenon generation
-   dovetails
-   CNC/G-code
-   structural engineering
-   photorealistic rendering
-   lumber pricing
-   purchasing integrations
-   sophisticated stock optimization
-   image/sketch interpretation
-   automatic tool selection
-   PDF build books

These are potential V2+ features.

------------------------------------------------------------------------

## 27. Development Principle

Prioritize a narrow, reliable vertical slice:

``` text
Natural-language request
        ↓
Codex
        ↓
our MCP tools
        ↓
our Ruby extension
        ↓
SketchUp geometry
        ↓
structured project files
        ↓
visual confirmation
```

Own the integration code. Use SketchUp's supported Ruby API and the
official MCP SDK. Avoid making low-adoption community MCP servers
runtime dependencies.

The goal of V1 is not to build a complete woodworking CAD platform.

The goal is to prove that an AI agent can reliably design, render,
inspect, modify, and export a simple piece of buildable furniture in
SketchUp through a controlled local interface.
