# Covers FAC-004 deterministic filename-based directional placement.
extends Node

const FacingGridScript = preload("res://facing/facing_grid_definition.gd")
const FilenamePlacementModelScript = preload("res://facing/facing_filename_placement_model.gd")
const FilenameDialogScene = preload("res://facing/facing_filename_placement_dialog.tscn")


func run_tests() -> Dictionary:
	var grid: FacingGridDefinition = FacingGridScript.new("batch_grid", "Batch Grid")
	grid.set_direction_set(FacingGridScript.DirectionSet.EIGHT_WAY)
	var dialog: Node = FilenameDialogScene.instantiate() as Node
	add_child(dialog)
	dialog.call("open_for_grid", grid)
	dialog.call("set_entries_text", "ast_north | hero_north.png\nast_northeast | hero_north_east.png\nast_east | hero_east.png")
	var preview: Dictionary = dialog.call("preview_entries") as Dictionary
	var applied: Dictionary = dialog.call("apply_preview") as Dictionary
	var malformed := FilenamePlacementModelScript.parse_entries("bad line")
	var unknown := FilenamePlacementModelScript.preview(grid, [{"asset_id": "ast_unknown", "filename": "hero_jump.png", "line": 1}])
	var duplicate := FilenamePlacementModelScript.preview(grid, [
		{"asset_id": "ast_one", "filename": "hero_west.png", "line": 1},
		{"asset_id": "ast_two", "filename": "villain_west.png", "line": 2},
	])
	var custom: FacingGridDefinition = FacingGridScript.new("custom", "Custom")
	custom.set_direction_set(FacingGridScript.DirectionSet.CUSTOM, ["forward", "back"])
	var custom_preview := FilenamePlacementModelScript.preview(custom, [{"asset_id": "ast_forward", "filename": "hero_forward.png", "line": 1}])
	var four_way: FacingGridDefinition = FacingGridScript.new("four", "Four")
	four_way.set_direction_set(FacingGridScript.DirectionSet.FOUR_WAY)
	var four_preview := FilenamePlacementModelScript.preview(four_way, [{"asset_id": "ast_south", "filename": "hero_south.png", "line": 1}])
	var sixteen_way: FacingGridDefinition = FacingGridScript.new("sixteen", "Sixteen")
	sixteen_way.set_direction_set(FacingGridScript.DirectionSet.SIXTEEN_WAY)
	var sixteen_preview := FilenamePlacementModelScript.preview(sixteen_way, [{"asset_id": "ast_seven", "filename": "hero_direction_07.png", "line": 1}])
	var checks := {
		"preview_and_apply": bool(preview.get("valid", false)) and bool(applied.get("success", false)) and grid.get_cell("north").get("asset_id", "") == "ast_north" and grid.get_cell("north_east").get("asset_id", "") == "ast_northeast" and grid.get_cell("east").get("asset_id", "") == "ast_east",
		"diagnostics": not (malformed.get("diagnostics", []) as Array).is_empty() and not bool(unknown.get("valid", true)) and not bool(duplicate.get("valid", true)),
		"custom": bool(custom_preview.get("valid", false)) and custom_preview.get("assignments", {}).get("forward", "") == "ast_forward",
		"four_and_sixteen": bool(four_preview.get("valid", false)) and four_preview.get("assignments", {}).get("south", "") == "ast_south" and bool(sixteen_preview.get("valid", false)) and sixteen_preview.get("assignments", {}).get("direction_07", "") == "ast_seven",
	}
	dialog.queue_free()
	if _all_true(checks):
		print("  PASS: Filename batch placement previews deterministically, applies atomically, and rejects malformed, unknown, and duplicate mappings")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Filename placement acceptance failed: %s" % checks]}


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true
