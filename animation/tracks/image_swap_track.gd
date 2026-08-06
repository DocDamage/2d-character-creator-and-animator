# ImageSwapTrack -- Specialized track for per-frame sprite/image replacement
# ANM-009: Implement image-swap tracks
extends "res://animation/tracks/track_schema.gd"

## Schema version for migration support.
const IMAGE_SWAP_SCHEMA_VERSION := "1.0.0"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.IMAGE_SWAP


## Add an image-swap keyframe at the given time.
## asset_id is a stable asset registry ID string.
func add_image_key(time: float, asset_id: String, key_id: String) -> Dictionary:
	var k := {
		"key_id": key_id,
		"time": time,
		"value": asset_id,
		"interpolation": Interpolation.STEPPED,
		"easing": 0.0
	}
	keys.append(k)
	return k


## Evaluate the current image asset ID at the given time.
## Returns an empty string if no key has been reached yet.
func evaluate_image(t: float) -> String:
	var sorted := get_sorted_keys()
	var current := ""
	for k in sorted:
		if float(k.get("time", 0.0)) <= t:
			current = str(k.get("value", ""))
		else:
			break
	return current


## Validate that all key values are non-empty strings.
func validate() -> Array:
	var errors := super.validate()
	for k in keys:
		var v = k.get("value", "")
		if typeof(v) != TYPE_STRING or str(v).is_empty():
			errors.append("ImageSwapTrack key at t=%s has empty asset_id" % str(k.get("time", "?")))
	return errors
