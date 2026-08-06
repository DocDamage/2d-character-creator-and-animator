# Focus Ring Overlay — Renders a high-contrast visual focus ring outline around focused controls
class_name FocusRingOverlay
extends Control

@export var ring_color: Color = Color(0.2, 0.6, 1.0, 0.95)
@export var ring_width: float = 3.0
@export var ring_padding: float = 2.0
@export var corner_radius: float = 4.0

var target_control: Control = null
var _last_rect: Rect2 = Rect2()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 1000
	visible = false

func set_target_control(control: Control) -> void:
	target_control = control
	if target_control != null and target_control.is_inside_tree() and target_control.is_visible_in_tree():
		visible = true
		_update_bounds()
	else:
		visible = false

func clear_target() -> void:
	target_control = null
	visible = false

func _process(_delta: float) -> void:
	if not visible or target_control == null:
		return
	if not target_control.is_inside_tree() or not target_control.is_visible_in_tree():
		visible = false
		return
	var current_rect := target_control.get_global_rect()
	if current_rect != _last_rect:
		_update_bounds()

func _update_bounds() -> void:
	if target_control == null:
		return
	_last_rect = target_control.get_global_rect()
	global_position = _last_rect.position - Vector2(ring_padding, ring_padding)
	size = _last_rect.size + Vector2(ring_padding * 2.0, ring_padding * 2.0)
	queue_redraw()

func _draw() -> void:
	if target_control == null or size.x <= 0 or size.y <= 0:
		return
	var draw_rect := Rect2(Vector2.ZERO, size)
	draw_rect_outline(draw_rect, ring_color, ring_width)

func draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
	var half_w := width * 0.5
	var outer := rect.grow(half_w)
	# Draw top, bottom, left, right border lines
	draw_line(Vector2(outer.position.x, outer.position.y), Vector2(outer.end.x, outer.position.y), color, width)
	draw_line(Vector2(outer.end.x, outer.position.y), Vector2(outer.end.x, outer.end.y), color, width)
	draw_line(Vector2(outer.end.x, outer.end.y), Vector2(outer.position.x, outer.end.y), color, width)
	draw_line(Vector2(outer.position.x, outer.end.y), Vector2(outer.position.x, outer.position.y), color, width)
