# AnimationPreviewEvaluator -- Evaluates project animation without touching the
# rest-pose document.  The returned dictionary is a disposable preview frame
# consumed by canvas, Inspector, onion skin, and review rendering alike.
class_name AnimationPreviewEvaluator
extends RefCounted

const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")
const BezierEvaluatorScript = preload("res://animation/curves/bezier_evaluator.gd")
const AngleInterpolatorScript = preload("res://animation/curves/angle_interpolator.gd")
const SmoothCubicEvaluatorScript = preload("res://animation/curves/smooth_cubic_evaluator.gd")


func evaluate(session, clip: Dictionary, current_time: float, previous_time: float = -1.0, is_playing: bool = false, base_layers: Array = []) -> Dictionary:
	var layers: Array = base_layers.duplicate(true) if not base_layers.is_empty() else (session.get_preview_layers().duplicate(true) if session != null and is_instance_valid(session) else [])
	var rig: Dictionary = session.get_active_rig().duplicate(true) if session != null and is_instance_valid(session) else {}
	var frame := {
		"clip_id": str(clip.get("clip_id", "")), "time": maxf(0.0, current_time), "layers": layers, "rig_pose": rig,
		"layer_overrides": {}, "bone_overrides": {}, "image_swaps": {}, "z_order": {},
		"action_points": [], "hitboxes": [], "hurtboxes": [], "viseme_state": [], "audio_cues": [],
		"events": [], "script_parameters": {}, "preview_log": [], "warnings": [],
	}
	if clip.is_empty() or session == null or not is_instance_valid(session): return frame.duplicate(true)
	var tracks: Array = clip.get("tracks", [])
	var has_solo := false
	for raw_track in tracks:
		if bool((raw_track as Dictionary).get("solo", false)): has_solo = true
	for raw_track in tracks:
		var track: Dictionary = raw_track
		if bool(track.get("muted", false)) or (has_solo and not bool(track.get("solo", false))): continue
		_apply_track(session, clip, track, frame, current_time, previous_time, is_playing)
	_apply_layer_order(frame)
	return frame.duplicate(true)


func _apply_track(session, clip: Dictionary, track: Dictionary, frame: Dictionary, time: float, previous_time: float, is_playing: bool) -> void:
	var kind := int(track.get("track_type", TrackDefinition.TrackType.ATTRIBUTE))
	var object_id := str(track.get("object_id", ""))
	var property_path := str(track.get("property_path", ""))
	var track_id := str(track.get("track_id", ""))
	var value = _evaluate_track_value(track, time, _is_discrete_track(kind))
	if value == null and kind not in [TrackDefinition.TrackType.EVENT, TrackDefinition.TrackType.AUDIO_CUE]: return
	match kind:
		TrackDefinition.TrackType.TRANSFORM_POSITION, TrackDefinition.TrackType.TRANSFORM_ROTATION, TrackDefinition.TrackType.TRANSFORM_SCALE, TrackDefinition.TrackType.VISIBILITY, TrackDefinition.TrackType.ATTRIBUTE:
			_apply_property_value(frame, object_id, property_path, value, kind)
		TrackDefinition.TrackType.IMAGE_SWAP:
			_apply_image_swap(session, frame, object_id, value, track_id)
		TrackDefinition.TrackType.Z_ORDER:
			if not object_id.is_empty(): frame.z_order[object_id] = int(value)
		TrackDefinition.TrackType.ACTION_POINT:
			if value is Dictionary:
				var point: Dictionary = (value as Dictionary).duplicate(true)
				point["track_id"] = track_id
				point["object_id"] = object_id
				frame.action_points.append(point)
		TrackDefinition.TrackType.HITBOX, TrackDefinition.TrackType.HURTBOX:
			if value is Array:
				for raw_shape in value:
					if not (raw_shape is Dictionary): continue
					var shape: Dictionary = (raw_shape as Dictionary).duplicate(true)
					shape["track_id"] = track_id
					shape["object_id"] = object_id
					shape["kind"] = "hitbox" if kind == TrackDefinition.TrackType.HITBOX else "hurtbox"
					if kind == TrackDefinition.TrackType.HITBOX: frame.hitboxes.append(shape)
					else: frame.hurtboxes.append(shape)
		TrackDefinition.TrackType.VISEME:
			if value is Dictionary:
				var viseme: Dictionary = (value as Dictionary).duplicate(true)
				viseme["track_id"] = track_id
				var mouth_layer_id := str(viseme.get("mouth_attachment_id", object_id))
				if mouth_layer_id.is_empty(): mouth_layer_id = object_id
				var viseme_asset_id := str(viseme.get("asset_id", viseme.get("image_asset_id", viseme.get("mouth_asset_id", ""))))
				if not viseme_asset_id.is_empty():
					_apply_image_swap(session, frame, mouth_layer_id, viseme_asset_id, track_id)
					viseme["resolved_asset_id"] = viseme_asset_id
				elif _layer_index(frame.layers, mouth_layer_id) < 0:
					frame.warnings.append("Viseme on '" + track_id + "' targets an unavailable mouth attachment.")
				frame.viseme_state.append(viseme)
		TrackDefinition.TrackType.SCRIPT_PARAMETER:
			var parameter_name := str(track.get("parameter_name", ""))
			if parameter_name.is_empty():
				var parameter_segments := property_path.split(".", false)
				parameter_name = str(parameter_segments[parameter_segments.size() - 1]) if not parameter_segments.is_empty() else "parameter"
			frame.script_parameters[parameter_name] = value
			frame.preview_log.append({"type": "script_parameter", "track_id": track_id, "parameter": parameter_name, "value": value, "safe": true})
		TrackDefinition.TrackType.EVENT:
			for event in _values_crossed(track, clip, previous_time, time, is_playing):
				var safe_event: Dictionary = event
				safe_event["track_id"] = track_id
				safe_event["safe"] = true
				frame.events.append(safe_event)
				frame.preview_log.append({"type": "event", "track_id": track_id, "event": safe_event, "safe": true})
		TrackDefinition.TrackType.AUDIO_CUE:
			for cue in _values_crossed(track, clip, previous_time, time, is_playing):
				var safe_cue: Dictionary = cue
				safe_cue["track_id"] = track_id
				var audio_asset: Dictionary = session.asset_registry.get_asset(str(safe_cue.get("audio_asset_id", "")))
				if audio_asset.is_empty() or not FileAccess.file_exists(str(audio_asset.get("path", ""))):
					frame.warnings.append("Audio cue on '" + track_id + "' references unavailable imported audio.")
					safe_cue["resolvable"] = false
				else:
					safe_cue["resolvable"] = true
				frame.audio_cues.append(safe_cue)
				frame.preview_log.append({"type": "audio_cue", "track_id": track_id, "cue": safe_cue, "safe": true})


