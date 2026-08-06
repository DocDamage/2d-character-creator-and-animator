# WorkspaceNavigation — Figma-style top-level mode switcher for the editor shell.
class_name WorkspaceNavigation
extends HBoxContainer

const ACTIVE_BACKGROUND := Color("#8240f5")
const ACTIVE_BORDER := Color("#ad73ff")
const IDLE_BACKGROUND := Color("#161921")
const IDLE_BORDER := Color("#292e3b")
const IDLE_TEXT := Color("#8f9cb2")

@export var project_context_path: NodePath

var _button_workspace_ids := {
	"ProjectButton": "project_assets",
	"CreateButton": "character_creator",
	"RigButton": "rigging_deformation",
	"AnimateButton": "animation_studio",
	"WeaponButton": "weapon_equipment",
	"ExportButton": "preview_export",
}


func _ready() -> void:
	for button_name in _button_workspace_ids:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button != null:
			button.pressed.connect(_switch_workspace.bind(_button_workspace_ids[button_name] as String))
	if WorkspaceManager != null and WorkspaceManager.has_signal("workspace_changed"):
		if not WorkspaceManager.workspace_changed.is_connected(_on_workspace_changed):
			WorkspaceManager.workspace_changed.connect(_on_workspace_changed)
	call_deferred("_sync_active_workspace")


func _switch_workspace(workspace_id: String) -> void:
	if WorkspaceManager != null:
		WorkspaceManager.call("switch_workspace", workspace_id)


func _on_workspace_changed(workspace_id: String, _previous_workspace_id: String) -> void:
	_set_active_button(workspace_id)


func _sync_active_workspace() -> void:
	if WorkspaceManager != null:
		_set_active_button(WorkspaceManager.call("get_active_workspace_id") as String)


func _set_active_button(active_workspace_id: String) -> void:
	for button_name in _button_workspace_ids:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button == null:
			continue
		var is_active: bool = String(_button_workspace_ids[button_name]) == active_workspace_id
		_apply_button_style(button, is_active)
	_update_project_context(active_workspace_id)


func _apply_button_style(button: Button, is_active: bool) -> void:
	var background := ACTIVE_BACKGROUND if is_active else IDLE_BACKGROUND
	var border := ACTIVE_BORDER if is_active else IDLE_BORDER
	var text_color := Color.WHITE if is_active else IDLE_TEXT
	button.add_theme_stylebox_override("normal", _make_box(background, border))
	button.add_theme_stylebox_override("hover", _make_box(background.lightened(0.08), border))
	button.add_theme_stylebox_override("pressed", _make_box(background.darkened(0.16), border))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _update_project_context(workspace_id: String) -> void:
	var context := get_node_or_null(project_context_path) as Label
	if context == null:
		return
	var details := {
		"project_assets": "Project dashboard",
		"character_creator": "Character creator",
		"rigging_deformation": "Rigging & deformation",
		"animation_studio": "Animation studio",
		"weapon_equipment": "Weapon & equipment",
		"preview_export": "Preview & export",
	}
	context.text = details.get(workspace_id, "Project dashboard") as String


func _make_box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box
