# Unit Test Suite — APP-007 Theme and DPI Scaling
extends Node

const MainWindowScene = preload("res://app/shared_ui/main_window.tscn")
const PaperButtonScene = preload("res://app/shared_ui/paper_quest/paper_button.tscn")
const StatusChipScene = preload("res://app/shared_ui/paper_quest/status_chip.tscn")
const ProjectHubScene = preload("res://app/bootstrap/project_hub_panel.tscn")

var _pass_count: int = 0
var _fail_count: int = 0

func run_all_tests() -> bool:
	_pass_count = 0
	_fail_count = 0
	print("\n[TEST 11] Theme Service & DPI Scaling Workflows...")
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	
	test_theme_service_initialization()
	test_theme_mode_switching()
	test_theme_color_tokens()
	test_dpi_scale_management()
	test_dpi_scale_clamping()
	test_dpi_scale_cycling()
	test_theme_settings_export_import()
	test_paper_quest_appearance_modes()
	test_paper_quest_native_components()
	test_command_palette_shortcuts()
	test_main_window_theme_integration()
	test_responsive_layout_matrix()
	
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	ThemeService.set_dpi_scale(1.0)
	ThemeService.set_reduced_motion(false)
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
		_assert(ThemeService.get_default_appearance_mode() == ThemeService.AppearanceMode.OBSIDIAN, "The configured first-run appearance is Obsidian Studio.")
		_assert(ThemeService.get_appearance_mode() == ThemeService.AppearanceMode.OBSIDIAN, "Obsidian Studio is the default appearance.")
		_assert(ThemeService.get_appearance_mode_name() == "Obsidian Studio", "Default appearance has the expected user-facing name.")
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
	_assert(ThemeService.get_appearance_mode() == ThemeService.AppearanceMode.OBSIDIAN, "DARK compatibility mode selects Obsidian Studio.")
	_theme_signal_received = false
	_last_theme_signal_mode = ""
	
	if not ThemeService.theme_changed.is_connected(_on_theme_changed_signal):
		ThemeService.theme_changed.connect(_on_theme_changed_signal)
	
	ThemeService.set_theme_mode(ThemeService.ThemeMode.LIGHT)
	_assert(ThemeService.get_theme_mode() == ThemeService.ThemeMode.LIGHT, "Theme mode set to LIGHT.")
	_assert(ThemeService.get_appearance_mode() == ThemeService.AppearanceMode.PAPER_QUEST, "LIGHT compatibility mode selects Paper Quest Classic.")
	_assert(ThemeService.get_theme_mode_name() == "LIGHT", "Theme mode name returns 'LIGHT'.")
	_assert(_theme_signal_received and _last_theme_signal_mode == "LIGHT", "theme_changed signal emitted for LIGHT mode.")
	
	_theme_signal_received = false
	ThemeService.toggle_theme_mode()
	_assert(ThemeService.get_appearance_mode() == ThemeService.AppearanceMode.OBSIDIAN, "toggle_theme_mode switches back to Obsidian Studio.")
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
	_assert(exported.get("appearance_id") == "paper_quest", "Export contains the stable Paper Quest appearance identifier.")
	_assert(exported.has("dpi_scale") and absf(float(exported["dpi_scale"]) - 1.75) < 0.001, "Export contains dpi_scale 1.75.")
	
	ThemeService.set_theme_mode(ThemeService.ThemeMode.DARK)
	ThemeService.set_dpi_scale(1.0)
	
	var success := ThemeService.import_settings(exported)
	_assert(success, "import_settings returns true.")
	_assert(ThemeService.get_theme_mode() == ThemeService.ThemeMode.LIGHT, "Import restored LIGHT theme mode.")
	_assert(ThemeService.get_appearance_mode_name() == "Paper Quest Classic", "Import restored the selected named appearance.")
	_assert(absf(ThemeService.get_dpi_scale() - 1.75) < 0.001, "Import restored 1.75 DPI scale.")

func test_paper_quest_appearance_modes() -> void:
	if ThemeService == null:
		return
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	_assert(ThemeService.get_appearance_mode_name() == "Obsidian Studio", "The new Obsidian UI is selectable.")
	_assert(not ThemeService.uses_paper_texture(), "Obsidian Studio removes the decorative kraft texture.")
	var obsidian_bg := ThemeService.get_color_token("bg_main")
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.PAPER_QUEST)
	_assert(ThemeService.get_appearance_mode_name() == "Paper Quest Classic", "The original light UI remains selectable.")
	_assert(ThemeService.uses_paper_texture(), "Paper Quest Classic restores the decorative kraft texture.")
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.DARK_CRAFT)
	_assert(ThemeService.get_appearance_mode_name() == "Dark Craft", "The original dark craft UI remains selectable.")
	_assert(ThemeService.get_color_token("bg_main") != obsidian_bg, "Dark Craft retains its brown palette instead of the Obsidian palette.")
	ThemeService.set_high_contrast(true)
	_assert(ThemeService.get_appearance_mode_name() == "High Contrast", "High Contrast is exposed as a distinct appearance.")
	_assert(ThemeService.get_color_token("bg_main") == Color.BLACK, "High Contrast uses a texture-free black shell token.")
	var exported := ThemeService.export_settings()
	_assert(exported.get("appearance_mode") == "High Contrast", "Appearance export records the semantic mode.")
	ThemeService.import_settings({"theme_mode": "LIGHT", "dpi_scale": 1.0, "high_contrast": false, "reduced_motion": false})
	_assert(ThemeService.get_appearance_mode_name() == "Paper Quest Classic", "Legacy LIGHT settings import into the original UI without data loss.")
	ThemeService.import_settings({"appearance_mode": "Dark Craft", "high_contrast": false})
	_assert(ThemeService.get_appearance_mode() == ThemeService.AppearanceMode.DARK_CRAFT, "Legacy Dark Craft settings retain their original palette.")
	_assert(ThemeService.get_appearance_options().size() == 4, "All four appearances are exposed to UI pickers.")
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	ThemeService.cycle_appearance_mode()
	_assert(ThemeService.get_appearance_mode() == ThemeService.AppearanceMode.PAPER_QUEST, "Appearance cycling follows the visible picker order.")

