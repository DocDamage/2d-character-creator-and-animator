# PivotEditor — Pivot point editing and normalized anchor placement helper
class_name PivotEditor
extends RefCounted

signal pivot_changed(pivot_offset: Vector2, normalized_pivot: Vector2)

enum AnchorPreset { TOP_LEFT, TOP_CENTER, TOP_RIGHT, CENTER_LEFT, CENTER, CENTER_RIGHT, BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT }


static func get_preset_normalized(p_preset: AnchorPreset) -> Vector2:
	match p_preset:
		AnchorPreset.TOP_LEFT: return Vector2(0.0, 0.0)
		AnchorPreset.TOP_CENTER: return Vector2(0.5, 0.0)
		AnchorPreset.TOP_RIGHT: return Vector2(1.0, 0.0)
		AnchorPreset.CENTER_LEFT: return Vector2(0.0, 0.5)
		AnchorPreset.CENTER: return Vector2(0.5, 0.5)
		AnchorPreset.CENTER_RIGHT: return Vector2(1.0, 0.5)
		AnchorPreset.BOTTOM_LEFT: return Vector2(0.0, 1.0)
		AnchorPreset.BOTTOM_CENTER: return Vector2(0.5, 1.0)
		AnchorPreset.BOTTOM_RIGHT: return Vector2(1.0, 1.0)
	return Vector2(0.5, 0.5)


static func normalize_pivot(p_offset: Vector2, p_texture_size: Vector2) -> Vector2:
	if p_texture_size.x <= 0 or p_texture_size.y <= 0:
		return Vector2(0.5, 0.5)
	return Vector2(p_offset.x / p_texture_size.x, p_offset.y / p_texture_size.y)


static func denormalize_pivot(p_normalized: Vector2, p_texture_size: Vector2) -> Vector2:
	return Vector2(p_normalized.x * p_texture_size.x, p_normalized.y * p_texture_size.y)


static func calculate_preset_offset(p_preset: AnchorPreset, p_texture_size: Vector2) -> Vector2:
	var norm := get_preset_normalized(p_preset)
	return denormalize_pivot(norm, p_texture_size)
