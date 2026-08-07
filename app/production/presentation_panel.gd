# PresentationPanel -- Character-facing approval delivery for turntables, visemes, outfits, and pose boards.
class_name PresentationPanel
extends VBoxContainer

const PresentationExporterScript = preload("res://presentation/presentation_package_exporter.gd")

var _session = null
var _approval_url: LineEdit
var _output_path: LineEdit
var _expression_id: LineEdit
var _viseme: LineEdit
var _pose_ids: LineEdit
var _turntable_id: LineEdit
var _output: RichTextLabel
var _status: Label
var _reveal: Button
var _last_folder := ""


func _ready() -> void:
	name = "PresentationPanel"; size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL; _build(); _refresh()
	get_viewport().size_changed.connect(_apply_output_height)
	call_deferred("_apply_output_height")


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
	_refresh()


func _build() -> void:
	var title := Label.new(); title.text = "Presentation & Approval"; title.add_theme_font_size_override("font_size", 18); add_child(title)
	var hint := Label.new(); hint.text = "Create a client-ready package with authored turntable stops, expression/viseme data, real outfit batch sheets, pose-board references, and an approval page."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(hint)
	var row := HFlowContainer.new(); row.name = "PresentationExportControls"; add_child(row)
	_approval_url = _new_text_input("ApprovalUrl", "Optional https:// approval link", "Optional secure approval URL"); _add_labeled_control(row, "Approval link", _approval_url, 270.0)
	_output_path = _new_text_input("PresentationOutputPath", "Choose a presentation folder", "Presentation output folder"); _add_labeled_control(row, "Output folder", _output_path, 250.0)
	var export_button := Button.new(); export_button.text = "Export approval package"; export_button.pressed.connect(_export); row.add_child(export_button)
	_reveal = Button.new(); _reveal.text = "Reveal output"; _reveal.disabled = true; _reveal.pressed.connect(func(): if not _last_folder.is_empty(): OS.shell_open(_absolute(_last_folder))); row.add_child(_reveal)
	row.remove_child(export_button); _add_labeled_control(row, "Package", export_button, 180.0)
	row.remove_child(_reveal); _add_labeled_control(row, "Folder", _reveal, 130.0)
	var library_row := HFlowContainer.new(); library_row.name = "PresentationLibraryControls"; add_child(library_row)
	_expression_id = _new_text_input("ExpressionId", "e.g. confident", "Expression ID"); _add_labeled_control(library_row, "Expression", _expression_id, 150.0)
	_viseme = _new_text_input("Viseme", "Optional, e.g. A", "Optional viseme"); _add_labeled_control(library_row, "Viseme", _viseme, 140.0)
	var expression_button := Button.new(); expression_button.text = "Save expression"; expression_button.pressed.connect(_save_expression); library_row.add_child(expression_button)
	library_row.remove_child(expression_button); _add_labeled_control(library_row, "Expression library", expression_button, 155.0)
	_pose_ids = _new_text_input("PoseIds", "idle, attack, victory", "Comma-separated pose IDs"); _add_labeled_control(library_row, "Pose board poses", _pose_ids, 210.0)
	var board_button := Button.new(); board_button.text = "Save pose board"; board_button.pressed.connect(_save_pose_board); library_row.add_child(board_button)
	library_row.remove_child(board_button); _add_labeled_control(library_row, "Pose board", board_button, 148.0)
	_turntable_id = _new_text_input("TurntableId", "e.g. hero_360", "Turntable ID"); _add_labeled_control(library_row, "Turntable", _turntable_id, 150.0)
	var turntable_button := Button.new(); turntable_button.text = "Save turntable"; turntable_button.pressed.connect(_save_turntable); library_row.add_child(turntable_button)
	library_row.remove_child(turntable_button); _add_labeled_control(library_row, "Turntable library", turntable_button, 148.0)
	var output_title := Label.new(); output_title.text = "PRESENTATION LIBRARY"; output_title.theme_type_variation = &"SectionLabel"; add_child(output_title)
	_output = RichTextLabel.new(); _output.name = "PresentationOutput"; _output.custom_minimum_size = Vector2(0, 220); _output.size_flags_vertical = Control.SIZE_EXPAND_FILL; _output.bbcode_enabled = true; add_child(_output)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_status)


func _apply_output_height() -> void:
	if _output == null:
		return
	var editor_window := get_window()
	var compact := editor_window != null and editor_window.size.y <= 760
	_output.custom_minimum_size.y = 110.0 if compact else 220.0


