import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));

// Overall: 21"W × 11"D × 12"H
// Two 8" bowl cutouts centered in each half of the top panel
const W=21, D=11, H=12;
const legSq=1.25, legH=11.25, topT=0.75;
const slatT=0.25, slatH=1.0;

// Six slats evenly distributed with equal top/bottom gap (0.75" each)
const nSlats=6;
const totalGap = legH - nSlats*slatH;
const gap = totalGap / (nSlats+1);
const slatZs = Array.from({length:nSlats}, (_,i) => +(gap + i*(slatH+gap)).toFixed(4));

function part(id, name, length, width, thickness, position, rotation, additional_positions=[]) {
  return {
    id, name,
    type: 'panel',
    material: 'white_oak',
    quantity: 1 + additional_positions.length,
    dimensions: {length, width, thickness},
    position,
    rotation,
    additional_positions,
    stock_type: 'hardwood',
    grain_direction: 'length',
    notes: [],
  };
}

function dogBowlStandDefinition() {
  // Rear y for legs
  const rearY = D - legSq; // 9.75

  const frontSlatAddlPos = slatZs.slice(1).map(z => ({x:0, y:0, z}));
  const rearY_slat = D - slatT; // 10.75
  const rearSlatAddlPos = slatZs.slice(1).map(z => ({x:0, y:rearY_slat, z}));
  const leftSlatAddlPos = slatZs.slice(1).map(z => ({x:0, y:0, z}));
  const rightSlatX = W - slatT; // 20.75
  const rightSlatAddlPos = slatZs.slice(1).map(z => ({x:rightSlatX, y:0, z}));

  const parts = [
    // Corner legs: ry=-90 → length→Z, width→Y, thickness→X
    part('front_left_leg',  'Front Left Leg',  legH, legSq, legSq, {x:0,       y:0,      z:0}, {x:0,y:-90,z:0}),
    part('front_right_leg', 'Front Right Leg', legH, legSq, legSq, {x:W-legSq, y:0,      z:0}, {x:0,y:-90,z:0}),
    part('rear_left_leg',   'Rear Left Leg',   legH, legSq, legSq, {x:0,       y:rearY,  z:0}, {x:0,y:-90,z:0}),
    part('rear_right_leg',  'Rear Right Leg',  legH, legSq, legSq, {x:W-legSq, y:rearY,  z:0}, {x:0,y:-90,z:0}),

    // Top frame: 5 pieces that leave two 8"×8" square openings for bowls
    // Layout: 1.5" front/back rim, 1.25" left/right ends, 2.5" center divider
    // flat (no rotation) → length→X, width→Y, thickness→Z
    part('top_front_rail',  'Top Front Rail',   W,    1.5, topT, {x:0,          y:0,   z:legH}, {x:0,y:0,z:0}),
    part('top_back_rail',   'Top Back Rail',    W,    1.5, topT, {x:0,          y:9.5, z:legH}, {x:0,y:0,z:0}),
    part('top_left_end',    'Top Left End',     legSq, 8,  topT, {x:0,          y:1.5, z:legH}, {x:0,y:0,z:0}),
    part('top_center_div',  'Top Center Div',   2.5,   8,  topT, {x:9.25,       y:1.5, z:legH}, {x:0,y:0,z:0}),
    part('top_right_end',   'Top Right End',    legSq, 8,  topT, {x:W-legSq,    y:1.5, z:legH}, {x:0,y:0,z:0}),

    // Front face slats: rx=90 → length→X, width→Z, thickness→Y
    part('front_slat', 'Front Slat', W, slatH, slatT,
      {x:0, y:0, z:slatZs[0]}, {x:90,y:0,z:0}, frontSlatAddlPos),

    // Rear face slats: rx=90, positioned at back face
    part('rear_slat', 'Rear Slat', W, slatH, slatT,
      {x:0, y:rearY_slat, z:slatZs[0]}, {x:90,y:0,z:0}, rearSlatAddlPos),

    // Left face slats: rx=90, rz=90 → thickness→X, length→Y, width→Z
    part('left_slat', 'Left Slat', D, slatH, slatT,
      {x:0, y:0, z:slatZs[0]}, {x:90,y:0,z:90}, leftSlatAddlPos),

    // Right face slats: rx=90, rz=90, positioned at right face
    part('right_slat', 'Right Slat', D, slatH, slatT,
      {x:rightSlatX, y:0, z:slatZs[0]}, {x:90,y:0,z:90}, rightSlatAddlPos),
  ];

  return {
    project: {id: 'dog-bowl-stand', name: 'Dog Bowl Stand', units: 'inches'},
    overall: {width: W, depth: D, height: H},
    materials: [{id: 'white_oak', species: 'white_oak', type: 'hardwood'}],
    parts,
    relationships: [
      {part_id: 'top_front_rail', depends_on: ['front_left_leg','front_right_leg'], description: 'Front top rail rests on front legs'},
      {part_id: 'top_back_rail',  depends_on: ['rear_left_leg','rear_right_leg'],  description: 'Back top rail rests on rear legs'},
      {part_id: 'top_left_end',   depends_on: ['front_left_leg','rear_left_leg'],  description: 'Left end rests on left legs'},
      {part_id: 'top_center_div', depends_on: ['front_left_leg','front_right_leg','rear_left_leg','rear_right_leg'], description: 'Center divider between bowl openings'},
      {part_id: 'top_right_end',  depends_on: ['front_right_leg','rear_right_leg'], description: 'Right end rests on right legs'},
      {part_id: 'front_slat',  depends_on: ['front_left_leg','front_right_leg'], description: 'Front slats attach to front legs'},
      {part_id: 'rear_slat',   depends_on: ['rear_left_leg','rear_right_leg'],   description: 'Rear slats attach to rear legs'},
      {part_id: 'left_slat',   depends_on: ['front_left_leg','rear_left_leg'],   description: 'Left slats attach to left legs'},
      {part_id: 'right_slat',  depends_on: ['front_right_leg','rear_right_leg'], description: 'Right slats attach to right legs'},
    ],
    notes: [
      'All dimensions are finished sizes in inches.',
      `Overall: ${W}"W × ${D}"D × ${H}"H.`,
      `Legs: ${legSq}" square solid white oak, ${legH}" tall.`,
      `Top frame: ${topT}" thick white oak in 5 pieces — 1.5" front/back rails, 1.25" left/right ends, 2.5" center divider — leaving two 8"×8" square openings for bowls.`,
      `Bowl fit: the square openings accept a round 8" bowl; the corners will be unsupported (bowl rim rests on the four straight edges). For a tighter fit, trace the bowl rim and jig-saw the opening to match.`,
      `Slats: ${slatT}" thick × ${slatH}" tall, 6 per face, spaced ${gap.toFixed(3)}" apart. Attach with glue and brad nails into leg faces.`,
      'Finish: oil+wax or water-based poly (food-safe when cured) to handle water splashes.',
      'Joinery: glue and finish nails for slat-to-leg; top can be pocket-screwed down from below.',
    ],
    door_assemblies: [],
    joints: [],
  };
}

const client = new Client({name: 'dog-bowl-stand-creator', version: '1.0.0'});
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

  const project_id = 'dog-bowl-stand';
  const previous = await raw('get_model', {project_id});
  const definition = dogBowlStandDefinition();

  const created = await call('create_project', {
    definition,
    expected_revision: previous.success ? previous.result.revision : null,
  });
  console.log('Created revision:', created.revision);

  const summary = await call('get_model_summary', {project_id});
  console.log('Parts in model:', summary.physical_part_count);
  console.log('Bounds:', summary.bounds);

  const exported = await call('export_project', {project_id});
  assert.ok(exported.complete, 'Export must be complete');
  console.log('Export complete. Files:', exported.files?.join(', ') ?? '(see projects/dog-bowl-stand/)');

  console.log(JSON.stringify({success: true, project_id, revision: created.revision, part_count: summary.physical_part_count}, null, 2));
} finally {
  await client.close();
}
