# TransformGizmo — Interactive on-canvas transform handles for translate, rotate, scale, and skew
class_name TransformGizmo
extends Node2D

signal transform_started()
signal transform_updated(transform_data: Dictionary)
signal transform_finished(final_transform_data: Dictionary)

enum GizmoMode { SELECT, TRANSLATE, ROTATE, SCALE, SKEW }
enum HandleType { NONE, POSITION, ROTATION, SCALE_TL, SCALE_TR, SCALE_BL, SCALE_BR, SKEW_X, SKEW_Y }

var active_mode := GizmoMode.TRANSLATE
var is_dragging := false
var _start_mouse_pos := Vector2.ZERO
var _start_target_pos := Vector2.ZERO
var _start_target_rot := 0.0
var _start_target_scale := Vector2.ONE
var _start_target_skew := Vector2.ZERO
var _snap_grid := 0.0
var _snap_angle := 0.0


func start_drag(p_handle: HandleType, p_mouse_pos: Vector2, p_current_pos: Vector2, p_current_rot: float, p_current_scale: Vector2, p_current_skew: Vector2 = Vector2.ZERO) -> void:
	is_dragging = true
	_start_mouse_pos = p_mouse_pos
	_start_target_pos = p_current_pos
	_start_target_rot = p_current_rot
	_start_target_scale = p_current_scale
	_start_target_skew = p_current_skew
	_snap_grid = 0.0
	_snap_angle = 0.0
	transform_started.emit()


func update_drag(p_mouse_pos: Vector2, p_snap_grid: float = 0.0, p_snap_angle: float = 0.0) -> Dictionary:
	if not is_dragging:
		return {}
	if p_snap_grid > 0.0:
		_snap_grid = p_snap_grid
	if p_snap_angle > 0.0:
		_snap_angle = p_snap_angle
	
	var delta_mouse := p_mouse_pos - _start_mouse_pos
	var result := {
		"position": _start_target_pos + delta_mouse,
		"rotation": _start_target_rot,
		"scale": _start_target_scale,
		"skew": _start_target_skew
	}
	
	if _snap_grid > 0.0:
		result["position"].x = snappedf(result["position"].x, _snap_grid)
		result["position"].y = snappedf(result["position"].y, _snap_grid)
	
	if active_mode == GizmoMode.ROTATE:
		var angle_delta := delta_mouse.x * 0.01
		var new_rot := _start_target_rot + angle_delta
		if _snap_angle > 0.0:
			new_rot = snappedf(rad_to_deg(new_rot), _snap_angle)
			new_rot = deg_to_rad(new_rot)
		result["rotation"] = new_rot
	elif active_mode == GizmoMode.SCALE:
		var scale_factor := Vector2(1.0 + delta_mouse.x * 0.01, 1.0 + delta_mouse.y * 0.01)
		result["scale"] = _start_target_scale * scale_factor
	
	transform_updated.emit(result)
	return result


func finish_drag(p_mouse_pos: Vector2) -> Dictionary:
	var final_data := update_drag(p_mouse_pos, _snap_grid, _snap_angle)
	is_dragging = false
	transform_finished.emit(final_data)
	return final_data
