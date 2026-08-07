# RuntimePreviewEvaluator -- Runtime-only playback used unchanged by QA and exported contracts.
class_name RuntimePreviewEvaluator
extends RefCounted

const StateMachineDefinitionScript = preload("res://animation/state_machine/state_machine_definition.gd")
const StateMachineEvaluatorScript = preload("res://animation/state_machine/state_machine_evaluator.gd")
const RuleGraphScript = preload("res://animation/rules/rule_graph.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")
const SecondaryMotionEvaluatorScript = preload("res://animation/secondary/secondary_motion_evaluator.gd")
const BezierEvaluatorScript = preload("res://animation/curves/bezier_evaluator.gd")
const SmoothCubicEvaluatorScript = preload("res://animation/curves/smooth_cubic_evaluator.gd")

var contract: Dictionary = {}
var state_evaluator = StateMachineEvaluatorScript.new()
var rule_graph = null
var secondary = SecondaryMotionEvaluatorScript.new()
var equipment: Dictionary = {}
var clip_id := ""
var clip_time := 0.0
var _previous_time := 0.0
var _trace: Array = []


func load_contract(value: Dictionary) -> Dictionary:
	contract = value.duplicate(true)
	equipment = (contract.get("appearance", {}).get("equipment", {}) as Dictionary).duplicate(true)
	clip_id = _first_clip_id()
	clip_time = 0.0
	_previous_time = 0.0
	_trace.clear()
	rule_graph = null
	var machine: Dictionary = contract.get("state_machine", {}) as Dictionary
	if not machine.is_empty():
		var definition = StateMachineDefinitionScript.new().from_dict(machine)
		state_evaluator.configure(definition, contract.get("clip_durations", {}) as Dictionary)
		if not state_evaluator.current_state_id.is_empty(): clip_id = str(state_evaluator.snapshot().get("clip_id", clip_id))
	var rules: Dictionary = contract.get("rule_graph", {}) as Dictionary
	if not rules.is_empty(): rule_graph = RuleGraphScript.new().from_dict(rules)
	secondary.configure(contract.get("secondary_motion", {}) as Dictionary)
	return sample({"clip_id": clip_id})


func reset() -> void:
	clip_id = _first_clip_id()
	clip_time = 0.0
	_previous_time = 0.0
	_trace.clear()
	secondary.reset()


func sample(input: Dictionary = {}) -> Dictionary:
	if not str(input.get("clip_id", "")).is_empty(): clip_id = str(input.get("clip_id", ""))
	if input.has("time"):
		_previous_time = clip_time
		clip_time = _clip_time(float(input.get("time", 0.0)), clip_id)
	return _frame([], [], {})


func tick(delta: float, input: Dictionary = {}) -> Dictionary:
	for parameter_id in input.get("parameters", {}) as Dictionary: state_evaluator.set_parameter(str(parameter_id), input["parameters"][parameter_id])
	for trigger_id in input.get("triggers", []) as Array: state_evaluator.trigger(str(trigger_id))
	for slot_id in input.get("equipment", {}) as Dictionary: equipment[str(slot_id)] = input["equipment"][slot_id]
	var incoming_events: Array = (input.get("events", []) as Array).duplicate(true)
	var requested_clip := str(input.get("clip_id", ""))
	var force_clip := bool(input.get("force_clip", false))
	_previous_time = clip_time
	if state_evaluator.machine != null and not force_clip:
		var snapshot: Dictionary = state_evaluator.update(maxf(0.0, delta) * maxf(0.0, float(input.get("time_scale", 1.0))), {"events": incoming_events})
		clip_id = str(snapshot.get("clip_id", clip_id))
		clip_time = _clip_time(float(snapshot.get("state_time", 0.0)), clip_id)
	else:
		if not requested_clip.is_empty(): clip_id = requested_clip
		clip_time = _clip_time(clip_time + maxf(0.0, delta) * maxf(0.0, float(input.get("time_scale", 1.0))), clip_id)
	var timeline_events := _events_between(clip_id, _previous_time, clip_time)
	timeline_events.append_array(incoming_events)
	var rule_result := _rules(timeline_events)
	for action in rule_result.get("actions", []) as Array:
		var record: Dictionary = action as Dictionary
		if str(record.get("type", "")) == "equip": equipment[str(record.get("target", ""))] = record.get("value")
		elif str(record.get("type", "")) == "trigger_event": timeline_events.append({"event_name": str(record.get("target", "")), "source": "rule"})
	return _frame(timeline_events, rule_result.get("actions", []) as Array, rule_result)


func get_trace() -> Array:
	return _trace.duplicate(true)


