# BoneProperties — Handles bone color tags, groups, locking, and visibility toggles
class_name BoneProperties
extends RefCounted


static func set_bone_color(p_rig: Dictionary, p_bone_id: String, p_color: Color) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if bones.has(p_bone_id):
		bones[p_bone_id]["color"] = p_color


static func set_bone_group(p_rig: Dictionary, p_bone_id: String, p_group: String) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if bones.has(p_bone_id):
		bones[p_bone_id]["group"] = p_group


static func set_bone_locked(p_rig: Dictionary, p_bone_id: String, p_locked: bool) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if bones.has(p_bone_id):
		bones[p_bone_id]["locked"] = p_locked


static func set_bone_visible(p_rig: Dictionary, p_bone_id: String, p_visible: bool) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if bones.has(p_bone_id):
		bones[p_bone_id]["visible"] = p_visible


static func get_bones_by_group(p_rig: Dictionary, p_group: String) -> Array[String]:
	var result: Array[String] = []
	var bones: Dictionary = p_rig.get("bones", {})
	for b_id in bones:
		if bones[b_id].get("group", "default") == p_group:
			result.append(b_id)
	return result
