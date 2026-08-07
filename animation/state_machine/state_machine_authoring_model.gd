# StateMachineAuthoringModel -- Graph layout, transition editing, preview, and runtime export.
class_name StateMachineAuthoringModel
extends RefCounted

const DefinitionScript = preload("res://animation/state_machine/state_machine_definition.gd")
const EvaluatorScript = preload("res://animation/state_machine/state_machine_evaluator.gd")

var machine = null
var node_positions: Dictionary = {}
var evaluator = null
var preview_context: Dictionary = {}
var _history_recorder: Callable


func set_history_recorder(recorder: Callable = Callable()) -> void:
	_history_recorder = recorder


func create(machine_id: String, display_name: String) -> bool:
	var before := to_dict()
	machine = DefinitionScript.new(machine_id, display_name)
	node_positions.clear()
	evaluator = null
	preview_context.clear()
	var created := not machine_id.strip_edges().is_empty()
	if created:
		_record(before, "Created Animation State Machine")
	return created


func add_state(state_id: String, clip_id: String = "", display_name: String = "", position: Vector2 = Vector2.ZERO) -> bool:
	var before := to_dict()
	if machine == null or not machine.add_state(state_id, clip_id, display_name):
		return false
	node_positions[state_id] = [position.x, position.y]
	_record(before, "Added Animation State " + (display_name if not display_name.is_empty() else state_id))
	return true


func move_state(state_id: String, position: Vector2) -> bool:
	var before := to_dict()
	if machine == null or machine.get_state(state_id).is_empty():
		return false
	if node_positions.get(state_id, []) == [position.x, position.y]:
		return false
	node_positions[state_id] = [position.x, position.y]
	_record(before, "Moved Animation State " + state_id)
	return true


func connect_states(transition_id: String, from_state: String, to_state: String, conditions: Array = [], duration: float = 0.15, exit_time: float = -1.0, priority: int = 0, can_interrupt: bool = true) -> bool:
	var before := to_dict()
	if machine == null or not machine.add_transition(transition_id, from_state, to_state, conditions):
		return false
	machine.set_transition_property(transition_id, "duration", maxf(0.0, duration))
	machine.set_transition_property(transition_id, "exit_time", exit_time)
	machine.set_transition_property(transition_id, "priority", priority)
	machine.set_transition_property(transition_id, "can_interrupt", can_interrupt)
	_record(before, "Connected Animation States")
	return true


func set_nested_machine(state_id: String, nested) -> bool:
	var before := to_dict()
	var changed: bool = machine != null and machine.set_nested_machine(state_id, nested)
	if changed:
		_record(before, "Changed Nested Animation State")
	return changed


func configure_preview(clip_durations: Dictionary = {}) -> bool:
	if machine == null:
		return false
	evaluator = EvaluatorScript.new()
	return evaluator.configure(machine, clip_durations)


func set_preview_parameter(parameter_id: String, value: Variant) -> bool:
	return evaluator != null and evaluator.set_parameter(parameter_id, value)


func trigger_preview(parameter_id: String) -> bool:
	return evaluator != null and evaluator.trigger(parameter_id)


func preview_tick(delta: float, context: Dictionary = {}) -> Dictionary:
	if evaluator == null and not configure_preview():
		return {"errors": diagnostics()}
	preview_context = context.duplicate(true)
	return evaluator.update(delta, preview_context)


func export_runtime() -> Dictionary:
	return machine.to_dict() if machine != null else {}


func to_dict() -> Dictionary:
	return {"machine": export_runtime(), "node_positions": node_positions.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	machine = DefinitionScript.new().from_dict(data.get("machine", {}) as Dictionary)
	node_positions = (data.get("node_positions", {}) as Dictionary).duplicate(true)
	evaluator = null
	return diagnostics().is_empty()


func _record(before: Dictionary, description: String) -> void:
	if _history_recorder.is_valid():
		_history_recorder.call(before, to_dict(), description)


func diagnostics() -> Array:
	if machine == null:
		return ["state machine is not initialized"]
	var errors: Array = machine.validate()
	for state_id in machine.states:
		if not node_positions.has(state_id):
			errors.append("state " + str(state_id) + " has no graph position")
	return errors
