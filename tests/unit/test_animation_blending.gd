# Unit tests for Phase 5 layered animation blending.
extends Node

const BlendStackScript = preload("res://animation/blending/animation_blend_stack.gd")


func run_tests() -> int:
	var stack = BlendStackScript.new("hero_layers")
	var upper_ok: bool = stack.add_layer("upper", "aim", "override", 0.5, ["arm_r"], "locomotion")
	var additive_ok: bool = stack.add_layer("breath", "breathing", "additive", 0.5, ["chest"], "locomotion")
	var weapon_ok: bool = stack.add_layer("weapon", "sword", "override", 1.0, ["weapon"], "", true)
	var base := {"arm_r": {"position": [0.0, 0.0], "rotation": 0.0}, "chest": {"position": [0.0, 0.0]}, "weapon": {"rotation": 0.0}}
	var poses := {"aim": {"arm_r": {"position": [10.0, 0.0], "rotation": 1.0}, "leg": {"position": [9.0, 0.0]}}, "breathing": {"chest": {"position": [0.0, 2.0]}}, "sword": {"weapon": {"rotation": 0.75}}}
	var result: Dictionary = stack.evaluate(base, poses, {"upper": 0.2, "breath": 0.6}, false)
	var included: Dictionary = stack.evaluate(base, poses, {"upper": 0.2, "breath": 0.6}, true)
	var restored = BlendStackScript.new().from_dict(stack.to_dict())
	if upper_ok and additive_ok and weapon_ok and absf(float(result.pose.arm_r.position[0]) - 5.0) < 0.001 and absf(float(result.pose.chest.position[1]) - 1.0) < 0.001 and not result.pose.has("leg") and absf(float(result.pose.weapon.rotation)) < 0.001 and absf(float(included.pose.weapon.rotation) - 0.75) < 0.001 and absf(float(result.sync_times.upper) - 0.4) < 0.001 and restored.validate().is_empty():
		print("  PASS: BLD-001 through BLD-005 masks, additive layers, sync groups, and weapon overlays blend deterministically")
		return 1
	printerr("  FAIL: animation blend stack did not compose expected poses")
	return 0
