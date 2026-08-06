# AnimationCompositionPanel -- Dockable visual summary and time-based preview for composition tools.
class_name AnimationCompositionPanel
extends Control

@onready var graph_edit: GraphEdit = $Margin/Root/Graph
@onready var time_input: SpinBox = $Margin/Root/Controls/Time
@onready var output: RichTextLabel = $Margin/Root/Output
@onready var status_label: Label = $Margin/Root/Status

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
	_rebuild_graph()
	_refresh("Composition graph ready.")


func _on_preview() -> void:
	var state: Dictionary = state_machine_model.preview_tick(0.0, {"time": time_input.value}) if state_machine_model != null else {}
	var rules: Dictionary = rule_graph_model.preview({"time": time_input.value}, true) if rule_graph_model != null else {}
	var layers: int = int(blend_stack.layers.size()) if blend_stack != null else 0
	output.text = "Layers: %d\nState: %s\nRules fired: %s\nDiagnostics: %s" % [layers, str(state.get("state_id", "—")), str(rules.get("fired_rule_ids", [])), str(rules.get("diagnostics", []))]
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