func _apply_property_value(frame: Dictionary, object_id: String, property_path: String, value: Variant, track_type: int) -> void:
	if object_id.is_empty(): return
	var property_name := _property_name(property_path, track_type)
	if property_path.begins_with("layer:") or _layer_index(frame.layers, object_id) >= 0:
		var layer_index := _layer_index(frame.layers, object_id)
		if layer_index < 0:
			frame.warnings.append("Layer target '" + object_id + "' is unavailable for preview.")
			return
		var layer: Dictionary = frame.layers[layer_index]
		var state: Dictionary = layer.get("state", {}).duplicate(true)
		_apply_state_property(state, property_name, value)
		layer["state"] = state
		layer["visible"] = bool(state.get("visible", true))
		frame.layers[layer_index] = layer
		frame.layer_overrides[object_id] = state.duplicate(true)
	elif property_path.begins_with("bone:") or (frame.rig_pose.get("bones", {}) as Dictionary).has(object_id):
		var bones: Dictionary = frame.rig_pose.get("bones", {}).duplicate(true)
		if not bones.has(object_id):
			frame.warnings.append("Bone target '" + object_id + "' is unavailable for preview.")
			return
		var bone: Dictionary = bones[object_id].duplicate(true)
		_apply_bone_property(bone, property_name, value)
		bones[object_id] = bone
		frame.rig_pose["bones"] = bones
		frame.bone_overrides[object_id] = bone.duplicate(true)


func _apply_image_swap(session, frame: Dictionary, object_id: String, value: Variant, track_id: String) -> void:
	# Image-swap tracks historically stored the asset ID directly.  Accept the
	# newer explicit payload too so imported projects and artist-authored keys
	# evaluate identically.
	var asset_id: String = str((value as Dictionary).get("asset_id", "")) if value is Dictionary else str(value)
	var asset: Dictionary = session.asset_registry.get_asset(asset_id)
	var path := str(asset.get("path", ""))
	var index := _layer_index(frame.layers, object_id)
	if index < 0 or asset_id.is_empty() or path.is_empty() or not FileAccess.file_exists(path):
		frame.warnings.append("Image swap on '" + track_id + "' references unavailable imported artwork.")
		return
	var layer: Dictionary = frame.layers[index]
	layer["path"] = path
	layer["asset_id"] = asset_id
	layer["missing"] = false
	frame.layers[index] = layer
	frame.image_swaps[object_id] = asset_id


