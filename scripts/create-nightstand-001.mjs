import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));

// ─── Shared box geometry (same for all 3 drawers: same opening width/depth) ───
// All openings: 20.5"W × 17.75"D interior
// Lower cubby (12"H): 2 stacked drawers → box_h = 5.875"
// Upper bay  (6.75"H): 1 drawer         → box_h = 6.6875"
const BOX_W = 19.375;  // opening_width - 2*slide_clr = 20.5 - 1.125
const BOX_D = 16.25;   // opening_depth - 1.5 = 17.75 - 1.5
const BOX_T = 0.5, FACE_T = 0.75, BOTTOM_T = 0.5, DADO = 0.25;
const INNER_W   = BOX_W - 2 * BOX_T;          // 18.375
const BOTTOM_W  = INNER_W + 2 * DADO;         // 18.875
const BOTTOM_D  = BOX_D - BOX_T - DADO;       // 15.5

// ─── Lower cubby (two drawers, undermount: top_clear=0.0625, bottom_clear=0) ──
const LO_BOX_H  = 5.875;                       // (12 - 0.125) / 2 - 0.0625
const LO_BACK_H = LO_BOX_H - BOTTOM_T - DADO; // 5.125
const LO_FACE_W = 21.5, LO_FACE_H = 6.4375;

// Lower cubby z positions
const d1Z    = 7.75;                                    // top of carcass bottom panel
const d2Z    = d1Z + LO_BOX_H + 0.0625 + 0.125;        // 13.8125
const face1Z = d1Z - 0.5;                              // 7.25  (full-overlay below)
const face2Z = face1Z + LO_FACE_H + 0.125;             // 13.8125

// ─── Upper bay (one drawer, same slide spec) ──────────────────────────────────
const UP_BOX_H  = 6.6875;                      // 6.75 - 0.0625
const UP_BACK_H = UP_BOX_H - BOTTOM_T - DADO; // 5.9375
const d3Z = 20.5;                              // top of divider shelf

// ─── Shared X / Y positions (same for all drawers) ───────────────────────────
const leftSideX  = 0.75 + 0.5625;                   // 1.3125
const rightSideX = leftSideX + BOX_W - BOX_T;       // 20.1875
const subFrontX  = leftSideX + BOX_T;               // 1.8125
const boxY       = FACE_T;                          // 0.75
const backY      = FACE_T + BOX_D - BOX_T;          // 16.5
const botX       = leftSideX + BOX_T - DADO;        // 1.5625
const botY       = FACE_T + BOX_T - DADO;           // 1.0
const faceX      = 0.75 - 0.5;                      // 0.25

function boxPart(id, name, length, width, thickness, pos, rotation, material, notes = []) {
  return {
    id, name, type: 'panel', material, quantity: 1,
    dimensions: {length, width, thickness}, position: pos, rotation,
    additional_positions: [],
    stock_type: material === 'walnut' ? 'hardwood' : 'sheet_good',
    grain_direction: 'length', notes,
  };
}

function drawerBoxParts(prefix, label, boxH, backH, zBottom) {
  const r90z90 = {x:90, y:0, z:90};
  const r90    = {x:90, y:0, z:0};
  const flat   = {x:0,  y:0, z:0};
  return [
    boxPart(`${prefix}_left_side`,  `${label} Left Side`,  BOX_D,    boxH,   BOX_T,   {x:leftSideX,  y:boxY,  z:zBottom}, r90z90, 'birch_plywood'),
    boxPart(`${prefix}_right_side`, `${label} Right Side`, BOX_D,    boxH,   BOX_T,   {x:rightSideX, y:boxY,  z:zBottom}, r90z90, 'birch_plywood'),
    boxPart(`${prefix}_sub_front`,  `${label} Sub-Front`,  INNER_W,  boxH,   BOX_T,   {x:subFrontX,  y:boxY,  z:zBottom}, r90,    'birch_plywood'),
    boxPart(`${prefix}_back`,       `${label} Back`,       INNER_W,  backH,  BOX_T,   {x:subFrontX,  y:backY, z:zBottom}, r90,    'birch_plywood'),
    boxPart(`${prefix}_bottom`,     `${label} Bottom`,     BOTTOM_W, BOTTOM_D, BOTTOM_T, {x:botX, y:botY, z:zBottom}, flat, 'birch_plywood',
      ['1/2" bottom panel for undermount slide cradle; notch rear corners 1/2"×1/2" for mounting clips']),
  ];
}

function facePanel(prefix, label, faceW, faceH, faceZ) {
  return boxPart(`${prefix}_face`, `${label} Face`, faceW, faceH, FACE_T,
    {x:faceX, y:0, z:faceZ}, {x:90, y:0, z:0}, 'walnut');
}

