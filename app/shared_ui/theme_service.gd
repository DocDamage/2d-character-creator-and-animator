# Theme Service — Autoload service for managing dark/light theme switching and DPI scale
extends Node

signal theme_changed(mode_name: String, theme: Theme)
signal dpi_scale_changed(scale_factor: float)

enum ThemeMode { DARK = 0, LIGHT = 1 }

const SCALE_PRESETS: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]

var _current_mode: ThemeMode = ThemeMode.DARK
var _dpi_scale: float = 1.0
var _dark_theme: Theme = null
var _light_theme: Theme = null
var _high_contrast: bool = false
var _reduced_motion: bool = false

func _ready() -> void:
	_dark_theme = _build_dark_theme()
	_light_theme = _build_light_theme()
	_apply_current_theme()

func set_theme_mode(mode: int) -> void:
	var target_mode: ThemeMode = ThemeMode.LIGHT if mode == ThemeMode.LIGHT else ThemeMode.DARK
	if _current_mode == target_mode and get_current_theme() != null:
		return
	_current_mode = target_mode
	_apply_current_theme()
	theme_changed.emit(get_theme_mode_name(), get_current_theme())
	if DiagnosticsService != null:
		DiagnosticsService.info("Theme mode set to: " + get_theme_mode_name(), "ThemeService")

func get_theme_mode() -> ThemeMode:
	return _current_mode

func get_theme_mode_name() -> String:
	return "LIGHT" if _current_mode == ThemeMode.LIGHT else "DARK"

func toggle_theme_mode() -> void:
	if _current_mode == ThemeMode.DARK:
		set_theme_mode(ThemeMode.LIGHT)
	else:
		set_theme_mode(ThemeMode.DARK)

func get_current_theme() -> Theme:
	return _light_theme if _current_mode == ThemeMode.LIGHT else _dark_theme

func set_high_contrast(enabled: bool) -> void:
	if _high_contrast == enabled: return
	_high_contrast = enabled
	_dark_theme = _build_dark_theme(); _light_theme = _build_light_theme(); _apply_current_theme()
func is_high_contrast() -> bool: return _high_contrast
func set_reduced_motion(enabled: bool) -> void: _reduced_motion = enabled
func is_reduced_motion() -> bool: return _reduced_motion

func set_dpi_scale(scale_factor: float) -> void:
	var clamped_scale := clampf(scale_factor, 1.0, 2.0)
	if absf(_dpi_scale - clamped_scale) < 0.001:
		return
	_dpi_scale = clamped_scale
	_apply_dpi_scale()
	dpi_scale_changed.emit(_dpi_scale)
	if DiagnosticsService != null:
		DiagnosticsService.info("DPI scale set to: %.0f%%" % (_dpi_scale * 100.0), "ThemeService")

func get_dpi_scale() -> float:
	return _dpi_scale

func cycle_dpi_scale() -> float:
	var next_idx := 0
	for i in range(SCALE_PRESETS.size()):
		if _dpi_scale < SCALE_PRESETS[i] - 0.05:
			next_idx = i
			break
	if _dpi_scale >= SCALE_PRESETS[SCALE_PRESETS.size() - 1] - 0.05:
		next_idx = 0
	set_dpi_scale(SCALE_PRESETS[next_idx])
	return _dpi_scale

func apply_to_window(window: Window) -> void:
	if window == null:
		return
	window.theme = get_current_theme()
	window.content_scale_factor = _dpi_scale

func get_color_token(token_name: String) -> Color:
	var is_dark := (_current_mode == ThemeMode.DARK)
	match token_name:
		"bg_main": return Color("#18181c") if is_dark else Color("#f4f4f7")
		"bg_panel": return Color("#222228") if is_dark else Color("#ffffff")
		"bg_header": return Color("#141418") if is_dark else Color("#e8e8ee")
		"text_primary": return Color("#f0f0f5") if is_dark else Color("#1a1a20")
		"text_secondary": return Color("#a0a0b0") if is_dark else Color("#606070")
		"accent": return (Color.WHITE if is_dark else Color.BLACK) if _high_contrast else (Color("#4f80ff") if is_dark else Color("#2b66ff"))
		"border": return Color("#333340") if is_dark else Color("#d0d0da")
		"selection": return Color("#2a4480") if is_dark else Color("#c5d8ff")
		_: return Color.WHITE if is_dark else Color.BLACK

func export_settings() -> Dictionary:
	return {
		"theme_mode": get_theme_mode_name(),
		"dpi_scale": _dpi_scale, "high_contrast": _high_contrast, "reduced_motion": _reduced_motion
	}

func import_settings(data: Dictionary) -> bool:
	if data == null:
		return false
	if data.has("theme_mode"):
		var m_str: String = String(data["theme_mode"]).to_upper()
		set_theme_mode(ThemeMode.LIGHT if m_str == "LIGHT" else ThemeMode.DARK)
	if data.has("dpi_scale"):
		set_dpi_scale(float(data["dpi_scale"]))
	if data.has("high_contrast"): set_high_contrast(bool(data["high_contrast"]))
	if data.has("reduced_motion"): set_reduced_motion(bool(data["reduced_motion"]))
	return true

func _apply_current_theme() -> void:
	var win := get_window()
	if win != null:
		win.theme = get_current_theme()

func _apply_dpi_scale() -> void:
	var win := get_window()
	if win != null:
		win.content_scale_factor = _dpi_scale

