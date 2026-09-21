import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {fileURLToPath} from 'node:url';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../', import.meta.url));
const client = new Client({name: 'spread-projects', version: '1.0.0'});

// Lay pieces out side by side along X with 24" gaps between them.
// bench(72") — 24" gap — bookshelf(36") — 24" gap — media console(60")
const layout = [
  {id: 'acceptance-bench',  xOffset: 0},
  {id: 'bookshelf-001',     xOffset: 72 + 24},        // 96"
  {id: 'media-console-001', xOffset: 72 + 24 + 36 + 24}, // 156"
];

function withXOffset(definition, xOffset) {
  if (xOffset === 0) return definition;
  return {
    ...definition,
    parts: definition.parts.map(part => ({
      ...part,
      position: {...part.position, x: part.position.x + xOffset},
      additional_positions: part.additional_positions.map(pos => ({
        ...pos, x: pos.x + xOffset
      }))
    }))
  };
}

try {
  await client.connect(new StdioClientTransport({
    command: root + 'node_modules/node/bin/node',
    args: [root + 'dist/index.js']
  }));

  async function call(name, args) {
    const r = await client.callTool({name, arguments: args}, undefined, {timeout: 120000});
    const parsed = JSON.parse(r.content[0].text);
    assert.equal(parsed.success, true, JSON.stringify(parsed));
    return parsed.result;
  }

  for (const {id, xOffset} of layout) {
    const state = JSON.parse(await readFile(root + `projects/${id}/state.json`, 'utf8'));
    const definition = withXOffset(state.definition, xOffset);

    const raw = await client.callTool({name: 'get_model', arguments: {project_id: id}}, undefined, {timeout: 30000});
    const current = JSON.parse(raw.content[0].text);
    const expected_revision = current.success ? current.result.revision : null;

    const applied = await call('create_project', {definition, expected_revision});
    console.log(`${id}: offset +${xOffset}" → revision ${applied.revision}`);
  }

  console.log('All projects spread. Fitting camera...');
  await call('fit_camera', {project_id: 'acceptance-bench', view: 'perspective'});
  console.log('Done.');
} finally {
  await client.close();
}