func test_paper_quest_native_components() -> void:
	var button := PaperButtonScene.instantiate() as Button
	add_child(button)
	_assert(button.custom_minimum_size.x >= 40.0 and button.custom_minimum_size.y >= 40.0, "Paper button preserves the 40 px interaction target.")
	_assert(button.focus_mode == Control.FOCUS_ALL, "Paper button is keyboard and controller focusable.")
	var chip := StatusChipScene.instantiate() as PanelContainer
	add_child(chip)
	chip.call("set_status", "Missing source", PaperQuestStatusChip.Status.ERROR)
	var chip_text := chip.get_node("Margin/Row/Text") as Label
	_assert(chip_text.text == "Missing source" and chip.tooltip_text.contains("Error"), "Status chip pairs real text with a semantic error description.")
	var hub := ProjectHubScene.instantiate() as Control
	add_child(hub)
	var create_button := hub.get_node("Margin/Root/Content/Left/Actions/Margin/VBox/CreateButton") as Button
	_assert(create_button.focus_mode == Control.FOCUS_ALL and create_button.custom_minimum_size.y >= 40.0, "Project hub quick actions remain native focusable controls.")
	button.queue_free()
	chip.queue_free()
	hub.queue_free()

func test_command_palette_shortcuts() -> void:
	if ShortcutRegistry == null:
		return
	_assert(ShortcutRegistry.has_command("view.toggle_theme"), "view.toggle_theme command registered.")
	_assert(ShortcutRegistry.has_command("view.set_dpi_scale"), "view.set_dpi_scale command registered.")
	
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	var prev_mode := ThemeService.get_appearance_mode()
	ShortcutRegistry.execute_command("view.toggle_theme")
	_assert(ThemeService.get_appearance_mode() != prev_mode, "Executing view.toggle_theme changed appearance.")

func test_main_window_theme_integration() -> void:
	var win: Node = MainWindowScene.instantiate()
	add_child(win)
	_assert(win != null, "MainWindow instantiated for theme integration test.")
	var picker := win.get_node_or_null("RootVBox/TopHeaderBar/MoreButton") as OptionButton
	_assert(picker != null and picker.item_count == 4, "Main window exposes every appearance in its theme picker.")
	
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	win.call("_cmd_toggle_theme")
	_assert((win.call("get_status_message") as String).contains("Appearance: Paper Quest Classic"), "MainWindow status names the selected classic appearance.")
	
	win.call("_cmd_cycle_dpi_scale")
	_assert((win.call("get_status_message") as String).contains("DPI scale set to:"), "MainWindow status updated on _cmd_cycle_dpi_scale.")
	
	win.queue_free()


func test_responsive_layout_matrix() -> void:
	var win := MainWindowScene.instantiate() as Control
	add_child(win)
	var navigation := win.get_node_or_null("RootVBox/TopHeaderBar/WorkspaceNavigation") as Control
	var cases := [
		{"name": "1280×720", "size": Vector2(1280, 720), "scale": 1.0, "mode": "compact"},
		{"name": "1366×768", "size": Vector2(1366, 768), "scale": 1.0, "mode": "medium"},
		{"name": "ultrawide", "size": Vector2(3440, 1440), "scale": 1.0, "mode": "wide"},
		{"name": "4K", "size": Vector2(3840, 2160), "scale": 1.0, "mode": "wide"},
		{"name": "125%", "size": Vector2(1366, 768), "scale": 1.25, "mode": "compact"},
		{"name": "150%", "size": Vector2(1366, 768), "scale": 1.5, "mode": "compact"},
		{"name": "200%", "size": Vector2(3840, 2160), "scale": 2.0, "mode": "wide"},
	]
	for case_data in cases:
		var info: Dictionary = case_data
		var size: Vector2 = info.get("size", Vector2.ZERO)
		var scale := float(info.get("scale", 1.0))
		var state: Dictionary = win.call("apply_responsive_layout_for_size", size, scale)
		var nav_state: Dictionary = navigation.call("apply_responsive_navigation_for_width", size.x, scale) if navigation != null else {}
		var expected := str(info.get("mode", "wide"))
		var mode_matches := str(state.get("mode", "")) == expected
		var compact_safe := expected == "wide" or (not bool(state.get("command_palette_visible", true)) and bool(nav_state.get("overflow_visible", false)) and float(state.get("header_height", 0.0)) <= 64.0)
		var wide_safe := expected != "wide" or (bool(state.get("command_palette_visible", false)) and not bool(nav_state.get("overflow_visible", true)) and (nav_state.get("hidden_buttons", []) as Array).is_empty())
		_assert(mode_matches and compact_safe and wide_safe, "%s layout keeps header controls and workspace navigation uncrowded at %.0f%% scaling." % [str(info.get("name", "viewport")), scale * 100.0])
	win.queue_free()
