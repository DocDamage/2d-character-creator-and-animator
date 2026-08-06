# ActionPointDefinition -- Named locator for VFX, muzzle, footsteps, and gameplay origins.
class_name ActionPointDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var point_id: String = ""
var display_name: String = ""
var point_type: String = "generic"
var bone_id: String = ""
var local_position: Vector2 = Vector2.ZERO
var local_rotation: float = 0.0
var tags: PackedStringArray = []


func _init(p_id: String = "", p_name: String = "") -> void:
	point_id = p_id
	display_name = p_name


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"point_id": point_id,
		"display_name": display_name,
		"point_type": point_type,
		"bone_id": bone_id,
		"local_position": [local_position.x, local_position.y],
		"local_rotation": local_rotation,
		"tags": Array(tags)
	}


func from_dict(data: Dictionary) -> ActionPointDefinition:
	point_id = str(data.get("point_id", ""))
	display_name = str(data.get("display_name", ""))
	point_type = str(data.get("point_type", "generic"))
	bone_id = str(data.get("bone_id", ""))
	local_position = _as_vector2(data.get("local_position", Vector2.ZERO))
	local_rotation = float(data.get("local_rotation", 0.0))
	tags = PackedStringArray(data.get("tags", []))
	return self


func validate() -> Array:
	var errors: Array = []
	if point_id.is_empty():
		errors.append("ActionPointDefinition requires point_id")
	if display_name.is_empty():
		errors.append("ActionPointDefinition '%s' requires display_name" % point_id)
	return errors


func resolve_global_transform(rig: Dictionary) -> Dictionary:
	if bone_id.is_empty() or not (rig.get("bones", {}) as Dictionary).has(bone_id):
		return {"position": local_position, "rotation": local_rotation}
	var manager := BoneManager.new()
	manager.initialize(rig)
	var bone_transform := manager.get_global_transform(bone_id)
	return {
		"position": bone_transform.origin + local_position.rotated(bone_transform.get_rotation()),
		"rotation": bone_transform.get_rotation() + local_rotation
	}


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
