# RuleGraphAuthoringModel -- Visual graph metadata, diagnostics, and deterministic runtime preview.
class_name RuleGraphAuthoringModel
extends RefCounted

const RuleGraphScript = preload("res://animation/rules/rule_graph.gd")

var graph = null
var node_positions: Dictionary = {}


func create(graph_id: String, display_name: String) -> bool:
	graph = RuleGraphScript.new(graph_id, display_name)
	node_positions.clear()
	return not graph_id.strip_edges().is_empty()


func add_rule(rule_id: String, conditions: Array, actions: Array, priority: int = 0, position: Vector2 = Vector2.ZERO) -> bool:
	if graph == null or not graph.add_rule(rule_id, conditions, actions, priority):
		return false
	node_positions[rule_id] = [position.x, position.y]
	return true


func add_time_window_rule(rule_id: String, start: float, end: float, actions: Array, priority: int = 0, position: Vector2 = Vector2.ZERO) -> bool:
	return add_rule(rule_id, [{"type": "time_window", "start": start, "end": end}], actions, priority, position)


func add_event_rule(rule_id: String, event_id: String, actions: Array, priority: int = 0, position: Vector2 = Vector2.ZERO) -> bool:
	return add_rule(rule_id, [{"type": "event", "key": event_id, "value": true}], actions, priority, position)


func move_rule(rule_id: String, position: Vector2) -> bool:
	if graph == null or graph.get_rule(rule_id).is_empty():
		return false
	node_positions[rule_id] = [position.x, position.y]
	return true


func set_rule_enabled(rule_id: String, enabled: bool) -> bool:
	if graph == null:
		return false
	for rule in graph.rules:
		if str((rule as Dictionary).get("rule_id", "")) == rule_id:
			(rule as Dictionary)["enabled"] = enabled
			return true
	return false


func preview(context: Dictionary, cascading: bool = false) -> Dictionary:
	if graph == null:
		return {"actions": [], "diagnostics": ["rule graph is not initialized"]}
	return graph.evaluate_cascade(context) if cascading else graph.evaluate(context)


func export_runtime() -> Dictionary:
	return graph.to_dict() if graph != null else {}


func to_dict() -> Dictionary:
	return {"graph": export_runtime(), "node_positions": node_positions.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	graph = RuleGraphScript.new().from_dict(data.get("graph", {}) as Dictionary)
	node_positions = (data.get("node_positions", {}) as Dictionary).duplicate(true)
	return diagnostics().is_empty()


func diagnostics() -> Array:
	if graph == null:
		return ["rule graph is not initialized"]
	var errors: Array = graph.validate()
	for rule in graph.rules:
		var rule_id := str((rule as Dictionary).get("rule_id", ""))
		if not node_positions.has(rule_id):
			errors.append("rule " + rule_id + " has no graph position")
	return errors
