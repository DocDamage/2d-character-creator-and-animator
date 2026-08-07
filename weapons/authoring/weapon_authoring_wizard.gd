# WeaponAuthoringWizard -- User-facing coverage and repair controls for weapon authoring.
class_name WeaponAuthoringWizard
extends Control

signal coverage_changed(coverage: Dictionary)
signal workflow_changed(workflow_id: String)

const WizardModelScript = preload("res://weapons/authoring/weapon_authoring_wizard_model.gd")
const DocumentHistoryScript = preload("res://app/commands/document_history.gd")

var workflow_option: OptionButton
var body_types_input: LineEdit
var directions_input: LineEdit
var coverage_button: Button
var validate_button: Button
var summary_label: Label
var diagnostics_label: Label

var model = WizardModelScript.new()


func _ready() -> void:
	_ensure_controls()
	if not coverage_button.pressed.is_connected(run_coverage):
		coverage_button.pressed.connect(run_coverage)
	if not validate_button.pressed.is_connected(validate_workflow):
		validate_button.pressed.connect(validate_workflow)
	if not workflow_option.item_selected.is_connected(_on_workflow_selected):
		workflow_option.item_selected.connect(_on_workflow_selected)
	_refresh_labels({}, {"success": false, "errors": ["Bind a weapon profile and rig to begin."]})


func bind_context(weapon, pose_profile, rig: Dictionary, hand_pose_library = null) -> void:
	_ensure_controls()
	model.bind_context(weapon, pose_profile, rig, hand_pose_library)
	_refresh_labels({}, model.validate_workflow())


func set_coverage_dimensions(body_types: Array, directions: Array, record_history: bool = true) -> void:
	_ensure_controls()
	var before := _capture_document_snapshot()
	model.set_coverage_dimensions(body_types, directions)
	body_types_input.text = ", ".join(body_types)
	directions_input.text = ", ".join(directions)
	if record_history and before != _capture_document_snapshot() and not _record_document_change(before, "Changed Weapon Coverage Dimensions"):
		_mark_dirty()


func set_workflow(workflow_id: String) -> bool:
	_ensure_controls()
	var before := _capture_document_snapshot()
	if not model.set_workflow(workflow_id):
		return false
	for index in workflow_option.item_count:
		if workflow_option.get_item_text(index) == workflow_id:
			workflow_option.select(index)
	workflow_changed.emit(workflow_id)
	if before != _capture_document_snapshot() and not _record_document_change(before, "Changed Weapon Workflow to " + workflow_id.capitalize()):
		_mark_dirty()
	return true


func run_coverage() -> Dictionary:
	_ensure_controls()
	model.set_coverage_dimensions(_parse_ids(body_types_input.text), _parse_ids(directions_input.text))
	var coverage := model.evaluate_coverage()
	_refresh_labels(coverage, model.validate_workflow())
	coverage_changed.emit(coverage)
	return coverage


func validate_workflow() -> Dictionary:
	_ensure_controls()
	var validation := model.validate_workflow()
	_refresh_labels(model.get_last_coverage(), validation)
	return validation


func get_reachability_report() -> Array:
	return model.get_reachability_report()


func get_repair_actions() -> Array:
	var coverage := model.get_last_coverage()
	var actions: Array = []
	for cell in coverage.get("cells", []):
		actions.append_array(cell.get("repair_actions", []))
	return actions


func save_session() -> Dictionary:
	return model.to_dict()


func restore_session(data: Dictionary) -> bool:
	var restored := model.from_dict(data)
	if restored:
		set_coverage_dimensions(model.body_type_ids, model.direction_ids, false)
		_sync_workflow_control()
	return restored


func _setup_workflows() -> void:
	if workflow_option == null:
		return
	workflow_option.clear()
	for workflow_id in model.WORKFLOWS:
		workflow_option.add_item(workflow_id)
	workflow_option.select(0)


func _refresh_labels(coverage: Dictionary, validation: Dictionary) -> void:
	if summary_label == null or diagnostics_label == null:
		return
	if coverage.is_empty():
		summary_label.text = "Coverage has not been evaluated."
	else:
		summary_label.text = "%d / %d body-direction poses covered." % [int(coverage.get("covered_count", 0)), int(coverage.get("total_count", 0))]
	var messages: Array = validation.get("errors", []).duplicate()
	var valid := messages.is_empty()
	if valid: messages.append("Workflow is valid.")
	diagnostics_label.text = ("✓ " if valid else "× ") + "\n".join(messages)
	if ThemeService != null:
		diagnostics_label.add_theme_color_override("font_color", ThemeService.get_color_token("success" if valid else "error"))


func _on_workflow_selected(index: int) -> void:
	if index >= 0:
		set_workflow(workflow_option.get_item_text(index))


func _parse_ids(value: String) -> Array:
	return value.split(",", false)


func _ensure_controls() -> void:
	if workflow_option == null:
		workflow_option = get_node_or_null("Margin/RootVBox/WorkflowRow/WorkflowOption") as OptionButton
		body_types_input = get_node_or_null("Margin/RootVBox/BodyTypesInput") as LineEdit
		directions_input = get_node_or_null("Margin/RootVBox/DirectionsInput") as LineEdit
		coverage_button = get_node_or_null("Margin/RootVBox/ActionsRow/CoverageButton") as Button
		validate_button = get_node_or_null("Margin/RootVBox/ActionsRow/ValidateButton") as Button
		summary_label = get_node_or_null("Margin/RootVBox/SummaryLabel") as Label
		diagnostics_label = get_node_or_null("Margin/RootVBox/DiagnosticsLabel") as Label
	if workflow_option != null and workflow_option.item_count == 0:
		_setup_workflows()


func _sync_workflow_control() -> void:
	if workflow_option == null:
		return
	for index in workflow_option.item_count:
		if workflow_option.get_item_text(index) == model.workflow_id:
			workflow_option.select(index)
			return


func _capture_document_snapshot() -> Dictionary:
	return {
		"wizard": model.to_dict(),
		"weapon": model.weapon.to_dict() if model.weapon != null and model.weapon.has_method("to_dict") else {},
		"pose_profile": model.pose_profile.to_dict() if model.pose_profile != null and model.pose_profile.has_method("to_dict") else {},
	}


func _record_document_change(before: Dictionary, description: String) -> bool:
	return DocumentHistoryScript.record_applied(self, before, _capture_document_snapshot(), description)


func _apply_document_snapshot(snapshot: Dictionary, description: String = "") -> void:
	if snapshot.is_empty():
		return
	if model.weapon != null and model.weapon.has_method("from_dict") and snapshot.get("weapon", {}) is Dictionary:
		model.weapon.from_dict(snapshot.get("weapon", {}) as Dictionary)
	if model.pose_profile != null and model.pose_profile.has_method("from_dict") and snapshot.get("pose_profile", {}) is Dictionary:
		model.pose_profile.from_dict(snapshot.get("pose_profile", {}) as Dictionary)
	model.from_dict(snapshot.get("wizard", {}) as Dictionary)
	set_coverage_dimensions(model.body_type_ids, model.direction_ids, false)
	_sync_workflow_control()
	_refresh_labels(model.get_last_coverage(), model.validate_workflow())


func _mark_dirty() -> void:
	if AppState != null:
		AppState.mark_dirty()
