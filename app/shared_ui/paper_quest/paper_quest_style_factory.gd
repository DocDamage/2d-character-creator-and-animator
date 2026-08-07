class_name PaperQuestStyleFactory
extends RefCounted

static func box(
		background: Color,
		border: Color,
		radius: int = 6,
		border_width: int = 1,
		content_margin: float = 10.0,
		shadow_color: Color = Color.TRANSPARENT,
		shadow_size: int = 0,
		shadow_offset: Vector2 = Vector2.ZERO
	) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	style.anti_aliasing = true
	return style

static func paper(background: Color, border: Color, high_contrast: bool = false, raised: bool = true) -> StyleBoxFlat:
	var shadow := Color(0.16, 0.10, 0.05, 0.28) if raised and not high_contrast else Color.TRANSPARENT
	return box(background, border, 8, 2 if high_contrast else 1, 12.0, shadow, 4 if raised and not high_contrast else 0, Vector2(0, 3))

static func focus(background: Color, focus_color: Color, radius: int = 7) -> StyleBoxFlat:
	return box(background, focus_color, radius, 3, 10.0)

static func line(background: Color, border: Color, focus_color: Color, focused: bool = false) -> StyleBoxFlat:
	return box(background, focus_color if focused else border, 6, 3 if focused else 1, 9.0)
