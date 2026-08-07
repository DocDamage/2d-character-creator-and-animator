# KeyframeData -- Atomic keyframe data schema for all track types
# ANM-001: Defines key schema; value is a Variant stored as JSON-compatible type.
class_name KeyframeData
extends RefCounted

## Schema version for migration support.
const SCHEMA_VERSION := "1.0.0"

## Stable unique identifier within a track.
var key_id: String = ""

## Time in seconds (must be >= 0).
var time: float = 0.0

## The animated value. Stored as a JSON-compatible type:
##   float for scalars and angles
##   Array[float] for 2D/3D vectors ([x, y] or [x, y, z])
##   String for image_swap asset IDs and attribute strings
##   bool for visibility
##   int for z-order
var value: Variant = 0.0

## Interpolation mode applied going INTO this key.
## Uses TrackDefinition.Interpolation enum values.
var interpolation: int = 1  # LINEAR by default

## Optional per-key easing weight (0.0-1.0), for SMOOTH mode only.
var easing: float = 0.5

## Optional cubic Bézier handles, expressed in normalized segment space.
## `out_handle` belongs to the segment beginning at this key and
## `in_handle` belongs to the segment ending at this key.  They are optional
## on disk for backwards compatibility with every existing project.
var out_handle: Vector2 = Vector2(0.25, 0.0)
var in_handle: Vector2 = Vector2(-0.25, 0.0)


func _init(p_id: String = "", p_time: float = 0.0, p_value: Variant = 0.0) -> void:
	key_id = p_id
	time = p_time
	value = p_value


## Convert to a JSON-compatible dictionary (deterministic key order).
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"key_id": key_id,
		"time": time,
		"value": value,
		"interpolation": interpolation,
		"easing": easing,
		"out_handle": [out_handle.x, out_handle.y],
		"in_handle": [in_handle.x, in_handle.y]
	}


## Populate this instance from a serialized dictionary. Returns self.
func from_dict(d: Dictionary) -> KeyframeData:
	key_id = d.get("key_id", "")
	time = float(d.get("time", 0.0))
	value = d.get("value", 0.0)
	interpolation = int(d.get("interpolation", 1))
	easing = float(d.get("easing", 0.5))
	out_handle = _handle_from_value(d.get("out_handle", [0.25, 0.0]), Vector2(0.25, 0.0))
	in_handle = _handle_from_value(d.get("in_handle", [-0.25, 0.0]), Vector2(-0.25, 0.0))
	return self


## Validate required fields. Returns Array of error strings.
func validate() -> Array:
	var errors: Array = []
	if key_id.is_empty():
		errors.append("key_id is required")
	if time < 0.0:
		errors.append("key time must be >= 0")
	return errors


func _handle_from_value(raw: Variant, fallback: Vector2) -> Vector2:
	if raw is Vector2:
		return raw as Vector2
	if raw is Array and (raw as Array).size() >= 2:
		var values: Array = raw
		return Vector2(float(values[0]), float(values[1]))
	return fallback
