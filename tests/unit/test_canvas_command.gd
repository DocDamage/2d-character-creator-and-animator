# Unit Tests for Canvas and Command System (Milestone 4 — CAN-001 through CAN-012)
extends Node


func run_tests() -> int:
	print("--- Running Canvas & Command System Tests (Milestone 4) ---")
	var pass_count := 0
	
	pass_count += test_canvas_camera()
	pass_count += test_canvas_selection()
	pass_count += test_transform_gizmo()
	pass_count += test_pivot_editor()
	pass_count += test_grid_guides()
	pass_count += test_selection_sets()
	pass_count += test_z_order_editor()
	pass_count += test_tree_operations()
	pass_count += test_command_history()
	pass_count += test_pixel_perfect_canvas()
	
	print("--- Canvas & Command System Tests Finished: %d PASS ---" % pass_count)
	return pass_count


func test_canvas_camera() -> int:
	var passes := 0
	var cam := CanvasCamera.new()
	add_child(cam)
	
	cam.pan(Vector2(50, 100))
	if cam.position == Vector2(50, 100):
		print("  PASS: CanvasCamera pan updated position correctly")
		passes += 1
	
	cam.zoom_at(2.0, Vector2.ZERO)
	if cam.get_zoom_level() == 2.0:
		print("  PASS: CanvasCamera zoom updated scale level correctly")
		passes += 1
	
	cam.reset_view()
	if cam.position == Vector2.ZERO and cam.get_zoom_level() == 1.0:
		print("  PASS: CanvasCamera reset_view restored baseline")
		passes += 1
	
	cam.queue_free()
	return passes


func test_canvas_selection() -> int:
	var passes := 0
	var sel := CanvasSelection.new()
	add_child(sel)
	
	sel.select_single("node_1")
	if sel.get_selected_ids() == ["node_1"]:
		print("  PASS: CanvasSelection select_single selected item")
		passes += 1
	
	sel.toggle_select("node_2")
	if sel.get_selected_ids().size() == 2:
		print("  PASS: CanvasSelection toggle_select appended item")
		passes += 1
	
	var chosen := sel.cycle_overlap_at(Vector2(10, 10), ["node_a", "node_b", "node_c"])
	if chosen == "node_a":
		print("  PASS: CanvasSelection overlap cycling selected first element")
		passes += 1
	
	sel.queue_free()
	return passes


const TransformGizmoScript = preload("res://app/shared_ui/transform_gizmo.gd")


func test_transform_gizmo() -> int:
	var passes := 0
	var gizmo = TransformGizmoScript.new()
	add_child(gizmo)
	
	gizmo.start_drag(TransformGizmoScript.HandleType.POSITION, Vector2(0, 0), Vector2(10, 10), 0.0, Vector2.ONE)
	var updated := gizmo.update_drag(Vector2(20, 30))
	if updated.get("position", Vector2.ZERO) == Vector2(30, 40):
		print("  PASS: TransformGizmo drag translation calculated correct delta")
		passes += 1

	gizmo.start_drag(TransformGizmoScript.HandleType.POSITION, Vector2.ZERO, Vector2(3, 3), 0.0, Vector2.ONE)
	gizmo.update_drag(Vector2(6, 6), 4.0)
	var final_snapped := gizmo.finish_drag(Vector2(6, 6))
	if final_snapped.get("position", Vector2.ZERO) == Vector2(8, 8):
		print("  PASS: TransformGizmo preserves grid snapping when a drag is committed")
		passes += 1
	
	gizmo.queue_free()
	return passes


func test_pivot_editor() -> int:
	var passes := 0
	var norm := PivotEditor.normalize_pivot(Vector2(50, 100), Vector2(100, 200))
	if norm == Vector2(0.5, 0.5):
		print("  PASS: PivotEditor normalize_pivot calculated exact ratios")
		passes += 1
	
	var denorm := PivotEditor.denormalize_pivot(norm, Vector2(100, 200))
	if denorm == Vector2(50, 100):
		print("  PASS: PivotEditor denormalize_pivot restored pixel offsets")
		passes += 1
	
	return passes


