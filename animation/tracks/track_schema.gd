# TrackDefinition -- Per-object animation track data schema
# ANM-001: Defines track schema; ANM-004: per-object tracks
class_name TrackDefinition
extends RefCounted

## Schema version for migration support.
const SCHEMA_VERSION := "1.0.0"

## Track types supported by the timeline.
enum TrackType {
	TRANSFORM_POSITION,
	TRANSFORM_ROTATION,
	TRANSFORM_SCALE,
	IMAGE_SWAP,
	VISIBILITY,
	Z_ORDER,
	ATTRIBUTE,
	ACTION_POINT,
	EVENT,
	HITBOX,
	HURTBOX,
	AUDIO_CUE,
	VISEME,
	SCRIPT_PARAMETER
}

## Interpolation modes.  The first three values are deliberately stable so
## projects created before Bézier support retain their original behaviour.
enum Interpolation { STEPPED, LINEAR, SMOOTH, BEZIER }

## Stable unique identifier.
var track_id: String = ""

## ID of the animated object (bone, slot, sprite node, etc.).
var object_id: String = ""

## Dotted property path, e.g. "bone:upper_arm_r.rotation".
var property_path: String = ""

## Track type determines how values are evaluated and displayed.
var track_type: TrackType = TrackType.ATTRIBUTE

## Serialized KeyframeData dictionaries, sorted ascending by time.
var keys: Array = []

## Display and editing state.
var muted: bool = false
var solo: bool = false
var locked: bool = false
var color: Color = Color.WHITE

## Human-readable display label (optional override).
var display_name: String = ""


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path


## Convert to a serializable dictionary (deterministic key order).
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"track_id": track_id,
		"object_id": object_id,
		"property_path": property_path,
		"track_type": track_type,
		"muted": muted,
		"solo": solo,
		"locked": locked,
		"color": {"r": color.r, "g": color.g, "b": color.b, "a": color.a},
		"display_name": display_name,
		"keys": keys.duplicate(true)
	}


## Populate this instance from a serialized dictionary. Returns self.
func from_dict(d: Dictionary) -> TrackDefinition:
	track_id = d.get("track_id", "")
	object_id = d.get("object_id", "")
	property_path = d.get("property_path", "")
	track_type = int(d.get("track_type", TrackType.ATTRIBUTE)) as TrackType
	muted = bool(d.get("muted", false))
	solo = bool(d.get("solo", false))
	locked = bool(d.get("locked", false))
	var cd: Dictionary = d.get("color", {})
	if not cd.is_empty():
		color = Color(
			float(cd.get("r", 1.0)),
			float(cd.get("g", 1.0)),
			float(cd.get("b", 1.0)),
			float(cd.get("a", 1.0))
		)
	display_name = d.get("display_name", "")
	keys = (d.get("keys", []) as Array).duplicate(true)
	return self


## Validate required fields. Returns Array of error strings.
func validate() -> Array:
	var errors: Array = []
	if track_id.is_empty():
		errors.append("track_id is required")
	if object_id.is_empty():
		errors.append("object_id is required")
	if property_path.is_empty():
		errors.append("property_path is required")
	return errors


## Return keys sorted by ascending time (non-mutating).
func get_sorted_keys() -> Array:
	var sorted := keys.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	return sorted
