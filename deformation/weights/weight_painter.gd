# WeightPainter -- Interactive brush weight painting engine for skinning weights.
# MSH-006: Add, Subtract, Smooth, and Replace brush painting modes with falloff radius.
class_name WeightPainter
extends RefCounted

enum BrushMode {
	ADD = 0,
	SUBTRACT = 1,
	SMOOTH = 2,
	REPLACE = 3
}

var active_mode: int = BrushMode.ADD
var active_bone_id: String = ""
var brush_radius: float = 32.0
var brush_strength: float = 0.2
var brush_falloff: float = 1.0 # 1.0 = linear falloff


## Paints weights on mesh vertices around brush_center point in canvas world coords.
func paint_stroke(mesh: RefCounted, brush_center: Vector2) -> void:
	if mesh == null or active_bone_id.is_empty() or brush_radius <= 0.0:
		return

	var verts: Array = mesh.get("vertices")
	var MeshDataScript = preload("res://deformation/meshes/mesh_data.gd")
	var adjacency := _build_adjacency(mesh, verts.size())
	var before: Array[Dictionary] = []
	for vertex in verts: before.append(_weights_by_bone(vertex))

	for index in range(verts.size()):
		var v = verts[index]
		var dist: float = (v.position as Vector2).distance_to(brush_center)
		if dist <= brush_radius:
			var norm_dist: float = dist / brush_radius
			var factor: float = pow(1.0 - norm_dist, brush_falloff)
			var delta: float = brush_strength * factor

			if active_mode == BrushMode.SMOOTH:
				_apply_neighbor_smooth(v, active_bone_id, delta, adjacency.get(index, []), before, MeshDataScript)
			else:
				apply_brush_mode(v, active_bone_id, active_mode, delta, MeshDataScript)

			# Normalize total weights on vertex to 1.0
			var WeightNormalizerScript = preload("res://deformation/weights/weight_normalizer.gd")
			WeightNormalizerScript.normalize_vertex_weights(v)


func _build_adjacency(mesh: RefCounted, count: int) -> Dictionary:
	var result: Dictionary = {}
	for index in range(count): result[index] = []
	for raw_triangle in mesh.get("triangles"):
		var triangle: Array = raw_triangle as Array if raw_triangle is Array else []
		if triangle.size() != 3: continue
		for left in triangle:
			for right in triangle:
				var a := int(left); var b := int(right)
				if a != b and a >= 0 and b >= 0 and a < count and b < count and b not in result[a]: result[a].append(b)
	return result


func _weights_by_bone(vertex: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for weight in vertex.bone_weights: result[str(weight.get("bone_id"))] = float(weight.get("weight"))
	return result


func _apply_neighbor_smooth(vertex: RefCounted, bone_id: String, amount: float, neighbors: Array, before: Array[Dictionary], MeshDataScript: GDScript) -> void:
	if neighbors.is_empty(): return
	var average := 0.0
	for neighbor in neighbors: average += float((before[int(neighbor)] as Dictionary).get(bone_id, 0.0))
	average /= float(neighbors.size())
	var existing = null
	for weight in vertex.bone_weights:
		if str(weight.get("bone_id")) == bone_id: existing = weight; break
	if existing == null:
		if average > 0.0: vertex.bone_weights.append(MeshDataScript.BoneWeightData.new(bone_id, average * amount))
	else:
		existing.weight = lerpf(float(existing.weight), average, clampf(amount, 0.0, 1.0))


static func apply_brush_mode(v: RefCounted, bone_id: String, mode: int, delta: float, MeshDataScript: GDScript) -> void:
	var existing_bw: RefCounted = null
	for bw in v.bone_weights:
		if str(bw.get("bone_id")) == bone_id:
			existing_bw = bw
			break

	match mode:
		BrushMode.ADD:
			if existing_bw != null:
				existing_bw.weight = clampf(float(existing_bw.weight) + delta, 0.0, 1.0)
			else:
				var new_bw = MeshDataScript.BoneWeightData.new(bone_id, delta)
				v.bone_weights.append(new_bw)
		BrushMode.SUBTRACT:
			if existing_bw != null:
				existing_bw.weight = clampf(float(existing_bw.weight) - delta, 0.0, 1.0)
				if float(existing_bw.weight) <= 0.0:
					v.bone_weights.erase(existing_bw)
		BrushMode.REPLACE:
			if existing_bw != null:
				existing_bw.weight = clampf(delta, 0.0, 1.0)
			else:
				var new_bw = MeshDataScript.BoneWeightData.new(bone_id, delta)
				v.bone_weights.append(new_bw)
		BrushMode.SMOOTH:
			if existing_bw != null:
				existing_bw.weight = lerpf(float(existing_bw.weight), 0.5, delta)
