# RuleGraph -- Ordered, cycle-safe evaluation of authoring-time and runtime rules.
class_name RuleGraph
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var graph_id: String = ""
var display_name: String = "Untitled Rule Graph"
var rules: Array = []
var max_actions_per_evaluation: int = 64


func _init(p_graph_id: String = "", p_display_name: String = "Untitled Rule Graph") -> void:
	graph_id = p_graph_id
	display_name = p_display_name


func add_rule(rule_id: String, conditions: Array, actions: Array, priority: int = 0) -> bool:
	if rule_id.is_empty() or actions.is_empty() or not get_rule(rule_id).is_empty():
		return false
	rules.append({"rule_id": rule_id, "conditions": conditions.duplicate(true), "actions": actions.duplicate(true), "priority": priority, "enabled": true})
	return true


func get_rule(rule_id: String) -> Dictionary:
	for rule in rules:
		if str((rule as Dictionary).get("rule_id", "")) == rule_id:
			return (rule as Dictionary).duplicate(true)
	return {}


func evaluate(context: Dictionary) -> Dictionary:
	var output := {"actions": [], "fired_rule_ids": [], "diagnostics": []}
	var ordered := rules.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := int(a.get("priority", 0))
		var right := int(b.get("priority", 0))
		return str(a.get("rule_id", "")) < str(b.get("rule_id", "")) if left == right else left > right
	)
	var seen: Dictionary = {}
	for rule in ordered:
		if not bool(rule.get("enabled", true)) or not _matches(rule.get("conditions", []) as Array, context):
			continue
		var rule_id := str(rule.get("rule_id", ""))
		for action in rule.get("actions", []) as Array:
			if (output["actions"] as Array).size() >= max_actions_per_evaluation:
				(output["diagnostics"] as Array).append("rule action limit reached")
				return output
			var key := rule_id + ":" + str((action as Dictionary).get("type", "")) + ":" + str((action as Dictionary).get("target", ""))
			if seen.has(key):
				(output["diagnostics"] as Array).append("cycle prevented: " + key)
				continue
			seen[key] = true
			(output["actions"] as Array).append((action as Dictionary).duplicate(true))
		(output["fired_rule_ids"] as Array).append(rule_id)
	return output


func apply_actions(context: Dictionary, actions: Array) -> Dictionary:
	var next := context.duplicate(true)
	for action in actions:
		var record := action as Dictionary
		match str(record.get("type", "")):
			"set_variable":
				var variables: Dictionary = next.get("variables", {}).duplicate(true)
				variables[str(record.get("target", ""))] = record.get("value")
				next["variables"] = variables
			"trigger_event":
				var events: Array = next.get("events", []).duplicate()
				events.append(record.get("target", record.get("value", "")))
				next["events"] = events
			_:
				var applied: Array = next.get("rule_actions", []).duplicate(true)
				applied.append(record.duplicate(true))
				next["rule_actions"] = applied
	return next


func evaluate_cascade(context: Dictionary, max_passes: int = 16) -> Dictionary:
	var current := context.duplicate(true)
	var output := {"actions": [], "fired_rule_ids": [], "diagnostics": [], "context": current}
	var seen_actions: Dictionary = {}
	for pass_index in range(maxi(1, max_passes)):
		var result: Dictionary = evaluate(current)
		var new_actions: Array = []
		for action in result.get("actions", []) as Array:
			var key := _action_key(action as Dictionary)
			if seen_actions.has(key):
				(output["diagnostics"] as Array).append("cycle prevented: " + key)
				continue
			seen_actions[key] = true
			new_actions.append(action)
			(output["actions"] as Array).append(action)
		for rule_id in result.get("fired_rule_ids", []) as Array:
			if rule_id not in output["fired_rule_ids"]:
				(output["fired_rule_ids"] as Array).append(rule_id)
		if new_actions.is_empty():
			output["context"] = current
			return output
		current = apply_actions(current, new_actions)
	if not output["actions"].is_empty():
		(output["diagnostics"] as Array).append("cascade pass limit reached")
	output["context"] = current
	return output


func validate() -> Array:
	var errors: Array = []
	if graph_id.is_empty():
		errors.append("graph_id is required")
	var ids: Dictionary = {}
	for rule in rules:
		var record := rule as Dictionary
		var rule_id := str(record.get("rule_id", ""))
		if rule_id.is_empty() or ids.has(rule_id):
			errors.append("rules need unique non-empty ids")
		ids[rule_id] = true
		if (record.get("actions", []) as Array).is_empty():
			errors.append("rule " + rule_id + " has no actions")
		for condition in record.get("conditions", []) as Array:
			var condition_record := condition as Dictionary
			if str(condition_record.get("type", "")) == "time_window" and float(condition_record.get("start", 0.0)) > float(condition_record.get("end", 0.0)):
				errors.append("rule " + rule_id + " has an invalid time window")
	return errors


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "graph_id": graph_id, "display_name": display_name, "rules": rules.duplicate(true), "max_actions_per_evaluation": max_actions_per_evaluation}


func from_dict(data: Dictionary) -> RuleGraph:
	graph_id = str(data.get("graph_id", ""))
	display_name = str(data.get("display_name", "Untitled Rule Graph"))
	rules = (data.get("rules", []) as Array).duplicate(true)
	max_actions_per_evaluation = maxi(1, int(data.get("max_actions_per_evaluation", 64)))
	return self


func _matches(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var record := condition as Dictionary
		var type := str(record.get("type", "parameter"))
		if type == "time_window":
			var time := float(context.get("time", context.get("timeline_time", 0.0)))
			if time < float(record.get("start", 0.0)) or time > float(record.get("end", INF)):
				return false
			continue
		var key := str(record.get("key", record.get("parameter", "")))
		var expected = record.get("value", true)
		var actual = _context_value(context, type, key)
		if not _compare(actual, expected, str(record.get("operator", "=="))):
			return false
	return true


func _context_value(context: Dictionary, type: String, key: String) -> Variant:
	match type:
		"variable": return (context.get("variables", {}) as Dictionary).get(key)
		"tag": return key in (context.get("tags", []) as Array)
		"event": return key in (context.get("events", []) as Array)
		"parameter", "input": return (context.get("parameters", {}) as Dictionary).get(key)
		_: return context.get(type, context.get(key))


func _compare(actual: Variant, expected: Variant, operator: String) -> bool:
	match operator:
		"!=": return actual != expected
		">": return float(actual) > float(expected)
		">=": return float(actual) >= float(expected)
		"<": return float(actual) < float(expected)
		"<=": return float(actual) <= float(expected)
		_: return actual == expected


func _action_key(action: Dictionary) -> String:
	return str(action.get("type", "")) + ":" + str(action.get("target", "")) + ":" + str(action.get("value", ""))
