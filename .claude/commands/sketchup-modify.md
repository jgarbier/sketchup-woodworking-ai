Modify an existing furniture project in SketchUp.

The user's request is: $ARGUMENTS

The argument format is: `{project-id} {description of changes}`
Example: `media-console-001 make it 72 inches wide and add a second shelf to the right bay`

## Steps

1. **Identify the project.** Extract the project ID from the argument. Read `projects/{id}/state.json` to get the current definition and revision.

2. **Understand the current design.** Print the overall dimensions and list all parts with their dimensions and positions. Read `projects/{id}/renders/perspective.png` to see the current state visually.

3. **Plan the changes.** For each requested change, determine:
   - Which parts are directly affected (resize, reposition, add, remove)
   - Which parts are dependent and must move/resize accordingly
   - Do not scale the whole model — update each part individually

4. **Compute new positions.** Verify all arithmetic with a `node -e` snippet before applying. Check for: parts that would overlap, parts that would fall outside the overall bounding box, shelves that would be too close together.

5. **Apply the changes.** Write an inline update script or modify the existing `scripts/create-{id}.mjs` and re-run it. Use the current `revision` from state.json as `expected_revision` to prevent conflicts.

6. **Re-render.** Run `node --input-type=module` to call `export_project` via the MCP, or re-run the creation script. Read the updated renders and verify the changes look correct.

7. **Summarize** what changed: which parts were resized, repositioned, added, or removed. Show before/after overall dimensions. Commit if the result looks correct.

## Rules
- Always read the current state before modifying — never guess the current revision
- Preserve all part IDs that are not being deleted
- After dimensional changes: regenerate cut list, BOM, and renders (export_project handles this)
- If the change is ambiguous, ask one clarifying question before proceeding
