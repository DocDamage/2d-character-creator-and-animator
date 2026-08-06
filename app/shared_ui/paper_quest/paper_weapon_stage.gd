class_name PaperWeaponStage
extends "res://app/shared_ui/paper_quest/paper_diorama.gd"

func _draw() -> void:
	super._draw()
	var dark := ThemeService != null and ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK
	var contrast := ThemeService != null and ThemeService.is_high_contrast()
	var blade := Tokens.color("paper_dark", dark, contrast)
	var edge := Tokens.color("cardboard_dark", dark, contrast)
	var orange := Tokens.color("orange", dark, contrast)
	var blue := Tokens.color("blue", dark, contrast)
	var green := Tokens.color("green", dark, contrast)
	var scale_factor := clampf(minf(size.x / 720.0, size.y / 350.0), 0.72, 1.30)
	var grip := Vector2(size.x * 0.59, size.y * 0.61)
	var tip := grip + Vector2(94, -116) * scale_factor
	var normal := (tip - grip).normalized().orthogonal() * 12.0 * scale_factor
	draw_colored_polygon(PackedVector2Array([grip + normal, tip, grip - normal]), blade)
	draw_polyline(PackedVector2Array([grip + normal, tip, grip - normal]), edge, 3.0 * scale_factor, true)
	draw_line(grip + Vector2(-24, -18) * scale_factor, grip + Vector2(22, 20) * scale_factor, orange, 12.0 * scale_factor, true)
	draw_line(grip, grip + Vector2(-30, 34) * scale_factor, edge, 14.0 * scale_factor, true)
	_draw_target(grip + Vector2(-24, 18) * scale_factor, blue, scale_factor)
	_draw_target(grip + Vector2(-88, 16) * scale_factor, green, scale_factor)

func _draw_target(position: Vector2, color: Color, scale_factor: float) -> void:
	draw_circle(position, 17.0 * scale_factor, color)
	draw_circle(position, 10.0 * scale_factor, Color(1, 1, 1, 0.72))
	draw_circle(position, 4.0 * scale_factor, color)
