# Exercises every legacy facing-grid requirement as one independent workflow.
extends Node

const FacingGridScript = preload("res://facing/facing_grid_definition.gd")
const FacingGridEvaluatorScript = preload("res://facing/facing_grid_evaluator.gd")


func run_tests() -> Dictionary:
	var four_way: FacingGridDefinition = _grid(FacingGridScript.DirectionSet.FOUR_WAY)
	var eight_way: FacingGridDefinition = _grid(FacingGridScript.DirectionSet.EIGHT_WAY)
	var sixteen_way: FacingGridDefinition = FacingGridScript.new("sixteen", "Sixteen")
	sixteen_way.set_direction_set(FacingGridScript.DirectionSet.SIXTEEN_WAY)
	var custom_way: FacingGridDefinition = FacingGridScript.new("custom", "Custom")
	custom_way.set_direction_set(FacingGridScript.DirectionSet.CUSTOM, ["forward", "right", "back", "left", "forward", ""])
	for direction_id in custom_way.get_direction_ids():
		custom_way.set_cell(direction_id, {"asset_id": direction_id})
	var north := FacingGridEvaluatorScript.evaluate(four_way, Vector2.UP, FacingGridScript.BlendMode.NEAREST)
	var east := FacingGridEvaluatorScript.evaluate(four_way, Vector2.RIGHT, FacingGridScript.BlendMode.HARD_SWITCH)
	var sixteenth := FacingGridEvaluatorScript.evaluate(sixteen_way, Vector2.UP, FacingGridScript.BlendMode.NEAREST)
	var custom_forward := FacingGridEvaluatorScript.evaluate(custom_way, Vector2.UP, FacingGridScript.BlendMode.NEAREST)
	var mirrored: bool = four_way.mirror_cell("north", "south", true)
	var south: Dictionary = four_way.get_cell("south")
	var midpoint_direction := Vector2(sin(PI / 8.0), -cos(PI / 8.0))
	var crossfade := FacingGridEvaluatorScript.evaluate(eight_way, midpoint_direction, FacingGridScript.BlendMode.CROSSFADE)
	eight_way.pixel_mode = true
	var pixel_mode := FacingGridEvaluatorScript.evaluate(eight_way, midpoint_direction, FacingGridScript.BlendMode.CROSSFADE)
	eight_way.pixel_mode = false
	var disabled: Dictionary = eight_way.get_cell("north_east")
	disabled["blend_enabled"] = false
	eight_way.set_cell("north_east", disabled)
	var blend_disabled := FacingGridEvaluatorScript.evaluate(eight_way, midpoint_direction, FacingGridScript.BlendMode.CROSSFADE)
	var interpolated := FacingGridEvaluatorScript.interpolate_mesh_vertices([[0.0, 0.0], [4.0, 0.0]], [[2.0, 2.0], [6.0, 0.0]], 0.5)
	var incompatible := FacingGridEvaluatorScript.interpolate_mesh_vertices([Vector2.ZERO], [Vector2.ONE, Vector2.RIGHT], 0.5)
	var incomplete: FacingGridDefinition = FacingGridScript.new("incomplete", "Incomplete")
	incomplete.set_direction_set(FacingGridScript.DirectionSet.FOUR_WAY)
	incomplete.set_cell("north", {"asset_id": "north"})
	var restored: FacingGridDefinition = FacingGridScript.new().from_dict(four_way.to_dict())
	var first_serialization := JSON.stringify(four_way.to_dict(), "", true)
	var second_serialization := JSON.stringify(restored.to_dict(), "", true)
	var checks := {
		"direction_sets": four_way.get_direction_ids() == ["north", "east", "south", "west"] and eight_way.get_direction_ids().size() == 8 and sixteen_way.get_direction_ids().size() == 16 and custom_way.get_direction_ids() == ["forward", "right", "back", "left"],
		"selection": north.get("primary_direction") == "north" and east.get("primary_direction") == "east" and sixteenth.get("primary_direction") == "direction_00" and custom_forward.get("primary_direction") == "forward",
		"mirror": mirrored and bool(south.get("mirror_x", false)) and bool(south.get("handedness_swap", false)) and str((south.get("slot_swap", {}) as Dictionary).get("weapon", "")) == "hand_right" and str((south.get("slot_swap", {}) as Dictionary).get("shield", "")) == "hand_left",
		"blending": crossfade.get("mode") == "crossfade" and crossfade.get("primary_direction") == "north" and crossfade.get("secondary_direction") == "north_east" and is_equal_approx(float(crossfade.get("weight", 0.0)), 0.5) and pixel_mode.get("mode") == "hard_switch" and blend_disabled.get("mode") == "hard_switch",
		"mesh": interpolated.size() == 2 and (interpolated[0] as Array) == [1.0, 1.0] and (interpolated[1] as Array) == [5.0, 0.0] and incompatible.is_empty(),
		"diagnostics_persistence": incomplete.missing_directions() == ["east", "south", "west"] and not incomplete.set_cell("unknown", {}) and incomplete.validate().is_empty() and restored.missing_directions().is_empty() and first_serialization == second_serialization,
	}
	if _all_true(checks):
		print("  PASS: 4/8/16/custom grids, selection, mirroring, blending, mesh interpolation, and persistence behave deterministically")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Facing-grid acceptance failed: %s" % checks]}


func _grid(direction_set: int) -> FacingGridDefinition:
	var grid: FacingGridDefinition = FacingGridScript.new("grid_%d" % direction_set, "Grid %d" % direction_set)
	grid.set_direction_set(direction_set)
	for direction_id in grid.get_direction_ids():
		grid.set_cell(direction_id, {"asset_id": "asset_" + direction_id, "slot_swap": {"weapon": "hand_left", "shield": "hand_right"}})
	return grid


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true
