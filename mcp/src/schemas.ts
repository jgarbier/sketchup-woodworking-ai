import {projectSchema,projectPartSchema,vectorSchema} from './project-schema.js';
import {z} from 'zod';
export const identifier = z.string().regex(/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/);
export const position = z.object({x:z.number().finite(),y:z.number().finite(),z:z.number().finite()}).strict();
export const boardSchema = z.object({project_id:identifier,id:identifier,name:z.string().trim().min(1).max(256),
  length:z.number().finite().positive(),width:z.number().finite().positive(),thickness:z.number().finite().positive(),position}).strict();
export const partSchema = z.object({project_id:identifier,id:identifier}).strict();
const cutoutBase = z.object({
  project_id:identifier, part_id:identifier,
  shape:z.enum(['circle','rectangle']),
  face:z.enum(['top','bottom','front','back','right','left']),
  x:z.number().finite(), y:z.number().finite(),
  depth:z.number().finite().positive()
});
export const cutoutSchema = z.discriminatedUnion('shape',[
  cutoutBase.extend({shape:z.literal('circle'), radius:z.number().finite().positive()}).strict(),
  cutoutBase.extend({shape:z.literal('rectangle'), width:z.number().finite().positive(), height:z.number().finite().positive()}).strict()
]);
export const commandSchemas = {
 add_cutout:cutoutSchema,
 export_project:z.object({project_id:identifier}).strict(),
 save_model:z.object({project_id:identifier}).strict(),
 get_model_summary:z.object({project_id:identifier}).strict(),
 fit_camera:z.object({project_id:identifier,view:z.enum(['perspective','front','right','top'])}).strict(),
 render_view:z.object({project_id:identifier,view:z.enum(['perspective','front','right','top','exploded'])}).strict(),
 sketchup_status:z.object({}).strict(),create_board:boardSchema,get_part:partSchema,
 create_project:z.object({definition:projectSchema,expected_revision:z.string().uuid().nullable()}).strict(),
 get_model:z.object({project_id:identifier}).strict(),
 get_parts:z.object({project_id:identifier}).strict(),
 update_part:partSchema.extend({expected_revision:z.string().uuid(),changes:projectPartSchema.omit({id:true}).partial().refine(v=>Object.keys(v).length>0)}).strict(),
 move_part:partSchema.extend({expected_revision:z.string().uuid(),position:vectorSchema,additional_positions:z.array(vectorSchema).max(99)}).strict(),
 delete_part:partSchema.extend({expected_revision:z.string().uuid()}).strict()
};
export type Command = keyof typeof commandSchemas;
export const responseSchema = z.discriminatedUnion('success',[
  z.object({request_id:identifier,success:z.literal(true),result:z.record(z.string(),z.unknown())}),
  z.object({request_id:identifier.nullable(),success:z.literal(false),error:z.object({code:z.string(),message:z.string()})})
]);
