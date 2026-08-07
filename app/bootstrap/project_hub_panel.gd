class_name ProjectHubPanel
extends Control

const SAMPLE_PROJECT_PATH := "res://samples/humanoid_modular.chrproj"
const STARTUP_SCENE_PATH := "res://app/bootstrap/startup.tscn"
const WorkflowWizardScript = preload("res://app/bootstrap/project_workflow_wizard.gd")
const ProjectScaleAdvisorScript = preload("res://quality/performance/project_scale_advisor.gd")
const SupportBundleExporterScript = preload("res://quality/recovery/support_bundle_exporter.gd")

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
@onready var _update_button: Button = %UpdateButton
@onready var _update_copy: Label = %UpdateCopy
@onready var _rename_button: Button = $Margin/Root/Content/Center/Recent/Margin/VBox/RecentActions/Rename
@onready var _duplicate_button: Button = $Margin/Root/Content/Center/Recent/Margin/VBox/RecentActions/Duplicate
@onready var _archive_button: Button = $Margin/Root/Content/Center/Recent/Margin/VBox/RecentActions/Archive
@onready var _reveal_button: Button = $Margin/Root/Content/Center/Recent/Margin/VBox/RecentActions/Reveal
@onready var _locate_button: Button = $Margin/Root/Content/Center/Recent/Margin/VBox/RecentActions/Locate
@onready var _margin: MarginContainer = $Margin

var _rename_dialog: AcceptDialog
var _rename_input: LineEdit
var _locate_dialog: FileDialog
var _pending_locate_path := ""
var _update_download_available := false
var _autosave_display_timer: Timer
var _layout_sync_frames := 0
var _session = null
var _snapshot_name_input: LineEdit
var _snapshot_note_input: LineEdit
var _snapshot_list: ItemList
var _snapshot_status: Label
var _appearance_name_input: LineEdit
var _appearance_list: ItemList
var _appearance_status: Label
var _appearance_generate_count: SpinBox
var _readiness_status: Label
var _asset_provenance_list: ItemList
var _asset_author_input: LineEdit
var _asset_license_input: LineEdit
var _asset_source_input: LineEdit
var _asset_safety_status: Label
var _scale_status: Label
var _support_status: Label
var _last_support_bundle := ""
var _wizard = null
var _generate_appearances_dialog: ConfirmationDialog
var _preview_controller = null

func _ready() -> void:
	if not resized.is_connected(_request_layout_sync):
		resized.connect(_request_layout_sync)
	_request_layout_sync()
	_connect_signals()
	_build_authoring_sections()
	_start_autosave_display_timer()
	_refresh()


func _sync_fill_layout() -> void:
	# This panel is hosted inside dock containers whose height can change after
	# their tabs initialize. Keep the anchored root in the panel's current rect.
	if _margin == null: return
	_margin.position = Vector2.ZERO
	_margin.size = size


func _request_layout_sync() -> void:
	# Dock split containers can settle over more than one layout pass. Keep the
	# explicit child rect current through those initial passes, then sleep.
	_layout_sync_frames = 3
	set_process(true)
	_sync_fill_layout()


func _process(_delta: float) -> void:
	if _layout_sync_frames <= 0:
		set_process(false)
		return
	_sync_fill_layout()
	_layout_sync_frames -= 1

func _connect_signals() -> void:
	%CreateButton.pressed.connect(_create_or_continue)
	%OpenSampleButton.pressed.connect(_open_sample)
	%RecoveryButton.pressed.connect(_open_quality)
	_update_button.pressed.connect(_check_or_open_update)
	_continue_button.pressed.connect(_switch_workspace.bind("character_creator"))
	_save_button.pressed.connect(_save_project)
	_recent_list.item_activated.connect(_open_recent)
	_recent_list.item_selected.connect(func(_index): _refresh_recent_action_state())
	_rename_button.pressed.connect(_open_rename_dialog)
	_duplicate_button.pressed.connect(_duplicate_selected_project)
	_archive_button.pressed.connect(_archive_selected_project)
	_reveal_button.pressed.connect(_reveal_selected_project)
	_locate_button.pressed.connect(_locate_selected_project)
	_build_management_dialogs()
	if AppState != null:
		AppState.project_opened.connect(func(_path): _refresh())
		AppState.project_closed.connect(_refresh)
		AppState.dirty_state_changed.connect(func(_dirty): _refresh())
		AppState.autosave_triggered.connect(_refresh)
		AppState.autosave_completed.connect(func(_path, _timestamp): _refresh())
	if RecentProjectsService != null:
		RecentProjectsService.recent_projects_changed.connect(_refresh)
	if UpdateService != null:
		if not UpdateService.update_check_completed.is_connected(_on_update_check_completed):
			UpdateService.update_check_completed.connect(_on_update_check_completed)
		_apply_update_result(UpdateService.get_last_result())
	if DiagnosticsService != null:
		DiagnosticsService.count_changed.connect(func(_counts): _refresh_health())

