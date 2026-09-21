import net from 'node:net';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
async function command(command, params) {
  const request_id = randomUUID();
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({host: '127.0.0.1', port: 48763});
    let data = '';
    socket.setTimeout(12000, () => socket.destroy(new Error('Bridge timed out; dismiss SketchUp modal dialogs.')));
    socket.on('error', reject);
    socket.on('connect', () => socket.write(JSON.stringify({request_id, command, params}) + '\n'));
    socket.on('data', chunk => {
      data += chunk.toString();
      if (data.length > 65536) return socket.destroy(new Error('Oversized response'));
      if (!data.includes('\n')) return;
      try {
        const result = JSON.parse(data.split('\n')[0]);
        assert.equal(result.request_id, request_id);
        socket.end();
        resolve(result);
      } catch (error) { socket.destroy(); reject(error); }
    });
    socket.on('end', () => { if (!data.includes('\n')) reject(new Error('Incomplete response')); });
  });
}
const status = await command('sketchup_status', {});
assert.equal(status.success, true);
const invalid = await command('eval_ruby', {code: 'forbidden'});
assert.equal(invalid.success, false);
const board = {project_id:'tabletop-checkpoint', id:'top', name:'Checkpoint Tabletop 48 × 18 × 1',
  length:48, width:18, thickness:1, position:{x:0,y:0,z:0}};
for (let i=0; i<2; i++) {
  const created = await command('create_board', board);
  assert.equal(created.success, true, JSON.stringify(created));
}
const queried = await command('get_part', {project_id:board.project_id, id:board.id});
assert.equal(queried.success, true, JSON.stringify(queried));
assert.deepEqual(queried.result.dimensions, {length:48,width:18,thickness:1});
assert.equal(queried.result.solid, true);
console.log(JSON.stringify({success:true, checks:['status','reject arbitrary Ruby','create/update twice','query one solid 48×18×1 part'], status, queried},null,2));
