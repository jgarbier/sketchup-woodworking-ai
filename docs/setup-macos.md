# macOS setup

Requirements: SketchUp Pro 2026, Node.js 18+, Git.

## 1. Clone and build

```sh
git clone https://github.com/jgarbier/sketchup-woodworking-ai.git
cd sketchup-woodworking-ai
npm ci
npm run build
npm test
```

## 2. Install the extension

```sh
./scripts/install-extension.sh
```

This creates symlinks in `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins`.
Repeating it is safe. Keep the repository in place — the extension loads directly from it.

Restart SketchUp, then choose **Extensions → Woodworking AI → Verify 48 × 18 × 1 Tabletop**.
Allow the locally developed extension if prompted. A success dialog confirms the extension loaded.

To package for distribution: `./scripts/package-extension.sh` produces `dist/woodworking-ai-0.1.0.rbz`.
The RBZ is an alternative to the symlink install; do not use both at once.

## 3. Verify the bridge

The extension starts the bridge automatically. To confirm it's running, open SketchUp's Ruby Console
(**Extensions → Developer → Ruby Console**) and run:

```ruby
load '/path/to/sketchup-woodworking-ai/scripts/reload-extension.rb'
```

Expected: `Woodworking AI project tools loaded (bridge version 3).`

The bridge listens on `127.0.0.1:48763`. If the port is occupied, the extension logs an error and
does not take over an existing listener.

## 4. Run the live tests

With SketchUp open and the bridge running:

```sh
node scripts/test-bridge.mjs    # basic bridge connectivity
node scripts/test-project.mjs   # project create/edit/delete cycle
node scripts/test-acceptance.mjs  # full bench build, resize, and export
```

Or run all live tests: `npm run test:live`

## 5. Register with your MCP client

See the [README](../README.md#register-the-mcp-server-with-your-agent) for per-client registration commands.
Use absolute paths to `node_modules/node/bin/node` and `dist/index.js` in your repo.

## Reloading the extension during development

After changing Ruby extension code:

1. Open SketchUp's Ruby Console
2. Run: `load '/path/to/sketchup-woodworking-ai/scripts/reload-extension.rb'`
3. Confirm output ends with `bridge version 3`

After changing TypeScript MCP code: `npm run build`, then restart your MCP client session.
