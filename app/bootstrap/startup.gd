# Startup — Application bootstrap and startup diagnostics screen
# Extends startup sequence with an interactive Recent Projects landing view.
extends Control

## === Signals ================================================================

signal startup_completed(success: bool, errors: Array[String])
signal diagnostic_check_completed(check_name: String, success: bool)
signal project_selected(path: String)
signal project_created(path: String, title: String)
signal workspace_transition_requested(path: String)

## === Constants ==============================================================

const APP_NAME := "Paper Quest Character Studio"
const APP_VERSION := "0.1.0-dev"
const APP_BUILD_DATE := "2026-08-05"
const SAMPLE_PROJECT_PATH := "res://samples/humanoid_modular.chrproj"
const MAIN_WINDOW_SCENE_PATH := "res://app/shared_ui/main_window.tscn"
const PACKAGED_ACCEPTANCE_SCENE_PATH := "res://tests/packaged_ui_acceptance.tscn"
const PACKAGED_ACCEPTANCE_ARG := "--packaged-ui-acceptance"
const PACKAGED_ACCEPTANCE_META := &"paper_quest_packaged_acceptance_started"

const StartupDiagnosticsScript = preload("res://app/bootstrap/startup_diagnostics.gd")

## === Node References ========================================================

@onready var _status_label: Label = get_node_or_null("MarginContainer/MainLayout/Header/HeaderLeft/StatusLabel")
@onready var _log_text: TextEdit = get_node_or_null("MarginContainer/MainLayout/LogDrawer/LogText")
@onready var _version_label: Label = get_node_or_null("MarginContainer/MainLayout/Header/HeaderLeft/VersionLabel")
@onready var _recent_list: ItemList = get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/RecentList")
@onready var _search_input: LineEdit = get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/SearchBar/SearchEdit")
@onready var _empty_label: Label = get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/EmptyLabel")

@onready var _btn_new_project: Button = get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnNewProject")
@onready var _btn_open_project: Button = get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenProject")
@onready var _btn_open_sample: Button = get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenSample")
@onready var _btn_continue_last: Button = get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnContinueLast")
@onready var _btn_clear_missing: Button = get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/HeaderBar/BtnClearMissing")
@onready var _btn_toggle_log: Button = get_node_or_null("MarginContainer/MainLayout/Header/HeaderRight/BtnToggleLog")

@onready var _new_project_dialog: ConfirmationDialog = get_node_or_null("NewProjectDialog")
@onready var _open_project_dialog: FileDialog = get_node_or_null("OpenProjectDialog")
@onready var _missing_dialog: ConfirmationDialog = get_node_or_null("MissingProjectDialog")
@onready var _log_drawer: PanelContainer = get_node_or_null("MarginContainer/MainLayout/LogDrawer")

## === State ==================================================================

var _startup_complete := false
var _startup_errors: Array[String] = []
var _passed_checks: int = 0
var _total_checks: int = 0
var _pending_missing_path: String = ""
var _search_filter: String = ""
@export var transition_to_workspace := true

## === Lifecycle ==============================================================

func _ready() -> void:
	if _redirect_to_packaged_acceptance_if_requested():
		return
	if ThemeService != null: ThemeService.apply_to_window(get_window())
	if _version_label != null:
		_version_label.text = "Project dashboard · v%s" % APP_VERSION
	_connect_ui_signals()
	_run_startup_sequence()
	refresh_recent_list()


func _redirect_to_packaged_acceptance_if_requested() -> bool:
	if not OS.has_feature("template"):
		return false
	if PACKAGED_ACCEPTANCE_ARG not in OS.get_cmdline_user_args():
		return false
	if Engine.has_meta(PACKAGED_ACCEPTANCE_META):
		return false
	Engine.set_meta(PACKAGED_ACCEPTANCE_META, true)
	call_deferred("_launch_packaged_acceptance")
	return true


func _launch_packaged_acceptance() -> void:
	var error := get_tree().change_scene_to_file(PACKAGED_ACCEPTANCE_SCENE_PATH)
	if error != OK:
		printerr("PACKAGED UI ACCEPTANCE: unable to launch (%s)" % error_string(error))
		get_tree().quit(3)


func _get_recent_service() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("RecentProjectsService")
	return null


func _get_app_state() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("AppState")
	return null


## === Startup Diagnostics Sequence ===========================================

func _run_startup_sequence() -> void:
	_startup_errors.clear()

	var diag_res := StartupDiagnosticsScript.run_diagnostics(
		Callable(self, "_append_log"),
		Callable(self, "_on_check_completed")
	)

	_passed_checks = diag_res.get("passed", 0) as int
	_total_checks = diag_res.get("total", 0) as int
	var errs: Array = diag_res.get("errors", [])
	for e in errs:
		_startup_errors.append(String(e))

	if _startup_errors.is_empty():
		var msg := "Startup completed successfully (%d/%d checks passed)." % [_passed_checks, _total_checks]
		if _status_label != null:
			_status_label.text = "All systems ready · %d/%d checks passed" % [_passed_checks, _total_checks]
			_status_label.modulate = Color.GREEN
		_startup_complete = true
		startup_completed.emit(true, _startup_errors)
	else:
		if _status_label != null:
			_status_label.text = "Attention required · %d check(s) need review" % _startup_errors.size()
			_status_label.modulate = Color.RED
		startup_completed.emit(false, _startup_errors)


func _on_check_completed(check_name: String, success: bool) -> void:
	diagnostic_check_completed.emit(check_name, success)


## === Recent Projects & Actions ===============================================

