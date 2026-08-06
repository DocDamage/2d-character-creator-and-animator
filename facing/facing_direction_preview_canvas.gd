# FacingDirectionPreviewCanvas -- Draws the current directional scrub position.
class_name FacingDirectionPreviewCanvas
extends Control

var _direction: Vector2 = Vector2.UP
var _evaluation: Dictionary = {}
var _direction_count: int = 0


func set_preview(direction: Vector2, evaluation: Dictionary, direction_count: int) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	_evaluation = evaluation.duplicate(true)
	_direction_count = direction_count
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(12.0, minf(size.x, size.y) * 0.38)
	draw_circle(center, radius, Color("263248"), false, 2.0, true)
	if _direction_count > 0:
		for index in range(_direction_count):
			var angle := TAU * float(index) / float(_direction_count)
			var guide := center + Vector2(sin(angle), -cos(angle)) * radius
			draw_line(center, guide, Color("40516f"), 1.0, true)
	var endpoint := center + _direction * radius
	draw_line(center, endpoint, Color("70d6ff"), 3.0, true)
	draw_circle(endpoint, 5.0, Color("70d6ff"), true)
	if _evaluation.get("mode", "") == "crossfade":
		var weight := float(_evaluation.get("weight", 0.0))
		draw_arc(center, radius + 6.0, 0.0, weight * TAU, 16, Color("f6c85f"), 3.0, true)
