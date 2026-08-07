# PlaybackClock -- Authoritative lightweight animation playback clock
# ANM-012: Implement playback and looping
class_name PlaybackClock
extends RefCounted

## Loop modes.
enum LoopMode { NONE, LOOP, PING_PONG }

## Current time in seconds.
var current_time: float = 0.0

## Total duration in seconds.
var duration: float = 1.0

## Playback speed multiplier (1.0 = normal).
var speed: float = 1.0

## Whether playback is active.
var is_playing: bool = false

## Loop mode.
var loop_mode: LoopMode = LoopMode.NONE

## Optional loop region. When set, playback wraps within this range.
var loop_start: float = 0.0
var loop_end: float = -1.0  # -1 means use clip duration

## Direction flag for ping-pong. +1 = forward, -1 = backward.
var _ping_pong_direction: int = 1

## Signal: emitted when current_time changes.
signal time_changed(t: float)

## Signal: emitted when playback stops at the end (non-looping).
signal playback_stopped()


func _init(p_duration: float = 1.0) -> void:
	duration = maxf(0.0, p_duration)
	loop_end = duration


## Start or resume playback.
func play() -> void:
	is_playing = true


## Pause playback without resetting time.
func pause() -> void:
	is_playing = false


## Stop playback and reset to time 0.
func stop() -> void:
	is_playing = false
	current_time = 0.0
	_ping_pong_direction = 1
	time_changed.emit(current_time)


## Seek to a specific time. Clamps to [0, duration].
func seek(t: float) -> void:
	current_time = clampf(t, 0.0, maxf(0.0, duration))
	time_changed.emit(current_time)


## Advance the clock by delta_seconds. Call this from a game-loop update.
func advance(delta_seconds: float) -> void:
	if not is_playing:
		return
	var range := _effective_range()
	var effective_start: float = range.x
	var effective_end: float = range.y
	var span := effective_end - effective_start
	if span <= 0.0:
		current_time = effective_start
		is_playing = false
		playback_stopped.emit()
		time_changed.emit(current_time)
		return
	var travel := delta_seconds * speed

	match loop_mode:
		LoopMode.NONE:
			current_time += travel
			if current_time >= effective_end:
				current_time = effective_end
				is_playing = false
				playback_stopped.emit()
			elif current_time <= effective_start:
				current_time = effective_start
				if travel < 0.0:
					is_playing = false
					playback_stopped.emit()
		LoopMode.LOOP:
			current_time = effective_start + fposmod(current_time + travel - effective_start, span)
		LoopMode.PING_PONG:
			# Work in an unfolded two-span interval so large frame hitches keep
			# their remaining travel instead of sticking at a boundary.
			var local_position := clampf(current_time, effective_start, effective_end) - effective_start
			var unfolded := local_position if _ping_pong_direction >= 0 else 2.0 * span - local_position
			unfolded = fposmod(unfolded + travel, 2.0 * span)
			if unfolded < span:
				current_time = effective_start + unfolded
				_ping_pong_direction = 1
			else:
				current_time = effective_start + (2.0 * span - unfolded)
				_ping_pong_direction = -1
	time_changed.emit(current_time)


## Return the current playback percentage (0.0–1.0).
func get_normalized_time() -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(current_time / duration, 0.0, 1.0)


## Serialize clock settings (not runtime state).
func to_dict() -> Dictionary:
	return {
		"duration": duration,
		"speed": speed,
		"loop_mode": loop_mode,
		"loop_start": loop_start,
		"loop_end": loop_end
	}


## Populate settings from a dictionary.
func from_dict(d: Dictionary) -> void:
	duration = maxf(0.0, float(d.get("duration", 1.0)))
	speed = float(d.get("speed", 1.0))
	loop_mode = int(d.get("loop_mode", LoopMode.NONE)) as LoopMode
	loop_start = float(d.get("loop_start", 0.0))
	loop_end = float(d.get("loop_end", -1.0))
	current_time = clampf(current_time, 0.0, duration)


func _effective_range() -> Vector2:
	var maximum := maxf(0.0, duration)
	var end := clampf(loop_end if loop_end > 0.0 else maximum, 0.0, maximum)
	var start := clampf(loop_start, 0.0, end)
	# Invalid or degenerate loop regions must never enter a wrap loop.  A
	# non-empty clip falls back to its full duration; a zero-duration clip is
	# handled by advance() as a stopped clock.
	if end - start <= 0.000001 and maximum > 0.000001:
		start = 0.0
		end = maximum
	return Vector2(start, end)
