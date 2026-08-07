# LpcTypedTrackSchema -- Validated LPC-only track contracts; unknown executable behavior is never evaluated.
class_name LpcTypedTrackSchema
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const TYPES := ["source_frame", "image_cel_swap", "layer_transform", "visibility", "z_order", "palette", "rig_bone_transform", "ik_target", "mesh_control", "event", "direction"]
const DISCRETE_TYPES := ["source_frame", "image_cel_swap", "visibility", "z_order", "palette", "event", "direction"]


static func create(track_type: String, target_id: String, track_id: String = "") -> Dictionary:
	var kind := track_type.to_lower().strip_edges()
	return {"track_schema_version": SCHEMA_VERSION, "track_id": track_id if not track_id.is_empty() else "%s:%s" % [kind, target_id], "track_type": kind, "target_id": target_id, "keys": [], "muted": false, "solo": false, "locked": false, "interpolation": "linear", "metadata": {}}


static func validate(track: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var kind := str(track.get("track_type", "")).to_lower()
	if str(track.get("track_id", "")).is_empty(): errors.append("LPC track is missing track_id.")
	if kind not in TYPES: errors.append("LPC track '%s' has an unsupported executable type '%s'." % [track.get("track_id", ""), kind])
	if str(track.get("target_id", "")).is_empty() and kind not in ["event", "direction"]: errors.append("LPC track '%s' is missing target_id." % track.get("track_id", ""))
	var keys: Array = track.get("keys", [])
	var seen_times: Dictionary = {}
	for raw_key in keys:
		if not raw_key is Dictionary: errors.append("LPC track '%s' has a non-object key." % track.get("track_id", "")); continue
		var key: Dictionary = raw_key; var time := float(key.get("time", -1.0))
		if time < 0.0: errors.append("LPC track '%s' has a negative key time." % track.get("track_id", ""))
		var time_key := "%.6f" % time
		if seen_times.has(time_key): errors.append("LPC track '%s' has duplicate key time %s." % [track.get("track_id", ""), time_key])
		seen_times[time_key] = true
	return errors


static func with_key(track: Dictionary, time: float, value: Variant, interpolation: String = "") -> Dictionary:
	var result := track.duplicate(true); var keys: Array = (result.get("keys", []) as Array).duplicate(true); var replaced := false
	for index in range(keys.size()):
		if keys[index] is Dictionary and is_equal_approx(float((keys[index] as Dictionary).get("time", 0.0)), time):
			keys[index] = _key(str(result.get("track_id", "")), time, value, interpolation); replaced = true
	if not replaced: keys.append(_key(str(result.get("track_id", "")), time, value, interpolation))
	keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)));
	result["keys"] = keys; return result


static func value_at(track: Dictionary, time: float) -> Variant:
	var keys: Array = (track.get("keys", []) as Array).duplicate(true)
	if keys.is_empty(): return null
	keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	var previous: Dictionary = keys[0]
	if time <= float(previous.get("time", 0.0)): return previous.get("value")
	for index in range(1, keys.size()):
		var next: Dictionary = keys[index]
		if time <= float(next.get("time", 0.0)):
			var kind := str(track.get("track_type", "")).to_lower()
			var interpolation := str(previous.get("interpolation", track.get("interpolation", "linear"))).to_lower()
			if kind in DISCRETE_TYPES or interpolation == "stepped": return previous.get("value")
			var span := float(next.get("time", 0.0)) - float(previous.get("time", 0.0))
			return _interpolate(previous.get("value"), next.get("value"), clampf((time - float(previous.get("time", 0.0))) / span, 0.0, 1.0) if span > 0.0 else 1.0)
		previous = next
	return previous.get("value")


static func events_between(track: Dictionary, previous_time: float, current_time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if str(track.get("track_type", "")) != "event" or previous_time < 0.0: return result
	for raw_key in track.get("keys", []):
		if raw_key is Dictionary and float((raw_key as Dictionary).get("time", 0.0)) > previous_time and float((raw_key as Dictionary).get("time", 0.0)) <= current_time: result.append((raw_key as Dictionary).duplicate(true))
	return result


static func _key(track_id: String, time: float, value: Variant, interpolation: String) -> Dictionary:
	return {"key_id": "%s@%.6f" % [track_id, time], "time": maxf(0.0, time), "value": value, "interpolation": interpolation if not interpolation.is_empty() else "linear"}


static func _interpolate(left: Variant, right: Variant, amount: float) -> Variant:
	if typeof(left) != typeof(right): return left if amount < 1.0 else right
	match typeof(left):
		TYPE_INT, TYPE_FLOAT: return lerpf(float(left), float(right), amount)
		TYPE_VECTOR2: return (left as Vector2).lerp(right as Vector2, amount)
		TYPE_ARRAY:
			var result: Array = []; var a: Array = left; var b: Array = right
			for index in range(mini(a.size(), b.size())): result.append(_interpolate(a[index], b[index], amount))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = (left as Dictionary).duplicate(true)
			for key in (right as Dictionary):
				if result.has(key): result[key] = _interpolate(result[key], (right as Dictionary)[key], amount)
			return result
		_: return left if amount < 1.0 else right
