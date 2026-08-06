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
	var bg_panel := Color("#222228")
	var text_col := Color("#f0f0f5")
	var border_col := Color("#333340")
	var accent_col := Color.WHITE if _high_contrast else Color("#4f80ff")
	
	_style_theme_flat_box(t, "Panel", bg_panel, border_col)
	_style_theme_flat_box(t, "PanelContainer", bg_panel, border_col)
	_style_theme_button(t, Color("#2c2c36"), Color("#3a3a48"), accent_col, text_col, border_col)
	_style_theme_line_edit(t, Color("#1a1a20"), text_col, accent_col, border_col)
	t.set_color("font_color", "Label", text_col)
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

func _style_theme_flat_box(t: Theme, item_type: String, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	t.set_stylebox("panel", item_type, style)

func _style_theme_button(t: Theme, normal_bg: Color, hover_bg: Color, pressed_bg: Color, text_col: Color, border: Color) -> void:
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = normal_bg
	normal_box.border_color = border
	normal_box.set_border_width_all(1)
	normal_box.set_corner_radius_all(4)
	
	var hover_box := normal_box.duplicate() as StyleBoxFlat
	hover_box.bg_color = hover_bg
	
	var pressed_box := normal_box.duplicate() as StyleBoxFlat
	pressed_box.bg_color = pressed_bg
	
	t.set_stylebox("normal", "Button", normal_box)
	t.set_stylebox("hover", "Button", hover_box)
	t.set_stylebox("pressed", "Button", pressed_box)
	t.set_color("font_color", "Button", text_col)

func _style_theme_line_edit(t: Theme, bg: Color, text_col: Color, _accent: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	t.set_stylebox("normal", "LineEdit", box)
	t.set_color("font_color", "LineEdit", text_col)
