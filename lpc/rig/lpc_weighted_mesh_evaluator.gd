# LpcWeightedMeshEvaluator -- Explicit cage/pin/soft/bone/direct evaluation order for weighted LPC meshes.
class_name LpcWeightedMeshEvaluator
extends RefCounted

const MeshScript = preload("res://lpc/rig/lpc_weighted_mesh.gd")
const CageScript = preload("res://lpc/rig/lpc_cage_deformation.gd")
const RasterizerScript = preload("res://lpc/render/lpc_strict_triangle_rasterizer.gd")


static func evaluate(mesh: Dictionary, bone_deltas: Dictionary) -> Dictionary:
	var errors := MeshScript.validate(mesh, bone_deltas)
	if not errors.is_empty(): return {"success": false, "errors": errors, "warnings": [], "vertices": []}
	var rest := MeshScript.vectors(mesh.get("rest_vertices", [])); var vertices: Array[Vector2] = []
	for point in rest: vertices.append(point)
	var state := MeshScript.default_control_state(mesh.get("control_state", {})); var warnings: Array[String] = []
	for stage in state.get("evaluation_order", MeshScript.DEFAULT_ORDER):
		match str(stage):
			"cage": _apply_cage(vertices, state.get("cage", {}), warnings)
			"lattice": _apply_lattice(vertices, rest, state.get("lattice", {}))
			"pins": _apply_radial(vertices, rest, state.get("pins", []))
			"soft_drags": _apply_radial(vertices, rest, state.get("soft_drags", []))
			"bones": _apply_weights(vertices, mesh.get("weights", []), bone_deltas)
			"vertex_offsets": _apply_offsets(vertices, state.get("vertex_offsets", {}))
			_: warnings.append("Ignored unknown weighted-mesh evaluation stage '%s'." % stage)
	return {"success": true, "errors": [], "warnings": warnings, "vertices": vertices, "evaluation_order": state.get("evaluation_order", MeshScript.DEFAULT_ORDER)}


static func render(mesh: Dictionary, source: Image, bone_deltas: Dictionary, canvas: Vector2i) -> Dictionary:
	var evaluated := evaluate(mesh, bone_deltas)
	if not bool(evaluated.get("success", false)): return evaluated
	var raster := RasterizerScript.bake(source, mesh.get("uvs", []), evaluated.vertices, mesh.get("triangle_indices", []), canvas)
	raster["vertices"] = evaluated.vertices; raster["evaluation_order"] = evaluated.evaluation_order; raster["warnings"] = evaluated.warnings
	return raster


static func _apply_cage(vertices: Array[Vector2], raw_cage: Variant, warnings: Array[String]) -> void:
	if not raw_cage is Dictionary or (raw_cage as Dictionary).is_empty(): return
	var errors := CageScript.validate(raw_cage as Dictionary)
	if not errors.is_empty(): warnings.append_array(errors); return
	var transformed := CageScript.deform_positions(raw_cage as Dictionary, vertices)
	for index in range(vertices.size()): vertices[index] = transformed[index]
static func _apply_weights(vertices: Array[Vector2], raw_weights: Variant, deltas: Dictionary) -> void:
	if not raw_weights is Array: return
	for index in range(mini(vertices.size(), (raw_weights as Array).size())):
		var influences: Array = (raw_weights as Array)[index] if (raw_weights as Array)[index] is Array else []
		if influences.is_empty(): continue
		var position := Vector2.ZERO
		for raw in influences:
			if not raw is Dictionary: continue
			var influence: Dictionary = raw; var delta: Transform2D = deltas.get(str(influence.get("bone_id", "")), Transform2D.IDENTITY)
			position += (delta * vertices[index]) * float(influence.get("weight", 0.0))
		vertices[index] = position
static func _apply_radial(vertices: Array[Vector2], rest: Array[Vector2], raw: Variant) -> void:
	if not raw is Array: return
	for control_raw in raw:
		if not control_raw is Dictionary: continue
		var control: Dictionary = control_raw; var center := _vector(control.get("center", [0, 0])); var offset := _vector(control.get("offset", control.get("target", [0, 0])))
		if control.has("target"): offset -= center
		var radius := maxf(0.001, float(control.get("radius", 1.0)))
		for index in range(vertices.size()):
			var amount := clampf(1.0 - rest[index].distance_to(center) / radius, 0.0, 1.0)
			if str(control.get("falloff", "smooth")) != "linear": amount = amount * amount * (3.0 - 2.0 * amount)
			vertices[index] += offset * amount
static func _apply_lattice(vertices: Array[Vector2], rest: Array[Vector2], raw: Variant) -> void:
	if not raw is Dictionary or (raw as Dictionary).is_empty(): return
	var lattice: Dictionary = raw; var columns := maxi(2, int(lattice.get("columns", 2))); var rows := maxi(2, int(lattice.get("rows", 2)))
	var origin := _vector(lattice.get("origin", [0, 0])); var size := _vector(lattice.get("size", [0, 0])); if size.x <= 0.0 or size.y <= 0.0: return
	var offsets: Dictionary = lattice.get("offsets", {})
	for index in range(vertices.size()):
		var u := clampf((rest[index].x - origin.x) / size.x, 0.0, 1.0); var v := clampf((rest[index].y - origin.y) / size.y, 0.0, 1.0); var gx := u * (columns - 1); var gy := v * (rows - 1)
		var left := clampi(floori(gx), 0, columns - 1); var top := clampi(floori(gy), 0, rows - 1); var right := mini(columns - 1, left + 1); var bottom := mini(rows - 1, top + 1)
		var tx := gx - left; var ty := gy - top; var a := _offset(offsets, left, top); var b := _offset(offsets, right, top); var c := _offset(offsets, left, bottom); var d := _offset(offsets, right, bottom)
		vertices[index] += a.lerp(b, tx).lerp(c.lerp(d, tx), ty)
static func _apply_offsets(vertices: Array[Vector2], raw: Variant) -> void:
	if not raw is Dictionary: return
	for key in raw:
		var index := int(key); if index >= 0 and index < vertices.size(): vertices[index] += _vector(raw[key])
static func _offset(offsets: Dictionary, x: int, y: int) -> Vector2: return _vector(offsets.get("%d:%d" % [x, y], [0, 0]))
static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
