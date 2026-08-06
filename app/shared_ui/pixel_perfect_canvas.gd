# PixelPerfectCanvas — Controls integer snapping, pixel grid overlays, and viewport filtering
class_name PixelPerfectCanvas
extends Node

signal mode_changed(enabled: bool)

var is_pixel_perfect_enabled := true
const PIXEL_GRID_ZOOM_THRESHOLD := 4.0


func set_enabled(p_enabled: bool) -> void:
	is_pixel_perfect_enabled = p_enabled
	mode_changed.emit(is_pixel_perfect_enabled)


func snap_position(p_pos: Vector2) -> Vector2:
	if not is_pixel_perfect_enabled:
		return p_pos
	return Vector2(roundf(p_pos.x), roundf(p_pos.y))


func should_show_pixel_grid(p_zoom_level: float) -> bool:
	return is_pixel_perfect_enabled and p_zoom_level >= PIXEL_GRID_ZOOM_THRESHOLD


static func configure_viewport(p_viewport: SubViewport, p_pixel_perfect: bool) -> void:
	if p_viewport == null:
		return
	if p_pixel_perfect:
		p_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	else:
		p_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
