# Dictionary-backed deterministic state machine for the portable runtime addon.
extends RefCounted

var states: Dictionary = {}
var transitions: Array = []
var parameters: Dictionary = {}
var current_state_id := ""
var state_time := 0.0
var active_transition: Dictionary = {}
var clip_durations: Dictionary = {}
var _triggers: Dictionary = {}


func configure(machine: Variant, durations: Variant = {}) -> bool:
	if not machine is Dictionary or (machine as Dictionary).is_empty():
		return false
	states = ((machine as Dictionary).get("states", {}) as Dictionary).duplicate(true)
	transitions = ((machine as Dictionary).get("transitions", []) as Array).duplicate(true)
	clip_durations = (durations as Dictionary).duplicate(true) if durations is Dictionary else {}
	parameters.clear()
	for parameter_id in ((machine as Dictionary).get("parameters", {}) as Dictionary):
		parameters[parameter_id] = ((((machine as Dictionary)["parameters"] as Dictionary)[parameter_id]) as Dictionary).get("default")
	current_state_id = str((machine as Dictionary).get("entry_state_id", ""))
	state_time = 0.0
	active_transition.clear()
	_triggers.clear()
	return states.has(current_state_id)


func set_parameter(parameter_id: String, value: Variant) -> bool:
	if not parameters.has(parameter_id):
		return false
	parameters[parameter_id] = value
	return true


func trigger(parameter_id: String) -> bool:
	if not parameters.has(parameter_id):
		return false
	parameters[parameter_id] = true
	_triggers[parameter_id] = true
	return true


func update(delta: float, context: Dictionary = {}) -> Dictionary:
	if current_state_id.is_empty():
		return snapshot()
	state_time += maxf(delta, 0.0)
	if not active_transition.is_empty():
		active_transition["elapsed"] = float(active_transition.get("elapsed", 0.0)) + maxf(delta, 0.0)
		if blend_weight() >= 1.0:
			active_transition.clear()
	for transition in _ordered_outgoing():
		if _conditions_match(transition.get("conditions", []) as Array, context):
			_begin_transition(transition)
			break
	for trigger_id in _triggers:
		parameters[trigger_id] = false
	_triggers.clear()
	return snapshot()


func snapshot() -> Dictionary:
	var state: Dictionary = states.get(current_state_id, {})
	return {"state_id": current_state_id, "clip_id": str(state.get("clip_id", "")), "state_time": state_time, "transition": active_transition.duplicate(true), "blend_weight": blend_weight(), "parameters": parameters.duplicate(true)}


func blend_weight() -> float:
	if active_transition.is_empty():
		return 1.0
	var duration := float(active_transition.get("duration", 0.0))
	return 1.0 if duration <= 0.0 else clampf(float(active_transition.get("elapsed", 0.0)) / duration, 0.0, 1.0)


func _ordered_outgoing() -> Array:
	var output: Array = []
	for transition in transitions:
		if str((transition as Dictionary).get("from_state", "")) == current_state_id:
			output.append((transition as Dictionary).duplicate(true))
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	return output


func _conditions_match(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var record := condition as Dictionary
		var kind := str(record.get("type", "parameter"))
		var key := str(record.get("parameter", record.get("key", "")))
		var actual: Variant = parameters.get(key, context.get(key))
		if kind == "trigger": actual = _triggers.has(key)
		elif kind == "event": actual = key in (context.get("events", []) as Array)
		elif kind == "animation_complete": actual = _is_animation_complete()
		if not _compare(actual, record.get("value", true), str(record.get("operator", "=="))):
			return false
	return true


func _begin_transition(transition: Dictionary) -> void:
	var target := str(transition.get("to_state", current_state_id))
	if not states.has(target):
		return
	active_transition = transition.duplicate(true)
	active_transition["from_state"] = current_state_id
	active_transition["elapsed"] = 0.0
	current_state_id = target
	state_time = 0.0


func _is_animation_complete() -> bool:
	var state: Dictionary = states.get(current_state_id, {})
	return not bool(state.get("loop", true)) and state_time >= float(clip_durations.get(str(state.get("clip_id", "")), INF))


func _compare(actual: Variant, expected: Variant, operator: String) -> bool:
	match operator:
		"!=": return actual != expected
		">": return float(actual) > float(expected)
		">=": return float(actual) >= float(expected)
		"<": return float(actual) < float(expected)
		"<=": return float(actual) <= float(expected)
		_: return actual == expected
