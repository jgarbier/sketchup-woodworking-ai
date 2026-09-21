import {describe,it,expect} from 'vitest';
import {readFileSync} from 'node:fs';
import {parse,stringify} from 'yaml';
import {projectSchema} from '../src/project-schema.js';
const example=()=>parse(readFileSync(new URL('../../schema/example-bench.yaml',import.meta.url),'utf8'));
describe('project schema and serialization',()=>{
 it('round trips the example without lost dimensions',()=>{
  const p=projectSchema.parse(example()); expect(projectSchema.parse(parse(stringify(p)))).toEqual(p);
 });
 it('rejects duplicate IDs and dangling references',()=>{
  const p=example();p.parts.push(p.parts[0]); expect(()=>projectSchema.parse(p)).toThrow();
  const q=example();q.parts[0].material='missing';expect(()=>projectSchema.parse(q)).toThrow();
  const r=example();r.relationships=[{part_id:'missing',depends_on:[],description:'bad'}];expect(()=>projectSchema.parse(r)).toThrow();
 });
 it('requires explicit placements for copies',()=>{
  const p=example();p.parts[0].quantity=2;expect(()=>projectSchema.parse(p)).toThrow();
  p.parts[0].additional_positions=[{x:0,y:0,z:60}];expect(projectSchema.parse(p).parts[0].quantity).toBe(2);
 });
 it('rejects implicit units and invalid rotation',()=>{
  const p=example();p.project.units='mm';expect(()=>projectSchema.parse(p)).toThrow();
  const q=example();q.parts[0].rotation.x=NaN;expect(()=>projectSchema.parse(q)).toThrow();
 });
});
