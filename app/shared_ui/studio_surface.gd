# StudioSurface — Lightweight Figma-inspired visual surfaces for the empty editor docks.
class_name StudioSurface
extends Control

@export_enum("viewport", "animation", "assets", "hierarchy", "inspector", "timeline") var surface_mode := "viewport"

const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")

var background: Color
var panel: Color
var raised: Color
var grid: Color
var border: Color
var text_color: Color
var muted: Color
var blue: Color
var orange: Color
var green: Color


func _ready() -> void:
	_sync_palette()
	clip_contents = true
	resized.connect(queue_redraw)
	if ThemeService != null and not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background)
	match surface_mode:
		"assets": _draw_assets()
		"hierarchy": _draw_hierarchy()
		"inspector": _draw_inspector()
		"timeline": _draw_timeline()
		"animation": _draw_viewport(true)
		_: _draw_viewport()


func _draw_viewport(animate: bool = false) -> void:
	var toolbar := Rect2(12, 12, maxf(0.0, size.x - 24.0), 42)
	_draw_card(toolbar, panel, 10)
	var labels := ["Select", "Move", "Rotate", "Scale", "Pivot"]
	var x := toolbar.position.x + 12.0
	for i in range(labels.size()):
		var is_active := i == 0
		var width := 64.0 if i != 2 else 72.0
		var button := Rect2(x, toolbar.position.y + 5.0, width, 32.0)
		_draw_card(button, blue.darkened(0.08) if is_active else raised, 8, blue if is_active else border)
		_text(labels[i], button.position + Vector2(11, 21), 12, Color.WHITE if is_active else muted)
		x += width + 8.0
	var stage := Rect2(12, 66, maxf(0.0, size.x - 24.0), maxf(0.0, size.y - 78.0))
	_draw_card(stage, raised, 12, border)
	_draw_grid(stage.grow(-12.0))
	_draw_character(stage.get_center(), minf(stage.size.x, stage.size.y) * 0.43, animate)
	var preview_label := "Realtime preview · 8-direction blend" if animate else "Live character preview"
	_text(preview_label, Vector2(stage.get_center().x - 76.0, stage.end.y - 16.0), 12, muted)


func _draw_assets() -> void:
	var search := Rect2(12, 12, maxf(0.0, size.x - 24.0), 34)
	_draw_card(search, raised, 8, border)
	_text("Search compatible parts…", search.position + Vector2(12, 22), 12, muted)
	var tabs := ["All", "Recent", "Favorites"]
	var x := 12.0
	for i in range(tabs.size()):
		var width := 54.0 if i == 0 else 72.0
		var tab := Rect2(x, 58, width, 30)
		_draw_card(tab, blue.darkened(0.08) if i == 0 else raised, 7, blue if i == 0 else border)
		_text(tabs[i], tab.position + Vector2(11, 20), 11, Color.WHITE if i == 0 else muted)
		x += width + 8.0
	var cell_size := minf(92.0, (size.x - 42.0) / 3.0)
	var names := ["Base", "Athletic", "Heavy", "Tall", "Hero", "Compact", "Armored", "Rogue", "Custom"]
	for i in range(names.size()):
		var col := i % 3
		var row := i / 3
		var cell := Rect2(12.0 + col * (cell_size + 8.0), 102.0 + row * (cell_size + 10.0), cell_size, cell_size)
		var selected: bool = names[i] == "Hero"
		_draw_card(cell, raised, 10, blue if selected else border)
		var swatch := Rect2(cell.position + Vector2(16, 14), Vector2(cell.size.x - 32.0, maxf(22.0, cell.size.y - 46.0)))
		draw_rect(swatch, Color("#38597a") if selected else Color("#2e333d"), true)
		_text(names[i], cell.position + Vector2(12, cell.size.y - 11.0), 11, blue if selected else muted)


