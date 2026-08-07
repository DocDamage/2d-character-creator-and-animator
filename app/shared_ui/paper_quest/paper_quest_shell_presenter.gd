class_name PaperQuestShellPresenter
extends Node

@onready var _chip: PaperQuestStatusChip = get_node("../RootVBox/StatusBar/StatusHBox/SystemStateChip")
@onready var _project_label: Label = get_node("../RootVBox/StatusBar/StatusHBox/StatusProjectLabel")
@onready var _workspace_label: Label = get_node("../RootVBox/StatusBar/StatusHBox/StatusWorkspaceLabel")
@onready var _appearance_label: Label = get_node("../RootVBox/StatusBar/StatusHBox/StatusInfoLabel")
@onready var _texture: TextureRect = get_node("../RootTexture")
@onready var _appearance_picker: OptionButton = get_node("../RootVBox/TopHeaderBar/MoreButton")
@onready var _help_button: Button = get_node("../RootVBox/TopHeaderBar/HelpButton")
@onready var _brand_button: Button = get_node("../RootVBox/TopHeaderBar/BrandMark")

func _ready() -> void:
	if ThemeService != null:
		(get_parent() as Control).theme = ThemeService.get_current_theme()
	_setup_appearance_picker()
	_appearance_picker.item_selected.connect(_select_appearance)
	_help_button.pressed.connect(_show_help)
	_brand_button.pressed.connect(_open_project_hub)
	if AppState != null:
		AppState.project_opened.connect(func(_path): _refresh())
		AppState.project_closed.connect(_refresh)
		AppState.dirty_state_changed.connect(func(_dirty): _refresh())
	if WorkspaceManager != null:
		WorkspaceManager.workspace_changed.connect(func(_new_id, _old_id): _refresh())
	if DiagnosticsService != null:
		DiagnosticsService.count_changed.connect(func(_counts): _refresh())
	if ThemeService != null:
		ThemeService.theme_changed.connect(_on_theme_changed)
		ThemeService.dpi_scale_changed.connect(func(_scale): _refresh())
	_refresh()

func _refresh() -> void:
	_refresh_project()
	_refresh_workspace()
	_refresh_appearance()
	_refresh_state()

func _refresh_project() -> void:
	var project_name := "No project"
	if AppState != null and AppState.is_project_loaded():
		project_name = AppState.get_project_path().get_file().get_basename().capitalize()
	_project_label.text = "PROJECT: " + project_name

func _refresh_workspace() -> void:
	var workspace_id := WorkspaceManager.get_active_workspace_id() if WorkspaceManager != null else "project_assets"
	var names := {
		"project_assets": "Project",
		"character_creator": "Create",
		"rigging_deformation": "Rig",
		"animation_studio": "Animate",
		"weapon_equipment": "Weapon",
		"preview_export": "Export",
	}
	_workspace_label.text = "MODE: " + String(names.get(workspace_id, "Project"))

func _refresh_appearance() -> void:
	if ThemeService == null:
		return
	_appearance_label.text = "%s · %.0f%%" % [ThemeService.get_appearance_mode_name(), ThemeService.get_dpi_scale() * 100.0]
	_texture.visible = ThemeService.uses_paper_texture()
	_texture.modulate.a = ThemeService.get_paper_texture_opacity()
	for index in range(_appearance_picker.item_count):
		if _appearance_picker.get_item_id(index) == ThemeService.get_appearance_mode():
			_appearance_picker.select(index)
			break

func _refresh_state() -> void:
	if DiagnosticsService != null and not DiagnosticsService.get_errors().is_empty():
		_chip.set_status("Needs attention", PaperQuestStatusChip.Status.ERROR)
	elif AppState != null and AppState.is_dirty():
		_chip.set_status("Unsaved", PaperQuestStatusChip.Status.WARNING)
	else:
		_chip.set_status("Ready", PaperQuestStatusChip.Status.READY)

func _setup_appearance_picker() -> void:
	_appearance_picker.clear()
	if ThemeService == null:
		return
	for option in ThemeService.get_appearance_options():
		_appearance_picker.add_item(String(option["label"]), int(option["id"]))

func _select_appearance(index: int) -> void:
	if ThemeService != null:
		ThemeService.set_appearance_mode(_appearance_picker.get_item_id(index))
	var main_window := get_parent()
	if main_window != null and main_window.has_method("set_status_message"):
		main_window.call("set_status_message", "Appearance: " + ThemeService.get_appearance_mode_name())

func _show_help() -> void:
	var main_window := get_parent()
	if main_window != null and main_window.has_method("set_status_message"):
		main_window.call("set_status_message", "Tip: move through Project → Create → Rig → Animate → Weapon → Export. Press Ctrl+Shift+P to find any tool.")


func _open_project_hub() -> void:
	if WorkspaceManager != null: WorkspaceManager.switch_workspace("project_assets")

func _on_theme_changed(_mode: String, new_theme: Theme) -> void:
	(get_parent() as Control).theme = new_theme
	_refresh()
