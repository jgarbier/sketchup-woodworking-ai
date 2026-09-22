import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));

// Drawer geometry from calculate_drawer:
//   opening 20.5"W × 12"H × 17.75"D, 2 undermount drawers, full-overlay
// box_depth = opening_depth - 1.5 = 16.25
const BOX_W = 19.375, BOX_H = 5.875, BOX_D = 16.25;
const BOX_T = 0.5, FACE_T = 0.75, BOTTOM_T = 0.5; // undermount bottom is 1/2"
const INNER_W   = BOX_W - 2 * BOX_T;               // 18.375
const BOTTOM_W  = INNER_W + 2 * 0.25;              // 18.875
const BOTTOM_D  = BOX_D - BOX_T - 0.25;            // 15.5
const BACK_H    = BOX_H - BOTTOM_T - 0.25;         // 5.125
const FACE_W = 21.5, FACE_H = 6.4375;

// Opening geometry (lower cubby: inside carcass sides, above bottom panel, below divider shelf)
const OX = 0.75;       // inside face of left side
const OZ = 7.75;       // top of bottom panel (opening bottom)
const FRONT_Y = 0;     // cabinet front face
const SLIDE_CLR = 0.5625; // undermount each_side clearance
const OVERLAY   = 0.5;
const DADO      = 0.25;

// Shared X / Y positions for box parts
const leftSideX  = OX + SLIDE_CLR;                          // 1.3125
const rightSideX = leftSideX + BOX_W - BOX_T;               // 20.1875
const subFrontX  = leftSideX + BOX_T;                       // 1.8125
const boxY       = FRONT_Y + FACE_T;                        // 0.75  (where box starts behind face)
const backY      = FRONT_Y + FACE_T + BOX_D - BOX_T;       // 16.5
const botX       = leftSideX + BOX_T - DADO;                // 1.5625
const botY       = FRONT_Y + FACE_T + BOX_T - DADO;         // 1.0
const faceX      = OX - OVERLAY;                            // 0.25

// Drawer z positions (stacked, undermount: bottom_clear=0, top_clear=0.0625)
const d1Z    = OZ;                                           // 7.75
const d2Z    = d1Z + BOX_H + 0.0 + 0.0625 + 0.125;         // 13.8125

// Face z positions (face1 has overlay below opening; face2 follows immediately above face1+gap)
const face1Z = OZ - OVERLAY;                                 // 7.25
const face2Z = face1Z + FACE_H + 0.125;                     // 13.8125

function boxPart(id, name, length, width, thickness, pos, rotation, material, notes = []) {
  return {
    id, name,
    type: 'panel',
    material,
    quantity: 1,
    dimensions: {length, width, thickness},
    position: pos,
    rotation,
    additional_positions: [],
    stock_type: material === 'walnut' ? 'hardwood' : 'sheet_good',
    grain_direction: 'length',
    notes,
  };
}

function drawerParts(prefix, label, zBottom, faceZ) {
  const rot90z90 = {x:90, y:0, z:90};
  const rot90    = {x:90, y:0, z:0};
  const flat     = {x:0,  y:0, z:0};
  return [
    boxPart(`${prefix}_left_side`,  `${label} Left Side`,  BOX_D,    BOX_H,   BOX_T,   {x:leftSideX,  y:boxY,  z:zBottom}, rot90z90, 'birch_plywood'),
    boxPart(`${prefix}_right_side`, `${label} Right Side`, BOX_D,    BOX_H,   BOX_T,   {x:rightSideX, y:boxY,  z:zBottom}, rot90z90, 'birch_plywood'),
    boxPart(`${prefix}_sub_front`,  `${label} Sub-Front`,  INNER_W,  BOX_H,   BOX_T,   {x:subFrontX,  y:boxY,  z:zBottom}, rot90,    'birch_plywood'),
    boxPart(`${prefix}_back`,       `${label} Back`,       INNER_W,  BACK_H,  BOX_T,   {x:subFrontX,  y:backY, z:zBottom}, rot90,    'birch_plywood'),
    boxPart(`${prefix}_bottom`,     `${label} Bottom`,     BOTTOM_W, BOTTOM_D,BOTTOM_T, {x:botX,       y:botY,  z:zBottom}, flat,     'birch_plywood',
      ['1/2" bottom panel for undermount slide cradle; notch rear corners 1/2"×1/2" for mounting clips']),
    boxPart(`${prefix}_face`,       `${label} Face`,       FACE_W,   FACE_H,  FACE_T,  {x:faceX,      y:FRONT_Y, z:faceZ}, rot90,    'walnut'),
  ];
}

const newParts = [
  ...drawerParts('d1', 'Lower Drawer 1', d1Z, face1Z),
  ...drawerParts('d2', 'Lower Drawer 2', d2Z, face2Z),
];

const drawerAssemblies = [
  {
    id: 'lower_drawer_1', name: 'Lower Drawer 1',
    parts: ['d1_left_side', 'd1_right_side', 'd1_sub_front', 'd1_back', 'd1_bottom'],
    face_part_id: 'd1_face',
    slide_type: 'undermount',
    clearance_left: 0.5625, clearance_right: 0.5625,
    clearance_top: 0.0625,
    extension: 'full',
  },
  {
    id: 'lower_drawer_2', name: 'Lower Drawer 2',
    parts: ['d2_left_side', 'd2_right_side', 'd2_sub_front', 'd2_back', 'd2_bottom'],
    face_part_id: 'd2_face',
    slide_type: 'undermount',
    clearance_left: 0.5625, clearance_right: 0.5625,
    clearance_top: 0.0625,
    extension: 'full',
  },
];

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
  // Prefer the live model revision; fall back to state.json if the project isn't loaded.
  const modelState = await raw('get_model', {project_id});
  const revision = modelState.success && modelState.result?.revision != null
    ? modelState.result.revision : null;
  const existing = modelState.success && modelState.result?.definition != null
    ? modelState.result.definition
    : JSON.parse(readFileSync(root + `projects/${project_id}/state.json`, 'utf8')).definition;
  console.log('Using revision:', revision, revision ? '(live model)' : '(state.json, new build)');

  const definition = {
    ...existing,
    parts: [...existing.parts, ...newParts],
    drawer_assemblies: drawerAssemblies,
    notes: [
      ...existing.notes.filter(n => !n.includes('V2 detail')),
      'Lower cubby: 2-drawer stack on 16" undermount slides. Box: 19-3/8"W × 5-7/8"H × 16-1/4"D Baltic birch plywood.',
      'Faces: 21-1/2"W × 6-7/16"H full-overlay walnut, 1/8" gap between faces.',
      'Undermount slides: 1/2"×1/2" rear corner notches on box sides; rear nailer board in cabinet for slide attachment.',
    ],
  };

  const created = await call('create_project', {definition, expected_revision: revision});
  console.log('Created revision:', created.revision);

  const summary = await call('get_model_summary', {project_id});
  console.log('Parts in model:', summary.physical_part_count);

  const exported = await call('export_project', {project_id});
  assert.ok(exported.complete, 'Export must be complete');
  console.log('Export complete. Files:', exported.files?.join(', ') ?? '(see projects/nightstand-001/)');
} finally {
  await client.close();
}
