# Test Workspace Manager — Unit test suite for WorkspaceManager service
# Tests workspace registration, switching, state preservation, undo stack survival, and layout binding.
class_name TestWorkspaceManager
extends RefCounted

const WorkspaceManagerScript = preload("res://app/workspaces/workspace_manager.gd")
const DockLayoutManagerScript = preload("res://app/shared_ui/dock_layout_manager.gd")

var passes: int = 0
var fails: int = 0

func run_all_tests() -> Dictionary:
	passes = 0
	fails = 0

	test_default_workspaces_registered()
	test_workspace_switching_and_signals()
	test_state_preservation_per_workspace()
	test_undo_stack_preservation_across_switches()
	test_dock_layout_manager_binding()
	test_export_import_serialization()
	test_invalid_workspace_switch_safety()

	return {"passes": passes, "fails": fails}


func test_default_workspaces_registered() -> void:
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()

	var ids := mgr.get_registered_workspace_ids()
	_assert(ids.size() == 6, "WorkspaceManager registers 6 default workspaces")
	_assert(mgr.is_workspace_registered("project_assets"), "project_assets workspace registered")
	_assert(mgr.is_workspace_registered("character_creator"), "character_creator workspace registered")
	_assert(mgr.is_workspace_registered("rigging_deformation"), "rigging_deformation workspace registered")
	_assert(mgr.is_workspace_registered("animation_studio"), "animation_studio workspace registered")
	_assert(mgr.is_workspace_registered("weapon_equipment"), "weapon_equipment workspace registered")
	_assert(mgr.is_workspace_registered("preview_export"), "preview_export workspace registered")
	_assert(mgr.get_active_workspace_id() == "project_assets", "Default active workspace is project_assets")
	mgr.free()


func test_workspace_switching_and_signals() -> void:
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()

	var emitted := {"flag": false, "new_id": "", "old_id": ""}
	mgr.workspace_changed.connect(func(new_id: String, old_id: String):
		emitted["flag"] = true
		emitted["new_id"] = new_id
		emitted["old_id"] = old_id
	)

	var success := mgr.switch_workspace("animation_studio")
	_assert(success, "switch_workspace returns true for valid target")
	_assert(mgr.get_active_workspace_id() == "animation_studio", "Active workspace updated to animation_studio")
	_assert(emitted["flag"] as bool, "workspace_changed signal emitted on switch")
	_assert((emitted["new_id"] as String) == "animation_studio", "Signal reported new_id animation_studio")
	_assert((emitted["old_id"] as String) == "project_assets", "Signal reported old_id project_assets")
	mgr.free()


func test_state_preservation_per_workspace() -> void:
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()

	# Set state in project_assets
	mgr.update_workspace_state("project_assets", {"zoom_level": 2.5, "active_tool": "zoom"})
	var pa_state := mgr.get_workspace_state("project_assets")
	_assert(pa_state.get("zoom_level") == 2.5, "project_assets zoom level stored")

	# Switch to character_creator and set different state
	mgr.switch_workspace("character_creator")
	mgr.update_workspace_state("character_creator", {"zoom_level": 1.2, "active_tool": "color_picker"})

	# Verify states remain separate & preserved
	var cc_state := mgr.get_workspace_state("character_creator")
	pa_state = mgr.get_workspace_state("project_assets")
	_assert(cc_state.get("zoom_level") == 1.2, "character_creator zoom level preserved independently")
	_assert(pa_state.get("zoom_level") == 2.5, "project_assets zoom level preserved after switch")
	mgr.free()


func test_undo_stack_preservation_across_switches() -> void:
	if CommandService == null:
		_assert(true, "Skipped CommandService test (autoload unavailable)")
		return

	CommandService.clear_history()

	# Create a target object to receive command calls
	var test_target := Node.new()
	test_target.name = "TestTargetNode"

	# Execute test command
	var do_cmd := {"target": test_target, "method": "set_name", "args": ["RenamedTarget"]}
	var undo_cmd := {"target": test_target, "method": "set_name", "args": ["TestTargetNode"]}
	CommandService.execute(do_cmd, undo_cmd, "Rename Node")

	_assert(CommandService.can_undo(), "Command executed and added to undo stack")
	var count_before_switch := CommandService.get_undo_count()

	# Instantiate WorkspaceManager and switch workspace
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()
	mgr.switch_workspace("rigging_deformation")

	# Verify undo stack survived intact
	_assert(CommandService.can_undo(), "CommandService undo stack survives workspace switch")
	_assert(CommandService.get_undo_count() == count_before_switch, "Undo count unchanged after workspace switch")

	# Execute undo
	var undo_success := CommandService.undo()
	_assert(undo_success, "Undo succeeds after workspace switch")

	test_target.free()
	mgr.free()


func test_dock_layout_manager_binding() -> void:
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()
	var layout_mgr := DockLayoutManagerScript.new()

	mgr.bind_dock_layout_manager(layout_mgr)
	_assert(mgr.get_dock_layout_manager() == layout_mgr, "DockLayoutManager bound successfully")

	mgr.switch_workspace("character_creator")
	_assert(layout_mgr.get_active_preset_name() == DockLayoutManagerScript.PRESET_CHARACTER_CREATOR, "Character Creator preset applied on workspace switch")

	mgr.switch_workspace("preview_export")
	_assert(layout_mgr.get_active_preset_name() == DockLayoutManagerScript.PRESET_MINIMAL, "Minimal preset applied on preview_export switch")

	layout_mgr.free()
	mgr.free()


func test_export_import_serialization() -> void:
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()
	mgr.switch_workspace("animation_studio")
	mgr.update_workspace_state("animation_studio", {"playhead_position": 4.2})

	var exported := mgr.export_all_workspace_states()
	_assert(exported.has("active_workspace"), "Export contains active_workspace")
	_assert(exported["active_workspace"] == "animation_studio", "Export active workspace is animation_studio")

	var mgr2 := WorkspaceManagerScript.new()
	mgr2._ready()
	var imported := mgr2.import_all_workspace_states(exported)
	_assert(imported, "import_all_workspace_states returns true")
	_assert(mgr2.get_active_workspace_id() == "animation_studio", "Imported active workspace matches exported")
	_assert(mgr2.get_workspace_state("animation_studio").get("playhead_position") == 4.2, "Imported state matches exported playhead position")

	mgr.free()
	mgr2.free()


func test_invalid_workspace_switch_safety() -> void:
	var mgr := WorkspaceManagerScript.new()
	mgr._ready()
	var initial_id := mgr.get_active_workspace_id()

	var success := mgr.switch_workspace("non_existent_workspace")
	_assert(not success, "switch_workspace returns false for invalid workspace ID")
	_assert(mgr.get_active_workspace_id() == initial_id, "Active workspace unchanged after failed switch")
	mgr.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  PASS: " + message)
	else:
		fails += 1
		print("  FAIL: " + message)
