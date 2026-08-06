# ThemeService — Paper Quest appearance, accessibility, and DPI settings.
extends Node

signal theme_changed(mode_name: String, theme: Theme)
signal dpi_scale_changed(scale_factor: float)
signal accessibility_changed(high_contrast: bool, reduced_motion: bool)

enum ThemeMode { DARK = 0, LIGHT = 1 }

const ThemeBuilder = preload("res://app/shared_ui/paper_quest/paper_quest_theme_builder.gd")
const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")
const SCALE_PRESETS: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]

var _current_mode: ThemeMode = ThemeMode.LIGHT
var _dpi_scale := 1.0
var _dark_theme: Theme
var _light_theme: Theme
var _high_contrast := false
var _reduced_motion := false

func _ready() -> void:
	_rebuild_themes()
	_apply_current_theme()

func set_theme_mode(mode: int) -> void:
	var target := ThemeMode.LIGHT if mode == ThemeMode.LIGHT else ThemeMode.DARK
	if _current_mode == target and get_current_theme() != null:
		return
	_current_mode = target
	_apply_current_theme()
	theme_changed.emit(get_theme_mode_name(), get_current_theme())
	if DiagnosticsService != null:
		DiagnosticsService.info("Appearance set to: " + get_appearance_mode_name(), "ThemeService")

func get_theme_mode() -> ThemeMode:
	return _current_mode

func get_theme_mode_name() -> String:
	return "LIGHT" if _current_mode == ThemeMode.LIGHT else "DARK"

func get_appearance_mode_name() -> String:
	if _high_contrast:
		return "High Contrast"
	return "Craft" if _current_mode == ThemeMode.LIGHT else "Dark Craft"

func toggle_theme_mode() -> void:
	if _high_contrast:
		set_high_contrast(false)
	set_theme_mode(ThemeMode.LIGHT if _current_mode == ThemeMode.DARK else ThemeMode.DARK)

func get_current_theme() -> Theme:
	return _light_theme if _current_mode == ThemeMode.LIGHT else _dark_theme

func set_high_contrast(enabled: bool) -> void:
	if _high_contrast == enabled:
		return
	_high_contrast = enabled
	_rebuild_themes()
	_apply_current_theme()
	theme_changed.emit(get_theme_mode_name(), get_current_theme())
	accessibility_changed.emit(_high_contrast, _reduced_motion)

func is_high_contrast() -> bool:
	return _high_contrast

func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	accessibility_changed.emit(_high_contrast, _reduced_motion)

func is_reduced_motion() -> bool:
	return _reduced_motion

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
	var next_index := 0
	for index in range(SCALE_PRESETS.size()):
		if _dpi_scale < SCALE_PRESETS[index] - 0.05:
			next_index = index
			break
	if _dpi_scale >= SCALE_PRESETS[-1] - 0.05:
		next_index = 0
	set_dpi_scale(SCALE_PRESETS[next_index])
	return _dpi_scale

func apply_to_window(window: Window) -> void:
	if window == null:
		return
	window.theme = get_current_theme()
	window.content_scale_factor = _dpi_scale
	_sync_texture_visibility()

func get_color_token(token_name: String) -> Color:
	var aliases := {
		"bg_main": "cardboard_base",
		"bg_panel": "paper_base",
		"bg_header": "cardboard_light",
		"text_primary": "ink_primary",
		"text_secondary": "ink_muted",
		"accent": "blue",
		"border": "cardboard_edge",
		"selection": "blue",
	}
	var resolved := aliases.get(token_name, token_name) as String
	return Tokens.color(resolved, _current_mode == ThemeMode.DARK, _high_contrast)

func export_settings() -> Dictionary:
	return {
		"schema_version": 2,
		"theme_mode": get_theme_mode_name(),
		"appearance_mode": get_appearance_mode_name(),
		"dpi_scale": _dpi_scale,
		"high_contrast": _high_contrast,
		"reduced_motion": _reduced_motion,
	}

func import_settings(data: Dictionary) -> bool:
	if data == null:
		return false
	var appearance := String(data.get("appearance_mode", "")).strip_edges().to_upper()
	var legacy_mode := String(data.get("theme_mode", "")).strip_edges().to_upper()
	if appearance == "CRAFT":
		set_theme_mode(ThemeMode.LIGHT)
		set_high_contrast(false)
	elif appearance == "DARK CRAFT":
		set_theme_mode(ThemeMode.DARK)
		set_high_contrast(false)
	elif appearance == "HIGH CONTRAST":
		set_high_contrast(true)
	elif not legacy_mode.is_empty():
		set_theme_mode(ThemeMode.LIGHT if legacy_mode == "LIGHT" else ThemeMode.DARK)
	if data.has("high_contrast"):
		set_high_contrast(bool(data["high_contrast"]))
	if data.has("reduced_motion"):
		set_reduced_motion(bool(data["reduced_motion"]))
	if data.has("dpi_scale"):
		set_dpi_scale(float(data["dpi_scale"]))
	return true

func _rebuild_themes() -> void:
	_dark_theme = ThemeBuilder.build(true, _high_contrast)
	_light_theme = ThemeBuilder.build(false, _high_contrast)

func _apply_current_theme() -> void:
	var window := get_window()
	if window != null:
		window.theme = get_current_theme()
	_sync_texture_visibility()

func _apply_dpi_scale() -> void:
	var window := get_window()
	if window != null:
		window.content_scale_factor = _dpi_scale

func _sync_texture_visibility() -> void:
	if get_tree() == null:
		return
	get_tree().call_group("paper_quest_texture", "set_visible", not _high_contrast)
