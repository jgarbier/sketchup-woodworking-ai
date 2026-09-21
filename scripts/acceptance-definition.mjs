// Acceptance fixture designed by the agent; geometry remains generic in Ruby.
export function acceptanceDefinition(width=60,leg=2,shelfHeight=6) {
 const depth=18,height=30,topThickness=1,apronHeight=4,apronThickness=.75,shelfThickness=.75;
 const span=width-2*leg,insideDepth=depth-2*leg;
 const parts=[];
 function add(id,name,length,w,t,x,y,z,rotation={x:0,y:0,z:0}) {
  parts.push({id,name,type:['top','shelf'].includes(id)?'panel':'board',material:'white_oak',quantity:1,
   dimensions:{length,width:w,thickness:t},position:{x,y,z},rotation,additional_positions:[],stock_type:'hardwood',grain_direction:'length',notes:[]});
 }
 add('top','Bench Top',width,depth,topThickness,0,0,height-topThickness);
 for(const [side,x] of [['left',0],['right',width-leg]]) for(const [end,y] of [['front',0],['rear',depth-leg]])
  add(`${end}_${side}_leg`,`${end} ${side} leg`,height-topThickness,leg,leg,x,y,0,{x:0,y:-90,z:0});
 for(const [end,y] of [['front',0],['rear',depth-apronThickness]]) add(`${end}_apron`,`${end} apron`,span,apronHeight,apronThickness,leg,y,height-topThickness-apronHeight,{x:90,y:0,z:0});
 for(const [side,x] of [['left',0],['right',width-apronThickness]]) add(`${side}_apron`,`${side} apron`,insideDepth,apronHeight,apronThickness,x,leg,height-topThickness-apronHeight,{x:90,y:0,z:90});
 add('shelf','Lower Shelf',span,insideDepth,shelfThickness,leg,leg,shelfHeight);
 // Lower rails join the legs; cleats project inward underneath the shelf.
 for(const [end,y,cleatY] of [['front',0,leg],['rear',depth-leg,depth-leg-.75]]) {
  add(`${end}_lower_rail`,`${end} lower rail`,span,2,leg,leg,y,shelfHeight-2,{x:90,y:0,z:0});
  add(`${end}_shelf_cleat`,`${end} shelf cleat`,span,.75,.75,leg,cleatY,shelfHeight-.75);
 }
 return {project:{id:'acceptance-bench',name:'Entry Bench',units:'inches'},overall:{width,depth,height},materials:[{id:'white_oak',species:'white_oak',type:'hardwood'}],parts,
 relationships:[{part_id:'top',depends_on:['front_left_leg','front_right_leg','rear_left_leg','rear_right_leg'],description:'Top underside aligns with 29-inch leg tops.'},{part_id:'shelf',depends_on:['front_shelf_cleat','rear_shelf_cleat'],description:'Shelf underside rests on cleats; cleats attach to lower rails.'}],
 notes:['All sizes are finished dimensions, not nominal lumber sizes.','Shelf height is measured to its underside.','Lower rails and cleats provide shelf support.','Joinery, fastener selection and load capacity require a separate construction review.','Use a movement-accommodating top attachment and shelf mounting; do not rigidly cross-grain glue the panels.']};
}
