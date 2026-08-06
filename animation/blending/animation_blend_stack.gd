# AnimationBlendStack -- Deterministic masked override/additive layering with sync and weapon overlays.
class_name AnimationBlendStack
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const MODES := ["override", "additive"]

var stack_id: String = ""
var layers: Array = []


func _init(p_stack_id: String = "") -> void:
	stack_id = p_stack_id.strip_edges()


func add_layer(layer_id: String, clip_id: String, mode: String = "override", weight: float = 1.0, bone_mask: Array = [], sync_group: String = "", weapon_overlay: bool = false) -> bool:
	if layer_id.strip_edges().is_empty() or clip_id.strip_edges().is_empty() or mode not in MODES or get_layer(layer_id).size() > 0: return false
	layers.append({"layer_id": layer_id.strip_edges(), "clip_id": clip_id.strip_edges(), "mode": mode, "weight": clampf(weight, 0.0, 1.0), "bone_mask": bone_mask.duplicate(), "sync_group": sync_group.strip_edges(), "weapon_overlay": weapon_overlay, "enabled": true})
	return true


func get_layer(layer_id: String) -> Dictionary:
	for layer in layers:
		if str(layer.get("layer_id", "")) == layer_id: return layer.duplicate(true)
	return {}


func set_layer_property(layer_id: String, property: String, value: Variant) -> bool:
	for index in layers.size():
		if str(layers[index].get("layer_id", "")) != layer_id: continue
		if property == "weight": value = clampf(float(value), 0.0, 1.0)
		layers[index][property] = value
		return true
	return false


func evaluate(base_pose: Dictionary, layer_poses: Dictionary, normalized_times: Dictionary = {}, include_weapon_overlays: bool = true) -> Dictionary:
	var pose := base_pose.duplicate(true)
	var sync_times := _sync_times(normalized_times)
	for layer in layers:
		if not bool(layer.get("enabled", true)) or (bool(layer.get("weapon_overlay", false)) and not include_weapon_overlays): continue
		var clip_pose: Dictionary = layer_poses.get(str(layer.get("clip_id", "")), {})
		var weight := float(layer.get("weight", 1.0))
		for bone_id in clip_pose:
			if not _mask_allows(layer.get("bone_mask", []) as Array, str(bone_id)): continue
			pose[bone_id] = _blend_transform(pose.get(bone_id, {}), clip_pose[bone_id], weight, str(layer.get("mode", "override")))
	return {"pose": pose, "sync_times": sync_times, "active_layers": _active_layer_ids(include_weapon_overlays)}


func synchronize_times(normalized_times: Dictionary) -> Dictionary:
	return _sync_times(normalized_times)


func validate() -> Array:
	var errors: Array = []
	if stack_id.is_empty(): errors.append("Blend stack requires stack_id.")
	var ids: Dictionary = {}
	for layer in layers:
		var layer_id := str(layer.get("layer_id", ""))
		if layer_id.is_empty() or ids.has(layer_id): errors.append("Blend layers need unique IDs.")
		ids[layer_id] = true
		if str(layer.get("mode", "")) not in MODES: errors.append("Blend layer '%s' has an invalid mode." % layer_id)
		if float(layer.get("weight", 0.0)) < 0.0 or float(layer.get("weight", 0.0)) > 1.0: errors.append("Blend layer '%s' has invalid weight." % layer_id)
	return errors


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "stack_id": stack_id, "layers": layers.duplicate(true)}


func from_dict(data: Dictionary) -> AnimationBlendStack:
	stack_id = str(data.get("stack_id", "")).strip_edges()
	layers = (data.get("layers", []) as Array).duplicate(true)
	return self


func _sync_times(normalized_times: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	for layer in layers:
		var group := str(layer.get("sync_group", ""))
		if group.is_empty() or not bool(layer.get("enabled", true)): continue
		var layer_id := str(layer.get("layer_id", ""))
		if not groups.has(group): groups[group] = []
		groups[group].append(clampf(float(normalized_times.get(layer_id, 0.0)), 0.0, 1.0))
	var output := normalized_times.duplicate(true)
	for group in groups:
		var values: Array = groups[group]
		var sum := 0.0
		for value in values: sum += float(value)
		var shared := sum / values.size()
		for layer in layers:
			if str(layer.get("sync_group", "")) == group: output[str(layer.get("layer_id", ""))] = shared
	return output


func _mask_allows(mask: Array, bone_id: String) -> bool:
	return mask.is_empty() or bone_id in mask


func _blend_transform(base: Variant, layer: Variant, weight: float, mode: String) -> Dictionary:
	var from: Dictionary = base if base is Dictionary else {}
	var to: Dictionary = layer if layer is Dictionary else {}
	var result := from.duplicate(true)
	for key in ["position", "rotation", "scale"]:
		if not to.has(key): continue
		if key == "position" or key == "scale":
			var from_value := _vector(from.get(key, [0.0, 0.0]))
			var to_value := _vector(to[key])
			var value := from_value + to_value * weight if mode == "additive" else from_value.lerp(to_value, weight)
			result[key] = [value.x, value.y]
		else:
			var from_rotation := float(from.get(key, 0.0))
			var to_rotation := float(to[key])
			result[key] = from_rotation + to_rotation * weight if mode == "additive" else lerp_angle(from_rotation, to_rotation, weight)
	return result


func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size() >= 2: return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary: return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _active_layer_ids(include_weapon_overlays: bool) -> Array:
	var ids: Array = []
	for layer in layers:
		if bool(layer.get("enabled", true)) and (include_weapon_overlays or not bool(layer.get("weapon_overlay", false))): ids.append(str(layer.get("layer_id", "")))
	return ids
