# RuntimeDeliveryPanel -- Shared runtime preview, package export, and gameplay QA surface.
class_name RuntimeDeliveryPanel
extends VBoxContainer

const ContractBuilderScript = preload("res://runtime_plugin/preview/runtime_contract_builder.gd")
const RuntimePreviewScript = preload("res://runtime_plugin/preview/runtime_preview_evaluator.gd")
const EngineExporterScript = preload("res://export/engines/engine_runtime_package_exporter.gd")
const RuntimeQaScript = preload("res://quality/gameplay/runtime_qa_suite.gd")

var _session = null
var _preview = RuntimePreviewScript.new()
var _profile: OptionButton
var _time: SpinBox
var _parameter: LineEdit
var _parameter_value: LineEdit
var _equipment_slot: LineEdit
var _equipment_item: LineEdit
var _output_path: LineEdit
var _output: RichTextLabel
var _status: Label
var _reveal: Button
var _last_folder := ""


func _ready() -> void:
	name = "RuntimeDeliveryPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	_refresh()
	get_viewport().size_changed.connect(_apply_output_height)
	call_deferred("_apply_output_height")


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
	_refresh()


func _build() -> void:
	var title := Label.new(); title.text = "Game Runtime Preview & Delivery"; title.add_theme_font_size_override("font_size", 18); add_child(title)
	var hint := Label.new(); hint.text = "The preview, QA recorder, and exported packages consume the same deterministic runtime contract."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(hint)
	var runtime_row := HFlowContainer.new(); runtime_row.name = "RuntimeControls"; add_child(runtime_row)
	_profile = OptionButton.new(); _profile.name = "RuntimeProfile"; _profile.add_item("Godot"); _profile.add_item("Unity"); _profile.add_item("Unreal"); _profile.item_selected.connect(_on_profile_selected); runtime_row.add_child(_profile)
	runtime_row.remove_child(_profile); _add_labeled_control(runtime_row, "Runtime", _profile, 118.0)
	_time = SpinBox.new(); _time.name = "RuntimeTime"; _time.step = 1.0 / 30.0; _time.max_value = 3600.0; _time.tooltip_text = "Preview time in seconds"; _add_labeled_control(runtime_row, "Time (seconds)", _time, 118.0)
	var preview_button := Button.new(); preview_button.text = "Preview frame"; preview_button.pressed.connect(_preview_frame); runtime_row.add_child(preview_button)
	var tick_button := Button.new(); tick_button.text = "Advance runtime"; tick_button.pressed.connect(_tick); runtime_row.add_child(tick_button)
	runtime_row.remove_child(preview_button); _add_labeled_control(runtime_row, "Preview", preview_button, 128.0)
	runtime_row.remove_child(tick_button); _add_labeled_control(runtime_row, "Playback", tick_button, 138.0)
	var input_row := HFlowContainer.new(); input_row.name = "RuntimeInputs"; add_child(input_row)
	_parameter = _new_text_input("StateParameter", "e.g. is_grounded", "State parameter"); _add_labeled_control(input_row, "State parameter", _parameter, 170.0)
	_parameter_value = _new_text_input("StateParameterValue", "true, 1, idle", "State parameter value"); _add_labeled_control(input_row, "Value", _parameter_value, 130.0)
	var parameter_button := Button.new(); parameter_button.text = "Apply parameter"; parameter_button.pressed.connect(_apply_parameter); input_row.add_child(parameter_button)
	input_row.remove_child(parameter_button); _add_labeled_control(input_row, "Runtime state", parameter_button, 148.0)
	_equipment_slot = _new_text_input("EquipmentSlot", "e.g. main_hand", "Equipment slot"); _add_labeled_control(input_row, "Equipment slot", _equipment_slot, 155.0)
	_equipment_item = _new_text_input("EquipmentItem", "Item ID", "Equipment item ID"); _add_labeled_control(input_row, "Item ID", _equipment_item, 130.0)
	var equipment_button := Button.new(); equipment_button.text = "Swap equipment"; equipment_button.pressed.connect(_apply_equipment); input_row.add_child(equipment_button)
	input_row.remove_child(equipment_button); _add_labeled_control(input_row, "Equipment", equipment_button, 145.0)
	var export_row := HFlowContainer.new(); export_row.name = "RuntimeExport"; add_child(export_row)
	_output_path = _new_text_input("RuntimeOutputPath", "Choose a destination folder", "Runtime package output folder"); _output_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _add_labeled_control(export_row, "Output folder", _output_path, 360.0)
	var export_button := Button.new(); export_button.text = "Export engine packages"; export_button.pressed.connect(_export); export_row.add_child(export_button)
	var qa_button := Button.new(); qa_button.text = "Run runtime QA"; qa_button.pressed.connect(_run_qa); export_row.add_child(qa_button)
	_reveal = Button.new(); _reveal.text = "Reveal output"; _reveal.disabled = true; _reveal.pressed.connect(func(): if not _last_folder.is_empty(): OS.shell_open(_absolute(_last_folder))); export_row.add_child(_reveal)
	export_row.remove_child(export_button); _add_labeled_control(export_row, "Package", export_button, 172.0)
	export_row.remove_child(qa_button); _add_labeled_control(export_row, "Validation", qa_button, 145.0)
	export_row.remove_child(_reveal); _add_labeled_control(export_row, "Folder", _reveal, 130.0)
	var output_title := Label.new(); output_title.text = "RUNTIME SNAPSHOT"; output_title.theme_type_variation = &"SectionLabel"; add_child(output_title)
	_output = RichTextLabel.new(); _output.name = "RuntimePreviewOutput"; _output.custom_minimum_size = Vector2(0, 220); _output.size_flags_vertical = Control.SIZE_EXPAND_FILL; _output.bbcode_enabled = true; add_child(_output)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_status)


