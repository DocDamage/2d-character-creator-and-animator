# RigValidator — Structural integrity, cycle detection, and orphan checks for skeletal rigs
class_name RigValidator
extends RefCounted


static func validate(p_rig: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var schema_errs := RigSchema.validate_rig(p_rig)
	errors.append_array(schema_errs)

	var bones: Dictionary = p_rig.get("bones", {})
	var slots: Dictionary = p_rig.get("slots", {})
	var roots: Array[String] = []
	var expected_children: Dictionary = {}

	# Verify both directions of the hierarchy.  The parent_id is authoritative
	# for persisted data, while children is what drives the authoring tree.
	for raw_bone_id in bones:
		var b_id := str(raw_bone_id)
		var bone: Dictionary = bones[raw_bone_id]
		if str(bone.get("id", "")) != b_id:
			errors.append("Bone key '%s' does not match its internal id '%s'." % [b_id, str(bone.get("id", ""))])
		var parent_id: String = bone.get("parent_id", "")
		if parent_id.is_empty():
			roots.append(b_id)
		elif not bones.has(parent_id):
			errors.append("Bone '%s' references non-existent parent '%s'." % [b_id, parent_id])
		else:
			if not expected_children.has(parent_id): expected_children[parent_id] = []
			(expected_children[parent_id] as Array).append(b_id)
		var raw_children = bone.get("children", [])
		if not (raw_children is Array):
			errors.append("Bone '%s' has a non-array children value." % b_id)
			continue
		var children: Array = raw_children as Array
		var seen_children: Dictionary = {}
		for raw_child_id in children:
			var child_id := str(raw_child_id)
			if child_id.is_empty() or not bones.has(child_id):
				errors.append("Bone '%s' lists missing child '%s'." % [b_id, child_id])
			elif seen_children.has(child_id):
				errors.append("Bone '%s' lists child '%s' more than once." % [b_id, child_id])
			elif str((bones[child_id] as Dictionary).get("parent_id", "")) != b_id:
				errors.append("Bone '%s' lists '%s' as a child, but that bone has a different parent." % [b_id, child_id])
			seen_children[child_id] = true

	for raw_parent_id in expected_children:
		var parent_id := str(raw_parent_id)
		var parent_children: Array = (bones[parent_id] as Dictionary).get("children", [])
		var required_children: Array = expected_children[parent_id]
		for child_id in required_children:
			if not parent_children.has(child_id):
				errors.append("Parent bone '%s' is missing child reference '%s'." % [parent_id, str(child_id)])

	errors.append_array(_find_parent_cycles(bones))

	# Check slot parent bindings
	for s_id in slots:
		var slot: Dictionary = slots[s_id]
		var bound_bone_id: String = slot.get("bone_id", "")
		if not bones.has(bound_bone_id):
			errors.append("Slot '%s' bound to non-existent bone '%s'." % [s_id, bound_bone_id])
			
	# Check root selection after the hierarchy has been verified.  Multiple roots
	# are supported for repair/import workflows, but are surfaced clearly.
	if bones.size() > 0:
		var root_id := str(p_rig.get("root_bone_id", ""))
		if root_id.is_empty():
			warnings.append("Rig contains bones but root_bone_id is empty.")
		elif bones.has(root_id) and not str((bones[root_id] as Dictionary).get("parent_id", "")).is_empty():
			errors.append("Rig root bone '%s' must not have a parent." % root_id)
		if roots.is_empty():
			errors.append("Rig hierarchy has no root bone.")
		elif roots.size() > 1:
			warnings.append("Rig has %d root bones; select one root for export." % roots.size())

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}


static func _find_parent_cycles(bones: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var settled: Dictionary = {}
	for raw_start_id in bones:
		var start_id := str(raw_start_id)
		if settled.has(start_id): continue
		var path: Dictionary = {}
		var current_id := start_id
		while not current_id.is_empty() and bones.has(current_id) and not settled.has(current_id):
			if path.has(current_id):
				errors.append("Circular hierarchy detected involving bone '%s'." % current_id)
				break
			path[current_id] = true
			current_id = str((bones[current_id] as Dictionary).get("parent_id", ""))
		for resolved_id in path:
			settled[resolved_id] = true
	return errors
