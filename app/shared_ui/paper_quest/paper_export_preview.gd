class_name PaperExportPreview
extends Control

const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")
const Styles = preload("res://app/shared_ui/paper_quest/paper_quest_style_factory.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if ThemeService != null and not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	queue_redraw()

func _draw() -> void:
	var dark := ThemeService != null and ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK
	var contrast := ThemeService != null and ThemeService.is_high_contrast()
	var top := Tokens.color("paper_top", dark, contrast)
	var edge := Tokens.color("cardboard_edge", dark, contrast)
	var grid := Tokens.color("paper_dark", dark, contrast)
	var blue := Tokens.color("blue", dark, contrast)
	var green := Tokens.color("green", dark, contrast)
	draw_style_box(Styles.box(top, edge, 8, 2 if contrast else 1, 0.0), Rect2(Vector2.ZERO, size))
	var columns := 8
	var rows := 4
	var gap := 6.0
	var cell_size := minf((size.x - gap * float(columns + 1)) / float(columns), (size.y - gap * float(rows + 1)) / float(rows))
	var start_x := (size.x - (cell_size * columns + gap * (columns - 1))) * 0.5
	var start_y := (size.y - (cell_size * rows + gap * (rows - 1))) * 0.5
	for row in range(rows):
		for column in range(columns):
			var rect := Rect2(start_x + column * (cell_size + gap), start_y + row * (cell_size + gap), cell_size, cell_size)
			draw_style_box(Styles.box(top if (row + column) % 2 == 0 else grid.lightened(0.08), grid, 4, 1, 0.0), rect)
			_draw_frame(rect.get_center(), cell_size * 0.72, blue if row % 2 == 0 else green, edge, column)

func _draw_frame(center: Vector2, unit: float, clothing: Color, edge: Color, frame: int) -> void:
	var bob := sin(float(frame) * 0.9) * unit * 0.05
	draw_circle(center + Vector2(0, -unit * 0.22 + bob), unit * 0.16, edge)
	draw_circle(center + Vector2(0, -unit * 0.18 + bob), unit * 0.12, Color("#C88A5A"))
	draw_rect(Rect2(center + Vector2(-unit * 0.18, -unit * 0.04 + bob), Vector2(unit * 0.36, unit * 0.32)), clothing, true)
	draw_line(center + Vector2(-unit * 0.08, unit * 0.22 + bob), center + Vector2(-unit * (0.13 + frame % 2 * 0.06), unit * 0.43), edge, unit * 0.10, true)
	draw_line(center + Vector2(unit * 0.08, unit * 0.22 + bob), center + Vector2(unit * (0.19 - frame % 2 * 0.06), unit * 0.43), edge, unit * 0.10, true)

func _on_theme_changed(_mode: String, _theme: Theme) -> void:
	queue_redraw()
