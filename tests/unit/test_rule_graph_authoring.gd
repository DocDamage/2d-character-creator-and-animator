# Unit tests for Phase 5 rule-graph authoring, timeline conditions, and cycle safety.
extends Node

const ModelScript = preload("res://animation/rules/rule_graph_authoring_model.gd")


func run_tests() -> int:
	var model = ModelScript.new()
	var created: bool = model.create("combat_rules", "Combat Rules")
	var time_rule: bool = model.add_time_window_rule("impact_window", 0.2, 0.4, [{"type": "trigger_event", "target": "impact"}], 2, Vector2(10.0, 10.0))
	var event_rule: bool = model.add_event_rule("impact_response", "impact", [{"type": "set_variable", "target": "hit", "value": true}], 1, Vector2(200.0, 10.0))
	var at_window: Dictionary = model.preview({"time": 0.3})
	var after_window: Dictionary = model.preview({"time": 0.5})
	var cascade: Dictionary = model.preview({"time": 0.3}, true)
	var restored = ModelScript.new()
	var round_trip: bool = restored.from_dict(model.to_dict())
	var cascade_safe: bool = not cascade.get("diagnostics", []).is_empty() and str(cascade.get("diagnostics", [""])[0]).begins_with("cycle prevented")
	if created and time_rule and event_rule and at_window.get("fired_rule_ids", []).has("impact_window") and after_window.get("actions", []).is_empty() and cascade.get("context", {}).get("variables", {}).get("hit", false) and cascade_safe and round_trip and restored.diagnostics().is_empty():
		print("  PASS: RUL-001 through RUL-005 graph authoring, time/events, actions, diagnostics, and cycle-safe runtime parity")
		return 1
	printerr("  FAIL: rule-graph authoring did not preserve deterministic cycle-safe behavior: %s" % str(cascade))
	return 0