func _refresh() -> void:
	var loaded := AppState != null and AppState.is_project_loaded()
	var path := AppState.get_project_path() if loaded else ""
	_project_name.text = path.get_file().get_basename().capitalize() if loaded else "No quest open"
	_project_path.text = (path + " · Bundled sample is read-only — use Save As before editing.") if loaded and path.begins_with("res://") else (path if loaded else "Open a recent project or start with the sample adventure.")
	%CreateButton.text = "Open Character Creator" if loaded else "Create a character"
	_continue_button.disabled = not loaded
	_save_button.disabled = not loaded or not AppState.is_dirty()
	if not loaded:
		_project_state.set_status("Choose a project", PaperQuestStatusChip.Status.INFO)
	elif path.begins_with("res://"):
		_project_state.set_status("Read-only sample", PaperQuestStatusChip.Status.WARNING)
	elif AppState.is_dirty():
		_project_state.set_status("Changes pending", PaperQuestStatusChip.Status.WARNING)
	else:
		_project_state.set_status("All changes saved", PaperQuestStatusChip.Status.READY)
	_refresh_recent_projects()
	_refresh_health()
	_refresh_autosave()
	_refresh_recent_action_state()
	_refresh_authoring_sections()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session):
		if _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
		if _session.snapshots_changed.is_connected(_refresh_authoring_sections): _session.snapshots_changed.disconnect(_refresh_authoring_sections)
		if _session.appearance_sets_changed.is_connected(_refresh_authoring_sections): _session.appearance_sets_changed.disconnect(_refresh_authoring_sections)
	_session = session
	if _session != null and is_instance_valid(_session):
		if not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
		if not _session.snapshots_changed.is_connected(_refresh_authoring_sections): _session.snapshots_changed.connect(_refresh_authoring_sections)
		if not _session.appearance_sets_changed.is_connected(_refresh_authoring_sections): _session.appearance_sets_changed.connect(_refresh_authoring_sections)
		if _wizard != null: _wizard.bind_session(_session)
	_refresh_authoring_sections()


func bind_preview_controller(controller) -> void:
	_preview_controller = controller


func open_guided_setup() -> void:
	if _session == null or not is_instance_valid(_session) or _wizard == null: return
	_wizard.bind_session(_session)
	_wizard.open()

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
	_refresh_recent_action_state()

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
	elif AppState.get_autosave_age_seconds() >= 0:
		var age := AppState.get_autosave_age_seconds()
		_autosave_state.set_status("Autosaved", PaperQuestStatusChip.Status.READY)
		_autosave_copy.text = "Autosaved %s ago" % _format_elapsed(age)
	elif AppState.is_dirty():
		_autosave_state.set_status("Waiting to autosave", PaperQuestStatusChip.Status.INFO)
		_autosave_copy.text = "Interval: %.0f seconds" % AppState.get_autosave_interval()
	else:
		_autosave_state.set_status("Autosave on", PaperQuestStatusChip.Status.READY)
		_autosave_copy.text = "No unsaved changes are waiting."


func _start_autosave_display_timer() -> void:
	_autosave_display_timer = Timer.new()
	_autosave_display_timer.name = "AutosaveDisplayTimer"
	_autosave_display_timer.wait_time = 5.0
	_autosave_display_timer.timeout.connect(_refresh_autosave)
	add_child(_autosave_display_timer)
	_autosave_display_timer.start()


func _format_elapsed(seconds: int) -> String:
	if seconds < 5: return "just now"
	if seconds < 60: return "%d seconds" % seconds
	if seconds < 3600: return "%d minute%s" % [seconds / 60, "s" if seconds / 60 != 1 else ""]
	return "%d hour%s" % [seconds / 3600, "s" if seconds / 3600 != 1 else ""]

func _switch_workspace(workspace_id: String) -> void:
	if WorkspaceManager != null:
		WorkspaceManager.switch_workspace(workspace_id)

func _open_sample() -> void:
	if not _can_replace_project(): return
	if AppState != null:
		AppState.open_project(SAMPLE_PROJECT_PATH)
	if RecentProjectsService != null:
		RecentProjectsService.add_project(SAMPLE_PROJECT_PATH, "Forestbound Sample")
	_refresh()

func _save_project() -> void:
	var controller := get_tree().get_first_node_in_group("project_persistence")
	if controller != null: controller.call("save_current")
	else: _project_state.set_status("Save service unavailable", PaperQuestStatusChip.Status.ERROR)
	_refresh()

func _open_recent(index: int) -> void:
	var path := String(_recent_list.get_item_metadata(index))
	if RecentProjectsService != null and not RecentProjectsService.check_path_exists(path):
		var issue: Dictionary = RecentProjectsService.get_actionable_error(path)
		_project_state.set_status(str(issue.get("message", "Recent project is missing")) + " Use Locate or Archive.", PaperQuestStatusChip.Status.ERROR)
		return
	if AppState != null and AppState.is_project_loaded() and AppState.get_project_path() == path:
		_switch_workspace("character_creator")
		return
	if not _can_replace_project(): return
	if AppState != null:
		AppState.open_project(path)
	_refresh()

func _open_quality() -> void:
	_switch_workspace("preview_export")
	var manager := WorkspaceManager.get_dock_layout_manager() if WorkspaceManager != null else null
	if manager != null:
		manager.call("set_panel_visible", "panel_quality_dashboard", true)
		manager.call("activate_panel", "panel_quality_dashboard")


func _check_or_open_update() -> void:
	if UpdateService == null:
		_update_copy.text = "Update service is unavailable in this build."
		return
	if _update_download_available:
		if UpdateService.open_available_update():
			_update_copy.text = "Opened the release page in your browser."
		else:
			_update_copy.text = "This update does not include a valid download link."
		return
	_apply_update_result(UpdateService.check_for_updates())


func _on_update_check_completed(result: Dictionary) -> void:
	_apply_update_result(result)


func _apply_update_result(result: Dictionary) -> void:
	if _update_button == null or _update_copy == null:
		return
	if result.is_empty():
		_update_button.text = "Check for updates"
		_update_copy.text = "Checks a configured release feed, or this build's bundled manifest."
		_update_download_available = false
		return
	if bool(result.get("pending", false)):
		_update_button.disabled = true
		_update_button.text = "Checking for updates…"
		_update_copy.text = str(result.get("message", "Checking for updates…"))
		_update_download_available = false
		return
	_update_button.disabled = false
	_update_download_available = bool(result.get("success", false)) and bool(result.get("update_available", false)) and not str(result.get("download_url", "")).is_empty()
	_update_button.text = "Open update download" if _update_download_available else "Check for updates"
	_update_copy.text = str(result.get("message", "Update status unavailable."))


