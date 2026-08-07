# WorkspaceNavigation — persistent Paper Quest workspace tabs.
class_name WorkspaceNavigation
extends HBoxContainer

@export var project_context_path: NodePath

const WORKSPACES := {
	"ProjectButton": {"id": "project_assets", "variation": &"WorkspaceTabProject", "hint": "Project hub and asset health"},
	"CreateButton": {"id": "character_creator", "variation": &"WorkspaceTabCreate", "hint": "Build a modular character"},
	"RigButton": {"id": "rigging_deformation", "variation": &"WorkspaceTabRig", "hint": "Rig, constrain, and deform"},
	"AnimateButton": {"id": "animation_studio", "variation": &"WorkspaceTabAnimate", "hint": "Animate clips and state logic"},
	"WeaponButton": {"id": "weapon_equipment", "variation": &"WorkspaceTabWeapon", "hint": "Author weapons and grip poses"},
	"ExportButton": {"id": "preview_export", "variation": &"WorkspaceTabExport", "hint": "Validate, preview, and export"},
}

var _overflow_button: MenuButton
var _workspace_ids_by_menu_id: Dictionary = {}
var _compact_mode := false

func _ready() -> void:
	for button_name in WORKSPACES:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button == null:
			continue
		button.custom_minimum_size = Vector2(112, 48)
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.tooltip_text = WORKSPACES[button_name]["hint"] as String
		button.pressed.connect(_switch_workspace.bind(WORKSPACES[button_name]["id"] as String))
	if WorkspaceManager != null and WorkspaceManager.has_signal("workspace_changed"):
		if not WorkspaceManager.workspace_changed.is_connected(_on_workspace_changed):
			WorkspaceManager.workspace_changed.connect(_on_workspace_changed)
	_build_overflow_menu()
	resized.connect(_apply_responsive_navigation)
	get_viewport().size_changed.connect(_apply_responsive_navigation)
	call_deferred("_sync_active_workspace")
	call_deferred("_apply_responsive_navigation")

func _switch_workspace(workspace_id: String) -> void:
	if WorkspaceManager != null:
		WorkspaceManager.call("switch_workspace", workspace_id)
		_set_active_button(workspace_id)

func _on_workspace_changed(workspace_id: String, _previous_workspace_id: String) -> void:
	_set_active_button(workspace_id)

func _sync_active_workspace() -> void:
	if WorkspaceManager != null:
		_set_active_button(WorkspaceManager.call("get_active_workspace_id") as String)

func _set_active_button(active_workspace_id: String) -> void:
	for button_name in WORKSPACES:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button == null:
			continue
		var info: Dictionary = WORKSPACES[button_name]
		var active := String(info["id"]) == active_workspace_id
		button.theme_type_variation = info["variation"] as StringName if active else &"WorkspaceTab"
		button.set_pressed_no_signal(active)
	_update_project_context(active_workspace_id)
	_apply_responsive_navigation()

func _update_project_context(workspace_id: String) -> void:
	var context := get_node_or_null(project_context_path) as Label
	if context == null:
		return
	context.text = {
		"project_assets": "Project play hub",
		"character_creator": "Build your hero",
		"rigging_deformation": "Rig workspace",
		"animation_studio": "Animation studio",
		"weapon_equipment": "Weapon studio",
		"preview_export": "Export workshop",
	}.get(workspace_id, "Project play hub") as String


func get_compact_state() -> Dictionary:
	var hidden: Array[String] = []
	for button_name in WORKSPACES:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button != null and not button.visible: hidden.append(button_name)
	return {"compact": _compact_mode, "hidden_buttons": hidden, "overflow_visible": _overflow_button != null and _overflow_button.visible}


func _build_overflow_menu() -> void:
	_overflow_button = MenuButton.new()
	_overflow_button.name = "WorkspaceOverflowMenu"
	_overflow_button.text = "More"
	_overflow_button.tooltip_text = "More workspaces"
	_overflow_button.custom_minimum_size = Vector2(72, 48)
	_overflow_button.focus_mode = Control.FOCUS_ALL
	add_child(_overflow_button)
	var popup := _overflow_button.get_popup()
	var index := 0
	for button_name in WORKSPACES:
		var info: Dictionary = WORKSPACES[button_name]
		popup.add_item(String(button_name).trim_suffix("Button"), index)
		_workspace_ids_by_menu_id[index] = str(info["id"])
		index += 1
	popup.id_pressed.connect(func(menu_id: int): if _workspace_ids_by_menu_id.has(menu_id): _switch_workspace(str(_workspace_ids_by_menu_id[menu_id])))


func _apply_responsive_navigation() -> void:
	apply_responsive_navigation_for_width(get_viewport_rect().size.x)


func apply_responsive_navigation_for_width(viewport_width: float, dpi_scale: float = -1.0) -> Dictionary:
	if _overflow_button == null: return {}
	var scale := dpi_scale if dpi_scale > 0.0 else (ThemeService.get_dpi_scale() if ThemeService != null else 1.0)
	var width := viewport_width / maxf(1.0, scale)
	var active_id := WorkspaceManager.get_active_workspace_id() if WorkspaceManager != null else "project_assets"
	var visible_ids: Array[String] = []
	if width <= 1320.0:
		visible_ids = ["project_assets", "character_creator", active_id]
	elif width <= 1510.0:
		visible_ids = ["project_assets", "character_creator", "rigging_deformation", active_id]
	elif width <= 1710.0:
		visible_ids = ["project_assets", "character_creator", "rigging_deformation", "animation_studio", active_id]
	else:
		for info in WORKSPACES.values(): visible_ids.append(str((info as Dictionary)["id"]))
	visible_ids = _unique_ids(visible_ids)
	_compact_mode = visible_ids.size() < WORKSPACES.size()
	for button_name in WORKSPACES:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button != null:
			var is_visible := str((WORKSPACES[button_name] as Dictionary)["id"]) in visible_ids
			button.visible = is_visible
			button.custom_minimum_size = Vector2(86, 44) if _compact_mode else Vector2(112, 48)
	_overflow_button.visible = _compact_mode
	return get_compact_state()


func _unique_ids(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value not in result: result.append(value)
	return result
