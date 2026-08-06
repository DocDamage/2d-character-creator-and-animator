# AppState — Global application state service
# Autoload: AppState
# Tracks project open state, dirty flags, clean undo stack indices, UI mode, workspace selection, and autosave timers.
extends Node

## === Signals ================================================================

signal project_opened(project_path: String)
signal project_closed
signal dirty_state_changed(is_dirty: bool)
signal workspace_changed(workspace_id: String)
signal theme_changed(theme_id: String)
signal diagnostic_posted(level: String, message: String, source: String)
signal autosave_triggered
signal close_requested(cancel: bool)

## === Constants ==============================================================

const WORKSPACES := [
	"project_assets",
	"character_creator",
	"rigging_deformation",
	"animation_studio",
	"weapon_equipment",
	"preview_export",
]

const DEFAULT_WORKSPACE := "project_assets"

## === State ==================================================================

var _project_path: String = ""
var _project_loaded: bool = false
var _is_dirty: bool = false
var _current_workspace: String = DEFAULT_WORKSPACE
var _current_theme: String = "dark"
var _unsaved_changes: int = 0
var _clean_undo_index: int = 0
var _undo_available: bool = false
var _redo_available: bool = false
var _recent_projects: Array[String] = []

var _autosave_enabled: bool = true
var _autosave_interval_sec: float = 60.0
var _autosave_timer: Timer = null

## === Lifecycle ==============================================================

func _ready() -> void:
	_setup_autosave_timer()


## === Public API =============================================================

func is_project_loaded() -> bool:
	return _project_loaded


func get_project_path() -> String:
	return _project_path


func is_dirty() -> bool:
	return _is_dirty


func get_current_workspace() -> String:
	return _current_workspace


func get_current_theme() -> String:
	return _current_theme


func get_recent_projects() -> Array[String]:
	if RecentProjectsService != null and RecentProjectsService.has_method("get_recent_projects"):
		var list: Array[Dictionary] = RecentProjectsService.get_recent_projects()
		var res: Array[String] = []
		for item in list:
			if item.has("path"):
				res.append(item["path"])
		return res
	return _recent_projects.duplicate()


func get_unsaved_changes() -> int:
	return _unsaved_changes


func get_clean_undo_index() -> int:
	return _clean_undo_index


func is_undo_available() -> bool:
	return _undo_available


func is_redo_available() -> bool:
	return _redo_available


func get_formatted_title() -> String:
	var base_title := "Modular 2D Character Studio"
	if _project_loaded and not _project_path.is_empty():
		var fname := _project_path.get_file()
		if fname.is_empty():
			fname = _project_path
		base_title = fname + " - " + base_title
	if _is_dirty:
		base_title += " *"
	return base_title


func open_project(path: String) -> void:
	if _project_loaded:
		close_project()
	_project_path = path
	_project_loaded = true
	_is_dirty = false
	_unsaved_changes = 0
	_clean_undo_index = 0
	_add_recent_project(path)
	project_opened.emit(path)
	dirty_state_changed.emit(false)


func close_project() -> void:
	_project_path = ""
	_project_loaded = false
	_is_dirty = false
	_unsaved_changes = 0
	_clean_undo_index = 0
	_undo_available = false
	_redo_available = false
	project_closed.emit()
	dirty_state_changed.emit(false)


func mark_dirty() -> void:
	_unsaved_changes += 1
	if not _is_dirty:
		_is_dirty = true
		dirty_state_changed.emit(true)


func mark_clean() -> void:
	_is_dirty = false
	_unsaved_changes = 0
	if CommandService != null and CommandService.has_method("get_undo_count"):
		_clean_undo_index = CommandService.call("get_undo_count") as int
	dirty_state_changed.emit(false)


func clear_dirty() -> void:
	mark_clean()


func update_undo_dirty_state(current_undo_count: int) -> void:
	var new_dirty := (current_undo_count != _clean_undo_index)
	if new_dirty != _is_dirty:
		_is_dirty = new_dirty
		dirty_state_changed.emit(_is_dirty)


func set_workspace(workspace_id: String) -> void:
	if workspace_id in WORKSPACES and workspace_id != _current_workspace:
		_current_workspace = workspace_id
		workspace_changed.emit(workspace_id)


func set_theme(theme_id: String) -> void:
	if theme_id in ["light", "dark"] and theme_id != _current_theme:
		_current_theme = theme_id
		theme_changed.emit(theme_id)


func set_undo_available(available: bool) -> void:
	_undo_available = available


func set_redo_available(available: bool) -> void:
	_redo_available = available


func post_diagnostic(level: String, message: String, source: String = "") -> void:
	diagnostic_posted.emit(level, message, source)


func is_autosave_enabled() -> bool:
	return _autosave_enabled


func set_autosave_enabled(enabled: bool) -> void:
	_autosave_enabled = enabled
	if _autosave_timer != null:
		if enabled and _autosave_interval_sec > 0.0:
			_autosave_timer.start(_autosave_interval_sec)
		else:
			_autosave_timer.stop()


func get_autosave_interval() -> float:
	return _autosave_interval_sec


func set_autosave_interval(interval_sec: float) -> void:
	_autosave_interval_sec = maxf(1.0, interval_sec)
	if _autosave_timer != null and _autosave_enabled:
		_autosave_timer.start(_autosave_interval_sec)


func trigger_autosave() -> void:
	if _is_dirty:
		autosave_triggered.emit()
		post_diagnostic("info", "Autosave triggered for project: " + _project_path, "AppState")


## === Internal ===============================================================

func _setup_autosave_timer() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = false
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)
	if _autosave_enabled and _autosave_interval_sec > 0.0:
		_autosave_timer.start(_autosave_interval_sec)


func _on_autosave_timeout() -> void:
	trigger_autosave()


func _add_recent_project(path: String) -> void:
	if RecentProjectsService != null and RecentProjectsService.has_method("add_project"):
		RecentProjectsService.add_project(path)
	var idx := _recent_projects.find(path)
	if idx >= 0:
		_recent_projects.remove_at(idx)
	_recent_projects.push_front(path)
	if _recent_projects.size() > 10:
		_recent_projects.resize(10)