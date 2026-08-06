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
	duration = p_duration
	loop_end = p_duration


## Start or resume playback.
func play() -> void:
	is_playing = true
	_ping_pong_direction = 1


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
	current_time = clampf(t, 0.0, duration)
	time_changed.emit(current_time)


## Advance the clock by delta_seconds. Call this from a game-loop update.
func advance(delta_seconds: float) -> void:
	if not is_playing:
		return
	var effective_end := loop_end if loop_end > 0.0 else duration
	var effective_start := loop_start

	current_time += delta_seconds * speed * float(_ping_pong_direction)
	time_changed.emit(current_time)

	match loop_mode:
		LoopMode.NONE:
			if current_time >= effective_end:
				current_time = effective_end
				is_playing = false
				playback_stopped.emit()
		LoopMode.LOOP:
			while current_time >= effective_end:
				current_time -= (effective_end - effective_start)
			while current_time < effective_start:
				current_time += (effective_end - effective_start)
		LoopMode.PING_PONG:
			if current_time >= effective_end:
				current_time = effective_end
				_ping_pong_direction = -1
			elif current_time <= effective_start:
				current_time = effective_start
				_ping_pong_direction = 1


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
	duration = float(d.get("duration", 1.0))
	speed = float(d.get("speed", 1.0))
	loop_mode = int(d.get("loop_mode", LoopMode.NONE)) as LoopMode
	loop_start = float(d.get("loop_start", 0.0))
	loop_end = float(d.get("loop_end", -1.0))
