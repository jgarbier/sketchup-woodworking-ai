Add a drawer stack to an existing furniture project in SketchUp.

The user's request is: $ARGUMENTS

The argument format is: `{project-id} {description}`
Example: `nightstand-001 add 2 drawers to the left bay, full-overlay, undermount slides`

## Steps

1. **Parse the request.** Extract:
   - `project_id` — the project to modify
   - Which opening to target — described spatially ("left bay", "top opening") or by adjacent part IDs
   - `drawer_count` — number of drawers stacked in that opening (ask if not stated)
   - `face_style` — `full-overlay` (default), `half-overlay`, or `inset`
   - `slide_type` — `undermount` (default), `side-mount`, or `center-mount`
   - `box_material` — default: match cabinet carcass material
   - `face_material` — default: match cabinet face/door material, or carcass if no doors

2. **Read current model state.** Run both in parallel:
   - Read `projects/{id}/state.json` for the current definition, revision, and part list
   - Read `projects/{id}/renders/perspective.png` to see the current state visually
   
   Print the overall dimensions and list all parts with their dimensions and positions so you can reason about the opening geometry.

3. **Identify the opening bounds.** From the part positions, determine:
   - `opening_x` — X coordinate of the left wall of the opening (inside face of carcass side or divider)
   - `opening_width` — distance between the two side walls of the opening
   - `opening_z_bottom` — Z coordinate of the bottom of the opening (top of bottom rail or shelf)
   - `opening_height` — distance from bottom to top of opening (underside of top rail or carcass top)
   - `opening_depth` — interior depth (overall depth minus back panel thickness, typically overall.depth − 0.25 to 0.75)
   - `cabinet_front_y` — Y coordinate of the cabinet front face (usually 0)

   If the opening cannot be inferred unambiguously from part bounds, describe what you found and ask the user to confirm.

4. **Calculate drawer geometry.** Call the `calculate_drawer` MCP tool:
   ```
   calculate_drawer({
     opening_width, opening_height, opening_depth,
     drawer_count,           // integer
     slide_type, face_style,
     // gap_between, box_thickness, face_thickness use defaults unless user specified
   })
   ```
   The result gives exact cut dimensions for sides, sub-front, back, bottom, and face for each drawer. Read the `notes` array — it contains slide length recommendations and undermount-specific requirements.

5. **Plan positions.** Verify all arithmetic with a `node -e` snippet before writing the script. Use these conventions:
   - Coordinate system: X = width, Y = depth, Z = height, origin = front-left-bottom
   - **Box sides** (length=box_depth, width=box_height, thickness=box_thickness): rotation `{x:90, y:0, z:90}` → length runs along Y, width runs along Z. Left side at `x = opening_x + slide_clearance`, right side at `x = opening_x + slide_clearance + box_width − box_thickness`. Both at `y = cabinet_front_y + face_thickness`, `z = drawer_z_bottom`.
   - **Sub-front** (length=inner_width, width=box_height, thickness=box_thickness): rotation `{x:90, y:0, z:0}` → length along X, width along Z. Position `x = left_side_x + box_thickness`, `y = cabinet_front_y + face_thickness`, `z = drawer_z_bottom`.
   - **Back** (length=inner_width, width=back_height, thickness=box_thickness): same rotation as sub-front. Position `y = cabinet_front_y + face_thickness + box_depth − box_thickness`, same x and z.
   - **Bottom panel** (length=bottom_width, width=bottom_depth, thickness=bottom_thickness): no rotation (flat). Position `x = left_side_x + box_thickness − dado_depth`, `y = cabinet_front_y + face_thickness + box_thickness − dado_depth`, `z = drawer_z_bottom` (dado sits at the very bottom of the box sides).
   - **Face** (length=face_width, width=face_height, thickness=face_thickness): rotation `{x:90, y:0, z:0}`. Position `x = opening_x − overlay`, `y = cabinet_front_y`, `z = face_z_bottom`.
     - `dado_depth = 0.25` (standard groove depth)
     - `overlay = 0.5` for full-overlay, `0.25` for half-overlay, `−0.0625` for inset
     - For full/half overlay: `face_z_bottom = opening_z_bottom − overlay`; for inset: `face_z_bottom = opening_z_bottom + 0.0625`
   - For stacked drawers: the first drawer sits at `opening_z_bottom`; each subsequent drawer's `drawer_z_bottom` = previous `drawer_z_bottom + box_height + slide[:bottom_clear] + slide[:top_clear] + gap_between`.

6. **Write the updated definition.** Modify `scripts/create-{id}.mjs` (or write an inline `node --input-type=module` script) to:
   - Keep all existing parts unchanged
   - Append new drawer parts (use IDs like `drawer1_left_side`, `drawer1_sub_front`, `drawer1_back`, `drawer1_bottom`, `drawer1_face`, repeated per drawer index)
   - Add a `drawer_assemblies` entry grouping the box parts (sides, sub-front, back, bottom) under `parts`, set `face_part_id` to the face panel ID, and fill in `slide_type`, `clearance_left`, `clearance_right`, `clearance_top`, `clearance_bottom`, and `extension: 'full'`
   - Read the current revision from state.json and pass it as `expected_revision`
   - Call `create_project` with the merged definition, then `export_project`

7. **Run the script:** `node scripts/create-{id}.mjs` (or the inline script).

8. **Read and display the renders.** Read `projects/{id}/renders/perspective.png` and `projects/{id}/renders/front.png`. Verify:
   - Faces are flush with the cabinet front (or inset as specified)
   - Boxes sit in the correct opening with visible clearance to the cabinet sides
   - Stack spacing looks even
   - No parts visibly overlapping the carcass

9. **If issues found**, fix the position arithmetic and re-run. Do not report success until renders look correct.

10. **Summarize and commit.** Report: drawer count, box dimensions, face dimensions, slide type, recommended slide length (from `calculate_drawer` notes), and new part count. Run `git add scripts/create-{id}.mjs && git commit`.

## Constraints
- Never scale the whole model — all dimensions come from `calculate_drawer` output
- `drawer_count` must be passed as an integer to `calculate_drawer`, not a float
- Box parts (sides, sub-front, back, bottom) go into `drawer_assemblies[].parts`; the face panel does NOT — it goes in `face_part_id` only, so it renders at the cabinet front separate from the box group
- If slide_type is `undermount`: the bottom panel is 0.5" thick (not 0.25"), and the project notes should mention rear corner notches and a nailer board — add these as part notes or project notes
- If the opening is too shallow for even one drawer at the minimum box height, report the constraint and suggest alternatives (fewer drawers, different slide type, taller opening)
- Part IDs must be stable snake_case strings unique within the project — prefix with `d1_`, `d2_` etc. for multi-drawer stacks
- Preserve all existing part IDs, joints, door_assemblies, and relationships in the merged definition
