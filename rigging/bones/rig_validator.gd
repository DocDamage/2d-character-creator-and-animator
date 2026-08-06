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
	
	# Check for orphan bones and circular hierarchy loops
	for b_id in bones:
		var bone: Dictionary = bones[b_id]
		var parent_id: String = bone.get("parent_id", "")
		if not parent_id.is_empty() and not bones.has(parent_id):
			errors.append("Bone '%s' references non-existent parent '%s'." % [b_id, parent_id])
			
		if HierarchyOperations.is_ancestor_of(p_rig, b_id, b_id):
			errors.append("Circular dependency detected involving bone '%s'." % b_id)
			
	# Check slot parent bindings
	for s_id in slots:
		var slot: Dictionary = slots[s_id]
		var bound_bone_id: String = slot.get("bone_id", "")
		if not bones.has(bound_bone_id):
			errors.append("Slot '%s' bound to non-existent bone '%s'." % [s_id, bound_bone_id])
			
	# Check if root bone is set when bones exist
	if bones.size() > 0 and str(p_rig.get("root_bone_id", "")).is_empty():
		warnings.append("Rig contains bones but root_bone_id is empty.")
		
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}
