import {writeFileSync} from 'node:fs';
import {stringify} from 'yaml';
const parts=[];
function part(id,name,l,w,t,x,y,z,rotation={x:0,y:0,z:0}){parts.push({id,name,type:id==='top'||id==='shelf'?'panel':'board',material:'white_oak',quantity:1,dimensions:{length:l,width:w,thickness:t},position:{x,y,z},rotation,additional_positions:[],stock_type:'hardwood',grain_direction:'length',notes:[]});}
part('top','Bench Top',72,18,1,0,0,29);
for(const [side,x] of [['left',0],['right',70]]) for(const [depth,y] of [['front',0],['rear',16]]) part(`${depth}_${side}_leg`,`${depth} ${side} leg`,29,2,2,x,y,0,{x:0,y:-90,z:0});
part('front_apron','Front Apron',68,4,.75,2,0,25,{x:90,y:0,z:0});
part('rear_apron','Rear Apron',68,4,.75,2,17.25,25,{x:90,y:0,z:0});
part('left_apron','Left Apron',14,4,.75,0,2,25,{x:90,y:0,z:90});
part('right_apron','Right Apron',14,4,.75,71.25,2,25,{x:90,y:0,z:90});
part('shelf','Lower Shelf',68,14,.75,2,2,6);
const project={project:{id:'entry-bench-001',name:'Entry Bench',units:'inches'},overall:{width:72,depth:18,height:30},materials:[{id:'white_oak',species:'white_oak',type:'hardwood'}],parts,relationships:[{part_id:'top',depends_on:['front_left_leg','front_right_leg','rear_left_leg','rear_right_leg'],description:'Top underside is at the tops of the legs.'}],notes:['Dimensional layout only. Shelf supports and fastening details remain to be designed.','Shelf height refers to its underside. Actual finished leg size is 2 inches square.']};
writeFileSync(new URL('../schema/example-bench.yaml',import.meta.url),stringify(project));
writeFileSync(new URL('../schema/example-bench.json',import.meta.url),JSON.stringify(project,null,2)+'\n');
