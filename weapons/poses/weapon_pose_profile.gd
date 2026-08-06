# WeaponPoseProfile -- Per-body, direction, and animation weapon posing offsets.
class_name WeaponPoseProfile
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

enum DriveMode { MANUAL, PRIMARY_HAND, CONTROLLER, BODY_SOCKET, PATH, WORLD, CUSTOM }

var profile_id: String = ""
var display_name: String = ""
var weapon_id: String = ""
var base_position: Vector2 = Vector2.ZERO
var base_rotation: float = 0.0
var primary_grip_id: String = ""
var secondary_grip_id: String = ""
var hand_bindings: Array = []
var drive_mode: DriveMode = DriveMode.MANUAL
var drive_settings: Dictionary = {}
var body_type_offsets: Dictionary = {}
var direction_offsets: Dictionary = {}
var animation_offsets: Dictionary = {}


func _init(p_id: String = "", p_name: String = "") -> void:
	profile_id = p_id
	display_name = p_name


func resolve_transform(body_type_id: String = "", direction_id: String = "", animation_id: String = "") -> Dictionary:
	var result := {"position": base_position, "rotation": base_rotation}
	_apply_offset(result, body_type_offsets.get(body_type_id, {}))
	_apply_offset(result, direction_offsets.get(direction_id, {}))
	_apply_offset(result, animation_offsets.get(animation_id, {}))
	return result


func get_binding_for_grip(grip_id: String) -> Dictionary:
	for binding in hand_bindings:
		if str(binding.get("grip_id", "")) == grip_id:
			return (binding as Dictionary).duplicate(true)
	return {}


func set_hand_binding(binding: Dictionary) -> bool:
	var grip_id := str(binding.get("grip_id", ""))
	var hand_bone_id := str(binding.get("hand_bone_id", ""))
	if grip_id.is_empty() or hand_bone_id.is_empty():
		return false
	for index in hand_bindings.size():
		if str(hand_bindings[index].get("grip_id", "")) == grip_id:
			hand_bindings[index] = binding.duplicate(true)
			return true
	hand_bindings.append(binding.duplicate(true))
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": profile_id,
		"display_name": display_name,
		"weapon_id": weapon_id,
		"base_position": [base_position.x, base_position.y],
		"base_rotation": base_rotation,
		"primary_grip_id": primary_grip_id,
		"secondary_grip_id": secondary_grip_id,
		"hand_bindings": hand_bindings.duplicate(true),
		"drive_mode": int(drive_mode),
		"drive_settings": _serialize_drive_settings(drive_settings),
		"body_type_offsets": body_type_offsets.duplicate(true),
		"direction_offsets": direction_offsets.duplicate(true),
		"animation_offsets": animation_offsets.duplicate(true)
	}


func from_dict(data: Dictionary) -> WeaponPoseProfile:
	profile_id = str(data.get("profile_id", ""))
	display_name = str(data.get("display_name", ""))
	weapon_id = str(data.get("weapon_id", ""))
	base_position = _as_vector2(data.get("base_position", Vector2.ZERO))
	base_rotation = float(data.get("base_rotation", 0.0))
	primary_grip_id = str(data.get("primary_grip_id", ""))
	secondary_grip_id = str(data.get("secondary_grip_id", ""))
	hand_bindings = (data.get("hand_bindings", []) as Array).duplicate(true)
	drive_mode = int(data.get("drive_mode", DriveMode.MANUAL)) as DriveMode
	drive_settings = (data.get("drive_settings", {}) as Dictionary).duplicate(true)
	body_type_offsets = (data.get("body_type_offsets", {}) as Dictionary).duplicate(true)
	direction_offsets = (data.get("direction_offsets", {}) as Dictionary).duplicate(true)
	animation_offsets = (data.get("animation_offsets", {}) as Dictionary).duplicate(true)
	return self


func validate() -> Array:
	var errors: Array = []
	if profile_id.is_empty():
		errors.append("WeaponPoseProfile requires profile_id")
	if weapon_id.is_empty():
		errors.append("WeaponPoseProfile '%s' requires weapon_id" % profile_id)
	for binding in hand_bindings:
		if str(binding.get("grip_id", "")).is_empty() or str(binding.get("hand_bone_id", "")).is_empty():
			errors.append("WeaponPoseProfile '%s' has incomplete hand binding" % profile_id)
	if int(drive_mode) == DriveMode.PRIMARY_HAND and primary_grip_id.is_empty():
		errors.append("Primary-hand drive requires primary_grip_id")
	if int(drive_mode) == DriveMode.BODY_SOCKET and str(drive_settings.get("socket_bone_id", "")).is_empty():
		errors.append("Body-socket drive requires socket_bone_id")
	if int(drive_mode) == DriveMode.PATH and not drive_settings.has("path_points") and str(drive_settings.get("path_id", "")).is_empty():
		errors.append("Path drive requires path_points or path_id")
	if int(drive_mode) == DriveMode.CUSTOM and str(drive_settings.get("plugin_id", "")).is_empty():
		errors.append("Custom drive requires plugin_id")
	return errors


static func _apply_offset(result: Dictionary, offset: Variant) -> void:
	if not (offset is Dictionary):
		return
	result["position"] = result["position"] + _as_vector2(offset.get("position", Vector2.ZERO))
	result["rotation"] = float(result["rotation"]) + float(offset.get("rotation", 0.0))


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


static func _serialize_drive_settings(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Array:
		var serialized: Array = []
		for item in value:
			serialized.append(_serialize_drive_settings(item))
		return serialized
	if value is Dictionary:
		var serialized: Dictionary = {}
		for key in value:
			serialized[key] = _serialize_drive_settings(value[key])
		return serialized
	return value