func _create_or_continue() -> void:
	if AppState != null and AppState.is_project_loaded():
		_switch_workspace("character_creator")
		return
	if AppState != null:
		AppState.set_meta("open_new_project_dialog", true)
	if get_tree().change_scene_to_file(STARTUP_SCENE_PATH) != OK:
		if AppState != null:
			AppState.remove_meta("open_new_project_dialog")
		_project_state.set_status("Could not open project creation", PaperQuestStatusChip.Status.ERROR)


func _can_replace_project() -> bool:
	if AppState != null and AppState.is_dirty():
		_project_state.set_status("Save or close current changes first", PaperQuestStatusChip.Status.WARNING)
		return false
	return true


func _selected_recent_path() -> String:
	var items := _recent_list.get_selected_items()
	return str(_recent_list.get_item_metadata(items[0])) if not items.is_empty() else ""


func _refresh_recent_action_state() -> void:
	var path := _selected_recent_path()
	var selected := not path.is_empty()
	var exists := selected and (RecentProjectsService == null or RecentProjectsService.check_path_exists(path))
	_rename_button.disabled = not exists or path.begins_with("res://")
	_duplicate_button.disabled = not exists
	_archive_button.disabled = not selected
	_reveal_button.disabled = not exists
	_locate_button.disabled = not selected or exists


func _build_management_dialogs() -> void:
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Rename Project"
	_rename_dialog.ok_button_text = "Rename"
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Project title"
	_rename_input.custom_minimum_size = Vector2(360, 40)
	_rename_dialog.add_child(_rename_input)
	_rename_dialog.confirmed.connect(_rename_selected_project)
	add_child(_rename_dialog)
	_locate_dialog = FileDialog.new()
	_locate_dialog.title = "Locate Moved Project"
	_locate_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_locate_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_locate_dialog.filters = PackedStringArray(["*.chrproj ; Character Project"])
	_locate_dialog.file_selected.connect(_on_located_project)
	add_child(_locate_dialog)


func _open_rename_dialog() -> void:
	var path := _selected_recent_path()
	if path.is_empty() or RecentProjectsService == null: return
	var title := path.get_file().get_basename()
	for entry in RecentProjectsService.get_recent_projects(true):
		if str((entry as Dictionary).get("path", "")) == path: title = str((entry as Dictionary).get("title", title)); break
	_rename_input.text = title
	_rename_dialog.popup_centered()


func _rename_selected_project() -> void:
	var path := _selected_recent_path()
	if path.is_empty() or RecentProjectsService == null: return
	var result: Dictionary = RecentProjectsService.rename_project(path, _rename_input.text)
	_project_state.set_status("Project renamed" if result.get("success", false) else str(result.get("errors", ["Rename failed"])[0]), PaperQuestStatusChip.Status.READY if result.get("success", false) else PaperQuestStatusChip.Status.ERROR)
	_refresh()


func _duplicate_selected_project() -> void:
	var path := _selected_recent_path()
	if path.is_empty() or RecentProjectsService == null: return
	var result: Dictionary = RecentProjectsService.duplicate_project(path)
	_project_state.set_status("Created project copy" if result.get("success", false) else str(result.get("errors", ["Duplicate failed"])[0]), PaperQuestStatusChip.Status.READY if result.get("success", false) else PaperQuestStatusChip.Status.ERROR)
	_refresh()


func _archive_selected_project() -> void:
	var path := _selected_recent_path()
	if path.is_empty() or RecentProjectsService == null: return
	if RecentProjectsService.archive_project(path):
		_project_state.set_status("Project archived from the recent list", PaperQuestStatusChip.Status.INFO)
	else:
		_project_state.set_status("Project could not be archived", PaperQuestStatusChip.Status.ERROR)
	_refresh()


func _reveal_selected_project() -> void:
	var path := _selected_recent_path()
	if path.is_empty() or RecentProjectsService == null: return
	var result: Dictionary = RecentProjectsService.reveal_project(path)
	_project_state.set_status("Opened project folder in Explorer" if result.get("success", false) else str(result.get("errors", ["Could not open project folder"])[0]), PaperQuestStatusChip.Status.READY if result.get("success", false) else PaperQuestStatusChip.Status.ERROR)


func _locate_selected_project() -> void:
	_pending_locate_path = _selected_recent_path()
	if not _pending_locate_path.is_empty(): _locate_dialog.popup_centered_ratio(0.72)


func _on_located_project(path: String) -> void:
	if RecentProjectsService != null and RecentProjectsService.locate_project(_pending_locate_path, path):
		_project_state.set_status("Recent project location repaired", PaperQuestStatusChip.Status.READY)
	else:
		_project_state.set_status("The selected file could not repair this recent project", PaperQuestStatusChip.Status.ERROR)
	_pending_locate_path = ""
	_refresh()


# === Project authoring surfaces =============================================

