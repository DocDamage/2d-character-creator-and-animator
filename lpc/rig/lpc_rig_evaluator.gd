# LpcRigEvaluator -- Deterministic CPU evaluation of project-owned rigid LPC cutout pieces.
class_name LpcRigEvaluator
extends RefCounted

const AdapterScript = preload("res://lpc/rig/lpc_rig_adapter.gd")
const DerivativeStoreScript = preload("res://lpc/pixels/lpc_derivative_store.gd")
const ReferenceRendererScript = preload("res://lpc/render/lpc_reference_renderer.gd")
const WeightedEvaluatorScript = preload("res://lpc/rig/lpc_weighted_mesh_evaluator.gd")


static func evaluate(profile: Dictionary, adapter: Dictionary, rig_state: Dictionary = {}, canvas_size: Vector2i = Vector2i(64, 64)) -> Dictionary:
	var errors := AdapterScript.validate(adapter, AdapterScript.derivative_id_map(profile))
	if not errors.is_empty(): return {"success": false, "errors": errors, "warnings": [], "image": null}
	var transforms := bone_transforms(adapter, rig_state)
	if not bool(transforms.get("success", false)): return {"success": false, "errors": transforms.get("errors", []), "warnings": [], "image": null}
	var layers: Array = []; var records: Array = []; var warnings: Array[String] = []
	for raw_piece in adapter.get("pieces", []):
		if not raw_piece is Dictionary: continue
		var piece: Dictionary = raw_piece
		if str(piece.get("strategy", "RIGID_CUTOUT")).to_upper() == "HIDDEN": continue
		var weighted_mesh := _weighted_mesh(profile, str(adapter.get("instance_id", "")), str(piece.get("piece_id", "")))
		var derivative := _derivative(profile, str(weighted_mesh.get("derivative_id", piece.get("derivative_id", ""))))
		var image := DerivativeStoreScript.load_image(derivative)
		if image == null or image.is_empty(): warnings.append("Cutout piece '%s' is missing its project-owned PNG." % piece.get("piece_id", "")); continue
		var bone_id := str(piece.get("bone_id", "")); var delta: Transform2D = transforms.get("deltas", {}).get(bone_id, Transform2D.IDENTITY)
		var transformed: Image = null
		if str(piece.get("strategy", "RIGID_CUTOUT")).to_upper() == "WEIGHTED_MESH":
			if weighted_mesh.is_empty(): warnings.append("Weighted piece '%s' has no authored weighted mesh." % piece.get("piece_id", "")); continue
			var weighted := WeightedEvaluatorScript.render(weighted_mesh, image, transforms.get("deltas", {}), canvas_size)
			if not bool(weighted.get("success", false)): warnings.append_array(weighted.get("errors", [])); continue
			transformed = weighted.image
		else: transformed = _transform_image(image, delta, canvas_size)
		var z := int((adapter.get("z_groups", {}) as Dictionary).get(str(piece.get("z_group", "middle")), 0)) + int(piece.get("z_offset", 0))
		layers.append({"layer_id": str(piece.get("piece_id", "")), "z": z, "image": transformed, "offset": [0, 0]})
		records.append({"piece_id": piece.get("piece_id", ""), "derivative_id": piece.get("derivative_id", ""), "bone_id": bone_id, "z": z, "strategy": piece.get("strategy", "RIGID_CUTOUT")})
	var rendered := ReferenceRendererScript.render(layers, canvas_size)
	if not bool(rendered.get("success", false)): return {"success": false, "errors": rendered.get("errors", []), "warnings": warnings, "image": null}
	return {"success": true, "errors": [], "warnings": warnings, "image": rendered.image, "output_hash": rendered.output_hash, "piece_records": records, "bone_transforms": transforms, "anchors": evaluated_anchors(adapter, transforms)}


static func bone_transforms(adapter: Dictionary, rig_state: Dictionary = {}) -> Dictionary:
	var bones: Dictionary = adapter.get("bones", {})
	var rest: Dictionary = {}; var current: Dictionary = {}; var pending: Array = bones.keys(); var errors: Array[String] = []
	while not pending.is_empty():
		var progressed := false
		for raw_id in pending.duplicate():
			var bone_id := str(raw_id); var bone: Dictionary = bones[bone_id]
			var parent_id := str(bone.get("parent_id", ""))
			if not parent_id.is_empty() and not rest.has(parent_id): continue
			var rest_local := _local_transform(bone, {})
			var posed_local := _local_transform(bone, _state_for(adapter, bone_id, rig_state))
			rest[bone_id] = rest[ parent_id ] * rest_local if not parent_id.is_empty() else rest_local
			current[bone_id] = current[ parent_id ] * posed_local if not parent_id.is_empty() else posed_local
			pending.erase(raw_id); progressed = true
		if not progressed: errors.append("LPC rig pose could not resolve its bone hierarchy."); break
	if not errors.is_empty(): return {"success": false, "errors": errors}
	var deltas: Dictionary = {}
	for bone_id in rest: deltas[bone_id] = current[bone_id] * (rest[bone_id] as Transform2D).affine_inverse()
	return {"success": true, "errors": [], "rest": rest, "current": current, "deltas": deltas}


