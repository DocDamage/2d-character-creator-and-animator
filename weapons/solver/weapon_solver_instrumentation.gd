# WeaponSolverInstrumentation -- Summarizes deterministic solver evaluation output.
class_name WeaponSolverInstrumentation
extends RefCounted


static func summarize(arms: Array) -> Dictionary:
	var reachable := 0
	var limited := 0
	var max_gap := 0.0
	for arm in arms:
		if bool(arm.get("reachable", false)):
			reachable += 1
		limited += (arm.get("limited_joints", []) as Array).size()
		max_gap = maxf(max_gap, float(arm.get("grip_gap", 0.0)))
	return {"arm_count": arms.size(), "reachable_count": reachable, "limited_joint_count": limited, "max_grip_gap": max_gap}