func _build_authoring_sections() -> void:
	var right_column := get_node_or_null("Margin/Root/Content/Right") as VBoxContainer
	if right_column == null: return
	# The hub can host a long project history and many named appearances. Keep
	# those surfaces scrollable instead of squeezing the header/health cards at
	# 1280×720 or high-DPI compact layouts.
	var scroll := ScrollContainer.new()
	scroll.name = "AuthoringScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "AuthoringSections"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var workflow_panel := _make_panel("GuidedSetup", "GUIDED SETUP")
	var workflow_box := workflow_panel.get_node("Margin/VBox") as VBoxContainer
	var resume := Button.new()
	resume.name = "ResumeGuidedSetup"
	resume.text = "Resume guided setup"
	resume.pressed.connect(open_guided_setup)
	workflow_box.add_child(resume)
	var workflow_copy := Label.new()
	workflow_copy.name = "GuidedSetupCopy"
	workflow_copy.text = "Import → map slots → rig → idle → preview/export"
	workflow_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workflow_copy.add_theme_font_size_override("font_size", 12)
	workflow_box.add_child(workflow_copy)
	column.add_child(workflow_panel)

	var snapshot_panel := _make_panel("Snapshots", "SNAPSHOTS")
	var snapshot_box := snapshot_panel.get_node("Margin/VBox") as VBoxContainer
	_snapshot_name_input = LineEdit.new()
	_snapshot_name_input.name = "SnapshotName"
	_snapshot_name_input.placeholder_text = "Milestone name (for example: before rig rewrite)"
	snapshot_box.add_child(_snapshot_name_input)
	_snapshot_note_input = LineEdit.new()
	_snapshot_note_input.name = "SnapshotNote"
	_snapshot_note_input.placeholder_text = "Optional note"
	snapshot_box.add_child(_snapshot_note_input)
	var snapshot_actions := HFlowContainer.new()
	snapshot_box.add_child(snapshot_actions)
	var snapshot_create := Button.new()
	snapshot_create.name = "CreateSnapshot"
	snapshot_create.text = "Create"
	snapshot_create.pressed.connect(_create_snapshot)
	snapshot_actions.add_child(snapshot_create)
	var snapshot_restore := Button.new()
	snapshot_restore.name = "RestoreSnapshot"
	snapshot_restore.text = "Restore"
	snapshot_restore.pressed.connect(_restore_snapshot)
	snapshot_actions.add_child(snapshot_restore)
	var snapshot_delete := Button.new()
	snapshot_delete.name = "DeleteSnapshot"
	snapshot_delete.text = "Delete"
	snapshot_delete.pressed.connect(_delete_snapshot)
	snapshot_actions.add_child(snapshot_delete)
	var snapshot_reveal := Button.new()
	snapshot_reveal.name = "RevealSnapshot"
	snapshot_reveal.text = "Reveal"
	snapshot_reveal.pressed.connect(_reveal_snapshot)
	snapshot_actions.add_child(snapshot_reveal)
	_snapshot_list = ItemList.new()
	_snapshot_list.name = "SnapshotList"
	_snapshot_list.custom_minimum_size = Vector2(0, 92)
	_snapshot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	snapshot_box.add_child(_snapshot_list)
	_snapshot_list.item_selected.connect(_inspect_snapshot)
	_snapshot_status = Label.new()
	_snapshot_status.name = "SnapshotStatus"
	_snapshot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_snapshot_status.add_theme_font_size_override("font_size", 12)
	snapshot_box.add_child(_snapshot_status)
	column.add_child(snapshot_panel)

	var appearance_panel := _make_panel("AppearanceSets", "APPEARANCE SETS")
	var appearance_box := appearance_panel.get_node("Margin/VBox") as VBoxContainer
	_appearance_name_input = LineEdit.new()
	_appearance_name_input.name = "AppearanceName"
	_appearance_name_input.placeholder_text = "Knight, Mage, Red Outfit…"
	appearance_box.add_child(_appearance_name_input)
	var appearance_actions := HFlowContainer.new()
	appearance_box.add_child(appearance_actions)
	for item in [["SaveAppearance", "Save", _create_appearance], ["RenameAppearance", "Rename", _rename_appearance], ["PreviewAppearance", "Preview", _preview_appearance], ["ApplyAppearance", "Apply", _apply_appearance], ["DuplicateAppearance", "Duplicate", _duplicate_appearance], ["DeleteAppearance", "Delete", _delete_appearance], ["GenerateAppearances", "Generate", _confirm_generate_appearances]]:
		var button := Button.new()
		button.name = str(item[0])
		button.text = str(item[1])
		button.pressed.connect(item[2] as Callable)
		appearance_actions.add_child(button)
	_appearance_generate_count = SpinBox.new()
	_appearance_generate_count.name = "AppearanceGenerateCount"
	_appearance_generate_count.min_value = 1
	_appearance_generate_count.max_value = 512
	_appearance_generate_count.step = 1
	_appearance_generate_count.value = 8
	_appearance_generate_count.tooltip_text = "Number of deterministic imported-part combinations to request. More than 64 requires explicit confirmation."
	appearance_box.add_child(_appearance_generate_count)
	_appearance_list = ItemList.new()
	_appearance_list.name = "AppearanceList"
	_appearance_list.custom_minimum_size = Vector2(0, 92)
	_appearance_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	appearance_box.add_child(_appearance_list)
	_appearance_status = Label.new()
	_appearance_status.name = "AppearanceStatus"
	_appearance_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_appearance_status.add_theme_font_size_override("font_size", 12)
	appearance_box.add_child(_appearance_status)
	column.add_child(appearance_panel)

	var readiness_panel := _make_panel("Readiness", "READINESS")
	var readiness_box := readiness_panel.get_node("Margin/VBox") as VBoxContainer
	var readiness_actions := HBoxContainer.new()
	readiness_box.add_child(readiness_actions)
	var validate := Button.new()
	validate.name = "ValidateProject"
	validate.text = "Validate"
	validate.pressed.connect(_validate_project)
	readiness_actions.add_child(validate)
	var repair := Button.new()
	repair.name = "AutoRepairAll"
	repair.text = "Auto Repair All"
	repair.pressed.connect(_auto_repair_all)
	readiness_actions.add_child(repair)
	_readiness_status = Label.new()
	_readiness_status.name = "ReadinessStatus"
	_readiness_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readiness_status.add_theme_font_size_override("font_size", 12)
	readiness_box.add_child(_readiness_status)
	column.add_child(readiness_panel)

	var asset_safety_panel := _make_panel("AssetSafety", "ASSET SAFETY & PROVENANCE")
	var asset_safety_box := asset_safety_panel.get_node("Margin/VBox") as VBoxContainer
	var audit_imports := Button.new()
	audit_imports.name = "AuditImportedAssets"
	audit_imports.text = "Audit imported files"
	audit_imports.tooltip_text = "Check missing files, changed artwork, duplicates, transparency, scale, and provenance without changing the project."
	audit_imports.pressed.connect(_audit_imported_assets)
	asset_safety_box.add_child(audit_imports)
	_asset_provenance_list = ItemList.new()
	_asset_provenance_list.name = "ImportedAssetList"
	_asset_provenance_list.custom_minimum_size = Vector2(0, 88)
	_asset_provenance_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_provenance_list.item_selected.connect(_inspect_asset_provenance)
	asset_safety_box.add_child(_asset_provenance_list)
	_asset_author_input = LineEdit.new()
	_asset_author_input.name = "AssetAuthor"
	_asset_author_input.placeholder_text = "Artist / rights holder (optional)"
	asset_safety_box.add_child(_asset_author_input)
	_asset_license_input = LineEdit.new()
	_asset_license_input.name = "AssetLicense"
	_asset_license_input.placeholder_text = "License or permission (optional)"
	asset_safety_box.add_child(_asset_license_input)
	_asset_source_input = LineEdit.new()
	_asset_source_input.name = "AssetSourceReference"
	_asset_source_input.placeholder_text = "Source reference or purchase record (optional)"
	asset_safety_box.add_child(_asset_source_input)
	var provenance_actions := HFlowContainer.new()
	asset_safety_box.add_child(provenance_actions)
	var save_provenance := Button.new()
	save_provenance.name = "SaveAssetProvenance"
	save_provenance.text = "Save art details"
	save_provenance.pressed.connect(_save_asset_provenance)
	provenance_actions.add_child(save_provenance)
	_asset_safety_status = Label.new()
	_asset_safety_status.name = "AssetSafetyStatus"
	_asset_safety_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_asset_safety_status.add_theme_font_size_override("font_size", 12)
	asset_safety_box.add_child(_asset_safety_status)
	column.add_child(asset_safety_panel)

	var scale_panel := _make_panel("ProjectScale", "SCALE & DELIVERY")
	var scale_box := scale_panel.get_node("Margin/VBox") as VBoxContainer
	var analyze_scale := Button.new()
	analyze_scale.name = "AnalyzeProjectScale"
	analyze_scale.text = "Analyze project scale"
	analyze_scale.pressed.connect(_analyze_project_scale)
	scale_box.add_child(analyze_scale)
	_scale_status = Label.new()
	_scale_status.name = "ProjectScaleStatus"
	_scale_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scale_status.add_theme_font_size_override("font_size", 12)
	scale_box.add_child(_scale_status)
	column.add_child(scale_panel)

	var support_panel := _make_panel("SupportPrivacy", "SUPPORT & PRIVACY")
	var support_box := support_panel.get_node("Margin/VBox") as VBoxContainer
	var support_copy := Label.new()
	support_copy.text = "Create a local support ZIP only if you choose to share it. It contains diagnostics and a redacted project summary—never imported artwork or audio—and nothing is uploaded automatically."
	support_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	support_copy.add_theme_font_size_override("font_size", 12)
	support_box.add_child(support_copy)
	var support_actions := HFlowContainer.new()
	support_box.add_child(support_actions)
	var create_support_bundle := Button.new()
	create_support_bundle.name = "CreateSupportBundle"
	create_support_bundle.text = "Create local support bundle"
	create_support_bundle.pressed.connect(_create_support_bundle)
	support_actions.add_child(create_support_bundle)
	var reveal_support_bundle := Button.new()
	reveal_support_bundle.name = "RevealSupportBundle"
	reveal_support_bundle.text = "Reveal bundle"
	reveal_support_bundle.disabled = true
	reveal_support_bundle.pressed.connect(_reveal_support_bundle)
	support_actions.add_child(reveal_support_bundle)
	_support_status = Label.new()
	_support_status.name = "SupportStatus"
	_support_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_support_status.add_theme_font_size_override("font_size", 12)
	support_box.add_child(_support_status)
	column.add_child(support_panel)

	_wizard = WorkflowWizardScript.new()
	_wizard.name = "ProjectWorkflowWizard"
	_wizard.route_requested.connect(_route_wizard_step)
	add_child(_wizard)
	_generate_appearances_dialog = ConfirmationDialog.new()
	_generate_appearances_dialog.name = "GenerateAppearancesConfirmation"
	_generate_appearances_dialog.title = "Generate imported Appearance Sets"
	_generate_appearances_dialog.dialog_text = "Create deterministic combinations of the parts already imported into this project? No artwork will be generated or duplicated."
	_generate_appearances_dialog.confirmed.connect(_generate_appearances)
	add_child(_generate_appearances_dialog)


