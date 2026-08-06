# WeaponSolverOverlayModel -- Builds renderer-neutral arm solver overlay geometry.
class_name WeaponSolverOverlayModel
extends RefCounted


static func build(arm_result: Dictionary) -> Dictionary:
	var shoulder: Vector2 = arm_result.get("shoulder", Vector2.ZERO)
	var elbow: Vector2 = arm_result.get("elbow", shoulder)
	var hand: Vector2 = arm_result.get("hand", elbow)
	var target: Vector2 = arm_result.get("target", hand)
	return {
		"success": bool(arm_result.get("success", false)),
		"segments": [{"from": shoulder, "to": elbow}, {"from": elbow, "to": hand}],
		"target": target,
		"grip_gap": float(arm_result.get("grip_gap", 0.0)),
		"diagnostics": (arm_result.get("diagnostics", []) as Array).duplicate(true),
	}
