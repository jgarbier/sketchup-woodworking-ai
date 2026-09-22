# Checkpoints

Internal development verification log.

1–4. Passed: scaffold, Ruby primitive, live tabletop, installed extension.
5–6. Passed: localhost JSON bridge and live Node-to-SketchUp test (SketchUp 26.2.242).
7–9. Passed: official MCP SDK TypeScript server, sketchup_status and create_board tools.
      The get_part query tool also verifies actual geometry. Live stdio MCP test creates/updates
      one tabletop twice, then queries a solid 48 × 18 × 1 component without duplicates.
10–11. Passed: MCP server registered and verified via native agent tool calls.
12. Stable project/part IDs already verified; quantity adds stable instance_index metadata.
13. YAML + generated JSON Schema implemented; TypeScript and Ruby validation tests pass.
14. Passed live: create/update/move/delete, stale revision rejection, YAML round trip,
    quantity expansion and rotations. File/model rollback also tested locally.
15. Passed live: initial 60 × 18 × 30 bench with 14 solid components.
16–20. Scene, PNG, SKP, cut list, BOM and build-plan code implemented and verified.
21–22. Automatic regeneration and full modification acceptance script verified live.
23. V2 door assemblies: sliding/hinged doors rendered as SketchUp groups, visible in all views.
24. V2 joint types: dado, rabbet, mortise-tenon and 5 others; visual tenon-box markers,
    joinery-schedule.csv, and ## Joinery section in build-plan.md.

Current validation: TypeScript build, 18 Ruby tests / 75 assertions, and 12 Vitest tests pass.
