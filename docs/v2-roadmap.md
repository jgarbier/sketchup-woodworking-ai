# V2 Roadmap

## Build Detail Enhancements

### Tapered and Angled Legs
V1 legs are rectangular prisms. V2 would add a `tapered_board` geometry primitive to the Ruby extension — a board with independent cross-sections at each end. This enables the tapered square legs and splayed angles that define mid-century modern furniture.

Requires: new `create_tapered_board` Ruby method, new MCP tool, schema changes to support `taper_start` and `taper_end` dimensions.

### Decorative Panels
Support for cane, fluted, and louvered panel faces. V1 panels are solid rectangles. V2 would add a `panel_type` field (`solid` | `cane` | `fluted` | `louvered`) and render the appropriate face pattern in SketchUp using repeated geometry.

Requires: SketchUp component library for panel face patterns, schema field addition.

### Joint Types
The most structurally meaningful V2 feature. Render actual joinery at part intersections rather than just abutting faces. Priority joints:

| Joint | Use case |
|-------|----------|
| Mortise and tenon | Legs to aprons, rail frames |
| Through tenon | Visible joinery, Shaker/Arts & Crafts |
| Dovetail | Case corners, drawer boxes |
| Box joint (finger) | Box construction |
| Dado / housing | Shelf-to-side connections |
| Rabbet | Back panel seating |

Implementation approach: joints are computed at the intersection of two parts and subtracted/added to the relevant component geometry using SketchUp's boolean operations. The project schema would add a `joints` array under `relationships`, specifying joint type, depth, and which faces are involved.

Requires: boolean geometry operations in Ruby, joint schema, significant MCP tool additions (`define_joint`, `render_joint_detail`).

## Other V2 Features

- **Scene-level transforms** — project origins independent of SketchUp world coordinates, so `project.yaml` positions are always relative to the piece's own front-left-bottom corner regardless of scene layout
- **Adjustable shelf pin holes** — render pin hole layouts on side panels
- **Sliding and hinged doors** — door panel geometry with clearance gaps
- **PDF build plan export** — formatted construction document
- **Material textures** — apply wood grain texture maps to SketchUp faces
- **Grain direction visualization** — color-code faces by grain direction for cut optimization
- **Stock optimization** — arrange cut list parts on standard sheet/board sizes to minimize waste
