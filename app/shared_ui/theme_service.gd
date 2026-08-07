# ThemeService — Studio appearance, accessibility, DPI, and preference persistence.
extends Node

signal theme_changed(mode_name: String, theme: Theme)
signal dpi_scale_changed(scale_factor: float)
signal accessibility_changed(high_contrast: bool, reduced_motion: bool)

enum ThemeMode { DARK = 0, LIGHT = 1 }
enum AppearanceMode { OBSIDIAN, PAPER_QUEST, DARK_CRAFT, HIGH_CONTRAST }

const ThemeBuilder = preload("res://app/shared_ui/paper_quest/paper_quest_theme_builder.gd")
const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")
const DEFAULT_APPEARANCE := AppearanceMode.OBSIDIAN
const SCALE_PRESETS: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]
const PREFERENCES_PATH := "user://appearance_settings.json"
const APPEARANCE_NAMES := {
	AppearanceMode.OBSIDIAN: "Obsidian Studio",
	AppearanceMode.PAPER_QUEST: "Paper Quest Classic",
	AppearanceMode.DARK_CRAFT: "Dark Craft",
	AppearanceMode.HIGH_CONTRAST: "High Contrast",
}
const APPEARANCE_IDS := {
	AppearanceMode.OBSIDIAN: "obsidian",
	AppearanceMode.PAPER_QUEST: "paper_quest",
	AppearanceMode.DARK_CRAFT: "dark_craft",
	AppearanceMode.HIGH_CONTRAST: "high_contrast",
}

var _current_appearance: AppearanceMode = DEFAULT_APPEARANCE
var _last_standard_appearance: AppearanceMode = DEFAULT_APPEARANCE
var _dpi_scale := 1.0
var _themes: Dictionary = {}
var _reduced_motion := false
var _loading_preferences := false
var _save_pending := false

func _ready() -> void:
	_rebuild_themes()
	_load_preferences()
	_apply_current_theme()

func set_appearance_mode(mode: int) -> void:
	var target := _normalize_appearance(mode)
	if _current_appearance == target and get_current_theme() != null:
		return
	var was_high_contrast := is_high_contrast()
	_current_appearance = target
	if target != AppearanceMode.HIGH_CONTRAST:
		_last_standard_appearance = target
	_apply_current_theme()
	theme_changed.emit(get_theme_mode_name(), get_current_theme())
	if was_high_contrast != is_high_contrast():
		accessibility_changed.emit(is_high_contrast(), _reduced_motion)
	_schedule_save_preferences()
	if DiagnosticsService != null:
		DiagnosticsService.info("Appearance set to: " + get_appearance_mode_name(), "ThemeService")

func get_appearance_mode() -> AppearanceMode:
	return _current_appearance

func get_default_appearance_mode() -> AppearanceMode:
	return DEFAULT_APPEARANCE

func get_appearance_mode_name() -> String:
	return String(APPEARANCE_NAMES.get(_current_appearance, "Obsidian Studio"))

func get_appearance_id() -> String:
	return String(APPEARANCE_IDS.get(_current_appearance, "obsidian"))

func get_appearance_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for mode in [AppearanceMode.OBSIDIAN, AppearanceMode.PAPER_QUEST, AppearanceMode.DARK_CRAFT, AppearanceMode.HIGH_CONTRAST]:
		options.append({"id": mode, "label": APPEARANCE_NAMES[mode]})
	return options

func cycle_appearance_mode() -> void:
	var next_mode := (_current_appearance + 1) % AppearanceMode.size()
	set_appearance_mode(next_mode)

func set_theme_mode(mode: int) -> void:
	set_appearance_mode(AppearanceMode.PAPER_QUEST if mode == ThemeMode.LIGHT else AppearanceMode.OBSIDIAN)

func get_theme_mode() -> ThemeMode:
	var effective := _last_standard_appearance if is_high_contrast() else _current_appearance
	return ThemeMode.LIGHT if effective == AppearanceMode.PAPER_QUEST else ThemeMode.DARK

func get_theme_mode_name() -> String:
	return "LIGHT" if get_theme_mode() == ThemeMode.LIGHT else "DARK"

func toggle_theme_mode() -> void:
	var target := AppearanceMode.PAPER_QUEST if _current_appearance == AppearanceMode.OBSIDIAN else AppearanceMode.OBSIDIAN
	set_appearance_mode(target)

func get_current_theme() -> Theme:
	return _themes.get(_current_appearance) as Theme

func set_high_contrast(enabled: bool) -> void:
	if enabled:
		set_appearance_mode(AppearanceMode.HIGH_CONTRAST)
	elif is_high_contrast():
		set_appearance_mode(_last_standard_appearance)

func is_high_contrast() -> bool:
	return _current_appearance == AppearanceMode.HIGH_CONTRAST

func uses_paper_texture() -> bool:
	return _current_appearance in [AppearanceMode.PAPER_QUEST, AppearanceMode.DARK_CRAFT]

