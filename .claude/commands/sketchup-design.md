Design a new furniture piece in SketchUp from a natural-language description.

The user's request is: $ARGUMENTS

## Steps

1. **Parse the request.** Extract: furniture type, overall dimensions (or reasonable defaults for the type), material, style notes, and any structural requirements (number of shelves, drawers, sections, etc.).

2. **Derive a project slug** from the furniture type (e.g. `floating-shelf`, `nightstand-001`). Check `projects/` to avoid collisions.

3. **Design the geometry.** Work out all part positions before writing any code. Use the coordinate convention: X = width, Y = depth, Z = height, origin = front-left-bottom. All units in inches. Verify every position arithmetic in a `node -e` snippet before committing to the script.

4. **Write `scripts/create-{slug}.mjs`.** Follow the exact pattern of `scripts/create-media-console.mjs`:
   - Define a `{name}Definition()` function that returns the full project definition object
   - Parts must include: id, name, type, material, quantity, dimensions, position, rotation, additional_positions, stock_type, grain_direction, notes
   - Connect via MCP StdioClientTransport, call `get_model` for current revision, call `create_project`, call `get_model_summary`, call `export_project`
   - Assert `exported.complete === true`

5. **Run the script:** `node scripts/create-{slug}.mjs`

6. **Read and display the renders.** Read `projects/{id}/renders/perspective.png` and `projects/{id}/renders/front.png` using the Read tool. Visually inspect for geometry errors (overlapping parts, wrong proportions, missing components).

7. **If issues found**, fix the script and re-run. Do not report success until the renders look correct.

8. **Summarize:** overall dimensions, number of parts, materials, bay/section layout, and the files generated. Commit the new script with `git add scripts/create-{slug}.mjs && git commit`.

## Constraints
- Never scale the whole model to satisfy dimension changes — resize individual parts
- All parts must have stable, unique `id` strings (snake_case)
- Do not expose arbitrary Ruby execution
- Rotations: ry=-90 makes a board stand up vertically (length→Z); rx=90 makes a flat panel face front (length→X, width→Z)
