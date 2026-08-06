# WeaponArmReachability -- Evaluates arm-chain reach and available shoulder travel.
class_name WeaponArmReachability
extends RefCounted

const EPSILON := 0.001


static func evaluate(shoulder: Vector2, target: Vector2, upper_length: float, lower_length: float, shoulder_allowance: float = 0.0) -> Dictionary:
	if upper_length <= 0.0 or lower_length <= 0.0:
		return {"success": false, "code": "INVALID_LENGTH", "message": "Arm bone lengths must be positive."}
	var distance := shoulder.distance_to(target)
	var min_reach := absf(upper_length - lower_length)
	var chain_reach := upper_length + lower_length
	var allowance := maxf(0.0, shoulder_allowance)
	var shift := clampf(distance - chain_reach, 0.0, allowance)
	var reachable := distance >= min_reach - EPSILON and distance <= chain_reach + allowance + EPSILON
	return {
		"success": reachable,
		"code": "" if reachable else "UNREACHABLE_GRIP",
		"message": "" if reachable else "Grip is %.2f units outside the arm reach envelope." % _outside_distance(distance, min_reach, chain_reach + allowance),
		"distance": distance,
		"min_reach": min_reach,
		"chain_reach": chain_reach,
		"max_reach": chain_reach + allowance,
		"shoulder_shift": shift,
	}


static func _outside_distance(distance: float, min_reach: float, max_reach: float) -> float:
	if distance < min_reach:
		return min_reach - distance
	return distance - max_reach