func _draw_hierarchy() -> void:
	var search := Rect2(12, 12, maxf(0.0, size.x - 24.0), 34)
	_draw_card(search, raised, 8, border)
	_text("Search bones and tracks…", search.position + Vector2(12, 22), 12, muted)
	var rows := ["▾ Root", "   Pelvis", "   Torso", "   Head", "   Arm.L", "   Arm.R", "   Leg.L", "   Leg.R", "   Weapon.Socket"]
	for i in range(rows.size()):
		var y := 72.0 + i * 32.0
		if i == 0:
			_draw_card(Rect2(8, y - 17, maxf(0.0, size.x - 16.0), 28), panel, 7, blue.darkened(0.25))
		_text(rows[i], Vector2(18, y), 12, blue if i == 0 else text_color)
		draw_circle(Vector2(size.x - 20.0, y - 5.0), 4.0, green if i < 7 else muted)
	var clips_y := minf(size.y - 154.0, 386.0)
	_text("CLIPS", Vector2(12, clips_y), 11, muted)
	var clips := ["Idle", "Walk_8dir", "Run", "Attack_A"]
	for i in range(clips.size()):
		var row := Rect2(12, clips_y + 12.0 + i * 34.0, maxf(0.0, size.x - 24.0), 28)
		var selected: bool = clips[i] == "Walk_8dir"
		_draw_card(row, blue.darkened(0.08) if selected else raised, 7, blue if selected else border)
		_text(clips[i], row.position + Vector2(12, 19), 12, Color.WHITE if selected else text_color)


func _draw_inspector() -> void:
	_text("Selected: Arm.L", Vector2(12, 28), 15, text_color)
	var properties := [["Position X", "12 px", blue], ["Position Y", "-4 px", blue], ["Rotation", "-18°", orange], ["Scale X", "100%", blue], ["Scale Y", "100%", blue], ["Opacity", "100%", blue]]
	for i in range(properties.size()):
		var y := 64.0 + i * 48.0
		_text("%s   %s" % [properties[i][0], properties[i][1]], Vector2(12, y), 12, text_color)
		var rail := Rect2(12, y + 12.0, maxf(0.0, size.x - 24.0), 6)
		draw_rect(rail, raised, true)
		draw_rect(Rect2(rail.position, Vector2(rail.size.x * (0.42 + i * 0.06), 6)), properties[i][2] as Color, true)
	var constraints_y := 370.0
	_text("CONSTRAINTS", Vector2(12, constraints_y), 11, muted)
	for i in range(3):
		var row := Rect2(12, constraints_y + 14.0 + i * 44.0, maxf(0.0, size.x - 24.0), 34)
		_draw_card(row, raised, 8, border)
		_text(["Two-bone IK", "Ground contact", "Weapon grip"][i], row.position + Vector2(12, 22), 12, text_color)
		draw_circle(Vector2(row.end.x - 16.0, row.get_center().y), 6.0, green if i < 2 else muted)


func _draw_timeline() -> void:
	var transport := Rect2(12, 6, maxf(0.0, size.x - 24.0), 32)
	_draw_card(transport, raised, 8, border)
	_text("◀   ▶   ■   ◉", transport.position + Vector2(14, 22), 13, text_color)
	_text("24 fps", transport.position + Vector2(130, 22), 11, muted)
	_text("Auto-key", transport.end - Vector2(76, 11), 11, blue)
	var label_width := minf(80.0, size.x * 0.20)
	var all_tracks := ["Body", "Head", "Arm.L", "Arm.R", "Leg.L", "Leg.R", "Weapon"]
	var visible_tracks := clampi(int(floor((size.y - 46.0) / 18.0)), 0, all_tracks.size())
	for row in range(visible_tracks):
		var y := 46.0 + row * 18.0
		_text(all_tracks[row], Vector2(12, y + 3.0), 10, muted)
		var rail := Rect2(label_width, y, maxf(0.0, size.x - label_width - 12.0), 12)
		draw_line(rail.position + Vector2(0, 6), rail.end - Vector2(0, 6), grid, 1.0)
		for key in range(5):
			var key_x := rail.position.x + fmod(float(row * 31 + key * 57), maxf(20.0, rail.size.x - 12.0))
			draw_rect(Rect2(key_x, y + 2, 8, 8), orange if (row + key) % 3 == 0 else blue, true)
	var playhead_x := label_width + (size.x - label_width - 12.0) * 0.48
	draw_line(Vector2(playhead_x, 42), Vector2(playhead_x, size.y - 5), blue, 2.0)