func _apply_layer_order(frame: Dictionary) -> void:
	if (frame.z_order as Dictionary).is_empty(): return
	var original_index: Dictionary = {}
	for index in range((frame.layers as Array).size()):
		original_index[str(((frame.layers as Array)[index] as Dictionary).get("part_id", ""))] = index
	frame.layers.sort_custom(func(a: Dictionary, b: Dictionary):
		var za := int((frame.z_order as Dictionary).get(str(a.get("part_id", "")), original_index.get(str(a.get("part_id", "")), 0)))
		var zb := int((frame.z_order as Dictionary).get(str(b.get("part_id", "")), original_index.get(str(b.get("part_id", "")), 0)))
		return za < zb)


func _evaluate_track_value(track: Dictionary, time: float, force_stepped: bool) -> Variant:
	var keys: Array = _sorted_keys(track.get("keys", []))
	if keys.is_empty(): return null
	var previous: Dictionary = keys[0]
	var rotates := _is_rotation_track(track)
	var angle_mode := _rotation_mode(track)
	var degrees := _rotation_values_are_degrees(track)
	if time <= float(previous.get("time", 0.0)): return previous.get("value")
	for index in range(1, keys.size()):
		var next: Dictionary = keys[index]
		if time <= float(next.get("time", 0.0)):
			if force_stepped: return previous.get("value")
			var mode := int(previous.get("interpolation", TrackDefinition.Interpolation.LINEAR))
			if mode == TrackDefinition.Interpolation.STEPPED: return previous.get("value")
			var span := float(next.get("time", 0.0)) - float(previous.get("time", 0.0))
			var factor := clampf((time - float(previous.get("time", 0.0))) / span, 0.0, 1.0) if span > 0.0 else 1.0
			if mode == TrackDefinition.Interpolation.SMOOTH:
				factor = SmoothCubicEvaluatorScript.ease_factor(factor, clampf(float(previous.get("easing", 0.5)), 0.0, 1.0))
			elif mode == TrackDefinition.Interpolation.BEZIER:
				factor = BezierEvaluatorScript.evaluate_bezier_1d(factor, _handle(previous.get("out_handle", [0.25, 0.0]), Vector2(0.25, 0.0)), _handle(next.get("in_handle", [-0.25, 0.0]), Vector2(-0.25, 0.0)))
			return _interpolate_value(previous.get("value"), next.get("value"), factor, rotates, angle_mode, degrees)
		previous = next
	return previous.get("value")


func _values_crossed(track: Dictionary, clip: Dictionary, previous_time: float, current_time: float, is_playing: bool) -> Array:
	if not is_playing or previous_time < 0.0: return []
	var result: Array = []
	var duration := maxf(0.01, float(clip.get("duration", 1.0)))
	var loop_start := 0.0
	var loop_end := duration
	if bool(clip.get("loop_region_enabled", false)):
		var selected_region_id := str(clip.get("loop_region_id", ""))
		for raw_region in clip.get("regions", []):
			var region: Dictionary = raw_region
			if selected_region_id.is_empty() or str(region.get("region_id", "")) == selected_region_id:
				loop_start = clampf(float(region.get("start_time", 0.0)), 0.0, duration)
				loop_end = clampf(float(region.get("end_time", duration)), loop_start, duration)
				break
		if loop_end <= loop_start: loop_start = 0.0; loop_end = duration
	var looped := current_time < previous_time and int(clip.get("loop_mode", 0)) != 0
	for raw_key in _sorted_keys(track.get("keys", [])):
		var key: Dictionary = raw_key
		var key_time := float(key.get("time", 0.0))
		var crossed := key_time > previous_time and key_time <= current_time
		if looped: crossed = (key_time > previous_time and key_time <= loop_end) or (key_time >= loop_start and key_time <= current_time)
		if crossed:
			var value: Variant = key.get("value", {})
			var entry: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {"value": value}
			entry["time"] = key_time
			entry["key_id"] = str(key.get("key_id", ""))
			result.append(entry)
	return result


func _is_discrete_track(kind: int) -> bool:
	return kind in [TrackDefinition.TrackType.IMAGE_SWAP, TrackDefinition.TrackType.VISIBILITY, TrackDefinition.TrackType.Z_ORDER, TrackDefinition.TrackType.EVENT, TrackDefinition.TrackType.HITBOX, TrackDefinition.TrackType.HURTBOX, TrackDefinition.TrackType.AUDIO_CUE, TrackDefinition.TrackType.VISEME, TrackDefinition.TrackType.SCRIPT_PARAMETER]


func _is_rotation_track(track: Dictionary) -> bool:
	return int(track.get("track_type", TrackDefinition.TrackType.ATTRIBUTE)) == TrackDefinition.TrackType.TRANSFORM_ROTATION


func _rotation_values_are_degrees(track: Dictionary) -> bool:
	return str(track.get("property_path", "")).contains("rotation_degrees")


