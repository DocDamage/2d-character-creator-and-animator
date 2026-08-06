# BoneManager — Handles bone creation, deletion, transform resolution, and hierarchy updates
class_name BoneManager
extends RefCounted

const TransformInheritanceScript = preload("res://rigging/bones/transform_inheritance.gd")

signal bone_added(bone_id: String)
signal bone_removed(bone_id: String)
signal transform_changed(bone_id: String)

var _rig: Dictionary = {}


func initialize(p_rig: Dictionary) -> void:
	_rig = p_rig


func get_rig() -> Dictionary:
	return _rig


func add_bone(p_name: String, p_parent_id: String = "", p_length: float = 50.0) -> Dictionary:
	var bones: Dictionary = _rig.get("bones", {})
	var b_id := "bone_%d" % [bones.size() + 1]
	var bone := BoneSchema.create_default_bone(b_id, p_name, p_parent_id)
	bone["length"] = p_length
	
	bones[b_id] = bone
	_rig["bones"] = bones
	
	if p_parent_id.is_empty() and str(_rig.get("root_bone_id", "")).is_empty():
		_rig["root_bone_id"] = b_id
	elif not p_parent_id.is_empty() and bones.has(p_parent_id):
		var parent_bone: Dictionary = bones[p_parent_id]
		var children: Array = parent_bone.get("children", [])
		if not children.has(b_id):
			children.append(b_id)
			parent_bone["children"] = children
			
	bone_added.emit(b_id)
	return bone


func remove_bone(p_bone_id: String) -> bool:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id):
		return false
		
	var bone: Dictionary = bones[p_bone_id]
	var parent_id: String = bone.get("parent_id", "")
	if not parent_id.is_empty() and bones.has(parent_id):
		var p_children: Array = bones[parent_id].get("children", [])
		p_children.erase(p_bone_id)
		
	var children: Array = bone.get("children", []).duplicate()
	for child_id in children:
		remove_bone(child_id)
		
	bones.erase(p_bone_id)
	if _rig.get("root_bone_id", "") == p_bone_id:
		_rig["root_bone_id"] = ""
		
	bone_removed.emit(p_bone_id)
	return true


func get_global_transform(p_bone_id: String) -> Transform2D:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id):
		return Transform2D.IDENTITY
		
	var bone: Dictionary = bones[p_bone_id]
	var pos: Vector2 = bone.get("local_position", Vector2.ZERO)
	var rot: float = bone.get("local_rotation", 0.0)
	var scale: Vector2 = bone.get("local_scale", Vector2.ONE)
	var parent_id: String = bone.get("parent_id", "")
	if parent_id.is_empty() or not bones.has(parent_id):
		return Transform2D(rot, scale, 0.0, pos)
		
	var parent_tf := get_global_transform(parent_id)
	return TransformInheritanceScript.compute_inherited_transform(
		parent_tf,
		pos,
		rot,
		scale,
		bool(bone.get("inherit_position", true)),
		bool(bone.get("inherit_rotation", true)),
		bool(bone.get("inherit_scale", true))
	)


func set_local_transform(p_bone_id: String, p_pos: Vector2, p_rot: float, p_scale: Vector2) -> void:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id):
		return
	var bone: Dictionary = bones[p_bone_id]
	bone["local_position"] = p_pos
	bone["local_rotation"] = p_rot
	bone["local_scale"] = p_scale
	transform_changed.emit(p_bone_id)
