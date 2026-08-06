# PoseDefinition -- Serializable absolute or additive transforms for a named rig pose.
class_name PoseDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

enum Mode { ABSOLUTE, ADDITIVE }

var pose_id: String = ""
var display_name: String = "Untitled Pose"
var rig_profile_id: String = ""
var mode: Mode = Mode.ABSOLUTE
var bone_transforms: Dictionary = {}
var tags: Array = []
var metadata: Dictionary = {}


func _init(p_pose_id: String = "", p_display_name: String = "Untitled Pose") -> void:
	pose_id = p_pose_id
	display_name = p_display_name


func set_bone_transform(bone_id: String, transform: Dictionary) -> bool:
	var normalised_bone_id := bone_id.strip_edges()
	if normalised_bone_id.is_empty():
		return false
	bone_transforms[normalised_bone_id] = _normalise_transform(transform)
	return true


func get_bone_transform(bone_id: String) -> Dictionary:
	return (bone_transforms.get(bone_id, {}) as Dictionary).duplicate(true)


func remove_bone_transform(bone_id: String) -> bool:
	if not bone_transforms.has(bone_id):
		return false
	bone_transforms.erase(bone_id)
	return true


func validate() -> Array:
	var errors: Array = []
	if pose_id.strip_edges().is_empty():
		errors.append("pose_id is required")
	if display_name.strip_edges().is_empty():
		errors.append("display_name is required")
	if bone_transforms.is_empty():
		errors.append("a pose needs at least one bone transform")
	for bone_id in bone_transforms:
		if str(bone_id).strip_edges().is_empty():
			errors.append("pose has an empty bone ID")
	return errors


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"pose_id": pose_id,
		"display_name": display_name,
		"rig_profile_id": rig_profile_id,
		"mode": int(mode),
		"bone_transforms": bone_transforms.duplicate(true),
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


func from_dict(data: Dictionary) -> PoseDefinition:
	pose_id = str(data.get("pose_id", ""))
	display_name = str(data.get("display_name", "Untitled Pose"))
	rig_profile_id = str(data.get("rig_profile_id", ""))
	mode = int(data.get("mode", Mode.ABSOLUTE)) as Mode
	bone_transforms.clear()
	for bone_id in (data.get("bone_transforms", {}) as Dictionary):
		set_bone_transform(str(bone_id), data["bone_transforms"][bone_id] as Dictionary)
	tags = _unique_strings(data.get("tags", []) as Array)
	metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
	return self


func _normalise_transform(value: Dictionary) -> Dictionary:
	var position: Variant = value.get("position", value.get("local_position", [0.0, 0.0]))
	if position is Vector2:
		position = [position.x, position.y]
	elif not position is Array or position.size() < 2:
		position = [0.0, 0.0]
	var scale: Variant = value.get("scale", value.get("local_scale", [1.0, 1.0]))
	if scale is Vector2:
		scale = [scale.x, scale.y]
	elif not scale is Array or scale.size() < 2:
		scale = [1.0, 1.0]
	return {
		"position": [float(position[0]), float(position[1])],
		"rotation": float(value.get("rotation", value.get("local_rotation", 0.0))),
		"scale": [float(scale[0]), float(scale[1])],
	}


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var text := str(value).strip_edges()
		if not text.is_empty() and text not in result:
			result.append(text)
	return result
