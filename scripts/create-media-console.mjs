import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../', import.meta.url));
const client = new Client({name: 'media-console-builder', version: '1.0.0'});

function mediaConsoleDefinition() {
  const id = 'media-console-001';

  // Overall
  const width = 60, depth = 20, totalHeight = 26;

  // Legs
  const legH = 8, legSz = 1.5;

  // Carcass
  const thick = 0.75, backThick = 0.25;
  const bodyH    = totalHeight - legH;      // 18"
  const intWidth  = width - 2 * thick;       // 58.5"
  const intHeight = bodyH - 2 * thick;       // 16.5"
  const intDepth  = depth - backThick;       // 19.75"
  const intBottom = legH + thick;            // 8.75" — top of bottom panel
  const intTop    = totalHeight - thick;     // 25.25" — bottom of top panel

  // Three equal sections (vinyl | record player | equipment)
  const sectionW   = (intWidth - 2 * thick) / 3;   // 19" each
  const leftDivX   = thick + sectionW;               // 19.75 — left edge of left divider
  const rightDivX  = leftDivX + thick + sectionW;    // 39.5  — left edge of right divider

  // Mid-height shelf in left and right sections
  const shelfZ = intBottom + (intHeight - thick) / 2;  // perfectly centred → 16.625"

  const parts = [];

  function add(pid, name, length, w, t, x, y, z, rotation = {x:0,y:0,z:0}, material = 'walnut') {
    parts.push({
      id: pid, name,
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

  // ── Legs (ry=-90 → length rises along Z) ─────────────────────────────────
  // Inset 3" from left/right, 2" from front/back — gives MCM floating look
  const legInX = 3, legInY = 2;
  add('front_left_leg',  'Front Left Leg',  legH, legSz, legSz, legInX,                  legInY,                   0, {x:0,y:-90,z:0});
  add('front_right_leg', 'Front Right Leg', legH, legSz, legSz, width - legInX - legSz,  legInY,                   0, {x:0,y:-90,z:0});
  add('rear_left_leg',   'Rear Left Leg',   legH, legSz, legSz, legInX,                  depth - legInY - legSz,   0, {x:0,y:-90,z:0});
  add('rear_right_leg',  'Rear Right Leg',  legH, legSz, legSz, width - legInX - legSz,  depth - legInY - legSz,   0, {x:0,y:-90,z:0});

  // ── Cabinet sides (ry=-90 → length rises along Z) ────────────────────────
  add('left_side',  'Left Side',  bodyH, depth, thick, 0,            0, legH, {x:0,y:-90,z:0});
  add('right_side', 'Right Side', bodyH, depth, thick, width - thick, 0, legH, {x:0,y:-90,z:0});

  // ── Top and bottom panels (flat) ──────────────────────────────────────────
  add('bottom', 'Bottom', intWidth, depth, thick, thick, 0, legH);
  add('top',    'Top',    intWidth, depth, thick, thick, 0, totalHeight - thick);

  // ── Back panel — birch ply (rx=90 → length stays X, width rises Z) ───────
  add('back', 'Back Panel', intWidth, intHeight, backThick,
      thick, depth - backThick, intBottom, {x:90,y:0,z:0}, 'birch_plywood');

  // ── Interior dividers (ry=-90) ────────────────────────────────────────────
  add('left_divider',  'Left Divider',  intHeight, intDepth, thick, leftDivX,  0, intBottom, {x:0,y:-90,z:0});
  add('right_divider', 'Right Divider', intHeight, intDepth, thick, rightDivX, 0, intBottom, {x:0,y:-90,z:0});

  // ── Shelves in left (vinyl) and right (equipment) sections ───────────────
  add('left_shelf',  'Left Shelf',  sectionW, intDepth, thick, thick,           0, shelfZ);
  add('right_shelf', 'Right Shelf', sectionW, intDepth, thick, rightDivX + thick, 0, shelfZ);

  return {
    project: {id, name: 'Mid-Century Media Console', units: 'inches'},
    overall: {width, depth, height: totalHeight},
    materials: [
      {id: 'walnut',        species: 'walnut', type: 'hardwood'},
      {id: 'birch_plywood', species: 'birch',  type: 'sheet_good'}
    ],
    parts,
    relationships: [
      {part_id: 'bottom',        depends_on: ['front_left_leg','front_right_leg','rear_left_leg','rear_right_leg'], description: 'Cabinet body rests on four legs'},
      {part_id: 'top',           depends_on: ['left_side','right_side'],   description: 'Top panel sits between sides'},
      {part_id: 'back',          depends_on: ['left_side','right_side','top','bottom'], description: 'Back panel in rabbets'},
      {part_id: 'left_divider',  depends_on: ['bottom','top'],             description: 'Divides vinyl bay from centre'},
      {part_id: 'right_divider', depends_on: ['bottom','top'],             description: 'Divides centre from equipment bay'},
      {part_id: 'left_shelf',    depends_on: ['left_side','left_divider'], description: 'Mid-height shelf in vinyl bay'},
      {part_id: 'right_shelf',   depends_on: ['right_divider','right_side'], description: 'Mid-height shelf in equipment bay'}
    ],
    notes: [
      'All dimensions are finished sizes.',
      '4 solid walnut legs inset 3" from sides and 2" from front/back for MCM floating look.',
      'Centre bay (19"W × 19.75"D × 16.5"H) is fully open for record player and amp.',
      'Left and right bays each have one centred shelf — 7.875" clear height above and below.',
      'Back panel is 1/4" birch plywood.',
      'Tapered legs, cane panels, and sliding doors are V2 features.',
      'Total height 26": 8" leg + 18" carcass.'
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

  const definition = mediaConsoleDefinition();
  const project_id = definition.project.id;

  const raw = await client.callTool({name: 'get_model', arguments: {project_id}}, undefined, {timeout: 30000});
  const current = JSON.parse(raw.content[0].text);
  const expected_revision = current.success ? current.result.revision : null;

  console.log(`Creating ${definition.project.name} (${definition.overall.width}"W × ${definition.overall.depth}"D × ${definition.overall.height}"H)...`);
  const applied = await call('create_project', {definition, expected_revision});
  console.log(`Applied — revision ${applied.revision}, parts: ${applied.affected_part_ids.length}`);

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
    sections: {
      left_vinyl_bay: '19"W open with mid shelf',
      centre_record_player: '19"W fully open',
      right_equipment_bay: '19"W open with mid shelf'
    }
  }, null, 2));
} finally {
  await client.close();
}
