# WorkspaceManager — Manages workspace definitions, switching, layout presets, and state preservation
# Autoload: WorkspaceManager
# Coordinates six integrated workspaces and preserves canvas/viewport/panel state per workspace.
extends Node

## === Signals ================================================================

signal workspace_changed(new_workspace_id: String, old_workspace_id: String)
signal workspace_registered(workspace_id: String, title: String)
signal workspace_state_updated(workspace_id: String)

## === Constants ==============================================================

const WORKSPACE_PROJECT_ASSETS := "project_assets"
const WORKSPACE_CHARACTER_CREATOR := "character_creator"
const WORKSPACE_RIGGING_DEFORMATION := "rigging_deformation"
const WORKSPACE_ANIMATION_STUDIO := "animation_studio"
const WORKSPACE_WEAPON_EQUIPMENT := "weapon_equipment"
const WORKSPACE_PREVIEW_EXPORT := "preview_export"

## === State ==================================================================

var _registered_workspaces: Dictionary = {} # String id -> Dictionary { "id": String, "title": String, "preset": String }
var _workspace_states: Dictionary = {} # String id -> Dictionary state
var _active_workspace_id: String = WORKSPACE_PROJECT_ASSETS
var _dock_layout_manager: Node = null

## === Lifecycle ==============================================================

func _ready() -> void:
	_setup_default_workspaces()

## === Public API =============================================================

func get_active_workspace_id() -> String:
	return _active_workspace_id


func get_active_workspace_title() -> String:
	if _registered_workspaces.has(_active_workspace_id):
		return _registered_workspaces[_active_workspace_id]["title"] as String
	return ""


func get_registered_workspace_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _registered_workspaces:
		result.append(key as String)
	return result


func get_workspace_title(workspace_id: String) -> String:
	if _registered_workspaces.has(workspace_id):
		return _registered_workspaces[workspace_id]["title"] as String
	return ""


func is_workspace_registered(workspace_id: String) -> bool:
	return _registered_workspaces.has(workspace_id)


func register_workspace(workspace_id: String, title: String, default_preset: String = "Default") -> void:
	_registered_workspaces[workspace_id] = {
		"id": workspace_id,
		"title": title,
		"preset": default_preset,
	}
	if not _workspace_states.has(workspace_id):
		_workspace_states[workspace_id] = _create_default_state(default_preset)
	workspace_registered.emit(workspace_id, title)


func bind_dock_layout_manager(mgr: Node) -> void:
	_dock_layout_manager = mgr


func get_dock_layout_manager() -> Node:
	return _dock_layout_manager


func switch_workspace(target_workspace_id: String) -> bool:
	if not _registered_workspaces.has(target_workspace_id):
		if DiagnosticsService != null:
			DiagnosticsService.warn("Attempted switch to unregistered workspace: " + target_workspace_id, "WorkspaceManager")
		return false

	if target_workspace_id == _active_workspace_id:
		return true

	var old_id := _active_workspace_id
	_active_workspace_id = target_workspace_id

	# 1. Update AppState autoload
	if AppState != null and AppState.has_method("set_workspace"):
		AppState.call("set_workspace", target_workspace_id)

	# 2. Apply layout preset to bound DockLayoutManager if present
	var ws_info: Dictionary = _registered_workspaces[target_workspace_id]
	var preset_name: String = ws_info.get("preset", "Default") as String
	if _dock_layout_manager != null and _dock_layout_manager.has_method("apply_preset_by_name"):
		_dock_layout_manager.call("apply_preset_by_name", preset_name)
		_focus_workspace_primary_panel(target_workspace_id)

	# 3. Log workspace switch
	if DiagnosticsService != null:
		DiagnosticsService.info("Switched workspace from '" + old_id + "' to '" + target_workspace_id + "'", "WorkspaceManager")

	workspace_changed.emit(target_workspace_id, old_id)
	return true


func update_workspace_state(workspace_id: String, state_updates: Dictionary) -> bool:
	if not _registered_workspaces.has(workspace_id):
		return false

	if not _workspace_states.has(workspace_id):
		_workspace_states[workspace_id] = {}

	var current_state: Dictionary = _workspace_states[workspace_id]
	for key in state_updates:
		current_state[key] = state_updates[key]

	_workspace_states[workspace_id] = current_state
	workspace_state_updated.emit(workspace_id)
	return true


func get_workspace_state(workspace_id: String) -> Dictionary:
	if _workspace_states.has(workspace_id):
		return (_workspace_states[workspace_id] as Dictionary).duplicate(true)
	return {}


func get_active_workspace_state() -> Dictionary:
	return get_workspace_state(_active_workspace_id)


func export_all_workspace_states() -> Dictionary:
	return {
		"active_workspace": _active_workspace_id,
		"workspace_states": _workspace_states.duplicate(true),
		"registered_workspaces": _registered_workspaces.duplicate(true)
	}


func import_all_workspace_states(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	if data.has("registered_workspaces"):
		var reg: Dictionary = data["registered_workspaces"]
		for wid in reg:
			var info: Dictionary = reg[wid]
			register_workspace(
				wid as String,
				info.get("title", wid) as String,
				info.get("preset", "Default") as String
			)

	if data.has("workspace_states"):
		_workspace_states = (data["workspace_states"] as Dictionary).duplicate(true)

	if data.has("active_workspace"):
		var target_id := data["active_workspace"] as String
		if _registered_workspaces.has(target_id):
			switch_workspace(target_id)

	return true

## === Private Methods ========================================================

func _setup_default_workspaces() -> void:
	register_workspace(WORKSPACE_PROJECT_ASSETS, "Project & Asset Workspace", "Default")
	register_workspace(WORKSPACE_CHARACTER_CREATOR, "Character Creator Workspace", "Character Creator")
	register_workspace(WORKSPACE_RIGGING_DEFORMATION, "Rigging & Deformation Workspace", "Rigging & Deformation")
	register_workspace(WORKSPACE_ANIMATION_STUDIO, "Animation Studio Workspace", "Animation Studio")
	register_workspace(WORKSPACE_WEAPON_EQUIPMENT, "Weapon & Equipment Studio", "Default")
	register_workspace(WORKSPACE_PREVIEW_EXPORT, "Preview & Export Workspace", "Minimal")
	_active_workspace_id = WORKSPACE_PROJECT_ASSETS


func _create_default_state(preset_name: String) -> Dictionary:
	return {
		"zoom_level": 1.0,
		"pan_offset": [0.0, 0.0],
		"playhead_position": 0.0,
		"selected_ids": [],
		"active_tool": "select",
		"layout_preset": preset_name
	}


func _focus_workspace_primary_panel(workspace_id: String) -> void:
	if _dock_layout_manager == null:
		return
	var primary_panel := "panel_viewport"
	match workspace_id:
		WORKSPACE_PROJECT_ASSETS: primary_panel = "panel_project_hub"
		WORKSPACE_CHARACTER_CREATOR: primary_panel = "panel_character_creator"
		WORKSPACE_ANIMATION_STUDIO: primary_panel = "panel_animation_composition"
		WORKSPACE_WEAPON_EQUIPMENT: primary_panel = "panel_weapon_wizard"
		WORKSPACE_PREVIEW_EXPORT:
			_dock_layout_manager.call("set_panel_visible", "panel_batch_export", true)
			_dock_layout_manager.call("set_panel_visible", "panel_quality_dashboard", true)
			primary_panel = "panel_batch_export"
	if _dock_layout_manager.has_method("activate_panel"):
		_dock_layout_manager.call("activate_panel", primary_panel)
