class_name PaperQuestMascot
extends Control

const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if ThemeService != null and not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	queue_redraw()

func _draw() -> void:
	var blue := _token("blue")
	var blue_dark := _token("blue_dark")
	var paper := _token("paper_top")
	var ink := _token("ink_primary")
	var red := _token("red")
	var scale_factor := minf(size.x, size.y) / 100.0
	var center := Vector2(size.x * 0.5, size.y * 0.50)
	var outline := 4.0 * scale_factor
	var left_ear := PackedVector2Array([center + Vector2(-30, -25) * scale_factor, center + Vector2(-48, -52) * scale_factor, center + Vector2(-12, -42) * scale_factor])
	var right_ear := PackedVector2Array([center + Vector2(30, -25) * scale_factor, center + Vector2(48, -52) * scale_factor, center + Vector2(12, -42) * scale_factor])
	draw_colored_polygon(left_ear, blue_dark)
	draw_colored_polygon(right_ear, blue_dark)
	draw_circle(center, 38.0 * scale_factor, blue_dark)
	draw_circle(center, (38.0 * scale_factor) - outline, blue)
	for offset in [Vector2(-24, -30), Vector2(-8, -40), Vector2(10, -40), Vector2(25, -28)]:
		var spike := PackedVector2Array([
			center + (offset + Vector2(-7, 8)) * scale_factor,
			center + (offset + Vector2(0, -13)) * scale_factor,
			center + (offset + Vector2(7, 8)) * scale_factor,
		])
		draw_colored_polygon(spike, blue_dark)
	draw_circle(center + Vector2(-14, -5) * scale_factor, 8.0 * scale_factor, paper)
	draw_circle(center + Vector2(14, -5) * scale_factor, 8.0 * scale_factor, paper)
	draw_circle(center + Vector2(-12, -4) * scale_factor, 3.5 * scale_factor, ink)
	draw_circle(center + Vector2(12, -4) * scale_factor, 3.5 * scale_factor, ink)
	draw_circle(center + Vector2(0, 8) * scale_factor, 4.0 * scale_factor, blue_dark)
	draw_arc(center + Vector2(0, 10) * scale_factor, 13.0 * scale_factor, 0.25, PI - 0.25, 18, ink, 2.5 * scale_factor, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-28, 28) * scale_factor,
		center + Vector2(28, 28) * scale_factor,
		center + Vector2(18, 42) * scale_factor,
		center + Vector2(-18, 42) * scale_factor,
	]), red)

func _on_theme_changed(_mode: String, _theme: Theme) -> void:
	queue_redraw()

func _token(name: String) -> Color:
	return ThemeService.get_color_token(name) if ThemeService != null else Tokens.color(name)
