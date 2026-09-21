import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../', import.meta.url));
const client = new Client({name: 'bookshelf-builder', version: '1.0.0'});

function bookcaseDefinition() {
  const id = 'bookshelf-001';
  const width = 36, depth = 12, height = 72;
  const sideThick = 0.75, shelfThick = 0.75, backThick = 0.25;
  const interiorWidth = width - 2 * sideThick;    // 34.5"
  const interiorDepth = depth - backThick;          // 11.75"
  const interiorHeight = height - 2 * sideThick;   // 70.5"

  // 4 shelves divide interior into 5 equal bays
  const numShelves = 4;
  const bayHeight = (interiorHeight - numShelves * shelfThick) / (numShelves + 1); // 13.5"

  const parts = [];

  function add(partId, name, length, w, t, x, y, z, rotation = {x:0,y:0,z:0}, material = 'white_oak') {
    parts.push({
      id: partId, name,
      type: 'panel',
      material,
      quantity: 1,
      dimensions: {length, width: w, thickness: t},
      position: {x, y, z},
      rotation,
      additional_positions: [],
      stock_type: material === 'birch_plywood' ? 'sheet_good' : 'hardwood',
      grain_direction: 'length',
      notes: []
    });
  }

  // Sides: ry=-90 stands them up (length→Z, width→Y, thickness→X)
  add('left_side',  'Left Side',  height, depth, sideThick, 0,                  0, 0, {x:0, y:-90, z:0});
  add('right_side', 'Right Side', height, depth, sideThick, width - sideThick,  0, 0, {x:0, y:-90, z:0});

  // Top and bottom (horizontal, fit between the sides)
  add('top',    'Top',    interiorWidth, depth, shelfThick, sideThick, 0, height - shelfThick);
  add('bottom', 'Bottom', interiorWidth, depth, shelfThick, sideThick, 0, 0);

  // Fixed shelves (horizontal, slightly less deep to clear the back panel)
  for (let i = 0; i < numShelves; i++) {
    const z = sideThick + (i + 1) * bayHeight + i * shelfThick;
    add(`shelf_${i + 1}`, `Shelf ${i + 1}`, interiorWidth, interiorDepth, shelfThick, sideThick, 0, z);
  }

  // Back panel: rx=90 makes it vertical (length→X, width→Z, thickness→-Y)
  // Placed so its face sits flush with the back edges of the sides (y = 11.75 to 12)
  add('back', 'Back Panel', interiorWidth, interiorHeight, backThick,
      sideThick, depth - backThick, sideThick, {x:90, y:0, z:0}, 'birch_plywood');

  return {
    project: {id, name: 'Bookshelf', units: 'inches'},
    overall: {width, depth, height},
    materials: [
      {id: 'white_oak',     species: 'white_oak', type: 'hardwood'},
      {id: 'birch_plywood', species: 'birch',     type: 'sheet_good'}
    ],
    parts,
    relationships: [
      {part_id: 'top',    depends_on: ['left_side', 'right_side'], description: 'Top panel fits between sides'},
      {part_id: 'bottom', depends_on: ['left_side', 'right_side'], description: 'Bottom panel fits between sides'},
      ...Array.from({length: numShelves}, (_, i) => ({
        part_id: `shelf_${i + 1}`,
        depends_on: ['left_side', 'right_side'],
        description: `Shelf ${i + 1} is dadoed into sides`
      })),
      {part_id: 'back', depends_on: ['left_side', 'right_side', 'top', 'bottom'],
       description: 'Back panel fits in rabbets cut into sides, top, and bottom'}
    ],
    notes: [
      'All dimensions are finished sizes.',
      'Shelves are fixed; adjustable shelf pins are a V2 feature.',
      'Back panel is 1/4" birch plywood; all other parts are solid white oak.',
      'Bay clear height is 13.5" — suitable for standard paperback and hardcover books.',
      'Joinery details and fastener selection require separate construction review.'
    ]
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

  const definition = bookcaseDefinition();
  const project_id = definition.project.id;

  // Get current revision (null if new project)
  const raw = await client.callTool({name: 'get_model', arguments: {project_id}}, undefined, {timeout: 30000});
  const current = JSON.parse(raw.content[0].text);
  const expected_revision = current.success ? current.result.revision : null;

  console.log(`Creating bookshelf (${definition.overall.width}"W × ${definition.overall.depth}"D × ${definition.overall.height}"H)...`);
  const applied = await call('create_project', {definition, expected_revision});
  console.log(`Applied — revision ${applied.revision}, ${applied.affected_part_ids.length} parts`);

  const summary = await call('get_model_summary', {project_id});
  console.log(`Bounds: ${JSON.stringify(summary.bounds)}, ${summary.physical_part_count} components`);

  console.log('Exporting views, SKP, cut list and BOM...');
  const exported = await call('export_project', {project_id});
  assert.equal(exported.complete, true, JSON.stringify(exported));

  console.log(JSON.stringify({
    success: true,
    project_id,
    overall: definition.overall,
    parts: summary.physical_part_count,
    bay_clear_height_inches: 13.5,
    files: exported.files
  }, null, 2));
} finally {
  await client.close();
}
