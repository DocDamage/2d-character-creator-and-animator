# BoneBinder -- Automated heat-map and distance-based skinning weight initializer.
# MSH-005: Binds mesh vertices to skeletal bone hierarchy using inverse distance weights.
class_name BoneBinder
extends RefCounted

const MeshDataScript = preload("res://deformation/meshes/mesh_data.gd")


## Binds mesh vertices to array of bone dictionaries (with bone_id, head_pos, tail_pos).
## max_bones_per_vertex: limits maximum influence count per vertex (e.g. 4).
## distance_falloff_power: exponent power for distance weight decay (default 2.0).
static func auto_bind_weights(mesh: RefCounted, bones: Array, max_bones_per_vertex: int = 4, distance_falloff_power: float = 2.0) -> void:
	if mesh == null or bones.is_empty():
		return

	var verts: Array = mesh.get("vertices")

	for v in verts:
		var pos: Vector2 = v.position
		var raw_weights: Array = [] # Array of { "bone_id": String, "weight": float }

		# Calculate inverse distance to line segment of each bone
		for b in bones:
			var b_id: String = str(b.get("bone_id", ""))
			var head: Vector2 = b.get("head_pos", Vector2.ZERO) as Vector2
			var tail: Vector2 = b.get("tail_pos", head + Vector2(0, 50)) as Vector2

			var dist: float = distance_to_segment(pos, head, tail)
			var safe_dist: float = maxf(dist, 1.0)
			var w: float = 1.0 / pow(safe_dist, distance_falloff_power)

			raw_weights.append({"bone_id": b_id, "weight": w})

		# Sort by weight descending
		raw_weights.sort_custom(func(a, b): return a["weight"] > b["weight"])

		# Keep top max_bones_per_vertex
		if raw_weights.size() > max_bones_per_vertex:
			raw_weights = raw_weights.slice(0, max_bones_per_vertex)

		# Normalize sum to 1.0
		var total_w: float = 0.0
		for item in raw_weights:
			total_w += item["weight"]

		v.bone_weights.clear()

		if total_w > 0.0:
			for item in raw_weights:
				var norm_w: float = item["weight"] / total_w
				var bw = MeshDataScript.BoneWeightData.new(item["bone_id"], norm_w)
				v.bone_weights.append(bw)
		else:
			# Fallback to first bone
			var bw = MeshDataScript.BoneWeightData.new(raw_weights[0]["bone_id"], 1.0)
			v.bone_weights.append(bw)


## Distance from point p to line segment (a, b).
static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2: float = a.distance_squared_to(b)
	if l2 == 0.0:
		return p.distance_to(a)

	var t: float = clampf((p - a).dot(b - a) / l2, 0.0, 1.0)
	var proj: Vector2 = a + t * (b - a)
	return p.distance_to(proj)
