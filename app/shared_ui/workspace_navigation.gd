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
	call_deferred("_sync_active_workspace")

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
