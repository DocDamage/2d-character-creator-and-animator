# Unit Test Suite — APP-007 Theme and DPI Scaling
extends Node

const MainWindowScene = preload("res://app/shared_ui/main_window.tscn")

var _pass_count: int = 0
var _fail_count: int = 0

func run_all_tests() -> bool:
	_pass_count = 0
	_fail_count = 0
	print("\n[TEST 11] Theme Service & DPI Scaling Workflows...")
	
	test_theme_service_initialization()
	test_theme_mode_switching()
	test_theme_color_tokens()
	test_dpi_scale_management()
	test_dpi_scale_clamping()
	test_dpi_scale_cycling()
	test_theme_settings_export_import()
	test_command_palette_shortcuts()
	test_main_window_theme_integration()
	
	return _fail_count == 0

func _assert(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: " + message)
	else:
		_fail_count += 1
		print("  FAIL: " + message)

func test_theme_service_initialization() -> void:
	_assert(ThemeService != null, "ThemeService autoload is available.")
	if ThemeService != null:
		_assert(ThemeService.get_theme_mode_name() == "DARK" or ThemeService.get_theme_mode_name() == "LIGHT", "ThemeService initializes with valid theme mode.")
		_assert(ThemeService.get_dpi_scale() >= 1.0 and ThemeService.get_dpi_scale() <= 2.0, "ThemeService initializes with DPI scale in valid range.")
		_assert(ThemeService.get_current_theme() != null, "ThemeService provides valid Theme resource.")

var _last_theme_signal_mode: String = ""
var _theme_signal_received: bool = false
var _last_dpi_signal_scale: float = 0.0
var _dpi_signal_received: bool = false

func _on_theme_changed_signal(mode_name: String, _theme: Theme) -> void:
	_theme_signal_received = true
	_last_theme_signal_mode = mode_name

func _on_dpi_scale_changed_signal(scale_factor: float) -> void:
	_dpi_signal_received = true
	_last_dpi_signal_scale = scale_factor

func test_theme_mode_switching() -> void:
	if ThemeService == null:
		return
	ThemeService.set_theme_mode(ThemeService.ThemeMode.DARK)
	_theme_signal_received = false
	_last_theme_signal_mode = ""
	
	if not ThemeService.theme_changed.is_connected(_on_theme_changed_signal):
		ThemeService.theme_changed.connect(_on_theme_changed_signal)
	
	ThemeService.set_theme_mode(ThemeService.ThemeMode.LIGHT)
	_assert(ThemeService.get_theme_mode() == ThemeService.ThemeMode.LIGHT, "Theme mode set to LIGHT.")
	_assert(ThemeService.get_theme_mode_name() == "LIGHT", "Theme mode name returns 'LIGHT'.")
	_assert(_theme_signal_received and _last_theme_signal_mode == "LIGHT", "theme_changed signal emitted for LIGHT mode.")
	
	_theme_signal_received = false
	ThemeService.toggle_theme_mode()
	_assert(ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK, "toggle_theme_mode switches back to DARK.")
	_assert(_theme_signal_received and _last_theme_signal_mode == "DARK", "theme_changed signal emitted for DARK mode.")
	
	if ThemeService.theme_changed.is_connected(_on_theme_changed_signal):
		ThemeService.theme_changed.disconnect(_on_theme_changed_signal)

func test_theme_color_tokens() -> void:
	if ThemeService == null:
		return
	ThemeService.set_theme_mode(ThemeService.ThemeMode.DARK)
	var dark_bg := ThemeService.get_color_token("bg_main")
	var dark_panel := ThemeService.get_color_token("bg_panel")
	var dark_text := ThemeService.get_color_token("text_primary")
	
	ThemeService.set_theme_mode(ThemeService.ThemeMode.LIGHT)
	var light_bg := ThemeService.get_color_token("bg_main")
	var light_panel := ThemeService.get_color_token("bg_panel")
	var light_text := ThemeService.get_color_token("text_primary")
	
	_assert(dark_bg != light_bg, "bg_main color differs between DARK and LIGHT modes.")
	_assert(dark_panel != light_panel, "bg_panel color differs between DARK and LIGHT modes.")
	_assert(dark_text != light_text, "text_primary color differs between DARK and LIGHT modes.")
	
	ThemeService.set_theme_mode(ThemeService.ThemeMode.DARK)

func test_dpi_scale_management() -> void:
	if ThemeService == null:
		return
	ThemeService.set_dpi_scale(1.0)
	_dpi_signal_received = false
	_last_dpi_signal_scale = 0.0
	
	if not ThemeService.dpi_scale_changed.is_connected(_on_dpi_scale_changed_signal):
		ThemeService.dpi_scale_changed.connect(_on_dpi_scale_changed_signal)
	
	ThemeService.set_dpi_scale(1.5)
	_assert(absf(ThemeService.get_dpi_scale() - 1.5) < 0.001, "DPI scale set to 150%.")
	_assert(_dpi_signal_received and absf(_last_dpi_signal_scale - 1.5) < 0.001, "dpi_scale_changed signal emitted with 1.5.")
	
	if ThemeService.dpi_scale_changed.is_connected(_on_dpi_scale_changed_signal):
		ThemeService.dpi_scale_changed.disconnect(_on_dpi_scale_changed_signal)

func test_dpi_scale_clamping() -> void:
	if ThemeService == null:
		return
	ThemeService.set_dpi_scale(0.5)
	_assert(absf(ThemeService.get_dpi_scale() - 1.0) < 0.001, "Under-bound DPI scale 0.5 clamped to 1.0.")
	
	ThemeService.set_dpi_scale(3.0)
	_assert(absf(ThemeService.get_dpi_scale() - 2.0) < 0.001, "Over-bound DPI scale 3.0 clamped to 2.0.")
	
	ThemeService.set_dpi_scale(1.0)

func test_dpi_scale_cycling() -> void:
	if ThemeService == null:
		return
	ThemeService.set_dpi_scale(1.0)
	var step1 := ThemeService.cycle_dpi_scale()
	_assert(absf(step1 - 1.25) < 0.001, "cycle_dpi_scale advances from 1.0 to 1.25.")
	var step2 := ThemeService.cycle_dpi_scale()
	_assert(absf(step2 - 1.5) < 0.001, "cycle_dpi_scale advances from 1.25 to 1.5.")
	
	ThemeService.set_dpi_scale(2.0)
	var step_wrap := ThemeService.cycle_dpi_scale()
	_assert(absf(step_wrap - 1.0) < 0.001, "cycle_dpi_scale wraps around from 2.0 to 1.0.")

func test_theme_settings_export_import() -> void:
	if ThemeService == null:
		return
	ThemeService.set_theme_mode(ThemeService.ThemeMode.LIGHT)
	ThemeService.set_dpi_scale(1.75)
	
	var exported := ThemeService.export_settings()
	_assert(exported.has("theme_mode") and exported["theme_mode"] == "LIGHT", "Export contains theme_mode 'LIGHT'.")
	_assert(exported.has("dpi_scale") and absf(float(exported["dpi_scale"]) - 1.75) < 0.001, "Export contains dpi_scale 1.75.")
	
	ThemeService.set_theme_mode(ThemeService.ThemeMode.DARK)
	ThemeService.set_dpi_scale(1.0)
	
	var success := ThemeService.import_settings(exported)
	_assert(success, "import_settings returns true.")
	_assert(ThemeService.get_theme_mode() == ThemeService.ThemeMode.LIGHT, "Import restored LIGHT theme mode.")
	_assert(absf(ThemeService.get_dpi_scale() - 1.75) < 0.001, "Import restored 1.75 DPI scale.")

func test_command_palette_shortcuts() -> void:
	if ShortcutRegistry == null:
		return
	_assert(ShortcutRegistry.has_command("view.toggle_theme"), "view.toggle_theme command registered.")
	_assert(ShortcutRegistry.has_command("view.set_dpi_scale"), "view.set_dpi_scale command registered.")
	
	var prev_mode := ThemeService.get_theme_mode_name()
	ShortcutRegistry.execute_command("view.toggle_theme")
	_assert(ThemeService.get_theme_mode_name() != prev_mode, "Executing view.toggle_theme changed theme mode.")

func test_main_window_theme_integration() -> void:
	var win: Node = MainWindowScene.instantiate()
	add_child(win)
	_assert(win != null, "MainWindow instantiated for theme integration test.")
	
	win.call("_cmd_toggle_theme")
	_assert((win.call("get_status_message") as String).contains("Switched theme mode to:"), "MainWindow status updated on _cmd_toggle_theme.")
	
	win.call("_cmd_cycle_dpi_scale")
	_assert((win.call("get_status_message") as String).contains("DPI scale set to:"), "MainWindow status updated on _cmd_cycle_dpi_scale.")
	
	win.queue_free()
