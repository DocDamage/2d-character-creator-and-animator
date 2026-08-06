# VisibilityTrack -- Specialized track for boolean object visibility animation
# ANM-010: Implement visibility tracks
extends "res://animation/tracks/track_schema.gd"

## Schema version for migration support.
const VISIBILITY_SCHEMA_VERSION := "1.0.0"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.VISIBILITY


## Add a visibility keyframe at the given time.
func add_visibility_key(time: float, visible: bool, key_id: String) -> Dictionary:
	var k := {
		"key_id": key_id,
		"time": time,
		"value": visible,
		"interpolation": Interpolation.STEPPED,
		"easing": 0.0
	}
	keys.append(k)
	return k


## Evaluate visibility state at the given time.
## Returns true if no key has been reached yet (default visible).
func evaluate_visibility(t: float) -> bool:
	var sorted := get_sorted_keys()
	var current := true
	for k in sorted:
		if float(k.get("time", 0.0)) <= t:
			current = bool(k.get("value", true))
		else:
			break
	return current


## Validate that all key values are booleans.
func validate() -> Array:
	var errors := super.validate()
	for k in keys:
		var v = k.get("value", true)
		if typeof(v) != TYPE_BOOL:
			errors.append("VisibilityTrack key at t=%s has non-bool value" % str(k.get("time", "?")))
	return errors
