# LpcWeightInitializer -- Clearly named rigid, distance-segment, and shared-topology weight initializers.
class_name LpcWeightInitializer
extends RefCounted

const MeshScript = preload("res://lpc/rig/lpc_weighted_mesh.gd")


static func nearest_bone_rigid(mesh: Dictionary, bones: Array) -> Dictionary:
	return _initialize(mesh, bones, 1, true)


static func distance_to_segment(mesh: Dictionary, bones: Array, max_influences: int = 4, falloff_power: float = 2.0) -> Dictionary:
	var result := mesh.duplicate(true); var vertices := MeshScript.vectors(result.get("rest_vertices", [])); var all_weights: Array = []
	for point in vertices:
		var ranked: Array = []
		for raw in bones:
			if not raw is Dictionary: continue
			var bone: Dictionary = raw; var bone_id := str(bone.get("bone_id", "")); if bone_id.is_empty(): continue
			var distance := _distance_to_segment(point, _vector(bone.get("head", bone.get("head_position", [0, 0]))), _vector(bone.get("tail", bone.get("tail_position", [0, 0]))))
			ranked.append({"bone_id": bone_id, "weight": 1.0 / pow(maxf(distance, 0.25), maxf(0.1, falloff_power))})
		ranked.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.weight) > float(b.weight))
		all_weights.append(_normalize(ranked.slice(0, mini(maxi(1, max_influences), ranked.size()))))
	result["weights"] = all_weights; result["initialization"] = {"method": "distance_to_segment", "max_influences": max_influences, "falloff_power": falloff_power}
	return result


static func transfer_shared_topology(target: Dictionary, source: Dictionary) -> Dictionary:
	if target.get("triangle_indices", []) != source.get("triangle_indices", []) or (target.get("rest_vertices", []) as Array).size() != (source.get("rest_vertices", []) as Array).size():
		return {"success": false, "errors": ["Shared-topology transfer requires identical vertex count and triangle topology."]}
	var result := target.duplicate(true); result["weights"] = (source.get("weights", []) as Array).duplicate(true); result["initialization"] = {"method": "shared_topology_transfer", "source_mesh_id": source.get("mesh_id", "")}
	return {"success": true, "errors": [], "mesh": result}


static func _initialize(mesh: Dictionary, bones: Array, max_influences: int, rigid: bool) -> Dictionary:
	var result := mesh.duplicate(true); var vertices := MeshScript.vectors(result.get("rest_vertices", [])); var weights: Array = []
	for point in vertices:
		var ranked: Array = []
		for raw in bones:
			if not raw is Dictionary: continue
			var bone: Dictionary = raw; var bone_id := str(bone.get("bone_id", "")); if bone_id.is_empty(): continue
			var distance := _distance_to_segment(point, _vector(bone.get("head", bone.get("head_position", [0, 0]))), _vector(bone.get("tail", bone.get("tail_position", [0, 0]))))
			ranked.append({"bone_id": bone_id, "weight": 1.0 / maxf(distance, 0.001)})
		ranked.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.weight) > float(b.weight))
		weights.append([{ "bone_id": str(ranked[0].bone_id), "weight": 1.0 }] if rigid and not ranked.is_empty() else _normalize(ranked.slice(0, mini(maxi(1, max_influences), ranked.size()))))
	result["weights"] = weights; result["initialization"] = {"method": "nearest_bone_rigid" if rigid else "distance_to_segment", "max_influences": max_influences}
	return result


static func _normalize(values: Array) -> Array:
	if values.is_empty(): return []
	var total := 0.0; for value in values: total += float((value as Dictionary).get("weight", 0.0))
	var output: Array = []; for value in values: output.append({"bone_id": str((value as Dictionary).get("bone_id", "")), "weight": float((value as Dictionary).get("weight", 0.0)) / maxf(total, 0.00001)})
	return output
static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var delta := b - a; var length_squared := delta.length_squared(); return point.distance_to(a) if length_squared < 0.000001 else point.distance_to(a + delta * clampf((point - a).dot(delta) / length_squared, 0.0, 1.0))
static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
