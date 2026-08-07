# StateMachineEvaluator -- Deterministic state selection and cross-fade progression.
class_name StateMachineEvaluator
extends RefCounted

var machine = null
var current_state_id: String = ""
var state_time: float = 0.0
var parameters: Dictionary = {}
var clip_durations: Dictionary = {}
var active_transition: Dictionary = {}
var _triggers: Dictionary = {}


func configure(definition, durations: Dictionary = {}) -> bool:
	if definition == null or not definition.validate().is_empty():
		return false
	machine = definition
	clip_durations = durations.duplicate(true)
	parameters.clear()
	for parameter_id in machine.parameters:
		parameters[parameter_id] = (machine.parameters[parameter_id] as Dictionary).get("default")
	current_state_id = machine.entry_state_id
	state_time = 0.0
	active_transition.clear()
	_triggers.clear()
	return true


func set_parameter(parameter_id: String, value: Variant) -> bool:
	if machine == null or not machine.parameters.has(parameter_id):
		return false
	parameters[parameter_id] = value
	return true


func trigger(parameter_id: String) -> bool:
	if machine == null or not machine.parameters.has(parameter_id):
		return false
	_triggers[parameter_id] = true
	parameters[parameter_id] = true
	return true


func update(delta: float, context: Dictionary = {}) -> Dictionary:
	if machine == null or current_state_id.is_empty():
		return snapshot()
	var elapsed := maxf(delta, 0.0)
	var current: Dictionary = machine.get_state(current_state_id)
	# state_time represents clip time, not wall-clock time.  Honour the
	# per-state speed scale here so exit-time and completion transitions agree
	# with the clip artists see during preview and runtime playback.
	state_time += elapsed * maxf(0.0, float(current.get("speed_scale", 1.0)))
	if not active_transition.is_empty():
		active_transition["elapsed"] = float(active_transition.get("elapsed", 0.0)) + elapsed
		if _transition_weight() >= 1.0:
			active_transition.clear()
	var transition := _select_transition(context)
	if not transition.is_empty() and (active_transition.is_empty() or bool(transition.get("can_interrupt", true))):
		_begin_transition(transition)
	for trigger_id in _triggers:
		parameters[trigger_id] = false
	_triggers.clear()
	return snapshot()


func snapshot() -> Dictionary:
	var current: Dictionary = machine.get_state(current_state_id) if machine != null else {}
	return {
		"state_id": current_state_id,
		"clip_id": str(current.get("clip_id", "")),
		"state_time": state_time,
		"transition": active_transition.duplicate(true),
		"blend_weight": _transition_weight(),
		"parameters": parameters.duplicate(true),
	}


func _select_transition(context: Dictionary) -> Dictionary:
	for transition in machine.get_outgoing(current_state_id):
		if _conditions_match(transition.get("conditions", []) as Array, context) and _exit_time_matches(transition):
			return transition
	return {}


func _conditions_match(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var record := condition as Dictionary
		var condition_type := str(record.get("type", "parameter"))
		var key := str(record.get("parameter", record.get("key", "")))
		var expected = record.get("value", true)
		var actual = parameters.get(key, context.get(key))
		if condition_type == "trigger":
			actual = _triggers.has(key)
		elif condition_type == "event":
			actual = key in (context.get("events", []) as Array)
		elif condition_type == "animation_complete":
			actual = _is_animation_complete()
		if not _compare(actual, expected, str(record.get("operator", "=="))):
			return false
	return true


func _exit_time_matches(transition: Dictionary) -> bool:
	var exit_time := float(transition.get("exit_time", -1.0))
	if exit_time < 0.0:
		return true
	return state_time >= exit_time


func _begin_transition(transition: Dictionary) -> void:
	var previous := current_state_id
	current_state_id = str(transition.get("to_state", current_state_id))
	state_time = 0.0
	active_transition = transition.duplicate(true)
	active_transition["from_state"] = previous
	active_transition["elapsed"] = 0.0


func _transition_weight() -> float:
	if active_transition.is_empty():
		return 1.0
	var duration := float(active_transition.get("duration", 0.0))
	return 1.0 if duration <= 0.0 else clampf(float(active_transition.get("elapsed", 0.0)) / duration, 0.0, 1.0)


func _is_animation_complete() -> bool:
	if machine == null:
		return false
	var state: Dictionary = machine.get_state(current_state_id)
	if bool(state.get("loop", true)):
		return false
	return state_time >= float(clip_durations.get(str(state.get("clip_id", "")), INF))


func _compare(actual: Variant, expected: Variant, operator: String) -> bool:
	match operator:
		"!=": return actual != expected
		">": return float(actual) > float(expected)
		">=": return float(actual) >= float(expected)
		"<": return float(actual) < float(expected)
		"<=": return float(actual) <= float(expected)
		_: return actual == expected
