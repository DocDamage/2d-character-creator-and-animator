# ConstraintDiagnostics — Reports evaluation failures, unreachable targets, and numerical issues
class_name ConstraintDiagnostics
extends RefCounted


static func diagnose_stack(p_rig: Dictionary, p_stack: ConstraintStack) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	var constraints := p_stack.get_constraints()
	var cycles := CycleDetector.detect_cycles(constraints)
	errors.append_array(cycles)
	
	var bones: Dictionary = p_rig.get("bones", {})
	for c in constraints:
		if not bones.has(c.owner_bone_id):
			errors.append("Constraint '%s' owner bone '%s' missing." % [c.id, c.owner_bone_id])
		if not c.target_bone_id.is_empty() and not bones.has(c.target_bone_id):
			warnings.append("Constraint '%s' target bone '%s' missing." % [c.id, c.target_bone_id])
			
	return {
		"healthy": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}
