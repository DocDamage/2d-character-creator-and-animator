class_name ProjectHubPanel
extends Control

const SAMPLE_PROJECT_PATH := "res://tests/fixtures/baseline/sample_project.json"

@onready var _project_name: Label = %ProjectName
@onready var _project_path: Label = %ProjectPath
@onready var _project_state: PaperQuestStatusChip = %ProjectState
@onready var _health_state: PaperQuestStatusChip = %HealthState
@onready var _health_copy: Label = %HealthCopy
@onready var _autosave_state: PaperQuestStatusChip = %AutosaveState
@onready var _autosave_copy: Label = %AutosaveCopy
@onready var _recent_list: ItemList = %RecentList
@onready var _continue_button: Button = %ContinueButton
@onready var _save_button: Button = %SaveButton

func _ready() -> void:
	_connect_signals()
	_refresh()

func _connect_signals() -> void:
	%CreateButton.pressed.connect(_switch_workspace.bind("character_creator"))
	%OpenSampleButton.pressed.connect(_open_sample)
	%RecoveryButton.pressed.connect(_open_quality)
	_continue_button.pressed.connect(_switch_workspace.bind("character_creator"))
	_save_button.pressed.connect(_save_project)
	_recent_list.item_activated.connect(_open_recent)
	if AppState != null:
		AppState.project_opened.connect(func(_path): _refresh())
		AppState.project_closed.connect(_refresh)
		AppState.dirty_state_changed.connect(func(_dirty): _refresh())
		AppState.autosave_triggered.connect(_refresh)
	if RecentProjectsService != null:
		RecentProjectsService.recent_projects_changed.connect(_refresh)
	if DiagnosticsService != null:
		DiagnosticsService.count_changed.connect(func(_counts): _refresh_health())

func _refresh() -> void:
	var loaded := AppState != null and AppState.is_project_loaded()
	var path := AppState.get_project_path() if loaded else ""
	_project_name.text = path.get_file().get_basename().capitalize() if loaded else "No quest open"
	_project_path.text = path if loaded else "Open a recent project or start with the sample adventure."
	_continue_button.disabled = not loaded
	_save_button.disabled = not loaded or not AppState.is_dirty()
	if not loaded:
		_project_state.set_status("Choose a project", PaperQuestStatusChip.Status.INFO)
	elif AppState.is_dirty():
		_project_state.set_status("Changes pending", PaperQuestStatusChip.Status.WARNING)
	else:
		_project_state.set_status("All changes saved", PaperQuestStatusChip.Status.READY)
	_refresh_recent_projects()
	_refresh_health()
	_refresh_autosave()

func _refresh_recent_projects() -> void:
	_recent_list.clear()
	if RecentProjectsService == null:
		return
	for project in RecentProjectsService.get_recent_projects():
		var exists := bool(project.get("exists", false))
		var label := "%s\n%s" % [project.get("title", "Untitled"), project.get("last_modified", "")]
		if not exists:
			label = "Missing · " + label
		var index := _recent_list.add_item(label)
		_recent_list.set_item_metadata(index, project.get("path", ""))
		if not exists:
			_recent_list.set_item_custom_fg_color(index, ThemeService.get_color_token("error"))

func _refresh_health() -> void:
	if DiagnosticsService == null:
		_health_state.set_status("Unavailable", PaperQuestStatusChip.Status.INFO)
		_health_copy.text = "Diagnostics service is not available."
		return
	var error_count := DiagnosticsService.get_errors().size()
	var warning_count := DiagnosticsService.get_count(DiagnosticsService.Level.WARNING)
	if error_count > 0:
		_health_state.set_status("%d errors" % error_count, PaperQuestStatusChip.Status.ERROR)
	elif warning_count > 0:
		_health_state.set_status("%d warnings" % warning_count, PaperQuestStatusChip.Status.WARNING)
	else:
		_health_state.set_status("No reported issues", PaperQuestStatusChip.Status.READY)
	_health_copy.text = "%d diagnostic entries in this session." % DiagnosticsService.get_count()

func _refresh_autosave() -> void:
	if AppState == null or not AppState.is_autosave_enabled():
		_autosave_state.set_status("Autosave off", PaperQuestStatusChip.Status.WARNING)
		_autosave_copy.text = "Enable autosave in project settings."
	elif AppState.is_dirty():
		_autosave_state.set_status("Waiting to autosave", PaperQuestStatusChip.Status.INFO)
		_autosave_copy.text = "Interval: %.0f seconds" % AppState.get_autosave_interval()
	else:
		_autosave_state.set_status("Autosave on", PaperQuestStatusChip.Status.READY)
		_autosave_copy.text = "No unsaved changes are waiting."

func _switch_workspace(workspace_id: String) -> void:
	if WorkspaceManager != null:
		WorkspaceManager.switch_workspace(workspace_id)

func _open_sample() -> void:
	if AppState != null:
		AppState.open_project(SAMPLE_PROJECT_PATH)
	if RecentProjectsService != null:
		RecentProjectsService.add_project(SAMPLE_PROJECT_PATH, "Forestbound Sample")
	_refresh()

func _save_project() -> void:
	if AppState != null:
		AppState.mark_clean()
	_refresh()

func _open_recent(index: int) -> void:
	var path := String(_recent_list.get_item_metadata(index))
	if RecentProjectsService != null and not RecentProjectsService.check_path_exists(path):
		_project_state.set_status("Recent project is missing", PaperQuestStatusChip.Status.ERROR)
		return
	if AppState != null:
		AppState.open_project(path)
	_refresh()

func _open_quality() -> void:
	_switch_workspace("preview_export")
	var manager := WorkspaceManager.get_dock_layout_manager() if WorkspaceManager != null else null
	if manager != null:
		manager.call("set_panel_visible", "panel_quality_dashboard", true)
		manager.call("activate_panel", "panel_quality_dashboard")
