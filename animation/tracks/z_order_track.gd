# ZOrderTrack -- Specialized track for animatable z-order (render layer index)
# ANM-011: Implement animatable z-order
extends "res://animation/tracks/track_schema.gd"

## Schema version for migration support.
const Z_ORDER_SCHEMA_VERSION := "1.0.0"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.Z_ORDER


## Add a z-order keyframe at the given time.
func add_z_order_key(time: float, z_index: int, key_id: String) -> Dictionary:
	var k := {
		"key_id": key_id,
		"time": time,
		"value": z_index,
		"interpolation": Interpolation.STEPPED,
		"easing": 0.0
	}
	keys.append(k)
	return k


## Evaluate z-order at the given time.
## Returns 0 if no key has been reached yet.
func evaluate_z_order(t: float) -> int:
	var sorted := get_sorted_keys()
	var current := 0
	for k in sorted:
		if float(k.get("time", 0.0)) <= t:
			current = int(k.get("value", 0))
		else:
			break
	return current


## Validate that all key values are integers.
func validate() -> Array:
	var errors := super.validate()
	for k in keys:
		var v = k.get("value", 0)
		if typeof(v) != TYPE_INT:
			errors.append("ZOrderTrack key at t=%s has non-integer value" % str(k.get("time", "?")))
	return errors
