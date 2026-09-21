# Woodworking project schema
The JSON Schema is generated from mcp/src/project-schema.ts. Ruby validates the same
schema packaged inside the extension, plus shared semantic constraints.

All lengths are numeric inches. X=project width, Y=depth, Z=height. Project origin is
front-left-bottom. A board's local length=X, width=Y, thickness=Z. Rotation contains
Euler degrees, applied X then Y then Z. Position anchors the rotated instance's
axis-aligned bounding-box minimum, so vertical parts need no sign-offset arithmetic.
Read tools distinguish local cut_dimensions from world-axis dimensions.

Each logical part has a unique stable id. Quantity is 1–100; additional_positions must
contain exactly quantity minus one positions. Every physical instance stores project_id,
part_id and instance_index. All copies share dimensions, rotation and material.
The project is limited to 200 logical parts and 500 physical instances.

Materials must exist and IDs must be unique. Relationships reference existing part IDs;
they document design intent, not executable formulas. The AI must update dependent
parts and overall dimensions together via create_project (full-definition replacement).

## Synchronization
get_model returns the definition and its revision from the active model. Every edit
requires that revision. create_project accepts null only for a new project. Validation
precedes file/geometry changes. project.yaml and recovery state.json are written before
geometry. Failures abort the model operation and restore prior files. One complete
project apply is one undo operation. An attached model observer synchronizes definition
files on Undo/Redo. Conflicting files are rejected rather than overwritten.
A process crash between file and model updates can leave a revision mismatch; this is
reported and requires recovery from the active model or state.json, not an automatic retry.

Primitive create_board refuses managed projects so it cannot bypass the definition.
Direct manual geometry edits are not imported automatically; the next explicit project
apply regenerates tagged geometry from its definition. Unrelated geometry is preserved.
Renders, cut lists, model saves and build plans are later checkpoints.