func refresh_recent_list() -> void:
	if _recent_list == null:
		return
	_recent_list.clear()

	var srv := _get_recent_service()
	var projects: Array[Dictionary] = []
	if srv != null and srv.has_method("get_recent_projects"):
		projects = srv.call("get_recent_projects")

	var visible_count := 0

	for item in projects:
		var path: String = item.get("path", "")
		var title: String = item.get("title", path.get_file())
		var exists: bool = item.get("exists", false)

		if not _search_filter.is_empty():
			if not (title.containsn(_search_filter) or path.containsn(_search_filter)):
				continue

		var display_text := "%s (%s)" % [title, path]
		if not exists:
			display_text = "[MISSING] " + display_text

		var idx := _recent_list.add_item(display_text)
		_recent_list.set_item_metadata(idx, path)
		if not exists:
			_recent_list.set_item_custom_bg_color(idx, Color(0.35, 0.1, 0.1, 0.5))

		visible_count += 1

	if _empty_label != null:
		_empty_label.visible = (visible_count == 0)
	_recent_list.visible = visible_count > 0

	if _btn_continue_last != null:
		_btn_continue_last.disabled = projects.is_empty() or not projects[0].get("exists", false)


func open_project_path(path: String) -> void:
	if path.is_empty():
		return

	var srv := _get_recent_service()
	var exists := true
	if srv != null and srv.has_method("check_path_exists"):
		exists = srv.call("check_path_exists", path)
	else:
		exists = FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

	if not exists:
		_pending_missing_path = path
		if _missing_dialog != null:
			_missing_dialog.dialog_text = "Project file or directory not found:\n%s\n\nWould you like to remove it from the recent list?" % path
			_missing_dialog.popup_centered()
		return

	if srv != null and srv.has_method("add_project"):
		srv.call("add_project", path)

	var app_st := _get_app_state()
	if app_st != null and app_st.has_method("open_project"):
		app_st.call("open_project", path)

	project_selected.emit(path)
	refresh_recent_list()
	_open_workspace(path)


func create_new_project(path: String, title: String, template_id: String) -> void:
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			var data := {
				"name": title,
				"template": template_id,
				"version": APP_VERSION,
				"created_at": Time.get_datetime_string_from_system(false, true)
			}
			file.store_string(JSON.stringify(data, "\t"))
			file.close()

	var srv := _get_recent_service()
	if srv != null and srv.has_method("add_project"):
		srv.call("add_project", path, title)

	var app_st := _get_app_state()
	if app_st != null and app_st.has_method("open_project"):
		app_st.call("open_project", path)

	project_created.emit(path, title)
	project_selected.emit(path)
	refresh_recent_list()
	_open_workspace(path)


func _open_workspace(path: String) -> void:
	workspace_transition_requested.emit(path)
	if transition_to_workspace:
		call_deferred("_change_to_main_workspace")


func _change_to_main_workspace() -> void:
	if get_tree().change_scene_to_file(MAIN_WINDOW_SCENE_PATH) != OK and DiagnosticsService != null:
		DiagnosticsService.error("Could not open main editor workspace.", "Startup")


## === Internal Signals & Connection =========================================

func _connect_ui_signals() -> void:
	if _recent_list != null:
		_recent_list.item_activated.connect(_on_recent_item_activated)
	if _search_input != null:
		_search_input.text_changed.connect(func(text):
			_search_filter = text.strip_edges()
			refresh_recent_list()
		)
	if _btn_new_project != null:
		_btn_new_project.pressed.connect(func():
			if _new_project_dialog != null and _new_project_dialog.has_method("open_dialog"):
				_new_project_dialog.call("open_dialog")
		)
	if _btn_open_project != null:
		_btn_open_project.pressed.connect(func():
			if _open_project_dialog != null:
				_open_project_dialog.popup_centered_ratio(0.72)
		)
	if _btn_open_sample != null:
		_btn_open_sample.pressed.connect(func(): open_project_path(SAMPLE_PROJECT_PATH))
	if _btn_continue_last != null:
		_btn_continue_last.pressed.connect(func():
			var srv := _get_recent_service()
			if srv != null and srv.has_method("get_recent_projects"):
				var projs: Array = srv.call("get_recent_projects")
				if not projs.is_empty():
					open_project_path(projs[0].get("path", ""))
		)
	if _btn_clear_missing != null:
		_btn_clear_missing.pressed.connect(func():
			var srv := _get_recent_service()
			if srv != null and srv.has_method("clear_missing"):
				srv.call("clear_missing")
				refresh_recent_list()
		)
	if _btn_toggle_log != null and _log_drawer != null:
		_btn_toggle_log.pressed.connect(func():
			_log_drawer.visible = not _log_drawer.visible
		)
	if _new_project_dialog != null and _new_project_dialog.has_signal("project_created"):
		_new_project_dialog.connect("project_created", Callable(self, "create_new_project"))
	if _open_project_dialog != null:
		_open_project_dialog.file_selected.connect(open_project_path)
	if _missing_dialog != null:
		_missing_dialog.confirmed.connect(func():
			if not _pending_missing_path.is_empty():
				var srv := _get_recent_service()
				if srv != null and srv.has_method("remove_project"):
					srv.call("remove_project", _pending_missing_path)
				_pending_missing_path = ""
				refresh_recent_list()
		)


func _on_recent_item_activated(index: int) -> void:
	if _recent_list == null:
		return
	var path: String = _recent_list.get_item_metadata(index)
	open_project_path(path)


func _append_log(msg: String) -> void:
	if _log_text != null:
		_log_text.text += msg + "\n"


func is_startup_complete() -> bool:
	return _startup_complete


func get_startup_errors() -> Array[String]:
	return _startup_errors.duplicate()


func get_passed_checks_count() -> int:
	return _passed_checks


func get_total_checks_count() -> int:
	return _total_checks
