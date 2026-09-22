import {McpServer} from '@modelcontextprotocol/sdk/server/mcp.js';
import {SketchupClient} from './sketchup-client.js';
import {commandSchemas,type Command} from './schemas.js';
export function createServer(client=new SketchupClient()) {
  const server=new McpServer({name:'woodworking',version:'0.1.0'});
  const descriptions:Record<Command,string>={
    export_project:'Regenerate project scenes, PNG views, cut list, material totals, build plan and a bench.skp copy. Fixed project output directory. Preserves unrelated model geometry. Read export-status.json for revision and completion.',
    save_model:'Save a bench.skp copy of the active SketchUp document into the project output folder. Preserves unrelated geometry.',
    get_model_summary:'Read project instance count, IDs, world bounds, persistent entity IDs and current revision for verification.',
    fit_camera:'Fit the SketchUp camera to this project with a specified view.',
    render_view:'Generate one named scene and PNG using SketchUp export. Exploded preview is separate from physical parts and excluded from cut lists.',
    create_project:'Apply a full validated project definition in inches. Uses one undo operation and writes project.yaml before geometry. Pass expected_revision=null only for a new project; read get_model before updating. Reconcile all dependent dimensions in the definition; never scale furniture.',
    get_model:'Read the active model project definition and revision. Use this before any edits.',
    get_parts:'Read all physical instances belonging to one project, with local cut dimensions and world bounds.',
    update_part:'Update fields on a logical project part. Requires current revision. Nested fields replace the entire object. Use create_project to edit multiple dependent parts atomically.',
    move_part:'Set the position and all additional instance positions in inches; preserves dimensions and rotation. Requires current revision.',
    delete_part:'Delete only one tagged logical part and its instances from a managed project. Requires current revision.',
    sketchup_status:'Check the local SketchUp bridge and supported commands.',
    create_board:'Create or update one named rectangular component by project_id and id. All dimensions and position are inches. Local length=X, width=Y, thickness=Z. Preserves unrelated geometry; one undo operation.',
    get_part:'Read exactly one owned component by project_id and id; returns measured world-axis dimensions in inches.',
    add_cutout:'Cut a circle or rectangle through a face of an existing part. Specify project_id, part_id, shape (circle or rectangle), face (top/bottom/front/back/right/left), x and y position on the face in inches from the component origin, depth in inches, and either radius (circle) or width+height (rectangle). x/y map to the two non-normal axes of the named face. Modifies geometry directly; run render_view to see the result.'
  };
  for(const name of Object.keys(commandSchemas) as Command[]) {
    server.registerTool(name,{description:descriptions[name],inputSchema:commandSchemas[name],
      annotations:{readOnlyHint:['sketchup_status','get_part','get_parts','get_model','get_model_summary'].includes(name),destructiveHint:name==='delete_part',idempotentHint:name!=='create_project',openWorldHint:false}},async(input:unknown)=>{
      const result=await client.call(name,input);
      return {content:[{type:'text' as const,text:JSON.stringify(result)}],structuredContent:result,isError:!result.success};
    });
  }
  return server;
}
