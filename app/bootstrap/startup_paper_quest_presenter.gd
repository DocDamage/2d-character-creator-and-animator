class_name StartupPaperQuestPresenter
extends Node

@onready var _startup: Control = get_parent() as Control
@onready var _startup_chip: PaperQuestStatusChip = _startup.get_node("MarginContainer/MainLayout/Header/HeaderRight/StartupStateChip")
@onready var _health_chip: PaperQuestStatusChip = _startup.get_node("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/HealthChip")
@onready var _health_copy: Label = _startup.get_node("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/HealthCopy")
@onready var _summary: Label = _startup.get_node("MarginContainer/MainLayout/Greeting/StartupSummary")
@onready var _project_title: Label = _startup.get_node("MarginContainer/MainLayout/ContentSplit/CurrentProject/Margin/VBox/CurrentProjectTitle")
@onready var _project_path: Label = _startup.get_node("MarginContainer/MainLayout/ContentSplit/CurrentProject/Margin/VBox/CurrentProjectPath")
@onready var _validation: Label = _startup.get_node("MarginContainer/MainLayout/Overview/OverviewVBox/Metrics/Validation")
@onready var _autosave: Label = _startup.get_node("MarginContainer/MainLayout/Overview/OverviewVBox/Metrics/Autosave")
@onready var _texture: TextureRect = _startup.get_node("BackgroundTexture")

func _ready() -> void:
	if ThemeService != null:
		_startup.theme = ThemeService.get_current_theme()
	_startup.startup_completed.connect(_on_startup_completed)
	if RecentProjectsService != null:
		RecentProjectsService.recent_projects_changed.connect(_refresh_project)
	if AppState != null:
		AppState.project_opened.connect(func(_path): _refresh_project())
		AppState.project_closed.connect(_refresh_project)
	if ThemeService != null:
		ThemeService.theme_changed.connect(_on_theme_changed)
	_refresh_project()
	_refresh_appearance()
	_refresh_autosave()

func _on_startup_completed(success: bool, errors: Array[String]) -> void:
	var passed := _startup.call("get_passed_checks_count") as int
	var total := _startup.call("get_total_checks_count") as int
	if success:
		_startup_chip.set_status("Studio ready", PaperQuestStatusChip.Status.READY)
		_health_chip.set_status("%d/%d checks passed" % [passed, total], PaperQuestStatusChip.Status.READY)
		_health_copy.text = "Core services, project resources, and required folders are available."
		_summary.text = "All %d startup checks passed" % total
		_validation.text = "DIAGNOSTICS  ·  %d/%d passed" % [passed, total]
	else:
		_startup_chip.set_status("Attention needed", PaperQuestStatusChip.Status.ERROR)
		_health_chip.set_status("%d startup issues" % errors.size(), PaperQuestStatusChip.Status.ERROR)
		_health_copy.text = errors[0] if not errors.is_empty() else "Review diagnostics before continuing."
		_summary.text = "%d startup checks need attention" % errors.size()
		_validation.text = "DIAGNOSTICS  ·  %d issues" % errors.size()

func _refresh_project() -> void:
	var projects: Array[Dictionary] = RecentProjectsService.get_recent_projects() if RecentProjectsService != null else []
	if AppState != null and AppState.is_project_loaded():
		var path := AppState.get_project_path()
		_project_title.text = path.get_file().get_basename().capitalize()
		_project_path.text = path
	elif not projects.is_empty():
		_project_title.text = String(projects[0].get("title", "Recent quest"))
		_project_path.text = String(projects[0].get("path", ""))
	else:
		_project_title.text = "Choose your next quest"
		_project_path.text = "Your most recent project will appear here."

func _refresh_autosave() -> void:
	var enabled := AppState != null and AppState.is_autosave_enabled()
	_autosave.text = "AUTOSAVE  ·  " + ("Enabled" if enabled else "Disabled")

func _refresh_appearance() -> void:
	if ThemeService != null:
		_texture.visible = not ThemeService.is_high_contrast()
		_texture.modulate.a = 0.20 if ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK else 0.46

func _on_theme_changed(_mode: String, new_theme: Theme) -> void:
	_startup.theme = new_theme
	_refresh_appearance()
