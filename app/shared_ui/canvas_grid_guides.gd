# CanvasGridGuides — Grid drawing settings, ruler, guide management, and snapping logic
class_name CanvasGridGuides
extends Node2D

signal guides_changed()

var grid_enabled := true
var grid_step := Vector2(16, 16)
var grid_color := Color(0.3, 0.3, 0.35, 0.5)

var snap_to_grid := true
var snap_to_guides := true
var snap_to_pivots := false
var angle_snap_step_deg := 15.0

var _h_guides: Array = [] # float Y positions
var _v_guides: Array = [] # float X positions


func snap_position(p_pos: Vector2) -> Vector2:
	var result := p_pos
	
	if snap_to_guides and not (_h_guides.is_empty() and _v_guides.is_empty()):
		for x in _v_guides:
			if absf(result.x - x) < 8.0:
				result.x = x
				break
		for y in _h_guides:
			if absf(result.y - y) < 8.0:
				result.y = y
				break
	
	if snap_to_grid and grid_step.x > 0 and grid_step.y > 0:
		result.x = roundf(result.x / grid_step.x) * grid_step.x
		result.y = roundf(result.y / grid_step.y) * grid_step.y
	
	return result


func snap_angle_rad(p_angle_rad: float) -> float:
	if angle_snap_step_deg <= 0.0:
		return p_angle_rad
	var deg := rad_to_deg(p_angle_rad)
	var snapped_deg := roundf(deg / angle_snap_step_deg) * angle_snap_step_deg
	return deg_to_rad(snapped_deg)


func add_horizontal_guide(p_y: float) -> void:
	if not (p_y in _h_guides):
		_h_guides.append(p_y)
		guides_changed.emit()


func add_vertical_guide(p_x: float) -> void:
	if not (p_x in _v_guides):
		_v_guides.append(p_x)
		guides_changed.emit()


func clear_guides() -> void:
	_h_guides.clear()
	_v_guides.clear()
	guides_changed.emit()


func get_horizontal_guides() -> Array:
	return _h_guides.duplicate()


func get_vertical_guides() -> Array:
	return _v_guides.duplicate()
