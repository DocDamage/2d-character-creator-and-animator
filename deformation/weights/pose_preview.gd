# PosePreview -- Extreme pose testing tool for mesh skinning and stretch evaluation.
# MSH-008: Evaluates mesh vertex deformation under extreme bone rotations and returns stretch metrics.
class_name PosePreview
extends RefCounted

## Evaluates deformed vertex positions for MeshData given bone transforms dictionary.
## bone_transforms: Dictionary of { "bone_id": Transform2D }
static func evaluate_deformed_vertices(mesh: RefCounted, bone_transforms: Dictionary) -> Array[Vector2]:
	var deformed: Array[Vector2] = []
	if mesh == null:
		return deformed

	var verts: Array = mesh.get("vertices")

	for v in verts:
		var bind_pos: Vector2 = v.position
		var final_pos := Vector2.ZERO
		var total_w: float = 0.0

		for bw in v.bone_weights:
			var b_id: String = str(bw.bone_id)
			var weight: float = float(bw.weight)

			if bone_transforms.has(b_id):
				var xform: Transform2D = bone_transforms[b_id] as Transform2D
				final_pos += (xform * bind_pos) * weight
				total_w += weight

		if total_w <= 0.0:
			final_pos = bind_pos

		deformed.append(final_pos)

	return deformed


## Calculates maximum edge stretch ratio (deformed_length / rest_length) across all triangles.
static func calculate_max_edge_stretch(mesh: RefCounted, deformed_positions: Array[Vector2]) -> float:
	if mesh == null or deformed_positions.is_empty():
		return 1.0

	var max_stretch: float = 1.0
	var tris: Array = mesh.get("triangles")

	for tri in tris:
		var t: Array = tri as Array
		var i0: int = t[0]
		var i1: int = t[1]
		var i2: int = t[2]

		var edges := [ [i0, i1], [i1, i2], [i2, i0] ]

		for edge in edges:
			var rest_dist: float = (mesh.vertices[edge[0]].position as Vector2).distance_to(mesh.vertices[edge[1]].position)
			if rest_dist > 1e-6:
				var def_dist: float = deformed_positions[edge[0]].distance_to(deformed_positions[edge[1]])
				var ratio: float = def_dist / rest_dist
				max_stretch = maxf(max_stretch, ratio)

	return max_stretch


## Evaluates an extreme rotation pose test on target bone ID.
static func test_extreme_bone_rotation(mesh: RefCounted, target_bone_id: String, bone_head: Vector2, angle_degrees: float) -> float:
	var rad: float = deg_to_rad(angle_degrees)
	var xform := Transform2D(rad, bone_head)
	var xforms := { target_bone_id: xform }

	var deformed := evaluate_deformed_vertices(mesh, xforms)
	return calculate_max_edge_stretch(mesh, deformed)