func _apply_output_height() -> void:
	if _output == null:
		return
	var editor_window := get_window()
	var compact := editor_window != null and editor_window.size.y <= 760
	_output.custom_minimum_size.y = 112.0 if compact else 220.0


func _refresh() -> void:
	if _session == null or not is_instance_valid(_session):
		_status.text = "Open a project to preview the exact runtime contract."; _output.text = "[b]No project selected[/b]\nOpen an editable project to inspect playback, game events, and package readiness."; return
	var contract := _contract()
	var validation: Dictionary = ContractBuilderScript.validate(contract)
	_select_profile(str(contract.get("active_profile_id", "godot")))
	_preview.load_contract(contract)
	if _output_path.text.strip_edges().is_empty(): _output_path.text = _session.project_path.get_base_dir().path_join("runtime_exports")
	_status.text = "Runtime contract: %d clips · %d event tracks · %d hitbox tracks · %d action-point tracks%s" % [int(validation.get("summary", {}).get("clips", 0)), int(validation.get("summary", {}).get("events", 0)), int(validation.get("summary", {}).get("hitbox_tracks", 0)), int(validation.get("summary", {}).get("action_point_tracks", 0)), " · %d warning(s)" % (validation.get("warnings", []) as Array).size() if not (validation.get("warnings", []) as Array).is_empty() else ""]
	_preview_frame()


func _preview_frame() -> void:
	if _session == null or not is_instance_valid(_session): return
	var frame: Dictionary = _preview.sample({"time": _time.value})
	_show(frame, "Previewed runtime frame at %.3fs." % _time.value)


func _tick() -> void:
	if _session == null or not is_instance_valid(_session): return
	var frame: Dictionary = _preview.tick(1.0 / 30.0)
	_time.value = float(frame.get("clip_time", _time.value))
	_show(frame, "Advanced state machine, rules, events, equipment, hitboxes, action points, and secondary motion.")


func _apply_parameter() -> void:
	var key := _parameter.text.strip_edges()
	if key.is_empty(): return
	var value: Variant = _coerce(_parameter_value.text)
	var frame: Dictionary = _preview.tick(0.0, {"parameters": {key: value}})
	_show(frame, "Applied runtime parameter '%s'." % key)


func _apply_equipment() -> void:
	var slot := _equipment_slot.text.strip_edges()
	if slot.is_empty(): return
	var frame: Dictionary = _preview.tick(0.0, {"equipment": {slot: {"item_id": _equipment_item.text.strip_edges()}}})
	_show(frame, "Applied equipment swap for '%s'." % slot)


func _export() -> void:
	if _session == null or not is_instance_valid(_session): return
	var targets := ["godot", "unity", "unreal"]
	var report: Dictionary = EngineExporterScript.new().export_all(_session.get_manifest_copy(), _session.get_production_suite_data(), _output_path.text.strip_edges(), targets)
	_last_folder = str(report.get("root", ""))
	_reveal.disabled = _last_folder.is_empty()
	_show(report, "Runtime package export " + ("completed." if bool(report.get("success", false)) else "failed."))


