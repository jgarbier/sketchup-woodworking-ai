import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {readFile} from 'node:fs/promises';
import {parse} from 'yaml';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const client=new Client({name:'project-checkpoint',version:'1.0.0'});
try {
 await client.connect(new StdioClientTransport({command:root+'node_modules/node/bin/node',args:[root+'dist/index.js']}));
 async function raw(name,args){const result=await client.callTool({name,arguments:args});return JSON.parse(result.content[0].text);}
 async function call(name,args){const result=await raw(name,args);assert.equal(result.success,true,JSON.stringify(result));return result.result;}
 assert.ok((await call('sketchup_status',{})).bridge_version>=2,'Reload the SketchUp extension first');
 const project_id='project-checkpoint';
 const previous=await raw('get_model',{project_id});
 const sample=JSON.parse(await readFile(root+'schema/example-bench.json','utf8'));
 sample.project={id:project_id,name:'Project Editing Checkpoint',units:'inches'};
 sample.parts=sample.parts.slice(0,1);sample.parts[0].dimensions={length:48,width:18,thickness:1};sample.parts[0].position={x:0,y:0,z:40};
 sample.relationships=[];sample.overall={width:48,depth:18,height:1};
 let result=await call('create_project',{definition:sample,expected_revision:previous.success?previous.result.revision:null});
 const initialRevision=result.revision;
 result=await call('update_part',{project_id,id:'top',expected_revision:result.revision,changes:{dimensions:{length:54,width:18,thickness:1}}});
 assert.equal((await raw('delete_part',{project_id,id:'top',expected_revision:initialRevision})).success,false,'Stale revision must be rejected');
 result=await call('move_part',{project_id,id:'top',expected_revision:result.revision,position:{x:0,y:0,z:43},additional_positions:[]});
 const read=await call('get_model',{project_id});
 assert.equal(read.definition.parts[0].dimensions.length,54);assert.equal(read.definition.parts[0].position.z,43);
 const yaml=parse(await readFile(root+`projects/${project_id}/project.yaml`,'utf8'));
 assert.deepEqual(yaml,read.definition);
 result=await call('update_part',{project_id,id:'top',expected_revision:result.revision,changes:{quantity:2,additional_positions:[{x:0,y:24,z:43}],rotation:{x:90,y:0,z:0}}});
 let parts=(await call('get_parts',{project_id})).parts;
 assert.equal(parts.length,2);for(const part of parts){assert.deepEqual(part.cut_dimensions,{length:54,width:18,thickness:1});assert.ok(Math.abs(part.dimensions.thickness-18)<1e-5);assert.equal(part.solid,true);}
 result=await call('delete_part',{project_id,id:'top',expected_revision:result.revision});
 assert.equal((await call('get_parts',{project_id})).parts.length,0);
 assert.equal((await call('get_model',{project_id})).definition.parts.length,0);
 // Restore one clearly named panel for visual verification.
 result=await call('create_project',{definition:sample,expected_revision:result.revision});
 parts=(await call('get_parts',{project_id})).parts;
 assert.equal(parts.length,1);assert.deepEqual(parts[0].cut_dimensions,{length:48,width:18,thickness:1});
 console.log(JSON.stringify({success:true,checks:['create','update','reject stale revision','move','YAML synchronized','quantity and rotation','delete','restore'],revision:result.revision},null,2));
} finally {await client.close();}
