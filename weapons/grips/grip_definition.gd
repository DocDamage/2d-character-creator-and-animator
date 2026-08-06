# GripDefinition -- A named hand contact authored in weapon-local space.
class_name GripDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

enum Role { PRIMARY, SECONDARY }

var grip_id: String = ""
var display_name: String = ""
var role: Role = Role.PRIMARY
var local_position: Vector2 = Vector2.ZERO
var local_rotation: float = 0.0
var hand_side: String = "right"
var hand_pose_id: String = ""
var required: bool = true
var body_type_offsets: Dictionary = {}


func _init(p_id: String = "", p_name: String = "", p_role: Role = Role.PRIMARY) -> void:
	grip_id = p_id
	display_name = p_name
	role = p_role


func resolve_transform(body_type_id: String = "") -> Dictionary:
	var offset: Dictionary = body_type_offsets.get(body_type_id, {})
	return {
		"position": local_position + _as_vector2(offset.get("position", Vector2.ZERO)),
		"rotation": local_rotation + float(offset.get("rotation", 0.0))
	}


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"grip_id": grip_id,
		"display_name": display_name,
		"role": role,
		"local_position": [local_position.x, local_position.y],
		"local_rotation": local_rotation,
		"hand_side": hand_side,
		"hand_pose_id": hand_pose_id,
		"required": required,
		"body_type_offsets": body_type_offsets.duplicate(true)
	}


func from_dict(data: Dictionary) -> GripDefinition:
	grip_id = str(data.get("grip_id", ""))
	display_name = str(data.get("display_name", ""))
	role = int(data.get("role", Role.PRIMARY)) as Role
	local_position = _as_vector2(data.get("local_position", Vector2.ZERO))
	local_rotation = float(data.get("local_rotation", 0.0))
	hand_side = str(data.get("hand_side", "right"))
	hand_pose_id = str(data.get("hand_pose_id", ""))
	required = bool(data.get("required", true))
	body_type_offsets = (data.get("body_type_offsets", {}) as Dictionary).duplicate(true)
	return self


func validate() -> Array:
	var errors: Array = []
	if grip_id.is_empty():
		errors.append("GripDefinition requires grip_id")
	if display_name.is_empty():
		errors.append("GripDefinition '%s' requires display_name" % grip_id)
	if hand_side not in ["left", "right", "either"]:
		errors.append("GripDefinition '%s' has invalid hand_side" % grip_id)
	return errors


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
