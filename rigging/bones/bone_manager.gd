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
	if not p_parent_id.is_empty() and not bones.has(p_parent_id): return {}
	var next_index := bones.size() + 1
	var b_id := "bone_%d" % next_index
	while bones.has(b_id):
		next_index += 1
		b_id = "bone_%d" % next_index
	var bone := BoneSchema.create_default_bone(b_id, p_name, p_parent_id)
	bone["length"] = maxf(1.0, p_length)
	
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
			bones[p_parent_id] = parent_bone
			_rig["bones"] = bones
			
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
		var parent: Dictionary = bones[parent_id]
		parent["children"] = p_children
		bones[parent_id] = parent
		
	var children: Array = bone.get("children", []).duplicate()
	for child_id in children:
		remove_bone(child_id)
		
	bones.erase(p_bone_id)
	if _rig.get("root_bone_id", "") == p_bone_id:
		_rig["root_bone_id"] = _first_root_bone_id(bones)
	_rig["bones"] = bones
		
	bone_removed.emit(p_bone_id)
	return true


func get_global_transform(p_bone_id: String) -> Transform2D:
	return _get_global_transform(p_bone_id, {})


func get_parent_global_transform(p_bone_id: String) -> Transform2D:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id):
		return Transform2D.IDENTITY
	var bone: Dictionary = bones[p_bone_id]
	var parent_id: String = bone.get("parent_id", "")
	return _get_global_transform(parent_id, {}) if not parent_id.is_empty() and bones.has(parent_id) else Transform2D.IDENTITY


func get_local_position_for_global(p_bone_id: String, p_global_position: Vector2) -> Vector2:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id): return p_global_position
	var bone: Dictionary = bones[p_bone_id]
	if not bool(bone.get("inherit_position", true)): return p_global_position
	return get_parent_global_transform(p_bone_id).affine_inverse() * p_global_position


func get_local_rotation_for_global(p_bone_id: String, p_global_rotation: float) -> float:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id): return p_global_rotation
	var bone: Dictionary = bones[p_bone_id]
	if not bool(bone.get("inherit_rotation", true)): return p_global_rotation
	return p_global_rotation - get_parent_global_transform(p_bone_id).get_rotation()


func get_local_scale_for_global(p_bone_id: String, p_global_scale: Vector2) -> Vector2:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id): return p_global_scale
	var bone: Dictionary = bones[p_bone_id]
	if not bool(bone.get("inherit_scale", true)): return p_global_scale
	var parent_scale := get_parent_global_transform(p_bone_id).get_scale()
	return Vector2(
		p_global_scale.x / parent_scale.x if absf(parent_scale.x) > 0.000001 else p_global_scale.x,
		p_global_scale.y / parent_scale.y if absf(parent_scale.y) > 0.000001 else p_global_scale.y
	)


func set_global_position(p_bone_id: String, p_global_position: Vector2) -> bool:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id): return false
	var bone: Dictionary = bones[p_bone_id]
	bone["local_position"] = get_local_position_for_global(p_bone_id, p_global_position)
	bones[p_bone_id] = bone
	_rig["bones"] = bones
	transform_changed.emit(p_bone_id)
	return true


func set_global_rotation(p_bone_id: String, p_global_rotation: float) -> bool:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id): return false
	var bone: Dictionary = bones[p_bone_id]
	bone["local_rotation"] = get_local_rotation_for_global(p_bone_id, p_global_rotation)
	bones[p_bone_id] = bone
	_rig["bones"] = bones
	transform_changed.emit(p_bone_id)
	return true


func set_global_transform(p_bone_id: String, p_global_transform: Transform2D) -> bool:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id): return false
	var bone: Dictionary = bones[p_bone_id]
	bone["local_position"] = get_local_position_for_global(p_bone_id, p_global_transform.origin)
	bone["local_rotation"] = get_local_rotation_for_global(p_bone_id, p_global_transform.get_rotation())
	bone["local_scale"] = get_local_scale_for_global(p_bone_id, p_global_transform.get_scale())
	bones[p_bone_id] = bone
	_rig["bones"] = bones
	transform_changed.emit(p_bone_id)
	return true


func _get_global_transform(p_bone_id: String, p_visiting: Dictionary) -> Transform2D:
	var bones: Dictionary = _rig.get("bones", {})
	if not bones.has(p_bone_id):
		return Transform2D.IDENTITY
	var bone: Dictionary = bones[p_bone_id]
	var pos: Vector2 = bone.get("local_position", Vector2.ZERO)
	var rot: float = bone.get("local_rotation", 0.0)
	var scale: Vector2 = bone.get("local_scale", Vector2.ONE)
	var local_transform := Transform2D(rot, scale, 0.0, pos)
	# Rig validation reports this condition, but transform queries are also used
	# while artists repair a bad hierarchy.  Never recurse forever in that UI
	# path; use the local transform as a stable fallback instead.
	if p_visiting.has(p_bone_id): return local_transform
	p_visiting[p_bone_id] = true
	var parent_id: String = bone.get("parent_id", "")
	if parent_id.is_empty() or not bones.has(parent_id):
		p_visiting.erase(p_bone_id)
		return local_transform
	var parent_tf := _get_global_transform(parent_id, p_visiting)
	p_visiting.erase(p_bone_id)
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
	bones[p_bone_id] = bone
	_rig["bones"] = bones
	transform_changed.emit(p_bone_id)


func _first_root_bone_id(bones: Dictionary) -> String:
	var roots: Array[String] = []
	for raw_bone_id in bones:
		var bone: Dictionary = bones[raw_bone_id]
		if str(bone.get("parent_id", "")).is_empty(): roots.append(str(raw_bone_id))
	roots.sort()
	return roots[0] if not roots.is_empty() else ""
