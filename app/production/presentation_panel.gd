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


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
	_refresh()


func _build() -> void:
	var title := Label.new(); title.text = "Presentation & Approval"; title.add_theme_font_size_override("font_size", 18); add_child(title)
	var hint := Label.new(); hint.text = "Create a client-ready package with authored turntable stops, expression/viseme data, real outfit batch sheets, pose-board references, and an approval page."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(hint)
	var row := HFlowContainer.new(); add_child(row)
	_approval_url = LineEdit.new(); _approval_url.tooltip_text = "Optional secure approval URL (https://…)"; _approval_url.custom_minimum_size.x = 250; row.add_child(_approval_url)
	_output_path = LineEdit.new(); _output_path.tooltip_text = "Presentation output folder"; _output_path.custom_minimum_size.x = 230; row.add_child(_output_path)
	var export_button := Button.new(); export_button.text = "Export approval package"; export_button.pressed.connect(_export); row.add_child(export_button)
	_reveal = Button.new(); _reveal.text = "Reveal output"; _reveal.disabled = true; _reveal.pressed.connect(func(): if not _last_folder.is_empty(): OS.shell_open(_absolute(_last_folder))); row.add_child(_reveal)
	var library_row := HFlowContainer.new(); add_child(library_row)
	_expression_id = LineEdit.new(); _expression_id.tooltip_text = "Expression ID"; _expression_id.custom_minimum_size.x = 120; library_row.add_child(_expression_id)
	_viseme = LineEdit.new(); _viseme.tooltip_text = "Viseme (optional)"; _viseme.custom_minimum_size.x = 120; library_row.add_child(_viseme)
	var expression_button := Button.new(); expression_button.text = "Save expression"; expression_button.pressed.connect(_save_expression); library_row.add_child(expression_button)
	_pose_ids = LineEdit.new(); _pose_ids.tooltip_text = "Pose IDs (comma separated)"; _pose_ids.custom_minimum_size.x = 190; library_row.add_child(_pose_ids)
	var board_button := Button.new(); board_button.text = "Save pose board"; board_button.pressed.connect(_save_pose_board); library_row.add_child(board_button)
	_turntable_id = LineEdit.new(); _turntable_id.tooltip_text = "Turntable ID"; _turntable_id.custom_minimum_size.x = 115; library_row.add_child(_turntable_id)
	var turntable_button := Button.new(); turntable_button.text = "Save turntable"; turntable_button.pressed.connect(_save_turntable); library_row.add_child(turntable_button)
	_output = RichTextLabel.new(); _output.name = "PresentationOutput"; _output.custom_minimum_size = Vector2(0, 220); _output.size_flags_vertical = Control.SIZE_EXPAND_FILL; _output.bbcode_enabled = false; add_child(_output)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_status)


func _refresh() -> void:
	if _session == null or not is_instance_valid(_session): _output.text = "Open a project to create a presentation package."; return
	if _output_path.text.strip_edges().is_empty(): _output_path.text = _session.project_path.get_base_dir().path_join("presentations")
	var production: Dictionary = _session.get_production_suite_data()
	var presentation: Dictionary = production.get("presentation", {}) as Dictionary
	_output.text = JSON.stringify({"turntables": presentation.get("turntables", {}), "expressions": presentation.get("expressions", {}), "pose_boards": presentation.get("pose_boards", {}), "note": "Outfit sheets are rendered from imported layers; runtime-facing presentation data remains authored and editable."}, "\t", true, false)
	_status.text = "Presentation package is ready to assemble from current approved source art and project metadata."


func _export() -> void:
	if _session == null or not is_instance_valid(_session): return
	var folder := _output_path.text.strip_edges().path_join("%s_%d" % [_session.project_path.get_file().get_basename().validate_filename(), Time.get_unix_time_from_system()])
	var report: Dictionary = PresentationExporterScript.new().export_package(_session, folder, {"approval_url": _approval_url.text.strip_edges()})
	_last_folder = str(report.get("folder", "")); _reveal.disabled = _last_folder.is_empty()
	_output.text = JSON.stringify(report, "\t", true, false)
	_status.text = "Presentation package complete." if bool(report.get("success", false)) else str(report.get("errors", ["Presentation export failed."])[0])


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
