# LpcWeightedMesh -- Deterministic LPC weighted-mesh schema with stable bone influences.
class_name LpcWeightedMesh
extends RefCounted

const CageScript = preload("res://lpc/rig/lpc_cage_deformation.gd")

const SCHEMA_VERSION := "1.0.0"
const DEFAULT_ORDER := ["cage", "lattice", "pins", "soft_drags", "bones", "vertex_offsets"]


static func create(options: Dictionary) -> Dictionary:
	var vertices: Array = serialize_vectors(options.get("rest_vertices", []))
	var weights: Array = (options.get("weights", []) as Array).duplicate(true)
	while weights.size() < vertices.size(): weights.append([])
	return {
		"weighted_mesh_schema_version": SCHEMA_VERSION, "mesh_id": str(options.get("mesh_id", "weighted_mesh_" + str(Time.get_ticks_usec()))),
		"rig_adapter_id": str(options.get("rig_adapter_id", "")), "piece_id": str(options.get("piece_id", "")),
		"derivative_id": str(options.get("derivative_id", "")), "source_binding": (options.get("source_binding", {}) as Dictionary).duplicate(true),
		"rest_vertices": vertices, "uvs": serialize_vectors(options.get("uvs", options.get("rest_vertices", []))),
		"triangle_indices": (options.get("triangle_indices", []) as Array).duplicate(true), "weights": weights,
		"max_influences": clampi(int(options.get("max_influences", 4)), 1, 8), "allow_unweighted": bool(options.get("allow_unweighted", false)),
		"control_state": default_control_state(options.get("control_state", {})), "validation": {}, "provenance": (options.get("provenance", {}) as Dictionary).duplicate(true),
	}


static func default_control_state(value: Variant = {}) -> Dictionary:
	var state: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not state.has("evaluation_order"): state["evaluation_order"] = DEFAULT_ORDER.duplicate()
	if not state.has("cage"): state["cage"] = {}
	if not state.has("lattice"): state["lattice"] = {}
	if not state.has("pins"): state["pins"] = []
	if not state.has("soft_drags"): state["soft_drags"] = []
	if not state.has("vertex_offsets"): state["vertex_offsets"] = {}
	return state


static func validate(mesh: Dictionary, bone_ids: Dictionary = {}, derivative_ids: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	for key in ["weighted_mesh_schema_version", "mesh_id", "rig_adapter_id", "rest_vertices", "uvs", "triangle_indices", "weights", "control_state"]:
		if not mesh.has(key): errors.append("LPC weighted mesh is missing '%s'." % key)
	if str(mesh.get("weighted_mesh_schema_version", "")) != SCHEMA_VERSION: errors.append("Unsupported LPC weighted mesh schema '%s'." % mesh.get("weighted_mesh_schema_version", ""))
	var vertices: Array = mesh.get("rest_vertices", []); var uvs: Array = mesh.get("uvs", []); var indices: Array = mesh.get("triangle_indices", []); var weights: Array = mesh.get("weights", [])
	if vertices.size() < 3 or uvs.size() != vertices.size(): errors.append("LPC weighted mesh requires matching vertices and UVs.")
	if indices.size() < 3 or indices.size() % 3 != 0: errors.append("LPC weighted mesh requires triangle index triples.")
	for index in indices:
		if int(index) < 0 or int(index) >= vertices.size(): errors.append("LPC weighted mesh has an out-of-range triangle index."); break
	if weights.size() != vertices.size(): errors.append("LPC weighted mesh needs one weight set per vertex.")
	var limit: int = max(1, int(mesh.get("max_influences", 4)))
	for vertex_index in range(mini(vertices.size(), weights.size())):
		var influences: Array = weights[vertex_index] if weights[vertex_index] is Array else []
		if influences.is_empty() and not bool(mesh.get("allow_unweighted", false)): errors.append("Weighted vertex %d has no influences." % vertex_index); continue
		if influences.size() > limit: errors.append("Weighted vertex %d exceeds its influence limit." % vertex_index)
		var sum := 0.0; var ids: Dictionary = {}
		for raw in influences:
			if not raw is Dictionary: errors.append("Weighted vertex %d has an invalid influence." % vertex_index); continue
			var influence: Dictionary = raw; var bone_id := str(influence.get("bone_id", "")); var weight := float(influence.get("weight", -1.0))
			if bone_id.is_empty() or ids.has(bone_id): errors.append("Weighted vertex %d has missing or duplicate bone influence." % vertex_index)
			ids[bone_id] = true
			if not bone_ids.is_empty() and not bone_ids.has(bone_id): errors.append("Weighted vertex %d references missing rig bone '%s'." % [vertex_index, bone_id])
			if weight < 0.0 or weight > 1.0 or is_nan(weight) or is_inf(weight): errors.append("Weighted vertex %d has an invalid influence weight." % vertex_index)
			sum += weight
		if not influences.is_empty() and not is_equal_approx(sum, 1.0): errors.append("Weighted vertex %d influences must normalize to 1.0." % vertex_index)
	if not mesh.get("control_state", {}) is Dictionary:
		errors.append("LPC weighted mesh control state must be an object.")
	else:
		var controls := default_control_state(mesh.get("control_state", {}))
		var order: Array = controls.get("evaluation_order", [])
		var seen_stages: Dictionary = {}
		for stage in order:
			var stage_id := str(stage)
			if stage_id not in DEFAULT_ORDER or seen_stages.has(stage_id): errors.append("LPC weighted mesh has an invalid or duplicate evaluation stage '%s'." % stage_id)
			seen_stages[stage_id] = true
		for required_stage in DEFAULT_ORDER:
			if not seen_stages.has(required_stage): errors.append("LPC weighted mesh evaluation order omits '%s'." % required_stage)
		var cage: Variant = controls.get("cage", {})
		if cage is Dictionary and not (cage as Dictionary).is_empty(): errors.append_array(CageScript.validate(cage as Dictionary))
		if not controls.get("pins", []) is Array or not controls.get("soft_drags", []) is Array: errors.append("LPC weighted mesh pins and soft drags must be arrays.")
		if not controls.get("vertex_offsets", {}) is Dictionary: errors.append("LPC weighted mesh vertex offsets must be an object.")
	var derivative_id := str(mesh.get("derivative_id", ""))
	if not derivative_ids.is_empty() and not derivative_id.is_empty() and not derivative_ids.has(derivative_id): errors.append("LPC weighted mesh references a missing derivative.")
	return errors


static func vectors(values: Array) -> Array[Vector2]:
	var output: Array[Vector2] = []
	for value in values: output.append(_vector(value))
	return output
static func serialize_vectors(values: Array) -> Array:
	var output: Array = []
	for value in values:
		var point := _vector(value); output.append([point.x, point.y])
	return output
static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