// All drawer parts (lower has separate faces; upper reuses existing drawer_face)
const drawerParts = [
  ...drawerBoxParts('d1', 'Lower Drawer 1', LO_BOX_H, LO_BACK_H, d1Z),
  facePanel('d1', 'Lower Drawer 1', LO_FACE_W, LO_FACE_H, face1Z),
  ...drawerBoxParts('d2', 'Lower Drawer 2', LO_BOX_H, LO_BACK_H, d2Z),
  facePanel('d2', 'Lower Drawer 2', LO_FACE_W, LO_FACE_H, face2Z),
  ...drawerBoxParts('d3', 'Upper Drawer', UP_BOX_H, UP_BACK_H, d3Z),
  // d3 face = existing drawer_face part (no new panel added)
];

const drawerAssemblies = [
  {
    id: 'lower_drawer_1', name: 'Lower Drawer 1',
    parts: ['d1_left_side', 'd1_right_side', 'd1_sub_front', 'd1_back', 'd1_bottom'],
    face_part_id: 'd1_face',
    slide_type: 'undermount', clearance_left: 0.5625, clearance_right: 0.5625,
    clearance_top: 0.0625, extension: 'full',
  },
  {
    id: 'lower_drawer_2', name: 'Lower Drawer 2',
    parts: ['d2_left_side', 'd2_right_side', 'd2_sub_front', 'd2_back', 'd2_bottom'],
    face_part_id: 'd2_face',
    slide_type: 'undermount', clearance_left: 0.5625, clearance_right: 0.5625,
    clearance_top: 0.0625, extension: 'full',
  },
  {
    id: 'upper_drawer', name: 'Upper Drawer',
    parts: ['d3_left_side', 'd3_right_side', 'd3_sub_front', 'd3_back', 'd3_bottom'],
    face_part_id: 'drawer_face',  // existing walnut face panel
    slide_type: 'undermount', clearance_left: 0.5625, clearance_right: 0.5625,
    clearance_top: 0.0625, extension: 'full',
  },
];

// Drawer part IDs — strip these from whatever the model has so the script is idempotent
const DRAWER_PREFIXES = ['d1_', 'd2_', 'd3_'];

const client = new Client({name: 'nightstand-001-creator', version: '1.0.0'});
try {
  await client.connect(new StdioClientTransport({
    command: root + 'node_modules/node/bin/node',
    args: [root + 'dist/index.js'],
  }));

  async function raw(name, args) {
    const result = await client.callTool({name, arguments: args});
    return JSON.parse(result.content[0].text);
  }
  async function call(name, args) {
    const result = await raw(name, args);
    assert.equal(result.success, true, JSON.stringify(result));
    return result.result;
  }

  const project_id = 'nightstand-001';
  const modelState = await raw('get_model', {project_id});
  const revision = modelState.success && modelState.result?.revision != null
    ? modelState.result.revision : null;

  // Base definition: live model or disk state, with any prior drawer parts stripped
  // so this script is safe to re-run without duplicating parts.
  const rawDef = modelState.success && modelState.result?.definition != null
    ? modelState.result.definition
    : JSON.parse(readFileSync(root + `projects/${project_id}/state.json`, 'utf8')).definition;
  const baseParts = rawDef.parts.filter(p =>
    !DRAWER_PREFIXES.some(pfx => p.id.startsWith(pfx)));
  console.log(`Base parts: ${baseParts.length}, adding ${drawerParts.length} drawer parts`);

  const definition = {
    ...rawDef,
    parts: [...baseParts, ...drawerParts],
    drawer_assemblies: drawerAssemblies,
    notes: [
      ...rawDef.notes.filter(n =>
        !n.includes('V2 detail') && !n.includes('Lower cubby') &&
        !n.includes('Faces:') && !n.includes('Undermount slides:')),
      'Lower cubby: 2-drawer stack on 16" undermount slides. Box: 19-3/8"W × 5-7/8"H × 16-1/4"D Baltic birch plywood.',
      'Upper bay: 1 drawer on 16" undermount slides. Box: 19-3/8"W × 6-11/16"H × 16-1/4"D Baltic birch plywood.',
      'Faces: full-overlay walnut, lower pair 21-1/2"W × 6-7/16"H with 1/8" gap; upper uses existing flush face.',
      'Undermount slides: 1/2"×1/2" rear corner notches on box sides; rear nailer board in cabinet for slide attachment.',
    ],
  };

  const created = await call('create_project', {definition, expected_revision: revision});
  console.log('Created revision:', created.revision);

  const summary = await call('get_model_summary', {project_id});
  console.log('Parts in model:', summary.physical_part_count);

  const exported = await call('export_project', {project_id});
  assert.ok(exported.complete, 'Export must be complete');
  console.log('Export complete.');
} finally {
  await client.close();
}
