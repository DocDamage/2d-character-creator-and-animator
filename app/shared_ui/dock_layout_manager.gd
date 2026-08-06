# Dock Layout Manager — Manages dockable panel registration, layouts, and presets
# Handles split panel containers, preset persistence, and panel visibility states.
class_name DockLayoutManager
extends Node

signal layout_changed(preset_name: String)
signal panel_visibility_changed(panel_id: String, is_visible: bool)

const DockPanelScript = preload("res://app/shared_ui/dock_panel.gd")

const PRESET_DEFAULT := "Default"
const PRESET_CHARACTER_CREATOR := "Character Creator"
const PRESET_RIGGING := "Rigging & Deformation"
const PRESET_ANIMATION := "Animation Studio"
const PRESET_MINIMAL := "Minimal"

var _panels: Dictionary = {} # String panel_id -> DockPanel
var _dock_containers: Dictionary = {} # String region ("LEFT", "RIGHT", etc) -> Control container
var _split_containers: Array[SplitContainer] = []
var _active_preset: String = PRESET_DEFAULT

func register_dock_region(region: String, container_node: Control) -> void:
	if container_node != null:
		_dock_containers[region.to_upper()] = container_node

func register_split_container(split_node: SplitContainer) -> void:
	if split_node != null and not _split_containers.has(split_node):
		_split_containers.append(split_node)

func register_panel(panel: Control, target_region: String = "LEFT") -> void:
	if panel == null:
		return
	var pid: String = panel.get("panel_id") if "panel_id" in panel else panel.name
	_panels[pid] = panel

	var region_key := target_region.to_upper()
	if _dock_containers.has(region_key):
		var target_container: Control = _dock_containers[region_key]
		if panel.get_parent() != target_container:
			if panel.get_parent() != null:
				panel.get_parent().remove_child(panel)
			target_container.add_child(panel)
			if target_container is TabContainer:
				var tabs := target_container as TabContainer
				tabs.set_tab_title(tabs.get_tab_count() - 1, panel.get("panel_title") as String)

	if panel.has_signal("dock_region_changed"):
		if not panel.dock_region_changed.is_connected(_on_panel_region_changed):
			panel.dock_region_changed.connect(_on_panel_region_changed)

func get_panel(panel_id: String) -> Control:
	return _panels.get(panel_id, null) as Control

func get_registered_panels() -> Array:
	var result: Array = []
	for key in _panels:
		var p := _panels[key] as Control
		if p != null:
			result.append(p)
	return result

func set_panel_visible(panel_id: String, is_visible: bool) -> void:
	if _panels.has(panel_id):
		var p := _panels[panel_id] as Control
		if p != null:
			p.visible = is_visible
			panel_visibility_changed.emit(panel_id, is_visible)


func activate_panel(panel_id: String) -> bool:
	var panel := get_panel(panel_id)
	if panel == null or not panel.get_parent() is TabContainer:
		return false
	var tabs := panel.get_parent() as TabContainer
	tabs.current_tab = panel.get_index()
	return true

func get_active_preset_name() -> String:
	return _active_preset

func apply_preset_by_name(preset_name: String) -> bool:
	match preset_name:
		PRESET_DEFAULT:
			_apply_default_preset()
		PRESET_CHARACTER_CREATOR:
			_apply_character_creator_preset()
		PRESET_RIGGING:
			_apply_rigging_preset()
		PRESET_ANIMATION:
			_apply_animation_preset()
		PRESET_MINIMAL:
			_apply_minimal_preset()
		_:
			return false

	_active_preset = preset_name
	layout_changed.emit(_active_preset)
	return true

func export_layout_preset() -> Dictionary:
	var panels_state: Dictionary = {}
	for pid in _panels:
		var p := _panels[pid] as Control
		if p != null and p.has_method("serialize_state"):
			panels_state[pid] = p.call("serialize_state")

	var split_offsets: Array[int] = []
	for split in _split_containers:
		if split != null:
			split_offsets.append(split.split_offset)

	return {
		"preset_name": _active_preset,
		"panels": panels_state,
		"split_offsets": split_offsets
	}

func import_layout_preset(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	if data.has("preset_name"):
		_active_preset = data["preset_name"] as String

	if data.has("panels"):
		var p_dict: Dictionary = data["panels"] as Dictionary
		for pid in p_dict:
			if _panels.has(pid):
				var p := _panels[pid] as Control
				if p != null and p.has_method("deserialize_state"):
					p.call("deserialize_state", p_dict[pid] as Dictionary)

	if data.has("split_offsets"):
		var offsets: Array = data["split_offsets"] as Array
		for i in range(min(offsets.size(), _split_containers.size())):
			if _split_containers[i] != null:
				_split_containers[i].split_offset = offsets[i] as int

	layout_changed.emit(_active_preset)
	return true

func _on_panel_region_changed(panel_id: String, new_region: String) -> void:
	if _panels.has(panel_id):
		var p := _panels[panel_id] as Control
		if p != null and _dock_containers.has(new_region):
			var target_container: Control = _dock_containers[new_region]
			if p.get_parent() != target_container:
				if p.get_parent() != null:
					p.get_parent().remove_child(p)
				target_container.add_child(p)

func _apply_default_preset() -> void:
	for pid in _panels:
		set_panel_visible(pid, true)
	activate_panel("panel_project_hub")

func _apply_character_creator_preset() -> void:
	for pid in _panels:
		var is_cc: bool = pid.contains("asset") or pid.contains("part") or pid.contains("character") or pid.contains("viewport") or pid.contains("inspector")
		set_panel_visible(pid, is_cc or pid == "panel_viewport" or pid == "panel_assets" or pid == "panel_inspector")
	activate_panel("panel_character_creator")

func _apply_rigging_preset() -> void:
	for pid in _panels:
		var is_rig: bool = pid in ["panel_hierarchy", "panel_pose_library", "panel_retarget_preview", "panel_viewport", "panel_inspector"]
		set_panel_visible(pid, is_rig)
	activate_panel("panel_viewport")

func _apply_animation_preset() -> void:
	for pid in _panels:
		var is_animation: bool = pid in ["panel_hierarchy", "panel_viewport", "panel_facing_grid", "panel_media_authoring", "panel_animation_composition", "panel_inspector", "panel_timeline", "panel_diagnostics"]
		set_panel_visible(pid, is_animation)
	activate_panel("panel_animation_composition")

func _apply_minimal_preset() -> void:
	for pid in _panels:
		var is_min: bool = (pid == "panel_viewport")
		set_panel_visible(pid, is_min)
	activate_panel("panel_viewport")