func test_grid_guides() -> int:
	var passes := 0
	var gg := CanvasGridGuides.new()
	add_child(gg)
	
	gg.grid_step = Vector2(16, 16)
	gg.snap_to_grid = true
	var snapped := gg.snap_position(Vector2(14, 35))
	if snapped == Vector2(16, 32):
		print("  PASS: CanvasGridGuides snap_position rounded to nearest grid step")
		passes += 1
	
	gg.queue_free()
	return passes


func test_selection_sets() -> int:
	var passes := 0
	var ss := SelectionSets.new()
	add_child(ss)
	
	ss.set_locked("obj_1", true)
	if ss.is_locked("obj_1"):
		print("  PASS: SelectionSets recorded locked object")
		passes += 1
	
	ss.set_solo("obj_2", true)
	if not ss.is_visible("obj_1") and ss.is_visible("obj_2"):
		print("  PASS: SelectionSets solo mode filtered visibility")
		passes += 1
	
	ss.save_selection_set("arm_group", ["obj_1", "obj_2"])
	if ss.get_selection_set("arm_group").size() == 2:
		print("  PASS: SelectionSets saved named selection group")
		passes += 1
	
	ss.queue_free()
	return passes


func test_z_order_editor() -> int:
	var passes := 0
	var objs := [
		{"id": "a", "z_index": 0},
		{"id": "b", "z_index": 1}
	]
	
	var front := ZOrderEditor.move_to_front(objs, "a")
	var a_z := 0
	for item in front:
		if item["id"] == "a":
			a_z = item["z_index"]
	if a_z == 1:
		print("  PASS: ZOrderEditor move_to_front promoted element z-index")
		passes += 1
	
	return passes


func test_tree_operations() -> int:
	var passes := 0
	var root := {
		"id": "bone_root",
		"position": Vector2(10, 10),
		"children": [
			{"id": "bone_child", "parent_id": "bone_root"}
		]
	}
	
	var clone := TreeOperations.clone_subtree(root, "clone")
	if clone["id"] != "bone_root" and clone["children"][0]["parent_id"] == clone["id"]:
		print("  PASS: TreeOperations clone_subtree remapped parent-child IDs")
		passes += 1
	
	return passes


class SimpleCmd extends CommandHistory.Command:
	var target: Array
	var value: String
	func _init(t: Array, v: String) -> void:
		target = t
		value = v
	func execute() -> void:
		target.append(value)
	func undo() -> void:
		target.erase(value)
	func get_name() -> String:
		return "SimpleCmd " + value


func test_command_history() -> int:
	var passes := 0
	var history := CommandHistory.new()
	add_child(history)
	
	var state: Array = []
	var cmd1 := SimpleCmd.new(state, "A")
	history.push_and_execute(cmd1)
	
	if state == ["A"] and history.can_undo():
		print("  PASS: CommandHistory executed command and enabled undo")
		passes += 1
	
	history.undo()
	if state.is_empty() and history.can_redo():
		print("  PASS: CommandHistory undo reverted state and enabled redo")
		passes += 1
	
	history.redo()
	if state == ["A"]:
		print("  PASS: CommandHistory redo reapplied command")
		passes += 1
	
	history.queue_free()
	return passes


func test_pixel_perfect_canvas() -> int:
	var passes := 0
	var ppc := PixelPerfectCanvas.new()
	add_child(ppc)
	
	var snapped := ppc.snap_position(Vector2(12.7, 44.2))
	if snapped == Vector2(13.0, 44.0):
		print("  PASS: PixelPerfectCanvas snapped float positions to integer coords")
		passes += 1
	
	if ppc.should_show_pixel_grid(5.0) and not ppc.should_show_pixel_grid(2.0):
		print("  PASS: PixelPerfectCanvas thresholded pixel grid overlay by zoom")
		passes += 1
	
	ppc.queue_free()
	return passes
