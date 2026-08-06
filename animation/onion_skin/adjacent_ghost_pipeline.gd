# AdjacentGhostPipeline -- Computes preceding and following frame ghost overlays.
# ONI-001: Calculates ghost pose frame times relative to current playhead time.
class_name AdjacentGhostPipeline
extends RefCounted

## Schema for a single ghost overlay frame.
class GhostFrame:
	var frame_index: int = 0
	var time: float = 0.0
	var is_past: bool = true
	var relative_step: int = 0 # e.g. -2, -1, +1, +2
	var transform: Transform2D = Transform2D.IDENTITY
	var opacity: float = 1.0
	var tint_color: Color = Color.WHITE

	func to_dict() -> Dictionary:
		return {
			"frame_index": frame_index,
			"time": time,
			"is_past": is_past,
			"relative_step": relative_step,
			"opacity": opacity,
			"tint_color": tint_color.to_html()
		}


## Configuration parameters for adjacent ghost generation.
var steps_before: int = 2
var steps_after: int = 2
var frame_delta: float = 0.0333 # 30 FPS step
var enabled: bool = true


func _init(p_before: int = 2, p_after: int = 2, p_fps: float = 30.0) -> void:
	steps_before = p_before
	steps_after = p_after
	frame_delta = 1.0 / p_fps if p_fps > 0.0 else 0.0333


## Generates array of GhostFrame instances relative to current playhead time.
func generate_ghost_frames(current_time: float, max_duration: float = 100.0) -> Array[GhostFrame]:
	var ghosts: Array[GhostFrame] = []
	if not enabled:
		return ghosts

	# Past frames (-steps_before .. -1)
	for i in range(steps_before, 0, -1):
		var step_idx: int = -i
		var ghost_time: float = current_time + step_idx * frame_delta
		if ghost_time >= 0.0:
			var frame := GhostFrame.new()
			frame.time = ghost_time
			frame.relative_step = step_idx
			frame.is_past = true
			frame.frame_index = int(round(ghost_time / frame_delta))
			ghosts.append(frame)

	# Future frames (+1 .. +steps_after)
	for j in range(1, steps_after + 1):
		var ghost_time: float = current_time + j * frame_delta
		if ghost_time <= max_duration:
			var frame := GhostFrame.new()
			frame.time = ghost_time
			frame.relative_step = j
			frame.is_past = false
			frame.frame_index = int(round(ghost_time / frame_delta))
			ghosts.append(frame)

	return ghosts
