# WeightNormalizer -- Total weight normalization and symmetry mirroring controller.
# MSH-007: Normalizes vertex weights to sum to 1.0 and mirrors weights across symmetry axes.
class_name WeightNormalizer
extends RefCounted

## Normalizes weights on a single vertex so total sum == 1.0.
static func normalize_vertex_weights(v: RefCounted) -> void:
	if v == null or v.bone_weights.is_empty():
		return

	# Remove zero-weight entries
	for i in range(v.bone_weights.size() - 1, -1, -1):
		if float(v.bone_weights[i].weight) <= 1e-6:
			v.bone_weights.remove_at(i)

	if v.bone_weights.is_empty():
		return

	var total_w: float = 0.0
	for bw in v.bone_weights:
		total_w += float(bw.weight)

	if total_w > 0.0:
		for bw in v.bone_weights:
			bw.weight = float(bw.weight) / total_w
	else:
		v.bone_weights[0].weight = 1.0


## Normalizes weights across all vertices in MeshData.
static func normalize_mesh_weights(mesh: RefCounted) -> void:
	if mesh == null:
		return

	var verts: Array = mesh.get("vertices")
	for v in verts:
		normalize_vertex_weights(v)


## Mirrors bone weights across symmetry plane (x=axis_x) for symmetric bone names.
## e.g. "arm_L" <-> "arm_R", "leg_left" <-> "leg_right".
static func mirror_weights_symmetry(mesh: RefCounted, axis_x: float = 0.0, left_prefix: String = "_L", right_prefix: String = "_R") -> void:
	if mesh == null:
		return

	var verts: Array = mesh.get("vertices")

	for i in range(verts.size()):
		var v_source: RefCounted = verts[i]
		var pos_s: Vector2 = v_source.position

		if pos_s.x < axis_x:
			# Left side vertex -> find mirrored right side vertex
			var mirrored_pos := Vector2(2.0 * axis_x - pos_s.x, pos_s.y)
			var target_v: RefCounted = find_closest_vertex(verts, mirrored_pos)

			if target_v != null:
				copy_mirrored_weights(v_source, target_v, left_prefix, right_prefix)


static func find_closest_vertex(verts: Array, target_pos: Vector2, max_dist: float = 16.0) -> RefCounted:
	var closest: RefCounted = null
	var min_dist: float = max_dist

	for v in verts:
		var dist: float = (v.position as Vector2).distance_to(target_pos)
		if dist < min_dist:
			min_dist = dist
			closest = v

	return closest


static func copy_mirrored_weights(src: RefCounted, dst: RefCounted, left_prefix: String, right_prefix: String) -> void:
	dst.bone_weights.clear()
	var MeshDataScript = preload("res://deformation/meshes/mesh_data.gd")

	for bw in src.bone_weights:
		var b_id: String = str(bw.bone_id)
		var mirrored_b_id: String = b_id

		if b_id.ends_with(left_prefix):
			mirrored_b_id = b_id.left(-left_prefix.length()) + right_prefix
		elif b_id.ends_with(right_prefix):
			mirrored_b_id = b_id.left(-right_prefix.length()) + left_prefix

		var new_bw = MeshDataScript.BoneWeightData.new(mirrored_b_id, float(bw.weight))
		dst.bone_weights.append(new_bw)
