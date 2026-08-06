# AutoKeyController -- Intercepts property changes and inserts keyframes
# ANM-005: Implement auto-key mode
class_name AutoKeyController
extends RefCounted

## Whether auto-key mode is active.
var enabled: bool = false

## The factory used to create keys (KeyFactory instance).
var factory = null

## The playback clock providing the current recording time (PlaybackClock instance).
var clock = null


func _init(p_factory = null, p_clock = null) -> void:
	factory = p_factory
	clock = p_clock


## Record a property change as a keyframe if auto-key is enabled.
## track: any object with a .keys Array.
## Returns the inserted key dict, or empty dict if auto-key is off.
func on_property_changed(track, value: Variant) -> Dictionary:
	if not enabled:
		return {}
	if factory == null:
		push_error("AutoKeyController: factory is not assigned")
		return {}
	if clock == null:
		push_error("AutoKeyController: clock is not assigned")
		return {}
	var t: float = clock.current_time
	return factory.create_key(track, t, value)


## Enable or disable auto-key mode.
func set_enabled(active: bool) -> void:
	enabled = active


## Returns true when auto-key is active, false otherwise.
func is_enabled() -> bool:
	return enabled