func _refresh() -> void:
	if _session == null or not is_instance_valid(_session): _output.text = "[b]No project selected[/b]\nOpen a project to create a client-ready turntable, pose-board, and approval package."; return
	if _output_path.text.strip_edges().is_empty(): _output_path.text = _session.project_path.get_base_dir().path_join("presentations")
	var production: Dictionary = _session.get_production_suite_data()
	var presentation: Dictionary = production.get("presentation", {}) as Dictionary
	_output.text = _format_presentation_library(presentation)
	_status.text = "Presentation package is ready to assemble from current approved source art and project metadata."


func _export() -> void:
	if _session == null or not is_instance_valid(_session): return
	var folder := _output_path.text.strip_edges().path_join("%s_%d" % [_session.project_path.get_file().get_basename().validate_filename(), Time.get_unix_time_from_system()])
	var report: Dictionary = PresentationExporterScript.new().export_package(_session, folder, {"approval_url": _approval_url.text.strip_edges()})
	_last_folder = str(report.get("folder", "")); _reveal.disabled = _last_folder.is_empty()
	var message := "Presentation package complete." if bool(report.get("success", false)) else str(report.get("errors", ["Presentation export failed."])[0])
	_output.text = _format_export_result(report, message)
	_status.text = message


func _save_expression() -> void:
	if not _writable_project(): return
	var expression_id := _expression_id.text.strip_edges().to_snake_case()
	if expression_id.is_empty(): _status.text = "Enter an expression ID."; return
	var production: Dictionary = _session.get_production_suite_data()
	production["presentation"]["expressions"][expression_id] = {"expression_id": expression_id, "display_name": expression_id.capitalize(), "viseme": _viseme.text.strip_edges()}
	_session.set_production_suite_data(production, "Saved Presentation Expression " + expression_id)
	_status.text = "Saved expression/viseme entry '" + expression_id + "'."
	_refresh()


func _save_pose_board() -> void:
	if not _writable_project(): return
	var pose_ids: Array = []
	for value in _pose_ids.text.split(",", false):
		var pose_id := value.strip_edges()
		if not pose_id.is_empty() and pose_id not in pose_ids: pose_ids.append(pose_id)
	if pose_ids.is_empty(): _status.text = "Enter at least one pose ID for the board."; return
	var production: Dictionary = _session.get_production_suite_data()
	production["presentation"]["pose_boards"]["approval_board"] = {"board_id": "approval_board", "display_name": "Approval Pose Board", "pose_ids": pose_ids}
	_session.set_production_suite_data(production, "Saved Presentation Pose Board")
	_status.text = "Saved the approval pose board."
	_refresh()


func _save_turntable() -> void:
	if not _writable_project(): return
	var turntable_id := _turntable_id.text.strip_edges().to_snake_case()
	if turntable_id.is_empty(): _status.text = "Enter a turntable ID."; return
	var production: Dictionary = _session.get_production_suite_data()
	production["presentation"]["turntables"][turntable_id] = {"turntable_id": turntable_id, "display_name": turntable_id.capitalize(), "enabled": true}
	_session.set_production_suite_data(production, "Saved Presentation Turntable " + turntable_id)
	_status.text = "Saved turntable definition '" + turntable_id + "'."
	_refresh()


func _on_session_changed(_description: String) -> void: _refresh()
func _writable_project() -> bool: return _session != null and is_instance_valid(_session) and not _session.is_read_only()
func _absolute(path: String) -> String: return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


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


func _format_presentation_library(presentation: Dictionary) -> String:
	var turntables: Dictionary = presentation.get("turntables", {}) as Dictionary
	var expressions: Dictionary = presentation.get("expressions", {}) as Dictionary
	var boards: Dictionary = presentation.get("pose_boards", {}) as Dictionary
	return "[b]Approval-ready material[/b]\nTurntables: %d  •  Expressions / visemes: %d  •  Pose boards: %d\n\n[b]What will be exported[/b]\n• Turntable contact sheet from the current approved source art\n• Expression and viseme metadata\n• Outfit batch sheets and saved pose-board references\n• A local approval page, with the optional link above when provided\n\nEverything remains editable in this project after export." % [turntables.size(), expressions.size(), boards.size()]


func _format_export_result(report: Dictionary, message: String) -> String:
	var lines := ["[b]Latest presentation export[/b]", message, "", "Result: " + ("Complete" if bool(report.get("success", false)) else "Needs attention")]
	var folder := str(report.get("folder", "")).strip_edges()
	if not folder.is_empty(): lines.append("Output folder: " + folder)
	var approval_page := str(report.get("approval_page", "")).strip_edges()
	if not approval_page.is_empty(): lines.append("Approval page: " + approval_page.get_file())
	var errors: Array = report.get("errors", []) as Array
	if not errors.is_empty(): lines.append("Details: " + str(errors[0]))
	return "\n".join(lines)
