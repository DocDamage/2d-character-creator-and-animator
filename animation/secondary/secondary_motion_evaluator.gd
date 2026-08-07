# SecondaryMotionEvaluator -- Simulates authored spring, trail, impact, and event-effect parameters.
class_name SecondaryMotionEvaluator
extends RefCounted

var definitions: Dictionary = {}
var _states: Dictionary = {}


func configure(data: Dictionary) -> void:
	definitions = data.duplicate(true)
	_states.clear()


func reset() -> void:
	_states.clear()


func step(anchor_positions: Dictionary, action_points: Array, delta: float, events: Array = [], clip_time: float = 0.0, clip_id: String = "") -> Dictionary:
	var offsets: Dictionary = {}
	for chain_id in definitions.get("chains", {}) as Dictionary:
		var chain: Dictionary = definitions["chains"][chain_id] as Dictionary
		if not bool(chain.get("enabled", true)): continue
		var state: Dictionary = _states.get(chain_id, {}) as Dictionary
		var output: Dictionary = {}
		for bone_id in chain.get("bone_ids", []) as Array:
			var target := _vector(anchor_positions.get(str(bone_id), [0.0, 0.0]))
			var previous := _vector(state.get(str(bone_id), target))
			var velocity := _vector(state.get(str(bone_id) + "_velocity", [0.0, 0.0]))
			var stiffness := clampf(float(chain.get("stiffness", 80.0)), 0.0, 1000.0)
			var damping := clampf(float(chain.get("damping", 12.0)), 0.0, 1000.0)
			var gravity := _vector(chain.get("gravity", [0.0, 0.0]))
			velocity += ((target - previous) * stiffness + gravity - velocity * damping) * maxf(0.0, delta)
			var next := previous + velocity * maxf(0.0, delta)
			var maximum := maxf(0.0, float(chain.get("max_offset", 48.0)))
			if maximum > 0.0: next = target + (next - target).limit_length(maximum)
			state[str(bone_id)] = [next.x, next.y]
			state[str(bone_id) + "_velocity"] = [velocity.x, velocity.y]
			output[str(bone_id)] = [next.x - target.x, next.y - target.y]
		_states[chain_id] = state
		offsets[chain_id] = output
	var event_names := _event_names(events)
	return {"bone_offsets": offsets, "weapon_trails": _trails(action_points, event_names), "impact_frames": _impacts(clip_id, clip_time), "event_effects": _effects(action_points, event_names), "authored_parameters_only": true}


static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	for chain_id in data.get("chains", {}) as Dictionary:
		var chain: Dictionary = data["chains"][chain_id] as Dictionary
		if (chain.get("bone_ids", []) as Array).is_empty(): errors.append("chain '%s' needs bones" % chain_id)
		if float(chain.get("stiffness", 0.0)) < 0.0 or float(chain.get("damping", 0.0)) < 0.0: errors.append("chain '%s' has invalid spring values" % chain_id)
	for trail_id in data.get("weapon_trails", {}) as Dictionary:
		if str((data["weapon_trails"][trail_id] as Dictionary).get("action_point_id", "")).is_empty(): errors.append("weapon trail '%s' needs an action point" % trail_id)
	return errors


func _trails(action_points: Array, event_names: Dictionary) -> Array:
	var result: Array = []
	for trail_id in definitions.get("weapon_trails", {}) as Dictionary:
		var trail: Dictionary = definitions["weapon_trails"][trail_id] as Dictionary
		if not bool(trail.get("enabled", true)): continue
		var gate := str(trail.get("event_gate", ""))
		if not gate.is_empty() and not event_names.has(gate): continue
		var points := _matching_points(action_points, str(trail.get("action_point_id", "")))
		if points.is_empty(): continue
		result.append({"trail_id": trail_id, "action_point_id": str(trail.get("action_point_id", "")), "width": maxf(0.0, float(trail.get("width", 8.0))), "lifetime": maxf(0.0, float(trail.get("lifetime", 0.12))), "action_points": points})
	return result


func _impacts(active_clip_id: String, clip_time: float) -> Array:
	var result: Array = []
	for impact_id in definitions.get("impact_frames", {}) as Dictionary:
		var impact: Dictionary = definitions["impact_frames"][impact_id] as Dictionary
		var start := float(impact.get("time", -1.0))
		var duration := maxf(0.0, float(impact.get("duration", 0.04)))
		if bool(impact.get("enabled", true)) and (str(impact.get("clip_id", "")).is_empty() or str(impact.get("clip_id", "")) == active_clip_id) and clip_time >= start and clip_time <= start + duration:
			result.append(impact.duplicate(true))
	return result


func _effects(action_points: Array, event_names: Dictionary) -> Array:
	var result: Array = []
	for effect_id in definitions.get("event_effects", {}) as Dictionary:
		var effect: Dictionary = definitions["event_effects"][effect_id] as Dictionary
		if bool(effect.get("enabled", true)) and event_names.has(str(effect.get("event_name", ""))):
			var record := effect.duplicate(true)
			record["effect_id"] = effect_id
			record["action_points"] = _matching_points(action_points, str(effect.get("action_point_id", "")))
			result.append(record)
	return result


func _matching_points(action_points: Array, requested_id: String) -> Array:
	var result: Array = []
	for raw_point in action_points:
		var point: Dictionary = raw_point as Dictionary
		var value: Dictionary = point.get("value", {}) as Dictionary
		var point_id := str(value.get("point_id", value.get("display_name", "")))
		if requested_id.is_empty() or point_id == requested_id: result.append(point.duplicate(true))
	return result


func _event_names(events: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_event in events:
		var event: Dictionary = raw_event as Dictionary
		var name := str(event.get("event_name", event.get("event_id", "")))
		if not name.is_empty(): result[name] = true
	return result


func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
