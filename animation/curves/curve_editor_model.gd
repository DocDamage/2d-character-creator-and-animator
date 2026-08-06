# CurveEditorModel -- Viewport data model for curve editor interaction and state.
# CRV-005: Manages viewport bounds, zoom, pan, tangent handle drag state, and selection.
class_name CurveEditorModel
extends RefCounted

## Signals for view/selection changes.
signal view_changed()
signal selection_changed()

## Viewport view state.
var pan_offset: Vector2 = Vector2.ZERO
var zoom_level: Vector2 = Vector2(100.0, 100.0) # pixels per unit (time_scale, value_scale)
var view_bounds: Rect2 = Rect2(-0.5, -2.0, 5.0, 4.0)

## Selection state.
var selected_key_ids: Array[String] = []
var active_handle: String = "" # e.g. "key_id:in" or "key_id:out"
var is_dragging_handle: bool = false
var handle_drag_start: Vector2 = Vector2.ZERO

## Selection box rect in viewport coords.
var is_box_selecting: bool = false
var box_select_rect: Rect2 = Rect2()


## Resets viewport state to default bounds.
func reset_view() -> void:
	pan_offset = Vector2.ZERO
	zoom_level = Vector2(100.0, 100.0)
	selected_key_ids.clear()
	active_handle = ""
	is_dragging_handle = false
	is_box_selecting = false
	view_changed.emit()


## Pans viewport by delta pixel offset.
func pan(delta_pixels: Vector2) -> void:
	pan_offset += delta_pixels
	view_changed.emit()


## Zooms viewport at center point with scale factor.
func zoom(factor: Vector2, center_pixel: Vector2 = Vector2.ZERO) -> void:
	var old_zoom := zoom_level
	zoom_level = (zoom_level * factor).clamp(Vector2(5.0, 5.0), Vector2(2000.0, 2000.0))
	pan_offset = center_pixel - (center_pixel - pan_offset) * (zoom_level / old_zoom)
	view_changed.emit()


## Converts graph world coords (time, value) to pixel position.
func world_to_pixel(world_pos: Vector2, viewport_size: Vector2) -> Vector2:
	var center := viewport_size * 0.5 + pan_offset
	return center + Vector2(world_pos.x * zoom_level.x, -world_pos.y * zoom_level.y)


## Converts pixel position to graph world coords (time, value).
func pixel_to_world(pixel_pos: Vector2, viewport_size: Vector2) -> Vector2:
	var center := viewport_size * 0.5 + pan_offset
	var rel := pixel_pos - center
	return Vector2(rel.x / zoom_level.x, -rel.y / zoom_level.y)


## Selects keyframe ID.
func select_key(key_id: String, append: bool = false) -> void:
	if not append:
		selected_key_ids.clear()
	if not key_id.is_empty() and not selected_key_ids.has(key_id):
		selected_key_ids.append(key_id)
	selection_changed.emit()


## Begins dragging a tangent handle.
func start_handle_drag(handle_id: String, start_pos: Vector2) -> void:
	active_handle = handle_id
	is_dragging_handle = true
	handle_drag_start = start_pos


## End dragging handle.
func end_handle_drag() -> void:
	is_dragging_handle = false
	active_handle = ""