func _make_panel(name_id: String, title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_id
	panel.theme_type_variation = &"PaperPanel"
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	margin.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	return panel


func _refresh_authoring_sections() -> void:
	if _snapshot_list == null or _appearance_list == null or _readiness_status == null: return
	_snapshot_list.clear()
	_appearance_list.clear()
	if _session == null or not is_instance_valid(_session):
		_snapshot_status.text = "Open an editable project to create portable milestones."
		_appearance_status.text = "Open a project to save imported-art appearances."
		_readiness_status.text = "Open a project to validate readiness."
		if _asset_provenance_list != null: _asset_provenance_list.clear()
		if _asset_safety_status != null: _asset_safety_status.text = "Open a project to audit imported files and record art details."
		if _scale_status != null: _scale_status.text = "Open a project to estimate live-preview and review-export scale."
		if _support_status != null: _support_status.text = "Support bundles are created locally and are never uploaded automatically."
		return
	var editable: bool = not _session.is_read_only()
	for control_name in ["CreateSnapshot", "RestoreSnapshot", "DeleteSnapshot", "SaveAppearance", "RenameAppearance", "ApplyAppearance", "DuplicateAppearance", "DeleteAppearance", "GenerateAppearances", "AutoRepairAll", "SaveAssetProvenance"]:
		var control := find_child(control_name, true, false) as BaseButton
		if control != null: control.disabled = not editable
	for provenance_input in [_asset_author_input, _asset_license_input, _asset_source_input]:
		if provenance_input != null: provenance_input.editable = editable
	if not editable:
		_snapshot_status.text = "Bundled sample is read-only. Use Save As before creating, restoring, or deleting snapshots."
		_appearance_status.text = "Bundled sample is read-only. Use Save As before changing Appearance Sets."
	for snapshot in _session.list_project_snapshots():
		var data: Dictionary = snapshot
		var timestamp := Time.get_datetime_string_from_unix_time(int(data.get("timestamp", 0)))
		var note: String = str(data.get("note", "")).strip_edges()
		var line := "%s\n%s%s" % [str(data.get("name", data.get("id", "Snapshot"))), timestamp, " · " + note.left(80) if not note.is_empty() else ""]
		var index := _snapshot_list.add_item(line)
		_snapshot_list.set_item_metadata(index, str(data.get("id", "")))
	_snapshot_status.text = "%d portable snapshot%s." % [_snapshot_list.item_count, "s" if _snapshot_list.item_count != 1 else ""]
	for appearance in _session.get_appearance_sets():
		var data: Dictionary = appearance
		var index := _appearance_list.add_item(str(data.get("name", data.get("appearance_id", "Appearance"))) + " · " + str(data.get("kind", "manual")))
		_appearance_list.set_item_metadata(index, str(data.get("appearance_id", "")))
	_appearance_status.text = "Uses only existing imported parts and palette values." if _appearance_list.item_count > 0 else "Save the current imported assembly as a named appearance."
	var report: Dictionary = _session.get_readiness_report()
	_readiness_status.text = "%d blocking issue%s · %d warning%s" % [(report.get("errors", []) as Array).size(), "s" if (report.get("errors", []) as Array).size() != 1 else "", (report.get("warnings", []) as Array).size(), "s" if (report.get("warnings", []) as Array).size() != 1 else ""]
	_refresh_asset_safety()
	_refresh_project_scale()
	if _support_status != null and _support_status.text.is_empty(): _support_status.text = "Nothing is uploaded automatically. Create a local ZIP only when you want to share diagnostics."


func _selected_snapshot_id() -> String:
	var selected := _snapshot_list.get_selected_items() if _snapshot_list != null else PackedInt32Array()
	return str(_snapshot_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""


func _selected_appearance_id() -> String:
	var selected := _appearance_list.get_selected_items() if _appearance_list != null else PackedInt32Array()
	return str(_appearance_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""


func _create_snapshot() -> void:
	if _session == null: return
	var name := _snapshot_name_input.text.strip_edges() if _snapshot_name_input != null else ""
	var note := _snapshot_note_input.text.strip_edges() if _snapshot_note_input != null else ""
	var report: Dictionary = _session.create_project_snapshot(name if not name.is_empty() else "Snapshot", note)
	_snapshot_status.text = "Created portable snapshot." if report.get("success", false) else str(report.get("errors", ["Snapshot failed."])[0])
	if _snapshot_name_input != null: _snapshot_name_input.clear()
	if _snapshot_note_input != null: _snapshot_note_input.clear()
	_refresh_authoring_sections()


func _inspect_snapshot(index: int) -> void:
	if _session == null or _snapshot_list == null or index < 0: return
	var snapshot: Dictionary = _session.get_project_snapshot(str(_snapshot_list.get_item_metadata(index)))
	if snapshot.is_empty():
		_snapshot_status.text = "This snapshot is no longer available."
		return
	var preview: Dictionary = snapshot.get("preview", {}) as Dictionary
	_snapshot_status.text = "%s · %d asset%s · %d clip%s%s" % [str(snapshot.get("kind", "manual")).replace("_", " ").capitalize(), int(preview.get("asset_count", 0)), "s" if int(preview.get("asset_count", 0)) != 1 else "", int(preview.get("clip_count", 0)), "s" if int(preview.get("clip_count", 0)) != 1 else "", " · " + str(snapshot.get("note", "")) if not str(snapshot.get("note", "")).is_empty() else ""]


func _restore_snapshot() -> void:
	if _session == null: return
	var id := _selected_snapshot_id()
	if id.is_empty(): _snapshot_status.text = "Select a snapshot to restore."; return
	var report: Dictionary = _session.restore_project_snapshot(id)
	_snapshot_status.text = "Restored snapshot; a Before restoring recovery point was created." if report.get("success", false) else str(report.get("errors", ["Restore failed."])[0])
	_refresh_authoring_sections()


func _delete_snapshot() -> void:
	if _session == null: return
	var id := _selected_snapshot_id()
	if id.is_empty(): _snapshot_status.text = "Select a snapshot to delete."; return
	var report: Dictionary = _session.delete_project_snapshot(id)
	_snapshot_status.text = "Deleted snapshot." if report.get("success", false) else str(report.get("errors", ["Delete failed."])[0])
	_refresh_authoring_sections()


func _reveal_snapshot() -> void:
	if _session == null: return
	var report: Dictionary = _session.reveal_project_snapshot(_selected_snapshot_id())
	_snapshot_status.text = "Opened snapshot folder in Explorer." if report.get("success", false) else str(report.get("errors", ["Reveal failed."])[0])


func _create_appearance() -> void:
	if _session == null: return
	var name := _appearance_name_input.text.strip_edges() if _appearance_name_input != null else ""
	var report: Dictionary = _session.create_appearance_set(name if not name.is_empty() else "Appearance Set")
	_appearance_status.text = "Saved Appearance Set." if report.get("success", false) else str(report.get("errors", ["Could not save Appearance Set."])[0])
	if _appearance_name_input != null: _appearance_name_input.clear()
	_refresh_authoring_sections()


func _apply_appearance() -> void:
	if _session == null: return
	var id := _selected_appearance_id()
	if id.is_empty(): _appearance_status.text = "Select an Appearance Set to apply."; return
	var report: Dictionary = _session.apply_appearance_set(id)
	if report.get("success", false) and _preview_controller != null and is_instance_valid(_preview_controller): _preview_controller.set_appearance_preview("")
	_appearance_status.text = "Applied Appearance Set." if report.get("success", false) else str(report.get("errors", ["Could not apply Appearance Set."])[0])


func _rename_appearance() -> void:
	if _session == null: return
	var id := _selected_appearance_id()
	var name := _appearance_name_input.text.strip_edges() if _appearance_name_input != null else ""
	if id.is_empty() or name.is_empty():
		_appearance_status.text = "Select an Appearance Set and enter its new name."
		return
	_appearance_status.text = "Renamed Appearance Set." if _session.rename_appearance_set(id, name) else "Could not rename Appearance Set."
	_refresh_authoring_sections()


func _preview_appearance() -> void:
	if _session == null: return
	var id := _selected_appearance_id()
	if id.is_empty():
		_appearance_status.text = "Select an Appearance Set to preview."
		return
	if _preview_controller == null or not is_instance_valid(_preview_controller):
		_appearance_status.text = "Canvas preview is unavailable."
		return
	_preview_controller.set_appearance_preview(id)
	_appearance_status.text = "Previewing this Appearance Set in the Canvas. Apply it to make the selection permanent."


func _duplicate_appearance() -> void:
	if _session == null: return
	var id := _selected_appearance_id()
	if id.is_empty(): _appearance_status.text = "Select an Appearance Set to duplicate."; return
	var report: Dictionary = _session.duplicate_appearance_set(id)
	_appearance_status.text = "Duplicated Appearance Set." if report.get("success", false) else str(report.get("errors", ["Could not duplicate Appearance Set."])[0])
	_refresh_authoring_sections()


func _delete_appearance() -> void:
	if _session == null: return
	var id := _selected_appearance_id()
	if id.is_empty(): _appearance_status.text = "Select an Appearance Set to delete."; return
	_appearance_status.text = "Deleted Appearance Set." if _session.delete_appearance_set(id) else "Could not delete Appearance Set."
	_refresh_authoring_sections()


func _confirm_generate_appearances() -> void:
	if _session == null or _generate_appearances_dialog == null: return
	var count: int = int(_appearance_generate_count.value) if _appearance_generate_count != null else 8
	_generate_appearances_dialog.dialog_text = "Create %d deterministic combinations of the parts already imported into this project? No artwork will be generated or duplicated.%s" % [count, " This is above the normal 64-set cap; confirming explicitly approves the larger request." if count > 64 else ""]
	_generate_appearances_dialog.popup_centered()


func _generate_appearances() -> void:
	if _session == null: return
	var count: int = int(_appearance_generate_count.value) if _appearance_generate_count != null else 8
	var report: Dictionary = _session.generate_appearance_sets(count, "Variation", true)
	_appearance_status.text = "Generated %d deterministic imported-art Appearance Sets." % int(report.get("generated", 0)) if report.get("success", false) else str(report.get("errors", ["Could not generate appearances."])[0])
	_refresh_authoring_sections()


func _validate_project() -> void:
	if _session == null: return
	var report: Dictionary = _session.get_readiness_report({"require_clips": false})
	_readiness_status.text = "Ready for review." if report.get("can_export", false) and (report.get("warnings", []) as Array).is_empty() else "%d errors · %d warnings. Fix the next listed issue before export." % [(report.get("errors", []) as Array).size(), (report.get("warnings", []) as Array).size()]


func _auto_repair_all() -> void:
	if _session == null: return
	var report: Dictionary = _session.auto_repair_all()
	if report.get("success", false):
		_readiness_status.text = "Auto Repair created a portable pre-repair snapshot; %d repair%s, %d preserved orphaned track%s." % [(report.get("repaired", []) as Array).size(), "s" if (report.get("repaired", []) as Array).size() != 1 else "", (report.get("muted_orphaned_tracks", []) as Array).size(), "s" if (report.get("muted_orphaned_tracks", []) as Array).size() != 1 else ""]
	else:
		_readiness_status.text = str(report.get("errors", ["Auto Repair failed."])[0])
	_refresh_authoring_sections()


func _selected_provenance_asset_id() -> String:
	var selected := _asset_provenance_list.get_selected_items() if _asset_provenance_list != null else PackedInt32Array()
	return str(_asset_provenance_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""


func _refresh_asset_safety() -> void:
	if _asset_provenance_list == null or _asset_safety_status == null:
		return
	var selected_id := _selected_provenance_asset_id()
	_asset_provenance_list.clear()
	if _session == null or not is_instance_valid(_session):
		return
	var assets: Array = _session.asset_registry.list_assets()
	assets.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	for raw_asset in assets:
		var asset: Dictionary = raw_asset
		var path := str(asset.get("path", ""))
		var label := str(asset.get("name", "Imported asset")) + " · " + str(asset.get("category", "source_art"))
		if path.is_empty() or not FileAccess.file_exists(path): label = "⚠ Missing · " + label
		var index := _asset_provenance_list.add_item(label)
		_asset_provenance_list.set_item_metadata(index, str(asset.get("asset_id", "")))
		if str(asset.get("asset_id", "")) == selected_id: _asset_provenance_list.select(index)
	var audit: Dictionary = _session.get_import_preflight_report()
	var errors := int(audit.get("error_count", 0))
	var warnings := int(audit.get("warning_count", 0))
	_asset_safety_status.text = "Import audit: %d blocking issue%s · %d warning%s. Record art details for assets you plan to hand off." % [errors, "s" if errors != 1 else "", warnings, "s" if warnings != 1 else ""]
	if not selected_id.is_empty():
		for index in range(_asset_provenance_list.item_count):
			if str(_asset_provenance_list.get_item_metadata(index)) == selected_id:
				_inspect_asset_provenance(index)
				break
	else:
		_asset_author_input.clear()
		_asset_license_input.clear()
		_asset_source_input.clear()


func _inspect_asset_provenance(index: int) -> void:
	if _session == null or _asset_provenance_list == null or index < 0: return
	var asset_id := str(_asset_provenance_list.get_item_metadata(index))
	var provenance: Dictionary = _session.get_asset_provenance(asset_id)
	_asset_author_input.text = str(provenance.get("author", ""))
	_asset_license_input.text = str(provenance.get("license", ""))
	_asset_source_input.text = str(provenance.get("source_reference", ""))


func _save_asset_provenance() -> void:
	if _session == null: return
	var asset_id := _selected_provenance_asset_id()
	if asset_id.is_empty():
		_asset_safety_status.text = "Select an imported asset before recording its art details."
		return
	var changed: bool = bool(_session.set_asset_provenance(asset_id, {"author": _asset_author_input.text, "license": _asset_license_input.text, "source_reference": _asset_source_input.text}))
	_asset_safety_status.text = "Saved art details for the selected asset." if changed else "Art details were unchanged or this project is read-only."
	_refresh_authoring_sections()


func _audit_imported_assets() -> void:
	if _session == null: return
	var report: Dictionary = _session.get_import_preflight_report()
	var errors := int(report.get("error_count", 0))
	var warnings := int(report.get("warning_count", 0))
	var first: Dictionary = (report.get("errors", [])[0] as Dictionary) if not (report.get("errors", []) as Array).is_empty() else ((report.get("warnings", [])[0] as Dictionary) if not (report.get("warnings", []) as Array).is_empty() else {})
	_asset_safety_status.text = "Import audit: %d blocking issue%s · %d warning%s%s" % [errors, "s" if errors != 1 else "", warnings, "s" if warnings != 1 else "", " · " + str(first.get("message", "")) if not first.is_empty() else " · all imported files look good"]


func _refresh_project_scale() -> void:
	if _scale_status == null: return
	if _session == null or not is_instance_valid(_session): return
	var report: Dictionary = _session.get_project_scale_report()
	_scale_status.text = ProjectScaleAdvisorScript.format_summary(report)


func _analyze_project_scale() -> void:
	if _session == null: return
	var report: Dictionary = _session.get_project_scale_report()
	var recommendations: Array = report.get("recommendations", []) as Array
	_scale_status.text = ProjectScaleAdvisorScript.format_summary(report) + (" · " + str(recommendations[0]) if not recommendations.is_empty() else "")


func _create_support_bundle() -> void:
	var report: Dictionary = SupportBundleExporterScript.new().create_bundle(_session)
	if bool(report.get("success", false)):
		_last_support_bundle = str(report.get("zip", ""))
		_support_status.text = "Created a local support ZIP. It contains no imported artwork or audio and was not uploaded."
		var reveal := find_child("RevealSupportBundle", true, false) as BaseButton
		if reveal != null: reveal.disabled = _last_support_bundle.is_empty()
	else:
		_support_status.text = str(report.get("errors", ["Could not create the local support bundle."])[0])


func _reveal_support_bundle() -> void:
	if _last_support_bundle.is_empty(): return
	var absolute := ProjectSettings.globalize_path(_last_support_bundle) if _last_support_bundle.begins_with("res://") or _last_support_bundle.begins_with("user://") else _last_support_bundle
	if OS.shell_open(absolute.get_base_dir()) != OK:
		_support_status.text = "Could not open the support-bundle folder."


func _route_wizard_step(workspace_id: String, panel_id: String) -> void:
	if WorkspaceManager != null: WorkspaceManager.switch_workspace(workspace_id)
	var manager := WorkspaceManager.get_dock_layout_manager() if WorkspaceManager != null else null
	if manager != null and not panel_id.is_empty():
		manager.call("set_panel_visible", panel_id, true)
		manager.call("activate_panel", panel_id)


func _on_session_changed(_description: String) -> void:
	_refresh_authoring_sections()
