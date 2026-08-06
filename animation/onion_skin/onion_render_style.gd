# OnionRenderStyle -- Color tinting, opacity falloff, and depth layering style configuration.
# ONI-004: Manages visual styling for onion skin ghosts (Red for past, Blue for future).
class_name OnionRenderStyle
extends RefCounted

## Color tint definitions.
var past_color: Color = Color(1.0, 0.2, 0.2, 0.5)   # Red / warm for past frames
var future_color: Color = Color(0.2, 0.5, 1.0, 0.5) # Blue / cool for future frames
var pinned_color: Color = Color(0.2, 0.9, 0.3, 0.6) # Green for pinned frames

## Opacity falloff controls.
var base_opacity: float = 0.6
var opacity_step_decay: float = 0.2 # Subtracts per step distance
var min_opacity: float = 0.05

## Layering ordering.
var render_behind_main: bool = true
var past_behind_future: bool = true


## Calculates tint color for a GhostFrame based on relative step distance.
func get_ghost_color(frame: RefCounted) -> Color:
	if frame == null:
		return Color.WHITE
	var is_past: bool = bool(frame.get("is_past"))
	var rel_step: int = int(frame.get("relative_step"))
	var base_c: Color = past_color if is_past else future_color
	var dist: int = abs(rel_step)
	var alpha: float = clampf(base_opacity - (dist - 1) * opacity_step_decay, min_opacity, 1.0)
	return Color(base_c.r, base_c.g, base_c.b, alpha * base_c.a)


## Calculates z-index offset for layering rendering of ghost frames.
func get_ghost_z_index(frame: RefCounted, main_z_index: int = 0) -> int:
	if frame == null:
		return main_z_index
	var rel_step: int = int(frame.get("relative_step"))
	var dist: int = abs(rel_step)
	if render_behind_main:
		return main_z_index - dist
	else:
		return main_z_index + dist


## Modifies opacity falloff parameters.
func configure_opacity(p_base: float, p_decay: float, p_min: float = 0.05) -> void:
	base_opacity = clampf(p_base, 0.0, 1.0)
	opacity_step_decay = clampf(p_decay, 0.0, 1.0)
	min_opacity = clampf(p_min, 0.0, 1.0)
