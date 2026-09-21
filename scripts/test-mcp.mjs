import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const client=new Client({name:'woodworking-live-test',version:'1.0.0'});
try {
 await client.connect(new StdioClientTransport({command:root+'node_modules/node/bin/node',args:[root+'dist/index.js']}));
 const list=await client.listTools();
 for(const name of ['create_board','get_part','sketchup_status']) assert.ok(list.tools.some(t=>t.name===name));
 async function call(name,args){const result=await client.callTool({name,arguments:args});assert.ok(!result.isError,JSON.stringify(result));return JSON.parse(result.content[0].text);}
 assert.equal((await call('sketchup_status',{})).success,true);
 const board={project_id:'tabletop-checkpoint',id:'top',name:'MCP Tabletop 48 × 18 × 1',length:48,width:18,thickness:1,position:{x:0,y:0,z:0}};
 await call('create_board',board); await call('create_board',board);
 const part=await call('get_part',{project_id:board.project_id,id:board.id});
 assert.deepEqual(part.result.dimensions,{length:48,width:18,thickness:1});assert.equal(part.result.solid,true);
 console.log(JSON.stringify({success:true,transport:'MCP stdio → TCP → SketchUp',part},null,2));
} finally {await client.close();}
