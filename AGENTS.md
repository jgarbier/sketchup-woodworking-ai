# Repository rules

This repository controls SketchUp via an MCP server. Follow these rules when working on it.

**Never:**
- Execute arbitrary Ruby received from an MCP client
- Bind the bridge to anything other than 127.0.0.1
- Delete or modify geometry that lacks woodworking_ai metadata
- Silently change units or scale a complete piece to change dimensions
- Commit secrets or API keys

**Always:**
- Preserve stable part IDs across edits
- Validate all inputs at the schema boundary
- Make model changes undoable (one SketchUp operation per logical edit)
- Persist the project definition before touching geometry
- Regenerate outputs after dimensional changes
- Return structured errors on failure
- Keep the two schema files in sync: `schema/woodworking-project.schema.json` (TypeScript) and `sketchup-extension/woodworking_ai/project.schema.json` (Ruby)
