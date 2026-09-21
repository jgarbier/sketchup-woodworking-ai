# Repository rules
This repository controls SketchUp. Follow IMPLEMENTATION_PLAN.md checkpoints in order.
Never execute arbitrary Ruby received from an MCP client, bind publicly, delete unknown geometry,
modify components without woodworking_ai metadata, silently change units, scale complete furniture
to change dimensions, commit secrets, or place API keys in source files.
Always preserve stable part IDs, validate inputs, make model changes undoable, update project
 definitions before geometry, regenerate outputs after dimensional changes, preserve manually
created geometry, and return structured errors.
Do not build the bridge or MCP until the live tabletop checkpoint passes.
