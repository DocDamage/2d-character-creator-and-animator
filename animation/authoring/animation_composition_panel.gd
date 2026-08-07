# AnimationCompositionPanel -- Dockable visual summary and time-based preview for composition tools.
class_name AnimationCompositionPanel
extends Control

const DocumentHistoryScript = preload("res://app/commands/document_history.gd")

@onready var graph_edit: GraphEdit = $Margin/Root/Graph
@onready var time_input: SpinBox = $Margin/Root/Controls/Time
@onready var output: RichTextLabel = $Margin/Root/Output
@onready var status_label: Label = $Margin/Root/Status
@onready var frame_label: Label = $Margin/Root/Header/FrameLabel

var blend_stack = null
var state_machine_model = null
var rule_graph_model = null


func _ready() -> void:
	$Margin/Root/Controls/Preview.pressed.connect(_on_preview)
	_refresh("Bind composition models to begin.")


func bind_context(blend, state_model, rule_model) -> void:
	blend_stack = blend
	state_machine_model = state_model
	rule_graph_model = rule_model
	_bind_document_history()
	_rebuild_graph()
	var state_count: int = state_machine_model.machine.states.size() if state_machine_model != null and state_machine_model.machine != null else 0
	var rule_count: int = rule_graph_model.graph.rules.size() if rule_graph_model != null and rule_graph_model.graph != null else 0
	frame_label.text = "%d states · %d rules" % [state_count, rule_count]
	_refresh("Composition graph ready.")


func _bind_document_history() -> void:
	if blend_stack != null and blend_stack.has_method("set_history_recorder"):
		blend_stack.set_history_recorder(Callable(self, "_record_animation_history").bind("blend_stack"))
	if state_machine_model != null and state_machine_model.has_method("set_history_recorder"):
		state_machine_model.set_history_recorder(Callable(self, "_record_animation_history").bind("state_machine"))
	if rule_graph_model != null and rule_graph_model.has_method("set_history_recorder"):
		rule_graph_model.set_history_recorder(Callable(self, "_record_animation_history").bind("rule_graph"))


func _record_animation_history(before: Dictionary, after: Dictionary, description: String, source_id: String) -> bool:
	var before_document := _capture_document_snapshot()
	before_document[source_id] = before.duplicate(true)
	var after_document := _capture_document_snapshot()
	after_document[source_id] = after.duplicate(true)
	return DocumentHistoryScript.record_applied(self, before_document, after_document, description)


func _capture_document_snapshot() -> Dictionary:
	return {
		"blend_stack": blend_stack.to_dict() if blend_stack != null and blend_stack.has_method("to_dict") else {},
		"state_machine": state_machine_model.to_dict() if state_machine_model != null and state_machine_model.has_method("to_dict") else {},
		"rule_graph": rule_graph_model.to_dict() if rule_graph_model != null and rule_graph_model.has_method("to_dict") else {},
	}


func _apply_document_snapshot(snapshot: Dictionary, description: String = "") -> void:
	if snapshot.is_empty():
		return
	if blend_stack != null and blend_stack.has_method("from_dict"):
		blend_stack.from_dict(snapshot.get("blend_stack", {}) as Dictionary)
	if state_machine_model != null and state_machine_model.has_method("from_dict"):
		state_machine_model.from_dict(snapshot.get("state_machine", {}) as Dictionary)
	if rule_graph_model != null and rule_graph_model.has_method("from_dict"):
		rule_graph_model.from_dict(snapshot.get("rule_graph", {}) as Dictionary)
	_rebuild_graph()
	_refresh(description if not description.is_empty() else "Restored animation document state.")


func _on_preview() -> void:
	var state: Dictionary = state_machine_model.preview_tick(0.0, {"time": time_input.value}) if state_machine_model != null else {}
	var rules: Dictionary = rule_graph_model.preview({"time": time_input.value}, true) if rule_graph_model != null else {}
	var layers: int = int(blend_stack.layers.size()) if blend_stack != null else 0
	output.text = "Layers: %d\nState: %s\nRules fired: %s\nDiagnostics: %s" % [layers, str(state.get("state_id", "—")), str(rules.get("fired_rule_ids", [])), str(rules.get("diagnostics", []))]
	frame_label.text = "Preview at %.3fs" % time_input.value
	_refresh("Previewed composition at %.3fs." % time_input.value)


func _rebuild_graph() -> void:
	for child in graph_edit.get_children():
		if child is GraphNode: child.queue_free()
	if state_machine_model != null and state_machine_model.machine != null:
		for state_id in state_machine_model.machine.states:
			var record: Dictionary = state_machine_model.machine.get_state(state_id)
			_add_node("state_" + str(state_id), str(record.get("display_name", state_id)), state_machine_model.node_positions.get(state_id, [0.0, 0.0]) as Array, "Clip: " + str(record.get("clip_id", "—")))
		for transition in state_machine_model.machine.transitions:
			var edge := transition as Dictionary
			graph_edit.connect_node("state_" + str(edge.get("from_state", "")), 0, "state_" + str(edge.get("to_state", "")), 0)
	if rule_graph_model != null and rule_graph_model.graph != null:
		for rule in rule_graph_model.graph.rules:
			var record := rule as Dictionary
			var rule_id := str(record.get("rule_id", ""))
			_add_node("rule_" + rule_id, "Rule: " + rule_id, rule_graph_model.node_positions.get(rule_id, [360.0, 0.0]) as Array, "Actions: %d" % (record.get("actions", []) as Array).size())


func _add_node(node_id: String, title: String, position: Array, detail: String) -> void:
	var node := GraphNode.new()
	node.name = node_id
	node.title = title
	node.draggable = false
	node.position_offset = Vector2(float(position[0]), float(position[1]))
	var label := Label.new()
	label.text = detail
	node.add_child(label)
	node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
	graph_edit.add_child(node)


func _refresh(message: String) -> void:
	if status_label == null: return
	var ready := "ready" in message.to_lower()
	status_label.text = ("✓ " if ready else "i ") + message
	if ThemeService != null: status_label.add_theme_color_override("font_color", ThemeService.get_color_token("success" if ready else "blue"))
