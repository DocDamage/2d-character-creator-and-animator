class_name PaperQuestDiorama
extends Control

const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")
const Styles = preload("res://app/shared_ui/paper_quest/paper_quest_style_factory.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	if ThemeService != null and not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	queue_redraw()

func _draw() -> void:
	var dark := ThemeService != null and ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK
	var contrast := ThemeService != null and ThemeService.is_high_contrast()
	var edge := _token("cardboard_edge")
	var paper := _token("paper_top")
	var sky := _token("blue").lightened(0.64 if not dark else 0.18)
	var ground := _token("green").darkened(0.02)
	var distant := _token("green_dark")
	draw_style_box(Styles.box(sky, edge, 10, 2 if contrast else 1, 0.0), Rect2(Vector2.ZERO, size))
	_draw_cloud(Vector2(size.x * 0.16, size.y * 0.20), paper, 0.8)
	_draw_cloud(Vector2(size.x * 0.72, size.y * 0.16), paper, 1.0)
	_draw_mountains(distant, paper)
	draw_rect(Rect2(0, size.y * 0.60, size.x, size.y * 0.40), ground, true)
	_draw_path(paper.darkened(0.10))
	for x_ratio in [0.06, 0.14, 0.82, 0.91]:
		_draw_tree(Vector2(size.x * x_ratio, size.y * 0.62), distant, edge, 0.78 if x_ratio < 0.5 else 0.92)
	_draw_castle(Vector2(size.x * 0.83, size.y * 0.54), paper.darkened(0.14), edge)
	_draw_hero(Vector2(size.x * 0.52, size.y * 0.57), edge, paper, dark, contrast)

func _draw_cloud(center: Vector2, color: Color, scale_factor: float) -> void:
	for cloud in [Vector2(-24, 4), Vector2(-8, -7), Vector2(10, -4), Vector2(25, 5)]:
		draw_circle(center + cloud * scale_factor, 15.0 * scale_factor, color)

func _draw_mountains(color: Color, snow: Color) -> void:
	for spec in [[0.02, 0.66, 0.24, 0.22], [0.18, 0.64, 0.44, 0.12], [0.60, 0.64, 0.80, 0.26]]:
		var left := size.x * float(spec[0])
		var base_y := size.y * float(spec[1])
		var peak_x := size.x * float(spec[2])
		var peak_y := size.y * float(spec[3])
		draw_colored_polygon(PackedVector2Array([Vector2(left, base_y), Vector2(peak_x, peak_y), Vector2(peak_x + size.x * 0.19, base_y)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(peak_x - 18, peak_y + 30), Vector2(peak_x, peak_y), Vector2(peak_x + 22, peak_y + 34), Vector2(peak_x + 6, peak_y + 26), Vector2(peak_x - 4, peak_y + 36)]), snow)

func _draw_path(color: Color) -> void:
	var center_x := size.x * 0.54
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 28, size.y * 0.60),
		Vector2(center_x + 24, size.y * 0.60),
		Vector2(center_x + size.x * 0.18, size.y),
		Vector2(center_x - size.x * 0.20, size.y),
	]), color)

func _draw_tree(base: Vector2, leaves: Color, trunk: Color, scale_factor: float) -> void:
	draw_rect(Rect2(base + Vector2(-5, -10) * scale_factor, Vector2(10, 52) * scale_factor), trunk, true)
	for y in [-60.0, -38.0, -17.0]:
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-30, y + 28) * scale_factor,
			base + Vector2(0, y - 22) * scale_factor,
			base + Vector2(30, y + 28) * scale_factor,
		]), leaves)

func _draw_castle(base: Vector2, stone: Color, edge: Color) -> void:
	draw_rect(Rect2(base + Vector2(-28, -60), Vector2(56, 60)), stone, true)
	draw_rect(Rect2(base + Vector2(-12, -94), Vector2(24, 40)), stone, true)
	for x in [-24.0, 0.0, 24.0]:
		draw_rect(Rect2(base + Vector2(x - 6, -70), Vector2(12, 12)), edge, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-18, -94), base + Vector2(0, -118), base + Vector2(18, -94)]), _token("red"))

func _draw_hero(center: Vector2, edge: Color, paper: Color, dark: bool, contrast: bool) -> void:
	var skin := Color("#C88A5A") if not contrast else paper
	var green := _token("green")
	var red := _token("red")
	var ink := _token("ink_primary")
	var scale_factor := clampf(minf(size.x / 700.0, size.y / 330.0), 0.72, 1.34)
	draw_circle(center + Vector2(0, -80) * scale_factor, 46.0 * scale_factor, edge)
	draw_circle(center + Vector2(0, -76) * scale_factor, 38.0 * scale_factor, skin)
	for spike_x in [-32.0, -16.0, 0.0, 16.0, 32.0]:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(spike_x - 13, -102) * scale_factor,
			center + Vector2(spike_x, -134 - absf(spike_x) * 0.18) * scale_factor,
			center + Vector2(spike_x + 13, -100) * scale_factor,
		]), edge)
	draw_circle(center + Vector2(-13, -76) * scale_factor, 3.8 * scale_factor, ink)
	draw_circle(center + Vector2(13, -76) * scale_factor, 3.8 * scale_factor, ink)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-42, -44) * scale_factor,
		center + Vector2(42, -44) * scale_factor,
		center + Vector2(34, 35) * scale_factor,
		center + Vector2(-34, 35) * scale_factor,
	]), green)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-43, -45) * scale_factor,
		center + Vector2(43, -45) * scale_factor,
		center + Vector2(20, -20) * scale_factor,
		center + Vector2(-20, -20) * scale_factor,
	]), red)
	for x in [-20.0, 20.0]:
		draw_line(center + Vector2(x, 22) * scale_factor, center + Vector2(x * 1.35, 76) * scale_factor, edge, 18.0 * scale_factor, true)
		draw_circle(center + Vector2(x * 1.35, 76) * scale_factor, 13.0 * scale_factor, edge)

func _on_theme_changed(_mode: String, _theme: Theme) -> void:
	queue_redraw()

func _token(name: String) -> Color:
	return ThemeService.get_color_token(name) if ThemeService != null else Tokens.color(name)
