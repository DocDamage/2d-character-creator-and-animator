# LpcWeightPainter -- Atomic non-destructive weight brush operations with topology-neighbor smoothing.
class_name LpcWeightPainter
extends RefCounted

const MeshScript = preload("res://lpc/rig/lpc_weighted_mesh.gd")
const MODES := ["ADD", "SUBTRACT", "REPLACE", "NORMALIZE", "RIGID_ASSIGN", "SMOOTH", "MIRROR"]


static func apply_stroke(mesh: Dictionary, bone_id: String, center: Variant, options: Dictionary = {}) -> Dictionary:
	var mode := str(options.get("mode", "ADD")).to_upper(); if mode not in MODES: return {"success": false, "errors": ["Unknown LPC weight brush mode '%s'." % mode]}
	var vertices := MeshScript.vectors(mesh.get("rest_vertices", [])); var radius := maxf(0.001, float(options.get("radius", 16.0))); var strength := clampf(float(options.get("strength", 0.25)), 0.0, 1.0); var point := _vector(center)
	var before: Array = (mesh.get("weights", []) as Array).duplicate(true); var next: Array = before.duplicate(true); var adjacency := _adjacency(vertices.size(), mesh.get("triangle_indices", [])); var touched: Array[int] = []
	for index in range(vertices.size()):
		var amount := clampf(1.0 - vertices[index].distance_to(point) / radius, 0.0, 1.0); if amount <= 0.0: continue
		amount = pow(amount, maxf(0.01, float(options.get("falloff", 1.0)))) * strength; touched.append(index)
		var values := _map(before[index] if index < before.size() else [])
		match mode:
			"ADD": values[bone_id] = float(values.get(bone_id, 0.0)) + amount
			"SUBTRACT": values[bone_id] = maxf(0.0, float(values.get(bone_id, 0.0)) - amount)
			"REPLACE": values[bone_id] = amount
			"NORMALIZE": pass
			"RIGID_ASSIGN": values = {bone_id: 1.0}
			"SMOOTH": values = _blend(values, _neighbor_average(before, adjacency.get(index, [])), amount)
			"MIRROR": values[bone_id] = float(values.get(bone_id, 0.0)) + amount
		next[index] = _serialize(_normalize(_limit(values, int(mesh.get("max_influences", 4)))))
	if mode == "MIRROR": _mirror_touched(next, touched, options.get("mirror_vertex_map", {}), bone_id, options.get("mirror_bone_map", {}), int(mesh.get("max_influences", 4)))
	var result := mesh.duplicate(true); result["weights"] = next; result["last_weight_stroke"] = {"mode": mode, "bone_id": bone_id, "center": [point.x, point.y], "radius": radius, "strength": strength, "touched_vertices": touched}
	return {"success": true, "errors": [], "mesh": result, "command": {"description": "Weight %s stroke" % mode.to_lower(), "before_weights": before, "after_weights": next, "atomic": true}, "touched_vertices": touched}


static func influences(mesh: Dictionary, vertex_index: int) -> Array:
	var weights: Array = mesh.get("weights", []); return (weights[vertex_index] as Array).duplicate(true) if vertex_index >= 0 and vertex_index < weights.size() and weights[vertex_index] is Array else []
static func adjacency(mesh: Dictionary) -> Dictionary: return _adjacency((mesh.get("rest_vertices", []) as Array).size(), mesh.get("triangle_indices", []))


static func _neighbor_average(weights: Array, neighbors: Array) -> Dictionary:
	if neighbors.is_empty(): return {}
	var totals: Dictionary = {}
	for index in neighbors:
		for bone_id in _map(weights[int(index)] if int(index) < weights.size() else []): totals[bone_id] = float(totals.get(bone_id, 0.0)) + float(_map(weights[int(index)] if int(index) < weights.size() else []).get(bone_id, 0.0))
	for bone_id in totals: totals[bone_id] = float(totals[bone_id]) / float(neighbors.size())
	return totals
static func _blend(current: Dictionary, neighbor: Dictionary, amount: float) -> Dictionary:
	var output: Dictionary = {}
	for bone_id in current: output[bone_id] = float(current[bone_id])
	for bone_id in neighbor: output[bone_id] = lerpf(float(output.get(bone_id, 0.0)), float(neighbor[bone_id]), amount)
	for bone_id in current:
		if not neighbor.has(bone_id): output[bone_id] = lerpf(float(current[bone_id]), 0.0, amount)
	return output
static func _mirror_touched(weights: Array, touched: Array[int], raw_map: Variant, bone_id: String, raw_bone_map: Variant, max_influences: int) -> void:
	if not raw_map is Dictionary: return
	var mirrored_bone := str((raw_bone_map as Dictionary).get(bone_id, bone_id)) if raw_bone_map is Dictionary else bone_id
	for source in touched:
		var target := int((raw_map as Dictionary).get(str(source), -1)); if target < 0 or target >= weights.size(): continue
		var values := _map(weights[source]); var target_values := _map(weights[target]); target_values[mirrored_bone] = float(values.get(bone_id, 0.0)); weights[target] = _serialize(_normalize(_limit(target_values, max_influences)))
static func _adjacency(count: int, indices: Array) -> Dictionary:
	var result: Dictionary = {}; for index in range(count): result[index] = []
	for start in range(0, indices.size() - 2, 3):
		var triangle := [int(indices[start]), int(indices[start + 1]), int(indices[start + 2])]
		for a in triangle:
			for b in triangle:
				if a != b and a >= 0 and b >= 0 and a < count and b < count and b not in result[a]: result[a].append(b)
	return result
static func _map(raw: Variant) -> Dictionary:
	var result: Dictionary = {}; if raw is Array:
		for value in raw:
			if value is Dictionary: result[str((value as Dictionary).get("bone_id", ""))] = float((value as Dictionary).get("weight", 0.0))
	return result
static func _normalize(values: Dictionary) -> Dictionary:
	var total := 0.0; for bone_id in values: total += maxf(0.0, float(values[bone_id]))
	if total <= 0.00001: return values
	var result: Dictionary = {}; for bone_id in values: if float(values[bone_id]) > 0.000001: result[bone_id] = maxf(0.0, float(values[bone_id])) / total
	return result
static func _limit(values: Dictionary, limit: int) -> Dictionary:
	var ranked: Array = []
	for bone_id in values:
		if float(values[bone_id]) > 0.000001: ranked.append({"bone_id": str(bone_id), "weight": float(values[bone_id])})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0)) if not is_equal_approx(float(a.get("weight", 0.0)), float(b.get("weight", 0.0))) else str(a.get("bone_id", "")) < str(b.get("bone_id", "")))
	var output: Dictionary = {}
	for record in ranked.slice(0, mini(maxi(1, limit), ranked.size())): output[str((record as Dictionary).get("bone_id", ""))] = float((record as Dictionary).get("weight", 0.0))
	return output
static func _serialize(values: Dictionary) -> Array:
	var result: Array = []; var ids: Array = values.keys(); ids.sort(); for bone_id in ids: result.append({"bone_id": str(bone_id), "weight": float(values[bone_id])})
	return result
static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