static func evaluated_anchors(adapter: Dictionary, transforms: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for anchor_id in (adapter.get("anchors", {}) as Dictionary):
		var anchor: Dictionary = adapter.anchors[anchor_id] if adapter.anchors[anchor_id] is Dictionary else {}
		var bone_id := str(anchor.get("bone_id", "")); var point := _vector(anchor.get("position", [0, 0]))
		var delta: Transform2D = transforms.get("deltas", {}).get(bone_id, Transform2D.IDENTITY)
		result[str(anchor_id)] = {"bone_id": bone_id, "position": _serialize(delta * point)}
	return result


static func _transform_image(source: Image, delta: Transform2D, canvas_size: Vector2i) -> Image:
	var output := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8); output.fill(Color(0, 0, 0, 0))
	var inverse := delta.affine_inverse()
	for y in range(canvas_size.y):
		for x in range(canvas_size.x):
			var source_point := inverse * Vector2(float(x) + 0.5, float(y) + 0.5)
			var sx := floori(source_point.x); var sy := floori(source_point.y)
			if sx >= 0 and sy >= 0 and sx < source.get_width() and sy < source.get_height(): output.set_pixel(x, y, source.get_pixel(sx, sy))
	return output


static func _local_transform(bone: Dictionary, state: Dictionary) -> Transform2D:
	var position := _vector(bone.get("rest_position", [0, 0]))
	position += _vector(state.get("position", state.get("offset", [0, 0])))
	var rotation := float(bone.get("rest_rotation_degrees", 0.0))
	if state.has("rotation_degrees"): rotation = float(state.get("rotation_degrees", rotation))
	rotation += float(state.get("rotation_offset_degrees", 0.0))
	var scale := _vector(state.get("scale", [1, 1]), Vector2.ONE)
	var radians := deg_to_rad(rotation); var x_axis := Vector2(cos(radians) * scale.x, sin(radians) * scale.x); var y_axis := Vector2(-sin(radians) * scale.y, cos(radians) * scale.y)
	return Transform2D(x_axis, y_axis, position)


static func _state_for(adapter: Dictionary, bone_id: String, rig_state: Dictionary) -> Dictionary:
	var result: Dictionary = ((adapter.get("pose_overrides", {}) as Dictionary).get(bone_id, {}) as Dictionary).duplicate(true)
	var instance_id: String = str(adapter.get("instance_id", "")); var direct: Variant = rig_state.get(instance_id + ":" + bone_id, rig_state.get(bone_id, {}))
	if direct is Dictionary:
		for key in (direct as Dictionary): result[key] = (direct as Dictionary)[key]
	var grouped: Variant = rig_state.get(instance_id, {})
	if grouped is Dictionary:
		var nested: Dictionary = grouped
		if nested.get("bones", {}) is Dictionary and (nested.get("bones", {}) as Dictionary).get(bone_id, {}) is Dictionary:
			for key in ((nested.get("bones", {}) as Dictionary).get(bone_id, {}) as Dictionary): result[key] = ((nested.get("bones", {}) as Dictionary).get(bone_id, {}) as Dictionary)[key]
	return result
static func _derivative(profile: Dictionary, derivative_id: String) -> Dictionary:
	for raw in profile.get("derivative_references", []): if raw is Dictionary and str((raw as Dictionary).get("derivative_id", "")) == derivative_id: return (raw as Dictionary).duplicate(true)
	return {}
static func _weighted_mesh(profile: Dictionary, adapter_id: String, piece_id: String) -> Dictionary:
	for raw in profile.get("weighted_meshes", []):
		if raw is Dictionary and str((raw as Dictionary).get("rig_adapter_id", "")) == adapter_id and str((raw as Dictionary).get("piece_id", "")) == piece_id: return (raw as Dictionary).duplicate(true)
	return {}
static func _vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return fallback
static func _serialize(value: Vector2) -> Array: return [value.x, value.y]
