# DeformationBaker -- Bakes free-form and cage deformations into static mesh positions or keyframes.
# DEF-005: Applies active deformation offsets permanently to MeshData vertex positions.
class_name DeformationBaker
extends RefCounted

## Bakes evaluated deformed vertex positions into a new static MeshData instance.
static func bake_deformed_mesh(original_mesh: RefCounted, deformed_positions: Array[Vector2]) -> RefCounted:
	if original_mesh == null:
		return null

	var MeshDataScript = preload("res://deformation/meshes/mesh_data.gd")
	var new_mesh = MeshDataScript.new("baked_" + str(original_mesh.get("mesh_id")))
	new_mesh.texture_asset_id = str(original_mesh.get("texture_asset_id"))

	var orig_verts: Array = original_mesh.get("vertices")
	var count: int = min(orig_verts.size(), deformed_positions.size())

	for i in range(count):
		var orig_v: RefCounted = orig_verts[i]
		var def_pos: Vector2 = deformed_positions[i]
		var new_v = new_mesh.add_vertex(def_pos, orig_v.uv)

		# Copy bone weights
		for bw in orig_v.bone_weights:
			var new_bw = MeshDataScript.BoneWeightData.new(str(bw.bone_id), float(bw.weight))
			new_v.bone_weights.append(new_bw)

	# Copy triangles
	var orig_tris: Array = original_mesh.get("triangles")
	for tri in orig_tris:
		var t: Array = tri as Array
		new_mesh.add_triangle(t[0], t[1], t[2])

	return new_mesh


## Bakes cage deformation controller output directly onto target MeshData in-place.
static func bake_cage_in_place(mesh: RefCounted, grid_cage: RefCounted) -> void:
	if mesh == null or grid_cage == null:
		return

	var verts: Array = mesh.get("vertices")
	for v in verts:
		var offset: Vector2 = grid_cage.evaluate_vertex_displacement(v.position)
		v.position = (v.position as Vector2) + offset
