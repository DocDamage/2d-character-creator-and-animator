# WeaponSolverJointLimits -- Applies optional per-joint local rotation ranges.
class_name WeaponSolverJointLimits
extends RefCounted


static func clamp_rotation(value: float, limits: Dictionary, joint_id: String) -> Dictionary:
	if not limits.has(joint_id):
		return {"value": value, "limited": false}
	var range: Variant = limits[joint_id]
	var minimum := -PI
	var maximum := PI
	if range is Array and range.size() >= 2:
		minimum = float(range[0])
		maximum = float(range[1])
	elif range is Dictionary:
		minimum = float(range.get("min", minimum))
		maximum = float(range.get("max", maximum))
	if minimum > maximum:
		return {"value": value, "limited": false, "invalid": true}
	var clamped := clampf(value, minimum, maximum)
	return {"value": clamped, "limited": not is_equal_approx(value, clamped), "invalid": false, "min": minimum, "max": maximum}
