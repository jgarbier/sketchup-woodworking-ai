import {z} from 'zod';
import {writeFile} from 'node:fs/promises';
import {projectBaseSchema} from '../dist/project-schema.js';
const schema=z.toJSONSchema(projectBaseSchema);
schema.$comment='Canonical inches. Semantic validation also requires unique IDs, valid material/relationship references, at most 500 instances, and quantity minus one additional_positions.';
await writeFile(new URL('../schema/woodworking-project.schema.json',import.meta.url),JSON.stringify(schema,null,2)+'\n');
