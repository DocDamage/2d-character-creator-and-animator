class_name PaperHeaderBar
extends HBoxContainer

func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()

func _draw() -> void:
	var style := get_theme_stylebox("panel", "TopNavigation")
	if style != null:
		draw_style_box(style, Rect2(Vector2.ZERO, size))