func _run_qa() -> void:
	if _session == null or not is_instance_valid(_session): return
	var contract := _contract()
	var report: Dictionary = RuntimeQaScript.new().run(contract, {"output_directory": _output_path.text.strip_edges()})
	_last_folder = _output_path.text.strip_edges()
	_reveal.disabled = _last_folder.is_empty()
	_show(report, "Runtime QA recorded collision playback, action-point checks, event trace, and debug screenshots.")


func _contract() -> Dictionary:
	return ContractBuilderScript.build(_session.get_manifest_copy(), _session.get_production_suite_data())


func _show(value: Dictionary, message: String) -> void:
	_output.text = _format_runtime_frame(value) if value.has("state") else _format_operation_result(value, message)
	_status.text = message


func _on_session_changed(_description: String) -> void: _refresh()
func _on_profile_selected(index: int) -> void:
	if _session == null or not is_instance_valid(_session) or _session.is_read_only(): return
	var profile_id := _profile_id(index)
	var production: Dictionary = _session.get_production_suite_data()
	if str(production.get("runtime", {}).get("active_profile_id", "godot")) == profile_id: return
	production["runtime"]["active_profile_id"] = profile_id
	_session.set_production_suite_data(production, "Selected Runtime Preview Profile " + profile_id.capitalize())
	_status.text = "Runtime profile set to " + profile_id.capitalize() + "."
func _select_profile(profile_id: String) -> void:
	for index in range(_profile.item_count):
		if _profile_id(index) == profile_id: _profile.select(index); return
func _profile_id(index: int) -> String: return ["godot", "unity", "unreal"][clampi(index, 0, 2)]


func _new_text_input(control_name: String, placeholder: String, hint: String) -> LineEdit:
	var input := LineEdit.new()
	input.name = control_name
	input.placeholder_text = placeholder
	input.tooltip_text = hint
	input.focus_mode = Control.FOCUS_ALL
	return input


func _add_labeled_control(parent: Container, label_text: String, control: Control, minimum_width: float) -> void:
	var field := VBoxContainer.new()
	field.name = control.name + "Field"
	field.custom_minimum_size = Vector2(minimum_width, 0)
	var label := Label.new()
	label.name = "FieldLabel"
	label.text = label_text
	label.theme_type_variation = &"CaptionLabel"
	field.add_child(label)
	control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, minimum_width), maxf(control.custom_minimum_size.y, 40.0))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(control)
	parent.add_child(field)


func _format_runtime_frame(frame: Dictionary) -> String:
	var state: Dictionary = frame.get("state", {}) as Dictionary
	var equipment: Dictionary = frame.get("equipment", {}) as Dictionary
	return "[b]Runtime snapshot[/b]\nThe preview is evaluating the same contract used for export.\n\n[b]Playback[/b]\nProfile: %s\nTime: %.3fs\nActive clip: %s\nState: %s\n\n[b]Gameplay[/b]\nEvents: %d  •  Hitboxes: %d  •  Hurtboxes: %d\nAction points: %d  •  Equipment slots: %d\nRule actions: %d  •  Secondary effects: %d" % [
		_profile_id(_profile.selected).capitalize(),
		float(frame.get("clip_time", _time.value)),
		_display_value(frame.get("clip_id", "")),
		_display_value(state.get("state_id", "")),
		(frame.get("events", []) as Array).size(),
		(frame.get("hitboxes", []) as Array).size(),
		(frame.get("hurtboxes", []) as Array).size(),
		(frame.get("action_points", []) as Array).size(),
		equipment.size(),
		(frame.get("rule_actions", []) as Array).size(),
		(frame.get("secondary_motion", {}).get("event_effects", []) as Array).size(),
	]


func _format_operation_result(report: Dictionary, message: String) -> String:
	var success := bool(report.get("success", false))
	var lines := ["[b]Latest runtime action[/b]", message, "", "Result: " + ("Complete" if success else "Needs attention")]
	for key in ["root", "folder", "package", "output_directory"]:
		var path := str(report.get(key, "")).strip_edges()
		if not path.is_empty():
			lines.append("Output: " + path)
			break
	var errors: Array = report.get("errors", []) as Array
	if not errors.is_empty(): lines.append("Details: " + str(errors[0]))
	return "\n".join(lines)


func _display_value(value: Variant) -> String:
	var text := str(value).strip_edges()
	return text if not text.is_empty() else "—"


func _coerce(value: String) -> Variant:
	var text := value.strip_edges()
	if text.to_lower() in ["true", "false"]: return text.to_lower() == "true"
	if text.is_valid_int(): return text.to_int()
	if text.is_valid_float(): return text.to_float()
	return text
func _absolute(path: String) -> String: return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