func get_paper_texture_opacity() -> float:
	if _current_appearance == AppearanceMode.PAPER_QUEST:
		return 0.46
	if _current_appearance == AppearanceMode.DARK_CRAFT:
		return 0.20
	return 0.0

func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	accessibility_changed.emit(is_high_contrast(), _reduced_motion)
	_schedule_save_preferences()

func is_reduced_motion() -> bool:
	return _reduced_motion

func set_dpi_scale(scale_factor: float) -> void:
	var clamped_scale := clampf(scale_factor, 1.0, 2.0)
	if absf(_dpi_scale - clamped_scale) < 0.001:
		return
	_dpi_scale = clamped_scale
	_apply_dpi_scale()
	dpi_scale_changed.emit(_dpi_scale)
	_schedule_save_preferences()
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
	return Tokens.color_for_palette(resolved, _get_palette())

func export_settings() -> Dictionary:
	return {
		"schema_version": 3,
		"theme_mode": get_theme_mode_name(),
		"appearance_id": get_appearance_id(),
		"appearance_mode": get_appearance_mode_name(),
		"dpi_scale": _dpi_scale,
		"high_contrast": is_high_contrast(),
		"reduced_motion": _reduced_motion,
	}

func import_settings(data: Dictionary) -> bool:
	if data == null:
		return false
	var target := _appearance_from_settings(data)
	if bool(data.get("high_contrast", false)):
		target = AppearanceMode.HIGH_CONTRAST
	elif data.has("high_contrast"):
		if target == AppearanceMode.HIGH_CONTRAST or (target < 0 and is_high_contrast()):
			target = _last_standard_appearance
	if target >= 0:
		set_appearance_mode(target)
	if data.has("reduced_motion"):
		set_reduced_motion(bool(data["reduced_motion"]))
	if data.has("dpi_scale"):
		set_dpi_scale(float(data["dpi_scale"]))
	return true

func save_preferences() -> bool:
	var file := FileAccess.open(PREFERENCES_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(export_settings(), "\t"))
	file.close()
	return true

func load_preferences() -> bool:
	return _load_preferences()

func _appearance_from_settings(data: Dictionary) -> int:
	for key in ["appearance_id", "appearance_mode"]:
		var value := String(data.get(key, "")).strip_edges().to_upper().replace("-", "_").replace(" ", "_")
		match value:
			"OBSIDIAN", "OBSIDIAN_STUDIO", "STUDIO": return AppearanceMode.OBSIDIAN
			"PAPER_QUEST", "PAPER_QUEST_CLASSIC", "CRAFT": return AppearanceMode.PAPER_QUEST
			"DARK_CRAFT", "DARK_CRAFT_CLASSIC": return AppearanceMode.DARK_CRAFT
			"HIGH_CONTRAST": return AppearanceMode.HIGH_CONTRAST
	var legacy_mode := String(data.get("theme_mode", "")).strip_edges().to_upper()
	if legacy_mode == "LIGHT":
		return AppearanceMode.PAPER_QUEST
	if legacy_mode == "DARK":
		return AppearanceMode.DARK_CRAFT
	return -1

func _normalize_appearance(mode: int) -> int:
	return mode if mode >= AppearanceMode.OBSIDIAN and mode <= AppearanceMode.HIGH_CONTRAST else AppearanceMode.OBSIDIAN

func _get_palette() -> int:
	match _current_appearance:
		AppearanceMode.PAPER_QUEST: return Tokens.Palette.PAPER_QUEST
		AppearanceMode.DARK_CRAFT: return Tokens.Palette.DARK_CRAFT
		AppearanceMode.HIGH_CONTRAST: return Tokens.Palette.HIGH_CONTRAST
		_: return Tokens.Palette.OBSIDIAN

func _rebuild_themes() -> void:
	_themes = {
		AppearanceMode.OBSIDIAN: ThemeBuilder.build_for_palette(Tokens.Palette.OBSIDIAN),
		AppearanceMode.PAPER_QUEST: ThemeBuilder.build_for_palette(Tokens.Palette.PAPER_QUEST),
		AppearanceMode.DARK_CRAFT: ThemeBuilder.build_for_palette(Tokens.Palette.DARK_CRAFT),
		AppearanceMode.HIGH_CONTRAST: ThemeBuilder.build_for_palette(Tokens.Palette.HIGH_CONTRAST),
	}

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
	if get_tree() != null:
		get_tree().call_group("paper_quest_texture", "set_visible", uses_paper_texture())

func _load_preferences() -> bool:
	if not FileAccess.file_exists(PREFERENCES_PATH):
		return false
	var file := FileAccess.open(PREFERENCES_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	_loading_preferences = true
	var imported := import_settings(parsed as Dictionary)
	_loading_preferences = false
	return imported

func _schedule_save_preferences() -> void:
	if _loading_preferences or _save_pending or not is_inside_tree():
		return
	_save_pending = true
	call_deferred("_save_preferences_deferred")

func _save_preferences_deferred() -> void:
	_save_pending = false
	save_preferences()