func _rotation_mode(track: Dictionary) -> int:
	var raw = track.get("rotation_mode", track.get("angle_mode", "shortest"))
	if raw is int:
		return clampi(int(raw), AngleInterpolatorScript.Mode.SHORTEST_PATH, AngleInterpolatorScript.Mode.COUNTER_CLOCKWISE)
	match str(raw).strip_edges().to_lower():
		"continuous": return AngleInterpolatorScript.Mode.CONTINUOUS
		"clockwise", "cw": return AngleInterpolatorScript.Mode.CLOCKWISE
		"counter_clockwise", "counterclockwise", "ccw": return AngleInterpolatorScript.Mode.COUNTER_CLOCKWISE
		_: return AngleInterpolatorScript.Mode.SHORTEST_PATH


func _property_name(path: String, track_type: int) -> String:
	if path.contains("."):
		# Preserve nested custom-property paths such as attribute.material.tint
		# instead of truncating them to just "attribute".
		return path.substr(path.find(".") + 1)
	match track_type:
		TrackDefinition.TrackType.TRANSFORM_POSITION: return "position"
		TrackDefinition.TrackType.TRANSFORM_ROTATION: return "rotation_degrees"
		TrackDefinition.TrackType.TRANSFORM_SCALE: return "scale"
		TrackDefinition.TrackType.VISIBILITY: return "visible"
	return "attribute"


func _apply_state_property(state: Dictionary, property_name: String, value: Variant) -> void:
	match property_name:
		"transform":
			if value is Dictionary:
				for key in ["position", "rotation_degrees", "scale", "pivot", "opacity", "tint", "visible"]:
					if (value as Dictionary).has(key): state[key] = (value as Dictionary)[key]
		"position", "rotation_degrees", "scale", "pivot", "opacity", "tint", "visible", "locked": state[property_name] = value
		_:
			var attributes: Dictionary = state.get("attributes", {}).duplicate(true)
			attributes[property_name.trim_prefix("attribute.")] = value
			state["attributes"] = attributes


func _apply_bone_property(bone: Dictionary, property_name: String, value: Variant) -> void:
	match property_name:
		"transform":
			if value is Dictionary:
				if (value as Dictionary).has("position"): bone["local_position"] = _as_vector2((value as Dictionary)["position"])
				if (value as Dictionary).has("rotation_degrees"): bone["local_rotation"] = deg_to_rad(float((value as Dictionary)["rotation_degrees"]))
				if (value as Dictionary).has("scale"): bone["local_scale"] = _as_vector2((value as Dictionary)["scale"], Vector2.ONE)
		"position", "local_position": bone["local_position"] = _as_vector2(value)
		"rotation", "rotation_degrees", "local_rotation": bone["local_rotation"] = deg_to_rad(float(value)) if property_name != "local_rotation" else float(value)
		"scale", "local_scale": bone["local_scale"] = _as_vector2(value, Vector2.ONE)
		"visible", "length": bone[property_name] = value
		_:
			var attributes: Dictionary = bone.get("attributes", {}).duplicate(true)
			attributes[property_name.trim_prefix("attribute.")] = value
			bone["attributes"] = attributes


func _layer_index(layers: Array, part_id: String) -> int:
	for index in range(layers.size()):
		if str((layers[index] as Dictionary).get("part_id", "")) == part_id: return index
	return -1


func _sorted_keys(raw_keys: Array) -> Array:
	var keys := raw_keys.duplicate(true)
	keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	return keys


func _handle(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _as_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _interpolate_value(a: Variant, b: Variant, factor: float, interpolate_angles: bool = false, angle_mode: int = AngleInterpolatorScript.Mode.SHORTEST_PATH, values_are_degrees: bool = false) -> Variant:
	if typeof(a) != typeof(b): return a if factor < 1.0 else b
	match typeof(a):
		TYPE_INT, TYPE_FLOAT:
			if interpolate_angles:
				return AngleInterpolatorScript.interpolate_degrees(float(a), float(b), factor, angle_mode) if values_are_degrees else AngleInterpolatorScript.interpolate_radians(float(a), float(b), factor, angle_mode)
			return lerpf(float(a), float(b), factor)
		TYPE_VECTOR2: return (a as Vector2).lerp(b as Vector2, factor)
		TYPE_COLOR: return (a as Color).lerp(b as Color, factor)
		TYPE_ARRAY:
			var left: Array = a
			var right: Array = b
			var result: Array = []
			for index in range(mini(left.size(), right.size())): result.append(_interpolate_value(left[index], right[index], factor))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = (a as Dictionary).duplicate(true)
			for key in (b as Dictionary):
				if result.has(key):
					var property_name := str(key)
					var nested_rotation := interpolate_angles and property_name in ["rotation", "rotation_degrees", "local_rotation"]
					result[key] = _interpolate_value(result[key], (b as Dictionary)[key], factor, nested_rotation, angle_mode, property_name == "rotation_degrees")
			return result
		_: return a if factor < 1.0 else b
