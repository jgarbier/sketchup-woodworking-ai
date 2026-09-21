import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {acceptanceDefinition} from './acceptance-definition.mjs';
const root=fileURLToPath(new URL('../',import.meta.url));
const client=new Client({name:'bench-acceptance',version:'1.0.0'});
try {
 await client.connect(new StdioClientTransport({command:root+'node_modules/node/bin/node',args:[root+'dist/index.js']}));
 async function raw(name,args){const r=await client.callTool({name,arguments:args},undefined,{timeout:120000});return JSON.parse(r.content[0].text);}
 async function call(name,args){const r=await raw(name,args);assert.equal(r.success,true,JSON.stringify(r));return r.result;}
 const project_id='acceptance-bench';const previous=await raw('get_model',{project_id});
 const revised=process.argv.includes('--revised');
 const definition=revised?acceptanceDefinition(72,2.5,9):acceptanceDefinition();
 const applied=await call('create_project',{definition,expected_revision:previous.success?previous.result.revision:null});
 const result=await call('get_parts',{project_id});
 assert.equal(result.parts.length,14);assert.ok(result.parts.every(p=>p.solid));
 const top=result.parts.find(p=>p.part_id==='top');assert.equal(top.cut_dimensions.length,revised?72:60);
 const legs=result.parts.filter(p=>p.part_id.endsWith('_leg'));
 assert.equal(legs.length,4);for(const leg of legs){assert.equal(leg.cut_dimensions.length,29);assert.equal(leg.cut_dimensions.width,revised?2.5:2);}
 if(process.argv.includes('--export')) console.log(JSON.stringify(await call('export_project',{project_id}),null,2));
 console.log(JSON.stringify({success:true,stage:revised?'revised':'initial',parts:result.parts.length,revision:applied.revision,overall:definition.overall},null,2));
} finally {await client.close();}
