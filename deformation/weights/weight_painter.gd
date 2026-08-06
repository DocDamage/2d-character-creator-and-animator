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

	for v in verts:
		var dist: float = (v.position as Vector2).distance_to(brush_center)
		if dist <= brush_radius:
			var norm_dist: float = dist / brush_radius
			var factor: float = pow(1.0 - norm_dist, brush_falloff)
			var delta: float = brush_strength * factor

			apply_brush_mode(v, active_bone_id, active_mode, delta, MeshDataScript)

			# Normalize total weights on vertex to 1.0
			var WeightNormalizerScript = preload("res://deformation/weights/weight_normalizer.gd")
			WeightNormalizerScript.normalize_vertex_weights(v)


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
