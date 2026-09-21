# Checkpoints
1–4. Passed: scaffold, Ruby primitive, live tabletop, installed extension.
5–6. Passed: localhost JSON bridge and live Node-to-SketchUp test (SketchUp 26.2.242).
7–9. Passed: official MCP SDK TypeScript server, sketchup_status and create_board tools.
The get_part query tool also verifies actual geometry. Live stdio MCP test creates/updates
one tabletop twice, then queries a solid 48 × 18 × 1 component without duplicates.
10. Passed: woodworking server registered globally with codex mcp add; enabled configuration verified.
11. PASSED: native Codex sketchup_status, create_board and get_part calls succeeded.
12. Stable project/part IDs already verified; quantity adds stable instance_index metadata.
13. YAML + generated JSON Schema implemented; TypeScript and Ruby validation tests pass.
14. PASSED live: create/update/move/delete, stale revision rejection, YAML round trip,
quantity expansion and rotations. File/model rollback also tested locally.
15. PASSED live: initial 60 × 18 × 30 bench with 14 solid components.
16–20. Scene, PNG, SKP, cut list, BOM and build-plan code implemented. Awaiting live
reload version 3 and output tests. No export success claimed yet.
21–22. Automatic regeneration and full modification acceptance script prepared; pending live tests.

Current validation: TypeScript build, 18 Ruby tests / 75 assertions, and 12 Vitest tests pass.