func _frame(events: Array, rule_actions: Array, rule_result: Dictionary) -> Dictionary:
	var sampled := _sample_metadata(clip_id, clip_time)
	var secondary_state: Dictionary = secondary.step(_secondary_anchors(sampled), sampled.get("action_points", []) as Array, maxf(0.0, clip_time - _previous_time), events, clip_time, clip_id)
	var state := state_evaluator.snapshot() if state_evaluator.machine != null else {"state_id": "", "clip_id": clip_id, "state_time": clip_time}
	var frame := {"state": state, "clip_id": clip_id, "clip_time": clip_time, "runtime_profile": str(contract.get("active_profile_id", "godot")), "equipment": equipment.duplicate(true), "action_points": sampled.get("action_points", []), "hitboxes": sampled.get("hitboxes", []), "hurtboxes": sampled.get("hurtboxes", []), "events": events.duplicate(true), "rule_actions": rule_actions.duplicate(true), "rule_diagnostics": rule_result.get("diagnostics", []), "secondary_motion": secondary_state, "authored_parameters_only": true}
	_trace.append({"clip_id": clip_id, "time": clip_time, "state": state.get("state_id", ""), "events": events.duplicate(true), "hitboxes": (frame["hitboxes"] as Array).size(), "action_points": (frame["action_points"] as Array).size()})
	if _trace.size() > 720: _trace.pop_front()
	return frame


func _sample_metadata(active_clip_id: String, time: float) -> Dictionary:
	var result := {"action_points": [], "hitboxes": [], "hurtboxes": []}
	var clip: Dictionary = (contract.get("clips", {}) as Dictionary).get(active_clip_id, {}) as Dictionary
	for raw_track in clip.get("tracks", []) as Array:
		var track: Dictionary = raw_track as Dictionary
		if bool(track.get("muted", false)): continue
		var value: Variant = _sample_track(track, time)
		match int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE)):
			TrackDefinitionScript.TrackType.ACTION_POINT:
				if value is Dictionary: (result["action_points"] as Array).append({"track_id": str(track.get("track_id", "")), "object_id": str(track.get("object_id", "")), "value": value.duplicate(true)})
			TrackDefinitionScript.TrackType.HITBOX:
				(result["hitboxes"] as Array).append_array(_shapes(value, track, "hitbox"))
			TrackDefinitionScript.TrackType.HURTBOX:
				(result["hurtboxes"] as Array).append_array(_shapes(value, track, "hurtbox"))
	return result


func _events_between(active_clip_id: String, from_time: float, to_time: float) -> Array:
	var result: Array = []
	var clip: Dictionary = (contract.get("clips", {}) as Dictionary).get(active_clip_id, {}) as Dictionary
	var wrapped := to_time < from_time
	for raw_track in clip.get("tracks", []) as Array:
		var track: Dictionary = raw_track as Dictionary
		if int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE)) != TrackDefinitionScript.TrackType.EVENT or bool(track.get("muted", false)): continue
		for raw_key in track.get("keys", []) as Array:
			var key: Dictionary = raw_key as Dictionary
			var at := float(key.get("time", 0.0))
			if (at > from_time and at <= to_time) or (wrapped and (at > from_time or at <= to_time)):
				var event: Dictionary = (key.get("value", {}) as Dictionary).duplicate(true)
				event["time"] = at
				event["track_id"] = str(track.get("track_id", ""))
				result.append(event)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_time := float(a.get("time", 0.0))
		var right_time := float(b.get("time", 0.0))
		return str(a.get("track_id", "")) < str(b.get("track_id", "")) if is_equal_approx(left_time, right_time) else left_time < right_time
	)
	return result


func _secondary_anchors(sampled: Dictionary) -> Dictionary:
	var anchors: Dictionary = {}
	var bones: Dictionary = contract.get("rig", {}).get("bones", {}) as Dictionary
	var pending: Array = bones.keys()
	pending.sort()
	while not pending.is_empty():
		var attached := false
		for raw_bone_id in pending.duplicate():
			var bone_id := str(raw_bone_id)
			var bone: Dictionary = bones[raw_bone_id] as Dictionary
			var parent_id := str(bone.get("parent_id", ""))
			if not parent_id.is_empty() and not anchors.has(parent_id): continue
			var local := _vector(bone.get("local_position", bone.get("position", [0.0, 0.0])))
			var parent := _vector(anchors.get(parent_id, [0.0, 0.0]))
			anchors[bone_id] = [parent.x + local.x, parent.y + local.y]
			pending.erase(raw_bone_id)
			attached = true
		if not attached:
			for raw_bone_id in pending:
				var fallback: Dictionary = bones[raw_bone_id] as Dictionary
				anchors[str(raw_bone_id)] = fallback.get("local_position", fallback.get("position", [0.0, 0.0]))
			break
	for raw_point in sampled.get("action_points", []) as Array:
		var point: Dictionary = raw_point as Dictionary
		var bone_id := str(point.get("object_id", ""))
		if bone_id.is_empty() or anchors.has(bone_id): continue
		var value: Dictionary = point.get("value", {}) as Dictionary
		anchors[bone_id] = value.get("local_position", [0.0, 0.0])
	return anchors


