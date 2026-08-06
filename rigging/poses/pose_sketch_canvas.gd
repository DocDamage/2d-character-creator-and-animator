# PoseSketchCanvas -- Small interactive gesture surface used by sketch-to-pose assistance.
class_name PoseSketchCanvas
extends Control

signal sketch_changed(points: Array)

var _points: Array[Vector2] = []
var _drawing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func get_points() -> Array:
	return _points.duplicate()


func set_points(points: Array) -> void:
	_points.clear()
	for point in points:
		if point is Vector2:
			_points.append(point)
	queue_redraw()
	sketch_changed.emit(get_points())


func clear_sketch() -> void:
	set_points([])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		if _drawing:
			_add_point(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _drawing:
		if _points.is_empty() or _points.back().distance_to(event.position) >= 3.0:
			_add_point(event.position)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("20242d"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("5c6c86"), false, 1.0)
	for index in range(1, _points.size()):
		draw_line(_points[index - 1], _points[index], Color("9ec3ff"), 2.0, true)
	for point in _points:
		draw_circle(point, 2.0, Color("d8e5ff"))


func _add_point(point: Vector2) -> void:
	_points.append(point.clamp(Vector2.ZERO, size))
	queue_redraw()
	sketch_changed.emit(get_points())
