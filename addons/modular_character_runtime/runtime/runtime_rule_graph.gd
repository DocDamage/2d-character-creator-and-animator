# Cycle-safe ordered rule evaluator for the portable runtime addon.
extends RefCounted

var rules: Array = []
var max_actions_per_evaluation := 64


func configure(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	rules = ((data as Dictionary).get("rules", []) as Array).duplicate(true)
	max_actions_per_evaluation = maxi(1, int((data as Dictionary).get("max_actions_per_evaluation", 64)))
	return true


func evaluate(context: Dictionary) -> Dictionary:
	var output := {"actions": [], "fired_rule_ids": [], "diagnostics": []}
	var ordered := rules.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var seen: Dictionary = {}
	for rule in ordered:
		var record := rule as Dictionary
		if not bool(record.get("enabled", true)) or not _matches(record.get("conditions", []) as Array, context):
			continue
		var rule_id := str(record.get("rule_id", ""))
		for action in record.get("actions", []) as Array:
			if (output["actions"] as Array).size() >= max_actions_per_evaluation:
				(output["diagnostics"] as Array).append("rule action limit reached")
				return output
			var action_record := action as Dictionary
			var key := rule_id + ":" + str(action_record.get("type", "")) + ":" + str(action_record.get("target", ""))
			if seen.has(key):
				(output["diagnostics"] as Array).append("cycle prevented: " + key)
				continue
			seen[key] = true
			(output["actions"] as Array).append(action_record.duplicate(true))
		(output["fired_rule_ids"] as Array).append(rule_id)
	return output


func _matches(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var record := condition as Dictionary
		var type := str(record.get("type", "parameter"))
		if type == "time_window":
			var time := float(context.get("time", context.get("timeline_time", 0.0)))
			if time < float(record.get("start", 0.0)) or time > float(record.get("end", INF)): return false
			continue
		var key := str(record.get("key", record.get("parameter", "")))
		var actual: Variant = _context_value(context, type, key)
		if not _compare(actual, record.get("value", true), str(record.get("operator", "=="))):
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