func _build_dark_theme() -> Theme:
	var t := Theme.new()
	var panel := Color("#11141b")
	var raised := Color("#161921")
	var header := Color("#0c0e14")
	var text_col := Color("#ebf0fa")
	var muted := Color("#8f9cb2")
	var border := Color("#292e3b")
	var accent := Color.WHITE if _high_contrast else Color("#8240f5")
	var accent_border := Color.WHITE if _high_contrast else Color("#ad73ff")

	_style_theme_flat_box(t, "Panel", panel, border, 10)
	_style_theme_flat_box(t, "PanelContainer", panel, border, 10)
	_style_theme_button(t, raised, Color("#202633"), accent, text_col, border, 8)
	_style_theme_button(t, accent, Color("#975cf8"), Color("#6931cc"), Color.WHITE, accent_border, 8, "PrimaryButton")
	_style_theme_line_edit(t, raised, text_col, accent, border)
	_style_theme_item_list(t, raised, text_col, muted, border, accent)
	_style_theme_tabs(t, panel, raised, accent, text_col, muted, border, accent_border)
	t.set_color("font_color", "Label", text_col)
	t.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	t.set_color("font_color", "Button", text_col)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_color", "OptionButton", text_col)
	t.set_color("font_color", "CheckBox", text_col)
	t.set_color("font_color", "MenuBar", muted)
	t.set_color("font_color", "TabBar", muted)
	t.set_color("font_selected_color", "TabBar", text_col)
	t.set_color("font_color", "RichTextLabel", text_col)
	t.set_color("font_uneditable_color", "LineEdit", muted)
	t.set_color("font_color", "SpinBox", text_col)
	t.set_color("font_color", "TextEdit", text_col)
	t.set_color("font_color", "PopupMenu", text_col)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_color", "Tree", text_col)
	t.set_color("font_selected_color", "Tree", text_col)
	t.set_color("font_color", "GraphEdit", text_col)
	t.set_color("font_color", "GraphNode", text_col)
	t.set_color("font_color", "ItemList", text_col)
	t.set_color("font_selected_color", "ItemList", text_col)
	t.set_constant("outline_size", "Label", 0)
	t.set_font_size("font_size", "Label", 14)
	t.set_font_size("font_size", "Button", 13)
	t.set_stylebox("panel", "GraphEdit", _box(Color("#0e1116"), border, 12))
	t.set_stylebox("panel", "GraphNode", _box(raised, border, 8))
	t.set_stylebox("panel", "TextEdit", _box(raised, border, 8))
	t.set_stylebox("normal", "OptionButton", _box(raised, border, 8))
	t.set_stylebox("hover", "OptionButton", _box(Color("#202633"), border, 8))
	t.set_stylebox("pressed", "OptionButton", _box(accent, accent_border, 8))
	return t

func _build_light_theme() -> Theme:
	var t := Theme.new()
	var bg_panel := Color("#ffffff")
	var text_col := Color("#1a1a20")
	var border_col := Color("#d0d0da")
	var accent_col := Color.BLACK if _high_contrast else Color("#2b66ff")
	
	_style_theme_flat_box(t, "Panel", bg_panel, border_col)
	_style_theme_flat_box(t, "PanelContainer", bg_panel, border_col)
	_style_theme_button(t, Color("#eef0f5"), Color("#dfe3ec"), accent_col, text_col, border_col)
	_style_theme_line_edit(t, Color("#f8f9fc"), text_col, accent_col, border_col)
	t.set_color("font_color", "Label", text_col)
	return t

func _style_theme_flat_box(t: Theme, item_type: String, bg: Color, border: Color, radius: int = 4) -> void:
	t.set_stylebox("panel", item_type, _box(bg, border, radius))

func _style_theme_button(t: Theme, normal_bg: Color, hover_bg: Color, pressed_bg: Color, text_col: Color, border: Color, radius: int = 4, variation: StringName = &"Button") -> void:
	t.set_stylebox("normal", variation, _box(normal_bg, border, radius))
	t.set_stylebox("hover", variation, _box(hover_bg, border, radius))
	t.set_stylebox("pressed", variation, _box(pressed_bg, border, radius))
	t.set_stylebox("disabled", variation, _box(normal_bg.darkened(0.25), border.darkened(0.2), radius))
	t.set_color("font_color", variation, text_col)
	t.set_color("font_hover_color", variation, text_col)
	t.set_color("font_pressed_color", variation, text_col)

func _style_theme_line_edit(t: Theme, bg: Color, text_col: Color, _accent: Color, border: Color) -> void:
	t.set_stylebox("normal", "LineEdit", _box(bg, border, 8))
	t.set_stylebox("focus", "LineEdit", _box(bg, _accent, 8, 2))
	t.set_color("font_color", "LineEdit", text_col)


func _style_theme_item_list(t: Theme, bg: Color, text_col: Color, muted: Color, border: Color, accent: Color) -> void:
	t.set_stylebox("panel", "ItemList", _box(bg, border, 8))
	t.set_stylebox("selected", "ItemList", _box(accent, accent.lightened(0.28), 6))
	t.set_stylebox("selected_focus", "ItemList", _box(accent, accent.lightened(0.28), 6))
	t.set_color("font_color", "ItemList", text_col)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("font_outline_color", "ItemList", muted)


func _style_theme_tabs(t: Theme, panel: Color, raised: Color, accent: Color, text_col: Color, muted: Color, border: Color, accent_border: Color) -> void:
	t.set_stylebox("panel", "TabContainer", _box(panel, border, 10))
	t.set_stylebox("tab_selected", "TabContainer", _box(accent, accent_border, 8))
	t.set_stylebox("tab_unselected", "TabContainer", _box(raised, border, 8))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color("#202633"), border, 8))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", muted)
	t.set_color("font_hovered_color", "TabContainer", text_col)


func _box(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10.0
	box.content_margin_top = 6.0
	box.content_margin_right = 10.0
	box.content_margin_bottom = 6.0
	return box
