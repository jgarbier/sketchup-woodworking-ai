import {describe,it,expect} from 'vitest';
import {boardSchema,commandSchemas} from '../src/schemas.js';
const board={project_id:'test',id:'top',name:'Top',length:48,width:18,thickness:1,position:{x:0,y:0,z:0}};
describe('boundary validation',()=>{
 it('preserves explicit inches',()=>expect(boardSchema.parse(board)).toEqual(board));
 it.each([0,-1,Infinity,NaN,'48',null])('rejects invalid dimensions %s',value=>expect(()=>boardSchema.parse({...board,length:value})).toThrow());
 it('rejects unknown fields and implicit conversions',()=>{
  expect(()=>boardSchema.parse({...board,units:'mm'})).toThrow();
  expect(()=>boardSchema.parse({...board,position:{x:0,y:0}})).toThrow();
  expect(()=>commandSchemas.sketchup_status.parse({code:'x'})).toThrow();
 });
});