func _draw_grid(area: Rect2) -> void:
	var step := 32.0
	var x := area.position.x
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), grid.darkened(0.10), 1.0)
		x += step
	var y := area.position.y
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid.darkened(0.10), 1.0)
		y += step
	var center := area.get_center()
	draw_line(Vector2(center.x, area.position.y), Vector2(center.x, area.end.y), Color("#335276"), 1.0)
	draw_line(Vector2(area.position.x, center.y), Vector2(area.end.x, center.y), Color("#335276"), 1.0)


func _draw_character(center: Vector2, unit: float, animate: bool) -> void:
	var head_center := center + Vector2(0, -unit * 0.32)
	var skin := Color("#b88057")
	if animate:
		_draw_ghost_character(center + Vector2(-unit * 0.42, unit * 0.03), unit, Color("#29476b"))
		_draw_ghost_character(center + Vector2(unit * 0.42, unit * 0.03), unit, Color("#29476b"))
	draw_circle(head_center, unit * 0.16, Color("#6e472e"))
	draw_circle(head_center + Vector2(0, unit * 0.02), unit * 0.13, skin)
	draw_circle(center + Vector2(0, -unit * 0.02), unit * 0.23, Color("#1c527a"))
	_draw_limb(center + Vector2(-unit * 0.25, unit * 0.00), Vector2(-unit * 0.14, unit * 0.36), unit * 0.11, skin)
	_draw_limb(center + Vector2(unit * 0.25, unit * 0.00), Vector2(unit * 0.14, unit * 0.36), unit * 0.11, skin)
	_draw_limb(center + Vector2(-unit * 0.10, unit * 0.20), Vector2(-unit * 0.10, unit * 0.62), unit * 0.12, Color("#1f242e"))
	_draw_limb(center + Vector2(unit * 0.10, unit * 0.20), Vector2(unit * 0.10, unit * 0.62), unit * 0.12, Color("#1f242e"))


func _draw_ghost_character(center: Vector2, unit: float, color: Color) -> void:
	draw_circle(center + Vector2(0, -unit * 0.30), unit * 0.13, color.darkened(0.2))
	draw_circle(center, unit * 0.21, color)
	draw_rect(Rect2(center + Vector2(-unit * 0.12, unit * 0.20), Vector2(unit * 0.10, unit * 0.36)), color, true)
	draw_rect(Rect2(center + Vector2(unit * 0.02, unit * 0.20), Vector2(unit * 0.10, unit * 0.36)), color, true)


func _draw_limb(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width * 2.0, true)
	draw_circle(from, width, color)
	draw_circle(to, width, color)


func _draw_card(rect: Rect2, color: Color, radius: int, border: Color = Color.TRANSPARENT) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)


func _text(content: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _sync_palette() -> void:
	var dark := ThemeService != null and ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK
	var contrast := ThemeService != null and ThemeService.is_high_contrast()
	background = Tokens.color("paper_base", dark, contrast)
	panel = Tokens.color("paper_muted", dark, contrast)
	raised = Tokens.color("paper_top", dark, contrast)
	grid = Tokens.color("paper_dark", dark, contrast)
	border = Tokens.color("cardboard_edge", dark, contrast)
	text_color = Tokens.color("ink_primary", dark, contrast)
	muted = Tokens.color("ink_muted", dark, contrast)
	blue = Tokens.color("blue", dark, contrast)
	orange = Tokens.color("orange", dark, contrast)
	green = Tokens.color("green", dark, contrast)


func _on_theme_changed(_mode: String, _theme: Theme) -> void:
	_sync_palette()
	queue_redraw()
