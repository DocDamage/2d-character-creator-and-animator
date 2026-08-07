# ProjectPersistenceController -- Routes shell persistence and history actions to the active editor.
class_name ProjectPersistenceController
extends Node

const CHARACTER_WORKSPACE := "character_creator"

var _save_as_dialog: FileDialog = null


func _ready() -> void:
	add_to_group("project_persistence")
	_build_save_as_dialog()
	if AppState != null and not AppState.autosave_triggered.is_connected(_on_autosave_requested):
		AppState.autosave_triggered.connect(_on_autosave_requested)


func save_current() -> Dictionary:
	var creator := _get_creator()
	var session = creator.call("get_session") if creator != null else null
	if creator == null or session == null:
		return _report_failure("Open an editable character project before saving.")
	if str(session.project_path).begins_with("res://"):
		open_save_as()
		return _report_failure("Bundled samples are read-only. Choose a location for your own copy.")
	var report: Dictionary = creator.call("save_project") as Dictionary
	_show_report(report, "Project saved successfully.", "Project save failed.")
	return report


func open_save_as() -> void:
	if AppState == null or not AppState.is_project_loaded():
		_report_failure("Open a project before using Save As.")
		return
	var project_dir := ProjectSettings.globalize_path("user://projects")
	DirAccess.make_dir_recursive_absolute(project_dir)
	_save_as_dialog.current_dir = project_dir
	_save_as_dialog.current_file = AppState.get_project_path().get_file().get_basename() + ".chrproj"
	_save_as_dialog.popup_centered_ratio(0.72)


func save_as_path(path: String) -> Dictionary:
	var creator := _get_creator()
	var session = creator.call("get_session") if creator != null else null
	if creator == null or session == null:
		return _report_failure("Open an editable character project before using Save As.")
	creator.call("commit_pending_edits")
	var target := path.strip_edges()
	if target.get_extension().is_empty(): target += ".chrproj"
	var report: Dictionary = session.call("save_project_as", target) as Dictionary
	if report.get("success", false):
		AppState.open_project(str(report.get("path", target)))
	_show_report(report, "Project copy saved successfully.", "Save As failed.")
	return report


func autosave_current() -> Dictionary:
	var session = _get_session()
	if session == null: return {"success": false, "errors": ["No editable project session is open."]}
	var report: Dictionary = session.call("autosave_project") as Dictionary
	if report.get("success", false):
		if AppState != null: AppState.record_autosave(str(report.get("path", "")))
		_set_status("Autosaved just now.")
	else:
		_show_report(report, "", "Autosave failed.")
	return report


func undo_current() -> bool:
	if CommandService != null and CommandService.can_undo():
		var label := CommandService.get_undo_description()
		CommandService.undo()
		AppState.update_undo_dirty_state(CommandService.get_undo_count())
		_set_status("Undid " + label)
		return true
	var creator := _get_creator()
	if _is_character_workspace() and creator != null and creator.call("undo_edit"):
		_set_status("Undid character edit.")
		return true
	return false


func redo_current() -> bool:
	if CommandService != null and CommandService.can_redo():
		var label := CommandService.get_redo_description()
		CommandService.redo()
		AppState.update_undo_dirty_state(CommandService.get_undo_count())
		_set_status("Redid " + label)
		return true
	var creator := _get_creator()
	if _is_character_workspace() and creator != null and creator.call("redo_edit"):
		_set_status("Redid character edit.")
		return true
	return false


func _build_save_as_dialog() -> void:
	_save_as_dialog = FileDialog.new()
	_save_as_dialog.name = "SaveAsDialog"
	_save_as_dialog.title = "Save Character Project As"
	_save_as_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_as_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_as_dialog.filters = PackedStringArray(["*.chrproj ; Character Project"])
	_save_as_dialog.file_selected.connect(save_as_path)
	add_child(_save_as_dialog)


func _get_creator() -> Control:
	var main_window := get_parent()
	if main_window == null or not main_window.has_method("get_panel"): return null
	var panel = main_window.call("get_panel", "panel_character_creator")
	return panel.get_node_or_null("MainVBox/ContentContainer/CharacterCreatorPanel") as Control if panel != null else null


func _get_session():
	var creator := _get_creator()
	return creator.call("get_session") if creator != null else null


func _is_character_workspace() -> bool:
	return WorkspaceManager != null and WorkspaceManager.get_active_workspace_id() == CHARACTER_WORKSPACE


func _on_autosave_requested() -> void:
	var report := autosave_current()
	if report.get("success", false) and DiagnosticsService != null:
		DiagnosticsService.info("Character project autosaved to " + str(report.get("path", "")), "ProjectPersistenceController")


func _show_report(report: Dictionary, success_message: String, fallback_error: String) -> void:
	if report.get("success", false):
		if not success_message.is_empty(): _set_status(success_message)
	else:
		_set_status(str(report.get("errors", [fallback_error])[0]))


func _report_failure(message: String) -> Dictionary:
	var report := {"success": false, "errors": [message], "repair_actions": []}
	_show_report(report, "", message)
	return report


func _set_status(message: String) -> void:
	var main_window := get_parent()
	if main_window != null and main_window.has_method("set_status_message"):
		main_window.call("set_status_message", message)
