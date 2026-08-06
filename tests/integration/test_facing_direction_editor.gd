# Covers the user-facing direction-set editor introduced by FAC-002.
extends Node

const FacingGridScript = preload("res://facing/facing_grid_definition.gd")
const DirectionEditorScene = preload("res://facing/facing_direction_set_editor.tscn")
const MirrorDialogScene = preload("res://facing/facing_mirror_dialog.tscn")
const FacingGridEvaluatorScript = preload("res://facing/facing_grid_evaluator.gd")
const FacingMeshBlendModelScript = preload("res://facing/facing_mesh_blend_model.gd")


func run_tests() -> Dictionary:
	var grid: FacingGridDefinition = FacingGridScript.new("editor_grid", "Editor Grid")
	grid.set_direction_set(FacingGridScript.DirectionSet.EIGHT_WAY)
	grid.set_cell("north", {"asset_id": "north_sprite"})
	grid.set_cell("north_east", {"asset_id": "north_east_sprite"})
	var editor: Control = DirectionEditorScene.instantiate() as Control
	add_child(editor)
	editor.call("bind_grid", grid)
	var four_way_ok: bool = bool(editor.call("set_direction_set", FacingGridScript.DirectionSet.FOUR_WAY))
	var four_way_directions: Array = grid.get_direction_ids()
	var custom_ok: bool = bool(editor.call("apply_custom_directions_from_text", "forward, right, back, left, forward"))
	var custom_directions: Array = grid.get_direction_ids()
	var selected_ok: bool = bool(editor.call("select_direction", "left"))
	var assigned: bool = bool(editor.call("assign_asset_to_selected", "asset_left"))
	var first_assignment: Dictionary = grid.get_cell("left")
	var replaced: bool = bool(editor.call("assign_asset_to_selected", "asset_left_replaced"))
	var replacement: Dictionary = grid.get_cell("left")
	var slot_cell := grid.get_cell("left")
	slot_cell["slot_swap"] = {"weapon": "hand_left", "shield": "hand_right"}
	grid.set_cell("left", slot_cell)
	var swapped: bool = bool(editor.call("swap_selected_slots"))
	var swapped_cell: Dictionary = grid.get_cell("left")
	var cleared: bool = bool(editor.call("clear_asset_from_selected"))
	editor.call("select_direction", "forward")
	var mesh_blend_controls: Node = editor.get_node("Margin/RootVBox/MeshBlendControls") as Node
	var malformed_mesh_rejected: bool = not bool(mesh_blend_controls.call("set_mesh_deformation", "body_mesh", "body_quad", "not-a-vertex"))
	var forward_mesh_stored: bool = bool(mesh_blend_controls.call("set_mesh_deformation", "body_mesh", "body_quad", "0,0; 2,0"))
	editor.call("select_direction", "right")
	var right_mesh_stored: bool = bool(mesh_blend_controls.call("set_mesh_deformation", "body_mesh", "body_quad", "2,2; 4,0"))
	editor.call("select_direction", "forward")
	var mesh_blend_enabled: bool = bool(mesh_blend_controls.call("set_mesh_blend_enabled", true))
	var mesh_blend_status: Label = mesh_blend_controls.get_node("MeshBlendStatusLabel") as Label
	var incompatible_mesh_blend := FacingMeshBlendModelScript.validate_cells(grid.get_cell("forward"), {"mesh_id": "other_mesh", "deformation": {"mesh_vertices": [[0.0, 0.0], [2.0, 0.0]]}})
	var mirror_grid: FacingGridDefinition = FacingGridScript.new("mirror", "Mirror")
	mirror_grid.set_direction_set(FacingGridScript.DirectionSet.FOUR_WAY)
	mirror_grid.set_cell("north", {"asset_id": "north_asset", "slot_swap": {"weapon": "hand_left"}})
	mirror_grid.set_cell("east", {"asset_id": "east_asset"})
	var mirror_dialog: Node = MirrorDialogScene.instantiate() as Node
	add_child(mirror_dialog)
	mirror_dialog.call("open_for_grid", mirror_grid, "north")
	mirror_dialog.call("set_destination_direction", "east")
	var overwrite_blocked: Dictionary = mirror_dialog.call("apply_mirror") as Dictionary
	mirror_dialog.call("set_overwrite_enabled", true)
	var mirrored: Dictionary = mirror_dialog.call("apply_mirror") as Dictionary
	var mirrored_cell: Dictionary = mirror_grid.get_cell("east")
	grid.default_blend_mode = FacingGridScript.BlendMode.CROSSFADE
	editor.call("_on_hard_switch_pressed")
	var hard_switch_enabled: bool = grid.default_blend_mode == FacingGridScript.BlendMode.HARD_SWITCH
	var blend_controls: Node = editor.get_node("Margin/RootVBox/BlendModeControls") as Node
	var crossfade_enabled: bool = bool(blend_controls.call("set_blend_mode", FacingGridScript.BlendMode.CROSSFADE))
	var crossfade_result := FacingGridEvaluatorScript.evaluate(grid, Vector2(1.0, -1.0))
	var mesh_blend_result: Dictionary = crossfade_result.get("mesh_blend", {}) as Dictionary
	var mesh_blend_vertices: Array = mesh_blend_result.get("vertices", []) as Array
	var direction_preview: Node = editor.get_node("Margin/RootVBox/DirectionScrubPreview") as Node
	var preview_result: Dictionary = direction_preview.call("set_angle_degrees", 45.0) as Dictionary
	var preview_selection: Label = direction_preview.get_node("PreviewSelectionLabel") as Label
	var preview_selection_text := preview_selection.text
	var missing_diagnostics: Node = editor.get_node("Margin/RootVBox/MissingCellDiagnostics") as Node
	var missing_direction_ids: Array = missing_diagnostics.call("get_missing_direction_ids") as Array
	var missing_selected: bool = bool(missing_diagnostics.call("select_missing_direction", 0))
	var selected_missing_direction: String = str(editor.call("get_selected_direction"))
	editor.call("select_direction", "forward")
	var pixel_mode_controls: Node = editor.get_node("Margin/RootVBox/PixelModeControls") as Node
	var pixel_mode_enabled: bool = bool(pixel_mode_controls.call("set_pixel_mode", true))
	var pixel_mode_status: Label = pixel_mode_controls.get_node("PixelModeStatusLabel") as Label
	var pixel_mode_result := FacingGridEvaluatorScript.evaluate(grid, Vector2(1.0, -1.0))
	var statuses: Array = editor.call("get_direction_statuses") as Array
	var invalid_custom: bool = not bool(editor.call("apply_custom_directions_from_text", "only_one"))
	var diagnostics: Array = editor.call("get_diagnostics") as Array
	var buttons: GridContainer = editor.get_node("Margin/RootVBox/DirectionGrid") as GridContainer
	var restored: FacingGridDefinition = FacingGridScript.new().from_dict(grid.to_dict())
	var checks := {
		"standard_sets": four_way_ok and four_way_directions == ["north", "east", "south", "west"] and not grid.cells.has("north_east"),
		"custom_validation": custom_ok and custom_directions == ["forward", "right", "back", "left"] and invalid_custom and not diagnostics.is_empty(),
		"selection_and_status": selected_ok and str(editor.call("get_selected_direction")) == "forward" and statuses.size() == 4 and buttons.get_child_count() == 4,
		"asset_assignment": assigned and str(first_assignment.get("asset_id", "")) == "asset_left" and replaced and str(replacement.get("asset_id", "")) == "asset_left_replaced" and cleared and grid.get_cell("left").is_empty(),
		"slot_swap": swapped and str((swapped_cell.get("slot_swap", {}) as Dictionary).get("weapon", "")) == "hand_right" and str((swapped_cell.get("slot_swap", {}) as Dictionary).get("shield", "")) == "hand_left",
		"mirroring": not bool(overwrite_blocked.get("success", true)) and bool(mirrored.get("success", false)) and str(mirrored_cell.get("asset_id", "")) == "north_asset" and str(mirrored_cell.get("mirrored_from", "")) == "north" and bool(mirrored_cell.get("mirror_x", false)),
		"hard_switch": hard_switch_enabled,
		"sprite_crossfade": crossfade_enabled and crossfade_result.get("mode", "") == "crossfade",
		"mesh_blending": malformed_mesh_rejected and forward_mesh_stored and right_mesh_stored and mesh_blend_enabled and "ready" in mesh_blend_status.text and bool(mesh_blend_result.get("compatible", false)) and mesh_blend_vertices.size() == 2 and (mesh_blend_vertices[0] as Vector2).is_equal_approx(Vector2(1.0, 1.0)) and not bool(incompatible_mesh_blend.get("compatible", true)),
		"direction_preview": preview_result.get("mode", "") == "crossfade" and preview_result.get("primary_direction", "") == "forward" and preview_result.get("secondary_direction", "") == "right" and "crossfade 50%" in preview_selection_text,
		"missing_diagnostics": missing_direction_ids == ["back", "left"] and missing_selected and selected_missing_direction == "back",
		"pixel_no_crossfade": pixel_mode_enabled and grid.pixel_mode and pixel_mode_result.get("mode", "") == "hard_switch" and "forces hard" in pixel_mode_status.text,
		"persistence": restored.get_direction_ids() == custom_directions and restored.pixel_mode and str(restored.get_cell("forward").get("mesh_id", "")) == "body_mesh",
	}
	mirror_dialog.hide()
	editor.queue_free()
	mirror_dialog.queue_free()
	if _all_true(checks):
		print("  PASS: Direction editor changes sets, assigns/replaces/clears cell assets, reports invalid input, and exposes selected cells")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Direction-set editor acceptance failed: %s" % checks]}


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true
