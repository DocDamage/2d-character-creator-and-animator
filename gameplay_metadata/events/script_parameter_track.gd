# ScriptParameterTrack -- Named, typed values consumable by runtime scripts and plugins.
class_name ScriptParameterTrack
extends "res://animation/tracks/track_schema.gd"

var parameter_name: String = ""
var value_type: String = "variant"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "", p_parameter_name: String = "", p_value_type: String = "variant") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	parameter_name = p_parameter_name
	value_type = p_value_type
	track_type = TrackType.SCRIPT_PARAMETER


func add_parameter_key(time: float, value: Variant, key_id: String, interpolation: int = Interpolation.STEPPED) -> Dictionary:
	var key := {"key_id": key_id, "time": time, "value": value, "interpolation": interpolation, "easing": 0.0}
	keys.append(key)
	return key


func evaluate_value(time: float, fallback: Variant = null) -> Variant:
	var current: Variant = fallback
	for key in get_sorted_keys():
		if float(key.get("time", 0.0)) > time:
			break
		current = key.get("value", fallback)
	return current


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["parameter_name"] = parameter_name
	data["value_type"] = value_type
	return data


func from_dict(data: Dictionary) -> TrackDefinition:
	super.from_dict(data)
	parameter_name = str(data.get("parameter_name", ""))
	value_type = str(data.get("value_type", "variant"))
	return self


func validate() -> Array:
	var errors := super.validate()
	if parameter_name.is_empty():
		errors.append("ScriptParameterTrack requires parameter_name")
	if value_type not in ["variant", "bool", "number", "string", "color"]:
		errors.append("ScriptParameterTrack has unsupported value_type")
	return errors
