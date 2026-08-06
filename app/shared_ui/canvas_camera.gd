# CanvasCamera — Manages canvas camera pan, zoom, frame selection, and view reset
class_name CanvasCamera
extends Node2D

signal camera_transformed(cam_position: Vector2, cam_zoom: Vector2)

const MIN_ZOOM := 0.1
const MAX_ZOOM := 32.0
const ZOOM_STEP := 1.15

var _zoom_level := 1.0


func pan(p_offset: Vector2) -> void:
	position += p_offset
	camera_transformed.emit(position, scale)


func zoom_at(p_factor: float, p_screen_pos: Vector2) -> void:
	var old_zoom := _zoom_level
	_zoom_level = clamp(_zoom_level * p_factor, MIN_ZOOM, MAX_ZOOM)
	
	if old_zoom == _zoom_level:
		return
	
	var zoom_ratio := _zoom_level / old_zoom
	position = p_screen_pos + (position - p_screen_pos) * zoom_ratio
	scale = Vector2(_zoom_level, _zoom_level)
	camera_transformed.emit(position, scale)


func set_zoom_level(p_level: float) -> void:
	_zoom_level = clamp(p_level, MIN_ZOOM, MAX_ZOOM)
	scale = Vector2(_zoom_level, _zoom_level)
	camera_transformed.emit(position, scale)


func reset_view() -> void:
	position = Vector2.ZERO
	_zoom_level = 1.0
	scale = Vector2.ONE
	camera_transformed.emit(position, scale)


func frame_bounds(p_rect: Rect2, p_viewport_size: Vector2) -> void:
	if p_rect.size.x <= 0 or p_rect.size.y <= 0:
		return
	
	var scale_x := p_viewport_size.x / p_rect.size.x
	var scale_y := p_viewport_size.y / p_rect.size.y
	_zoom_level = clamp(min(scale_x, scale_y) * 0.85, MIN_ZOOM, MAX_ZOOM)
	scale = Vector2(_zoom_level, _zoom_level)
	position = (p_viewport_size * 0.5) - (p_rect.get_center() * _zoom_level)
	camera_transformed.emit(position, scale)


func get_zoom_level() -> float:
	return _zoom_level
