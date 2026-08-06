# RegionData -- Named time region for loop ranges and sections
# ANM-013: Used by MarkerRegion registry
class_name RegionData
extends RefCounted

## Schema version.
const SCHEMA_VERSION := "1.0.0"

## Stable unique identifier.
var region_id: String = ""

## Display name.
var name: String = ""

## Start time in seconds.
var start_time: float = 0.0

## End time in seconds.
var end_time: float = 1.0

## Display color.
var color: Color = Color.CYAN


func _init(p_id: String = "", p_name: String = "", p_start: float = 0.0, p_end: float = 1.0) -> void:
	region_id = p_id
	name = p_name
	start_time = p_start
	end_time = p_end


func duration() -> float:
	return end_time - start_time


func to_dict() -> Dictionary:
	return {
		"region_id": region_id,
		"name": name,
		"start_time": start_time,
		"end_time": end_time,
		"color": {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
	}


## Populate this instance from a serialized dictionary. Returns self.
func from_dict(d: Dictionary) -> RegionData:
	region_id = d.get("region_id", "")
	name = d.get("name", "")
	start_time = float(d.get("start_time", 0.0))
	end_time = float(d.get("end_time", 1.0))
	var cd: Dictionary = d.get("color", {})
	if not cd.is_empty():
		color = Color(
			float(cd.get("r", 0.0)),
			float(cd.get("g", 1.0)),
			float(cd.get("b", 1.0)),
			1.0
		)
	return self


func validate() -> Array:
	var errors: Array = []
	if region_id.is_empty():
		errors.append("region_id is required")
	if end_time <= start_time:
		errors.append("region end_time must be > start_time")
	return errors
