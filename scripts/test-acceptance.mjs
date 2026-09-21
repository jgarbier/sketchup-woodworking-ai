import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {fileURLToPath} from 'node:url';
import {readFile,stat,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {parse} from 'yaml';
import assert from 'node:assert/strict';
import {acceptanceDefinition} from './acceptance-definition.mjs';
const root=fileURLToPath(new URL('../',import.meta.url));
const client=new Client({name:'full-acceptance',version:'1.0.0'});
const project_id='acceptance-bench';
const output=root+`projects/${project_id}/`;
try {
 await client.connect(new StdioClientTransport({command:root+'node_modules/node/bin/node',args:[root+'dist/index.js']}));
 async function call(name,args){const response=await client.callTool({name,arguments:args},undefined,{timeout:120000});const parsed=JSON.parse(response.content[0].text);assert.equal(parsed.success,true,JSON.stringify(parsed));return parsed.result;}
 assert.equal((await call('sketchup_status',{})).bridge_version,3);
 const before=await call('get_model',{project_id});
 const base=acceptanceDefinition();
 let result=await call('create_project',{definition:base,expected_revision:before.revision});
 console.log('Initial bench applied.');
 const initial=await call('get_model_summary',{project_id});
 assert.deepEqual(initial.bounds,{width:60,depth:18,height:30});assert.equal(initial.physical_part_count,14);
 let exported=await call('export_project',{project_id});assert.equal(exported.complete,true);
 console.log('Initial views, model and reports exported.');
 const initialPngHash=createHash('sha256').update(await readFile(output+'renders/perspective.png')).digest('hex');
 const revised=acceptanceDefinition(72,2.5,9);
 result=await call('create_project',{definition:revised,expected_revision:result.revision});
 assert.equal(result.export?.complete,true,JSON.stringify(result));
 console.log('Revised bench applied and outputs regenerated automatically.');
 const final=await call('get_model_summary',{project_id});
 assert.deepEqual(final.bounds,{width:72,depth:18,height:30});assert.equal(final.physical_part_count,14);
 assert.deepEqual(final.persistent_ids,initial.persistent_ids,'Existing physical instances must be retained');
 assert.equal(final.owned_scene_count,5);
 const model=await call('get_model',{project_id});
 assert.deepEqual(model.definition,revised);
 const yaml=parse(await readFile(output+'project.yaml','utf8'));assert.deepEqual(yaml,revised);
 const status=JSON.parse(await readFile(output+'export-status.json','utf8'));
 assert.equal(status.complete,true);assert.equal(status.revision,model.revision);
 const files=['bench.skp','cut-list.csv','bill-of-materials.csv','build-plan.md',...['perspective','front','right','side','top','exploded'].map(v=>`renders/${v}.png`)];
 for(const file of files) assert.ok((await stat(output+file)).size>0,`Missing/empty ${file}`);
 for(const view of ['perspective','front','right','side','top','exploded']){
  const png=await readFile(output+`renders/${view}.png`);assert.equal(png.subarray(1,4).toString(),'PNG');
  assert.equal(png.readUInt32BE(16),1600);assert.equal(png.readUInt32BE(20),1000);
 }
 const revisedPngHash=createHash('sha256').update(await readFile(output+'renders/perspective.png')).digest('hex');
 assert.notEqual(revisedPngHash,initialPngHash,'Revised visualization must change');
 const cut=await readFile(output+'cut-list.csv','utf8');assert.match(cut,/Bench Top,1,white_oak,72,18,1/);assert.match(cut,/front right leg,1,white_oak,29,2.5,2.5/);
 const build=await readFile(output+'build-plan.md','utf8');assert.match(build,/72" W × 18" D × 30" H/);
 const evidence={success:true,date:new Date().toISOString(),initial:{overall:base.overall,leg:2,shelf:6},revised:{overall:revised.overall,leg:2.5,shelf:9},physical_parts:14,preserved_persistent_ids:true,scenes:5,revision:model.revision,files,initial_png_sha256:initialPngHash,revised_png_sha256:revisedPngHash};
 await writeFile(output+'acceptance-result.json',JSON.stringify(evidence,null,2)+'\n');
 console.log(JSON.stringify(evidence,null,2));
} finally {await client.close();}
