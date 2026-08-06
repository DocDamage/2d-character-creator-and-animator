# Unit test for MainWindow, DockLayoutManager, and DockPanel layout system
# Validates REQ-APP-002 requirements under engine runtime.
extends Node

const MAIN_WINDOW_SCENE_PATH := "res://app/shared_ui/main_window.tscn"
const MainWindowScript = preload("res://app/shared_ui/main_window.gd")
const DockLayoutManagerScript = preload("res://app/shared_ui/dock_layout_manager.gd")
const DockPanelScript = preload("res://app/shared_ui/dock_panel.gd")
const BlendStackScript = preload("res://animation/blending/animation_blend_stack.gd")
const StateMachineModelScript = preload("res://animation/state_machine/state_machine_authoring_model.gd")
const RuleGraphModelScript = preload("res://animation/rules/rule_graph_authoring_model.gd")

func run_tests() -> Dictionary:
	var results := {"passed": 0, "failed": 0, "errors": []}

	print("[TEST 6] Main window instantiation & dock layout management...")

	var mw_packed := ResourceLoader.load(MAIN_WINDOW_SCENE_PATH) as PackedScene
	if mw_packed == null:
		results["failed"] += 1
		results["errors"].append("Failed to load MainWindow scene from: " + MAIN_WINDOW_SCENE_PATH)
		return results

	var mw_node: Node = mw_packed.instantiate()
	if mw_node == null:
		results["failed"] += 1
		results["errors"].append("Failed to instantiate MainWindow scene node.")
		return results

	add_child(mw_node)

	# 1. Test DockLayoutManager and registered panels
	var layout_mgr: Node = mw_node.call("get_dock_layout_manager")
	if layout_mgr == null:
		results["failed"] += 1
		results["errors"].append("MainWindow missing DockLayoutManager node.")
		mw_node.queue_free()
		return results

	var panels: Array = layout_mgr.call("get_registered_panels")
	var left_tabs := mw_node.get_node_or_null("RootVBox/MainHSplit/LeftDockRegion") as TabContainer
	var center_tabs := mw_node.get_node_or_null("RootVBox/MainHSplit/CenterVSplit/InnerHSplit/CenterDockRegion") as TabContainer
	var right_tabs := mw_node.get_node_or_null("RootVBox/MainHSplit/CenterVSplit/InnerHSplit/RightDockRegion") as TabContainer
	var bottom_tabs := mw_node.get_node_or_null("RootVBox/MainHSplit/CenterVSplit/BottomDockRegion") as TabContainer
	var tabs_ready := left_tabs != null and center_tabs != null and right_tabs != null and bottom_tabs != null
	if panels.size() >= 6 and tabs_ready and center_tabs.get_tab_title(0) == "2D Canvas Viewport":
		print("  PASS: DockLayoutManager registered %d panels in labeled tab regions." % panels.size())
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Expected tabbed dock regions with >= 6 panels, found %d." % panels.size())

	# 2. Test specific panel retrieval and state manipulation
	var p_assets: Control = mw_node.call("get_panel", "panel_assets")
	if p_assets != null and p_assets.call("get_panel_id") == "panel_assets":
		print("  PASS: Retrieved DockPanel 'panel_assets' successfully.")
		results["passed"] += 1

		# Test collapse operation
		var initial_collapse: bool = p_assets.call("is_collapsed")
		p_assets.call("toggle_collapse")
		var new_collapse: bool = p_assets.call("is_collapsed")
		if new_collapse != initial_collapse:
			print("  PASS: DockPanel toggle_collapse operates correctly.")
			results["passed"] += 1
			p_assets.call("toggle_collapse") # restore
		else:
			results["failed"] += 1
			results["errors"].append("DockPanel collapse state did not toggle.")
	else:
		results["failed"] += 1
		results["errors"].append("Failed to retrieve panel 'panel_assets'.")

	# 2b. Verify the FAC-002 editor is reachable through the application shell.
	var p_facing: Control = mw_node.call("get_panel", "panel_facing_grid") as Control
	var direction_editor: Control = null
	if p_facing != null and p_facing.has_method("get_content_container"):
		direction_editor = p_facing.call("get_content_container").get_node_or_null("FacingDirectionSetEditor") as Control
	if direction_editor != null and direction_editor.has_method("set_direction_set"):
		print("  PASS: Facing Grid Directions dock exposes the direction-set editor.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Facing Grid Directions dock does not expose the direction-set editor.")

	# 2c. Verify a rig can reach the POS-002 capture/apply controls through the shell.
	var p_poses: Control = mw_node.call("get_panel", "panel_pose_library") as Control
	var pose_editor: Control = p_poses.call("get_content_container").get_node_or_null("PoseLibraryPanel") as Control if p_poses != null else null
	var pose_rig := {"id": "dock_rig", "bones": {"root": {"local_position": Vector2(6, 2), "local_rotation": 0.0, "local_scale": Vector2.ONE}}}
	if pose_editor != null:
		mw_node.call("bind_pose_rig", pose_rig)
		(pose_editor.get_node("Form/PoseIdInput") as LineEdit).text = "dock_idle"
		var captured_pose: Dictionary = pose_editor.call("capture_current_pose")
		pose_rig["bones"]["root"]["local_position"] = Vector2.ZERO
		var applied_pose: Dictionary = pose_editor.call("apply_pose", "dock_idle")
		if captured_pose.get("success", false) and applied_pose.get("success", false) and pose_rig["bones"]["root"]["local_position"] == Vector2(6, 2):
			print("  PASS: Saved Poses dock captures and applies the bound rig.")
			results["passed"] += 1
		else:
			results["failed"] += 1
			results["errors"].append("Saved Poses dock did not capture and apply the bound rig.")
	else:
		results["failed"] += 1
		results["errors"].append("Saved Poses dock does not expose pose controls.")

	# 2d. Verify the WPA-001 wizard is reachable from the weapon workspace dock.
	var p_wizard: Control = mw_node.call("get_panel", "panel_weapon_wizard") as Control
	var wizard: Control = p_wizard.call("get_content_container").get_node_or_null("WeaponAuthoringWizard") as Control if p_wizard != null else null
	if wizard != null and wizard.has_method("run_coverage"):
		print("  PASS: Weapon Authoring Wizard dock exposes coverage controls.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Weapon Authoring Wizard dock does not expose coverage controls.")
	# 2e. Verify the CHR-015 creator dock is reachable and keyboard focusable.
	var p_creator: Control = mw_node.call("get_panel", "panel_character_creator") as Control
	var creator: Control = p_creator.call("get_content_container").get_node_or_null("CharacterCreatorPanel") as Control if p_creator != null else null
	var creator_search: LineEdit = creator.get_node_or_null("Margin/Root/Search") as LineEdit if creator != null else null
	layout_mgr.call("apply_preset_by_name", DockLayoutManagerScript.PRESET_CHARACTER_CREATOR)
	var creator_tab_is_active := center_tabs.current_tab == p_creator.get_index() if center_tabs != null and p_creator != null else false
	if creator != null and creator.has_method("bind_context") and creator_search != null and creator_search.focus_mode == Control.FOCUS_ALL and creator_tab_is_active:
		print("  PASS: Character Creator dock exposes focusable part-browsing controls in its workspace tab.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Character Creator dock does not expose focusable controls in its workspace tab.")
	# 2f. Verify the MED authoring panel is exposed through the application shell.
	var p_media: Control = mw_node.call("get_panel", "panel_media_authoring") as Control
	var media: Control = p_media.call("get_content_container").get_node_or_null("MediaAuthoringPanel") as Control if p_media != null else null
	var media_time: SpinBox = media.get_node_or_null("Margin/Root/Controls/Time") as SpinBox if media != null else null
	if media != null and media.has_method("bind_context") and media_time != null and media_time.focus_mode == Control.FOCUS_ALL:
		print("  PASS: Media Authoring dock exposes focusable timeline inspection controls.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Media Authoring dock does not expose focusable timeline inspection controls.")
	# 2g. Verify Phase 5 composition authoring is reachable through the animation workspace dock.
	var p_composition: Control = mw_node.call("get_panel", "panel_animation_composition") as Control
	var composition: Control = p_composition.call("get_content_container").get_node_or_null("AnimationCompositionPanel") as Control if p_composition != null else null
	var composition_time: SpinBox = composition.get_node_or_null("Margin/Root/Controls/Time") as SpinBox if composition != null else null
	var blend = BlendStackScript.new("dock_blend")
	blend.add_layer("upper", "aim", "override", 1.0, ["arm_r"])
	var state_model = StateMachineModelScript.new()
	state_model.create("dock_states", "Dock States")
	state_model.add_state("idle", "idle", "Idle", Vector2.ZERO)
	state_model.add_state("aim", "aim", "Aim", Vector2(180.0, 0.0))
	state_model.connect_states("to_aim", "idle", "aim")
	var rule_model = RuleGraphModelScript.new()
	rule_model.create("dock_rules", "Dock Rules")
	rule_model.add_time_window_rule("window", 0.0, 1.0, [{"type": "trigger_event", "target": "preview"}], 0, Vector2(360.0, 0.0))
	mw_node.call("bind_animation_composition_context", blend, state_model, rule_model)
	var composition_graph: GraphEdit = composition.get_node_or_null("Margin/Root/Graph") as GraphEdit if composition != null else null
	var composition_nodes := 0
	if composition_graph != null:
		for graph_child in composition_graph.get_children():
			if graph_child is GraphNode: composition_nodes += 1
	if composition != null and composition.has_method("bind_context") and composition_time != null and composition_time.focus_mode == Control.FOCUS_ALL and composition_nodes == 3:
		print("  PASS: Animation Composition dock exposes focusable visual composition controls.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Animation Composition dock does not expose focusable visual composition controls.")
	# 2h. Verify Phase 6 batch export controls are reachable through the shell.
	var p_batch: Control = mw_node.call("get_panel", "panel_batch_export") as Control
	var batch: Control = p_batch.call("get_content_container").get_node_or_null("BatchExportPanel") as Control if p_batch != null else null
	var batch_id: LineEdit = batch.get_node_or_null("Margin/Root/Queue/VariantId") as LineEdit if batch != null else null
	if batch != null and batch.has_method("bind_context") and batch_id != null and batch_id.focus_mode == Control.FOCUS_ALL:
		print("  PASS: Batch Export dock exposes focusable variant export controls.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Batch Export dock does not expose focusable variant export controls.")
	# 2i. Verify reliability controls are visible and keyboard reachable.
	var p_quality: Control = mw_node.call("get_panel", "panel_quality_dashboard") as Control
	var quality: Control = p_quality.call("get_content_container").get_node_or_null("QualityDashboardPanel") as Control if p_quality != null else null
	var quality_path: LineEdit = quality.get_node_or_null("Margin/Root/ProjectPath") as LineEdit if quality != null else null
	if quality != null and quality.has_method("bind_project_path") and quality_path != null and quality_path.focus_mode == Control.FOCUS_ALL:
		print("  PASS: Quality & Recovery dock exposes focusable reliability controls.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Quality & Recovery dock does not expose focusable controls.")

	# 3. Test layout preset switching
	var initial_preset: String = layout_mgr.call("get_active_preset_name")
	mw_node.call("select_workspace_preset", DockLayoutManagerScript.PRESET_MINIMAL)
	if layout_mgr.call("get_active_preset_name") == DockLayoutManagerScript.PRESET_MINIMAL:
		print("  PASS: Applied preset '%s' successfully." % DockLayoutManagerScript.PRESET_MINIMAL)
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Failed to apply preset '%s'." % DockLayoutManagerScript.PRESET_MINIMAL)

	# Restore default preset
	mw_node.call("select_workspace_preset", DockLayoutManagerScript.PRESET_DEFAULT)

	# 4. Test preset serialization round trip
	var exported_preset: Dictionary = layout_mgr.call("export_layout_preset")
	if exported_preset.has("preset_name") and exported_preset.has("panels"):
		print("  PASS: Exported layout preset dictionary successfully.")
		results["passed"] += 1
		var imported_ok: bool = layout_mgr.call("import_layout_preset", exported_preset)
		if imported_ok:
			print("  PASS: Imported layout preset dictionary successfully.")
			results["passed"] += 1
		else:
			results["failed"] += 1
			results["errors"].append("Failed to import exported layout preset dictionary.")
	else:
		results["failed"] += 1
		results["errors"].append("Exported layout preset missing required fields.")

	# 5. Test status bar update
	mw_node.call("set_status_message", "Test Status Message 123")
	if mw_node.call("get_status_message") == "Test Status Message 123":
		print("  PASS: Status bar message updated and verified.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Status bar message did not update.")

	mw_node.queue_free()
	return results
