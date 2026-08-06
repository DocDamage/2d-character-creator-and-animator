# RuntimeTrackPlayer -- Deterministic value/curve sampler for exported timeline tracks.
extends RefCounted


func evaluate(tracks: Array, time: float) -> Dictionary:
	var output: Dictionary = {}
	for track in tracks:
		var record := track as Dictionary
		var keys: Array = record.get("keys", []) as Array
		if keys.is_empty(): continue
		keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
		var before := keys[0] as Dictionary
		var after: Dictionary = {}
		for key in keys:
			if float((key as Dictionary).get("time", 0.0)) > time: after = key; break
			before = key
		var value = before.get("value")
		if not after.is_empty() and str(record.get("interpolation", "step")) == "linear" and value is float and after.get("value") is float:
			var span := maxf(0.000001, float(after.get("time", 0.0)) - float(before.get("time", 0.0)))
			value = lerpf(float(value), float(after.get("value")), clampf((time - float(before.get("time", 0.0))) / span, 0.0, 1.0))
		output[str(record.get("target", record.get("track_id", "")))] = value
	return output
