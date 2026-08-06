# KeyPinnedGhostManager -- Manages keyframe-only and user-pinned frame ghosts.
# ONI-002: Filters ghost pose overlays for keyframe boundaries and pinned frame indices.
class_name KeyPinnedGhostManager
extends RefCounted

## Ghost filter mode.
enum Mode {
	ADJACENT = 0,
	KEYFRAMES_ONLY = 1,
	PINNED_ONLY = 2,
	HYBRID = 3
}

var current_mode: int = Mode.ADJACENT
var pinned_frame_times: Array[float] = []
var max_keyframe_search_distance: int = 5


## Pins a specific animation time as a persistent ghost frame.
func pin_frame(time: float) -> void:
	if time >= 0.0 and not pinned_frame_times.has(time):
		pinned_frame_times.append(time)
		pinned_frame_times.sort()


## Unpins a previously pinned ghost frame time.
func unpin_frame(time: float) -> void:
	pinned_frame_times.erase(time)


## Clears all pinned ghost frames.
func clear_pins() -> void:
	pinned_frame_times.clear()


## Filters keyframe times from an AnimationClip to produce keyframe ghost frames.
func generate_keyframe_ghosts(clip: RefCounted, current_time: float) -> Array:
	var ghosts: Array = []
	if clip == null:
		return ghosts

	var AdjacentGhostPipelineScript = preload("res://animation/onion_skin/adjacent_ghost_pipeline.gd")

	var key_times: Array[float] = []
	var tracks: Array = clip.get("tracks") if clip.get("tracks") != null else []
	for track in tracks:
		var keys: Array = track.get("keys") if track.get("keys") != null else []
		for key in keys:
			var kt: float = float(key.get("time"))
			if not key_times.has(kt):
				key_times.append(kt)
	key_times.sort()

	for kt in key_times:
		if absf(kt - current_time) > 0.001:
			var frame = AdjacentGhostPipelineScript.GhostFrame.new()
			frame.time = kt
			frame.is_past = (kt < current_time)
			frame.relative_step = -1 if frame.is_past else 1
			ghosts.append(frame)

	return ghosts


## Generates ghost frames for user-pinned frame times.
func generate_pinned_ghosts(current_time: float) -> Array:
	var ghosts: Array = []
	var AdjacentGhostPipelineScript = preload("res://animation/onion_skin/adjacent_ghost_pipeline.gd")

	for pt in pinned_frame_times:
		if absf(pt - current_time) > 0.001:
			var frame = AdjacentGhostPipelineScript.GhostFrame.new()
			frame.time = pt
			frame.is_past = (pt < current_time)
			frame.relative_step = -1 if frame.is_past else 1
			ghosts.append(frame)

	return ghosts
