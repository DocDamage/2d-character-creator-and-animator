# HandPoseDefinition -- Serializable hand attachment and optional finger pose data.
class_name HandPoseDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var hand_pose_id: String = ""
var display_name: String = ""
var hand_side: String = "either"
var attachment_id: String = ""
var wrist_rotation_offset: float = 0.0
var bone_rotation_offsets: Dictionary = {}
var tags: PackedStringArray = []


func _init(p_id: String = "", p_name: String = "") -> void:
	hand_pose_id = p_id
	display_name = p_name


func get_rotation_for_bone(bone_id: String, fallback: float = 0.0) -> float:
	return float(bone_rotation_offsets.get(bone_id, fallback))


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"hand_pose_id": hand_pose_id,
		"display_name": display_name,
		"hand_side": hand_side,
		"attachment_id": attachment_id,
		"wrist_rotation_offset": wrist_rotation_offset,
		"bone_rotation_offsets": bone_rotation_offsets.duplicate(true),
		"tags": Array(tags)
	}


func from_dict(data: Dictionary) -> HandPoseDefinition:
	hand_pose_id = str(data.get("hand_pose_id", ""))
	display_name = str(data.get("display_name", ""))
	hand_side = str(data.get("hand_side", "either"))
	attachment_id = str(data.get("attachment_id", ""))
	wrist_rotation_offset = float(data.get("wrist_rotation_offset", 0.0))
	bone_rotation_offsets = (data.get("bone_rotation_offsets", {}) as Dictionary).duplicate(true)
	tags = PackedStringArray(data.get("tags", []))
	return self


func validate() -> Array:
	var errors: Array = []
	if hand_pose_id.is_empty():
		errors.append("HandPoseDefinition requires hand_pose_id")
	if display_name.is_empty():
		errors.append("HandPoseDefinition '%s' requires display_name" % hand_pose_id)
	if hand_side not in ["left", "right", "either"]:
		errors.append("HandPoseDefinition '%s' has invalid hand_side" % hand_pose_id)
	return errors
