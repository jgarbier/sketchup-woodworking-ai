import {z} from 'zod';
const id=z.string().regex(/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/);
const positive=z.number().finite().positive();
const text=z.string().min(1).max(500);
export const vectorSchema=z.object({x:z.number().finite(),y:z.number().finite(),z:z.number().finite()}).strict();
export const dimensionsSchema=z.object({length:positive,width:positive,thickness:positive}).strict();
export const projectPartSchema=z.object({id,name:text,type:z.enum(['board','panel']),material:id,
 quantity:z.number().int().min(1).max(100),dimensions:dimensionsSchema,position:vectorSchema,
 rotation:vectorSchema,additional_positions:z.array(vectorSchema).max(99),
 stock_type:z.enum(['hardwood','softwood','plywood','sheet_good']),grain_direction:z.enum(['length','width','none']),notes:z.array(text).max(100)}).strict();
export const projectBaseSchema=z.object({
 project:z.object({id,name:text,units:z.literal('inches')}).strict(),
 overall:z.object({width:positive,depth:positive,height:positive}).strict(),
 materials:z.array(z.object({id,species:text,type:z.enum(['hardwood','softwood','plywood','sheet_good'])}).strict()).min(1).max(100),
 parts:z.array(projectPartSchema).max(200),
 relationships:z.array(z.object({part_id:id,depends_on:z.array(id),description:text}).strict()).max(200),
 notes:z.array(text).max(100)
}).strict();
export const projectSchema=projectBaseSchema.superRefine((p,ctx)=>{
 const fail=(message:string)=>ctx.addIssue({code:'custom',message});
 const materialIds=new Set(p.materials.map(m=>m.id));
 const partIds=new Set(p.parts.map(x=>x.id));
 if(materialIds.size!==p.materials.length || partIds.size!==p.parts.length) fail('Material and part IDs must be unique');
 for(const part of p.parts){
  if(!materialIds.has(part.material)) fail(`Unknown material: ${part.material}`);
  if(part.additional_positions.length!==part.quantity-1) fail(`Part ${part.id} requires quantity minus one additional positions`);
 }
 for(const rel of p.relationships) if(!partIds.has(rel.part_id)||rel.depends_on.some(id=>!partIds.has(id))) fail('Relationship references an unknown part');
 if(p.parts.reduce((sum,x)=>sum+x.quantity,0)>500) fail('Maximum 500 physical parts per project');
});
export type Project=z.infer<typeof projectSchema>;
