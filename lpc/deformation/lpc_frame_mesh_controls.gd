# LpcFrameMeshControls -- Non-destructive direct, pin, lattice, and soft-drag evaluation.
class_name LpcFrameMeshControls
extends RefCounted

const MeshScript = preload("res://lpc/deformation/lpc_frame_mesh.gd")


static func evaluate(mesh: Dictionary, override_state: Dictionary = {}) -> Dictionary:
	var errors := MeshScript.validate(mesh)
	if not errors.is_empty(): return {"success": false, "errors": errors, "vertices": []}
	var rest := MeshScript.vectors(mesh.get("rest_vertices", []))
	var state := MeshScript.default_control_state(mesh.get("control_state", {}))
	for key in override_state:
		state[key] = override_state[key]
	var vertices: Array[Vector2] = []
	for point in rest: vertices.append(point)
	_apply_lattice(vertices, rest, state.get("lattice", {}))
	_apply_radial_offsets(vertices, rest, state.get("pins", []), "pin")
	_apply_radial_offsets(vertices, rest, state.get("soft_drags", []), "soft_drag")
	_apply_vertex_offsets(vertices, state.get("vertex_offsets", {}))
	for raw_index in mesh.get("locked_vertices", []):
		var index := int(raw_index)
		if index >= 0 and index < vertices.size(): vertices[index] = rest[index]
	return {"success": true, "errors": [], "vertices": vertices, "control_state": state}


static func set_vertex_offset(mesh: Dictionary, index: int, offset: Variant) -> Dictionary:
	var result := mesh.duplicate(true)
	var state := MeshScript.default_control_state(result.get("control_state", {}))
	var offsets: Dictionary = (state.get("vertex_offsets", {}) as Dictionary).duplicate(true)
	offsets[str(index)] = _serialize(_vector(offset))
	state["vertex_offsets"] = offsets
	result["control_state"] = state
	return result


static func remove_vertex_offset(mesh: Dictionary, index: int) -> Dictionary:
	var result := mesh.duplicate(true)
	var state := MeshScript.default_control_state(result.get("control_state", {}))
	var offsets: Dictionary = (state.get("vertex_offsets", {}) as Dictionary).duplicate(true)
	offsets.erase(str(index))
	state["vertex_offsets"] = offsets
	result["control_state"] = state
	return result


static func add_pin(mesh: Dictionary, center: Variant, offset: Variant, radius: float, falloff: String = "smooth") -> Dictionary:
	return _append_radial(mesh, "pins", center, offset, radius, falloff, "pin")


static func add_soft_drag(mesh: Dictionary, center: Variant, target: Variant, radius: float, falloff: String = "smooth") -> Dictionary:
	var source := _vector(center)
	return _append_radial(mesh, "soft_drags", source, _vector(target) - source, radius, falloff, "soft_drag")


static func set_lattice(mesh: Dictionary, lattice: Dictionary) -> Dictionary:
	var result := mesh.duplicate(true)
	var state := MeshScript.default_control_state(result.get("control_state", {}))
	state["lattice"] = lattice.duplicate(true)
	result["control_state"] = state
	return result


static func reset(mesh: Dictionary) -> Dictionary:
	var result := mesh.duplicate(true)
	result["control_state"] = MeshScript.default_control_state()
	return result


static func _append_radial(mesh: Dictionary, state_key: String, center: Variant, offset: Variant, radius: float, falloff: String, control_type: String) -> Dictionary:
	var result := mesh.duplicate(true)
	var state := MeshScript.default_control_state(result.get("control_state", {}))
	var controls: Array = (state.get(state_key, []) as Array).duplicate(true)
	controls.append({
		"type": control_type,
		"center": _serialize(_vector(center)),
		"offset": _serialize(_vector(offset)),
		"radius": maxf(0.001, radius),
		"falloff": falloff.to_lower(),
	})
	state[state_key] = controls
	result["control_state"] = state
	return result


static func _apply_lattice(vertices: Array[Vector2], rest: Array[Vector2], raw_lattice: Variant) -> void:
	if not raw_lattice is Dictionary: return
	var lattice: Dictionary = raw_lattice
	var columns := maxi(2, int(lattice.get("columns", 2)))
	var rows := maxi(2, int(lattice.get("rows", 2)))
	var origin := _vector(lattice.get("origin", [0, 0]))
	var size := _vector(lattice.get("size", [0, 0]))
	if size.x <= 0.0 or size.y <= 0.0: return
	var offsets: Dictionary = lattice.get("offsets", {})
	for index in range(vertices.size()):
		var local := rest[index] - origin
		var u := clampf(local.x / size.x, 0.0, 1.0)
		var v := clampf(local.y / size.y, 0.0, 1.0)
		var x := u * float(columns - 1)
		var y := v * float(rows - 1)
		var left := clampi(floori(x), 0, columns - 1)
		var top := clampi(floori(y), 0, rows - 1)
		var right := mini(columns - 1, left + 1)
		var bottom := mini(rows - 1, top + 1)
		var tx := x - float(left)
		var ty := y - float(top)
		var a := _lattice_offset(offsets, left, top)
		var b := _lattice_offset(offsets, right, top)
		var c := _lattice_offset(offsets, left, bottom)
		var d := _lattice_offset(offsets, right, bottom)
		vertices[index] += a.lerp(b, tx).lerp(c.lerp(d, tx), ty)


static func _apply_radial_offsets(vertices: Array[Vector2], rest: Array[Vector2], raw_controls: Variant, expected_type: String) -> void:
	if not raw_controls is Array: return
	for raw_control in raw_controls:
		if not raw_control is Dictionary: continue
		var control: Dictionary = raw_control
		if str(control.get("type", expected_type)) != expected_type: continue
		var center := _vector(control.get("center", [0, 0]))
		var offset := _vector(control.get("offset", [0, 0]))
		var radius := maxf(0.001, float(control.get("radius", 1.0)))
		for index in range(vertices.size()):
			var t := clampf(1.0 - rest[index].distance_to(center) / radius, 0.0, 1.0)
			if str(control.get("falloff", "smooth")) == "linear":
				vertices[index] += offset * t
			else:
				vertices[index] += offset * (t * t * (3.0 - 2.0 * t))


static func _apply_vertex_offsets(vertices: Array[Vector2], raw_offsets: Variant) -> void:
	if not raw_offsets is Dictionary: return
	for raw_index in (raw_offsets as Dictionary):
		var index := int(raw_index)
		if index >= 0 and index < vertices.size(): vertices[index] += _vector((raw_offsets as Dictionary)[raw_index])


static func _lattice_offset(offsets: Dictionary, x: int, y: int) -> Vector2:
	return _vector(offsets.get("%d:%d" % [x, y], [0, 0]))


static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO


static func _serialize(value: Vector2) -> Array:
	return [value.x, value.y]
