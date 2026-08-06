# SkeletonProfile -- Serializable semantic-bone contract for a rig used in retargeting.
class_name RigSkeletonProfile
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var profile_id: String = ""
var display_name: String = "Untitled Skeleton Profile"
var rig_id: String = ""
var bone_roles: Dictionary = {}
var metadata: Dictionary = {}


func _init(p_profile_id: String = "", p_display_name: String = "Untitled Skeleton Profile") -> void:
	profile_id = p_profile_id
	display_name = p_display_name


func set_bone_role(role: String, bone_id: String) -> bool:
	var clean_role := role.strip_edges().to_snake_case()
	var clean_bone_id := bone_id.strip_edges()
	if clean_role.is_empty() or clean_bone_id.is_empty():
		return false
	bone_roles[clean_role] = clean_bone_id
	return true


func get_bone_id(role: String) -> String:
	return str(bone_roles.get(role.strip_edges().to_snake_case(), ""))


func validate(available_bone_ids: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if profile_id.strip_edges().is_empty():
		errors.append("profile_id is required")
	if display_name.strip_edges().is_empty():
		errors.append("display_name is required")
	if not bone_roles.has("root"):
		errors.append("a skeleton profile needs a root role")
	var assigned_ids: Dictionary = {}
	for raw_role in bone_roles:
		var role := str(raw_role).strip_edges()
		var bone_id := str(bone_roles[raw_role]).strip_edges()
		if role.is_empty() or bone_id.is_empty():
			errors.append("semantic roles and bone IDs cannot be empty")
			continue
		if assigned_ids.has(bone_id):
			errors.append("bone '%s' is assigned to more than one role" % bone_id)
		assigned_ids[bone_id] = role
		if not available_bone_ids.is_empty() and bone_id not in available_bone_ids:
			errors.append("bone '%s' is not in the bound rig" % bone_id)
	return errors


func to_dict() -> Dictionary:
	var sorted_roles: Array = bone_roles.keys()
	sorted_roles.sort()
	var roles: Dictionary = {}
	for role in sorted_roles:
		roles[role] = bone_roles[role]
	return {"schema_version": SCHEMA_VERSION, "profile_id": profile_id, "display_name": display_name, "rig_id": rig_id, "bone_roles": roles, "metadata": metadata.duplicate(true)}


func from_dict(data: Dictionary) -> RigSkeletonProfile:
	profile_id = str(data.get("profile_id", ""))
	display_name = str(data.get("display_name", "Untitled Skeleton Profile"))
	rig_id = str(data.get("rig_id", ""))
	bone_roles.clear()
	for role in data.get("bone_roles", {}) as Dictionary:
		set_bone_role(str(role), str(data["bone_roles"][role]))
	metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
	return self


static func common_roles() -> Array[String]:
	return ["root", "hips", "spine", "chest", "head", "upper_arm_left", "lower_arm_left", "hand_left", "upper_arm_right", "lower_arm_right", "hand_right", "upper_leg_left", "lower_leg_left", "foot_left", "upper_leg_right", "lower_leg_right", "foot_right"]
