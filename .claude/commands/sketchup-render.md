Re-export and visually review renders for a furniture project.

The user's request is: $ARGUMENTS

The argument is a project ID (e.g. `media-console-001`). If omitted, list available projects and ask.

## Steps

1. **Verify the bridge is running.** Run:
   ```
   curl -s http://127.0.0.1:7654/status
   ```
   If it fails, tell the user to open SketchUp and run `/sketchup-reload`.

2. **Export fresh renders.** Run:
   ```js
   node --input-type=module <<'EOF'
   import {Client} from '@modelcontextprotocol/sdk/client/index.js';
   import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
   import {fileURLToPath} from 'node:url';
   const root = fileURLToPath(new URL('.', import.meta.url)) + '/';
   const client = new Client({name:'render',version:'1.0.0'});
   try {
     await client.connect(new StdioClientTransport({command:root+'node_modules/node/bin/node',args:[root+'dist/index.js']}));
     const r = await client.callTool({name:'export_project',arguments:{project_id:'{id}'}},undefined,{timeout:120000});
     console.log(JSON.parse(r.content[0].text));
   } finally { await client.close(); }
   EOF
   ```

3. **Read all renders.** Use the Read tool to load and display:
   - `projects/{id}/renders/perspective.png`
   - `projects/{id}/renders/front.png`
   - `projects/{id}/renders/top.png`
   - `projects/{id}/renders/right.png`

4. **Review and comment.** For each render, note:
   - Proportions (does the piece look right for its stated dimensions?)
   - Part alignment (are shelves flush? legs aligned? back panel seated correctly?)
   - Any visual anomalies (z-fighting, missing faces, parts at wrong orientation)

5. **Report findings.** List: what looks correct, any issues spotted, and recommended fixes if needed.
