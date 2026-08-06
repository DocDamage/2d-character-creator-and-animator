# WeaponDriveResolver -- Resolves a weapon transform from an authored drive mode.
class_name WeaponDriveResolver
extends RefCounted

const EPSILON := 0.0001


static func resolve(profile: Variant, weapon: Variant, rig: Dictionary, body_type_id: String = "", direction_id: String = "", animation_id: String = "", context: Dictionary = {}) -> Dictionary:
	if profile == null or weapon == null:
		return _failure("Weapon and pose profile are required.")
	match int(profile.drive_mode):
		1:
			return _resolve_primary_hand(profile, weapon, rig, body_type_id)
		2:
			return _resolve_controller(profile, context)
		3:
			return _resolve_body_socket(profile, rig)
		4:
			return _resolve_path(profile, context)
		5:
			return _resolve_world(profile, context)
		6:
			return _resolve_custom(profile, weapon, rig, context)
	var manual: Dictionary = profile.resolve_transform(body_type_id, direction_id, animation_id)
	return _success("manual", _as_vector2(manual.get("position", Vector2.ZERO)), float(manual.get("rotation", 0.0)))


static func _resolve_primary_hand(profile: Variant, weapon: Variant, rig: Dictionary, body_type_id: String) -> Dictionary:
	var binding: Dictionary = profile.get_binding_for_grip(str(profile.primary_grip_id))
	var grip = weapon.get_grip(str(profile.primary_grip_id))
	var hand_id := str(binding.get("hand_bone_id", ""))
	if grip == null or hand_id.is_empty():
		return _failure("Primary-hand drive needs a primary grip with a hand binding.")
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(hand_id):
		return _failure("Primary-hand drive references missing hand bone '%s'." % hand_id)
	var manager := BoneManager.new()
	manager.initialize(rig)
	var hand_transform := manager.get_global_transform(hand_id)
	var grip_transform: Dictionary = grip.resolve_transform(body_type_id)
	var rotation := hand_transform.get_rotation() - float(grip_transform.get("rotation", 0.0)) + _rotation_offset(profile)
	var position := hand_transform.origin - _as_vector2(grip_transform.get("position", Vector2.ZERO)).rotated(rotation)
	position += _position_offset(profile)
	return _success("primary_hand", position, rotation, {"hand_bone_id": hand_id})


static func _resolve_controller(profile: Variant, context: Dictionary) -> Dictionary:
	if not context.has("controller_position"):
		return _failure("Controller drive requires controller_position context.")
	var rotation := float(context.get("controller_rotation", 0.0)) + _rotation_offset(profile)
	var position := _as_vector2(context.get("controller_position", Vector2.ZERO)) + _position_offset(profile).rotated(rotation - _rotation_offset(profile))
	return _success("controller", position, rotation)


static func _resolve_body_socket(profile: Variant, rig: Dictionary) -> Dictionary:
	var socket_bone_id := str(profile.drive_settings.get("socket_bone_id", ""))
	var bones: Dictionary = rig.get("bones", {})
	if socket_bone_id.is_empty() or not bones.has(socket_bone_id):
		return _failure("Body-socket drive references missing socket bone '%s'." % socket_bone_id)
	var manager := BoneManager.new()
	manager.initialize(rig)
	var socket_bone := manager.get_global_transform(socket_bone_id)
	var socket_rotation := socket_bone.get_rotation() + float(profile.drive_settings.get("socket_rotation", 0.0))
	var socket_position := socket_bone.origin + _as_vector2(profile.drive_settings.get("socket_position", Vector2.ZERO)).rotated(socket_bone.get_rotation())
	var rotation := socket_rotation + _rotation_offset(profile)
	var position := socket_position + _position_offset(profile).rotated(socket_rotation)
	return _success("body_socket", position, rotation, {"socket_bone_id": socket_bone_id})


static func _resolve_path(profile: Variant, context: Dictionary) -> Dictionary:
	var raw_points: Variant = context.get("path_points", profile.drive_settings.get("path_points", []))
	if not (raw_points is Array) or raw_points.size() < 2:
		return _failure("Path drive requires at least two path_points.")
	var points: Array[Vector2] = []
	for raw_point in raw_points:
		points.append(_as_vector2(raw_point))
	var total_length := 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	if total_length <= EPSILON:
		return _failure("Path drive requires path_points with non-zero length.")
	var progress := clampf(float(context.get("path_progress", profile.drive_settings.get("path_progress", 0.0))), 0.0, 1.0)
	var remaining := total_length * progress
	var point := points[0]
	var tangent := points[1] - points[0]
	for index in range(points.size() - 1):
		var start := points[index]
		var end := points[index + 1]
		var segment := start.distance_to(end)
		if segment <= EPSILON:
			continue
		if remaining <= segment or index == points.size() - 2:
			point = start.lerp(end, remaining / segment)
			tangent = end - start
			break
		remaining -= segment
	var orient_to_path := bool(context.get("orient_to_path", profile.drive_settings.get("orient_to_path", true)))
	var base_rotation := tangent.angle() if orient_to_path else float(context.get("path_rotation", profile.drive_settings.get("path_rotation", 0.0)))
	var rotation := base_rotation + _rotation_offset(profile)
	return _success("path", point + _position_offset(profile).rotated(base_rotation), rotation, {"path_progress": progress})


static func _resolve_world(profile: Variant, context: Dictionary) -> Dictionary:
	if not context.has("world_position"):
		return _failure("World drive requires world_position context.")
	var base_rotation := float(context.get("world_rotation", 0.0))
	var rotation := base_rotation + _rotation_offset(profile)
	var position := _as_vector2(context.get("world_position", Vector2.ZERO)) + _position_offset(profile).rotated(base_rotation)
	return _success("world", position, rotation)


static func _resolve_custom(profile: Variant, weapon: Variant, rig: Dictionary, context: Dictionary) -> Dictionary:
	var plugin: Variant = context.get("custom_drive_plugin", null)
	if plugin == null:
		var plugins: Dictionary = context.get("custom_drive_plugins", {})
		plugin = plugins.get(str(profile.drive_settings.get("plugin_id", "")), null)
	if plugin == null or not plugin.has_method("resolve"):
		return _failure("Custom drive requires a registered custom_drive_plugin.")
	var resolved: Variant = plugin.resolve(profile, weapon, rig, context)
	if not (resolved is Dictionary):
		return _failure("Custom drive plugin must return a Dictionary.")
	var result: Dictionary = resolved
	if not bool(result.get("success", false)):
		return _failure(str(result.get("message", "Custom drive plugin could not resolve a transform.")))
	if not result.has("position") or not result.has("rotation"):
		return _failure("Custom drive plugin must return position and rotation.")
	return _success("custom", _as_vector2(result["position"]), float(result["rotation"]), {"plugin_id": str(profile.drive_settings.get("plugin_id", ""))})


static func _position_offset(profile: Variant) -> Vector2:
	return _as_vector2(profile.drive_settings.get("position_offset", Vector2.ZERO))


static func _rotation_offset(profile: Variant) -> float:
	return float(profile.drive_settings.get("rotation_offset", 0.0))


static func _success(mode: String, position: Vector2, rotation: float, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "drive_mode": mode, "position": position, "rotation": rotation}
	result.merge(extra)
	return result


static func _failure(message: String) -> Dictionary:
	return {"success": false, "message": message}


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