func _rules(events: Array) -> Dictionary:
	if rule_graph == null: return {"actions": [], "diagnostics": []}
	return rule_graph.evaluate_cascade({"state": state_evaluator.current_state_id, "parameters": state_evaluator.parameters, "events": _event_names(events), "equipment": equipment, "time": clip_time})


func _sample_track(track: Dictionary, time: float) -> Variant:
	var keys: Array = (track.get("keys", []) as Array).duplicate(true)
	keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	if keys.is_empty(): return {}
	var previous: Dictionary = keys[0] as Dictionary
	for index in range(1, keys.size()):
		var next: Dictionary = keys[index] as Dictionary
		if time < float(next.get("time", 0.0)):
			var mode := int(previous.get("interpolation", TrackDefinitionScript.Interpolation.LINEAR))
			if mode == TrackDefinitionScript.Interpolation.STEPPED: return previous.get("value")
			var factor := inverse_lerp(float(previous.get("time", 0.0)), float(next.get("time", 0.0)), time)
			if mode == TrackDefinitionScript.Interpolation.SMOOTH:
				factor = SmoothCubicEvaluatorScript.ease_factor(factor, clampf(float(previous.get("easing", 0.5)), 0.0, 1.0))
			elif mode == TrackDefinitionScript.Interpolation.BEZIER:
				factor = BezierEvaluatorScript.evaluate_bezier_1d(factor, _handle(previous.get("out_handle", [0.25, 0.0]), Vector2(0.25, 0.0)), _handle(next.get("in_handle", [-0.25, 0.0]), Vector2(-0.25, 0.0)))
			return _interpolate(previous.get("value"), next.get("value"), factor)
		previous = next
	return previous.get("value")


func _interpolate(left: Variant, right: Variant, factor: float) -> Variant:
	if typeof(left) != typeof(right): return left if factor < 1.0 else right
	if left is float or left is int: return lerpf(float(left), float(right), factor)
	if left is Array and (left as Array).size() >= 2 and (right as Array).size() >= 2: return [lerpf(float(left[0]), float(right[0]), factor), lerpf(float(left[1]), float(right[1]), factor)]
	if left is Dictionary:
		var result: Dictionary = (left as Dictionary).duplicate(true)
		if result.get("local_position") is Array and (right as Dictionary).get("local_position") is Array: result["local_position"] = _interpolate(result["local_position"], (right as Dictionary)["local_position"], factor)
		if result.has("local_rotation") and (right as Dictionary).has("local_rotation"): result["local_rotation"] = lerp_angle(float(result["local_rotation"]), float((right as Dictionary)["local_rotation"]), factor)
		if result.get("local_scale") is Array and (right as Dictionary).get("local_scale") is Array: result["local_scale"] = _interpolate(result["local_scale"], (right as Dictionary)["local_scale"], factor)
		return result
	return left if factor < 1.0 else right


func _handle(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _shapes(value: Variant, track: Dictionary, kind: String) -> Array:
	var result: Array = []
	var shapes: Array = value as Array if value is Array else []
	for raw_shape in shapes:
		if raw_shape is Dictionary:
			var shape: Dictionary = (raw_shape as Dictionary).duplicate(true)
			shape["track_id"] = str(track.get("track_id", ""))
			shape["kind"] = kind
			result.append(shape)
	return result


func _clip_time(value: float, active_clip_id: String) -> float:
	var duration := maxf(0.001, float((contract.get("clip_durations", {}) as Dictionary).get(active_clip_id, 1.0)))
	var clip: Dictionary = (contract.get("clips", {}) as Dictionary).get(active_clip_id, {}) as Dictionary
	var loop := int(clip.get("loop_mode", 1)) != 0 or bool(clip.get("loop", false))
	return fposmod(value, duration) if loop else clampf(value, 0.0, duration)


func _first_clip_id() -> String:
	var ids: Array = (contract.get("clips", {}) as Dictionary).keys()
	ids.sort()
	return str(ids[0]) if not ids.is_empty() else ""


func _event_names(events: Array) -> Array:
	var result: Array = []
	for raw_event in events:
		var event: Dictionary = raw_event as Dictionary
		var name := str(event.get("event_name", event.get("event_id", "")))
		if not name.is_empty(): result.append(name)
	return result


func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
