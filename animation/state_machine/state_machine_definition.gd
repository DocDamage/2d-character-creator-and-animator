# StateMachineDefinition -- Serializable animation states, parameters, and transitions.
class_name StateMachineDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var machine_id: String = ""
var display_name: String = "Untitled State Machine"
var entry_state_id: String = ""
var states: Dictionary = {}
var transitions: Array = []
var parameters: Dictionary = {}


func _init(p_machine_id: String = "", p_display_name: String = "Untitled State Machine") -> void:
	machine_id = p_machine_id
	display_name = p_display_name


func add_state(state_id: String, clip_id: String = "", display: String = "") -> bool:
	if state_id.is_empty() or states.has(state_id):
		return false
	states[state_id] = {
		"state_id": state_id,
		"display_name": display if not display.is_empty() else state_id,
		"clip_id": clip_id,
		"speed_scale": 1.0,
		"loop": true,
		"nested_machine": {},
	}
	if entry_state_id.is_empty():
		entry_state_id = state_id
	return true


func set_state_property(state_id: String, property: String, value: Variant) -> bool:
	if not states.has(state_id):
		return false
	(states[state_id] as Dictionary)[property] = value
	return true


func set_nested_machine(state_id: String, nested: Variant) -> bool:
	if not states.has(state_id):
		return false
	var exported: Dictionary = nested.to_dict() if nested != null and nested.has_method("to_dict") else nested as Dictionary
	if exported.is_empty() or str(exported.get("machine_id", "")).is_empty():
		return false
	(states[state_id] as Dictionary)["nested_machine"] = exported.duplicate(true)
	return true


func add_parameter(parameter_id: String, default_value: Variant = false, parameter_type: String = "bool") -> bool:
	if parameter_id.is_empty() or parameters.has(parameter_id):
		return false
	parameters[parameter_id] = {
		"parameter_id": parameter_id,
		"type": parameter_type,
		"default": default_value,
	}
	return true


func add_transition(transition_id: String, from_state: String, to_state: String, conditions: Array = []) -> bool:
	if transition_id.is_empty() or not states.has(from_state) or not states.has(to_state):
		return false
	for existing in transitions:
		if str((existing as Dictionary).get("transition_id", "")) == transition_id:
			return false
	transitions.append({
		"transition_id": transition_id,
		"from_state": from_state,
		"to_state": to_state,
		"conditions": conditions.duplicate(true),
		"exit_time": -1.0,
		"duration": 0.15,
		"priority": 0,
		"can_interrupt": true,
	})
	return true


func set_transition_property(transition_id: String, property: String, value: Variant) -> bool:
	for transition in transitions:
		var record := transition as Dictionary
		if str(record.get("transition_id", "")) == transition_id:
			record[property] = value
			return true
	return false


func get_state(state_id: String) -> Dictionary:
	return (states.get(state_id, {}) as Dictionary).duplicate(true)


func get_transition(transition_id: String) -> Dictionary:
	for transition in transitions:
		if str((transition as Dictionary).get("transition_id", "")) == transition_id:
			return (transition as Dictionary).duplicate(true)
	return {}


func get_outgoing(state_id: String) -> Array:
	var output: Array = []
	for transition in transitions:
		if str((transition as Dictionary).get("from_state", "")) == state_id:
			output.append((transition as Dictionary).duplicate(true))
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := int(a.get("priority", 0))
		var right := int(b.get("priority", 0))
		return str(a.get("transition_id", "")) < str(b.get("transition_id", "")) if left == right else left > right
	)
	return output


func validate() -> Array:
	var errors: Array = []
	if machine_id.is_empty():
		errors.append("machine_id is required")
	if states.is_empty():
		errors.append("at least one state is required")
	if not entry_state_id.is_empty() and not states.has(entry_state_id):
		errors.append("entry_state_id does not identify a state")
	for transition in transitions:
		var record := transition as Dictionary
		if not states.has(str(record.get("from_state", ""))) or not states.has(str(record.get("to_state", ""))):
			errors.append("transition references an unknown state")
		if float(record.get("duration", 0.0)) < 0.0:
			errors.append("transition duration cannot be negative")
	for state_id in states:
		var nested: Dictionary = (states[state_id] as Dictionary).get("nested_machine", {})
		if not nested.is_empty() and str(nested.get("machine_id", "")).is_empty():
			errors.append("state " + str(state_id) + " has an invalid nested machine")
	return errors


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"machine_id": machine_id,
		"display_name": display_name,
		"entry_state_id": entry_state_id,
		"states": states.duplicate(true),
		"transitions": transitions.duplicate(true),
		"parameters": parameters.duplicate(true),
	}


func from_dict(data: Dictionary) -> StateMachineDefinition:
	machine_id = str(data.get("machine_id", ""))
	display_name = str(data.get("display_name", "Untitled State Machine"))
	entry_state_id = str(data.get("entry_state_id", ""))
	states = (data.get("states", {}) as Dictionary).duplicate(true)
	transitions = (data.get("transitions", []) as Array).duplicate(true)
	parameters = (data.get("parameters", {}) as Dictionary).duplicate(true)
	return self
