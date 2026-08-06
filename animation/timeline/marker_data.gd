# MarkerData -- Named timeline position marker
# ANM-013: Used by MarkerRegion registry
class_name MarkerData
extends RefCounted

## Schema version.
const SCHEMA_VERSION := "1.0.0"

## Stable unique identifier.
var marker_id: String = ""

## Display name shown in the timeline ruler.
var name: String = ""

## Time in seconds.
var time: float = 0.0

## Display color.
var color: Color = Color.YELLOW


func _init(p_id: String = "", p_name: String = "", p_time: float = 0.0) -> void:
	marker_id = p_id
	name = p_name
	time = p_time


func to_dict() -> Dictionary:
	return {
		"marker_id": marker_id,
		"name": name,
		"time": time,
		"color": {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
	}


## Populate this instance from a serialized dictionary. Returns self.
func from_dict(d: Dictionary) -> MarkerData:
	marker_id = d.get("marker_id", "")
	name = d.get("name", "")
	time = float(d.get("time", 0.0))
	var cd: Dictionary = d.get("color", {})
	if not cd.is_empty():
		color = Color(
			float(cd.get("r", 1.0)),
			float(cd.get("g", 1.0)),
			float(cd.get("b", 0.0)),
			1.0
		)
	return self


func validate() -> Array:
	var errors: Array = []
	if marker_id.is_empty():
		errors.append("marker_id is required")
	if time < 0.0:
		errors.append("marker time must be >= 0")
	return errors
