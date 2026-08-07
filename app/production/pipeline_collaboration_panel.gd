# PipelineCollaborationPanel -- Headless workflow help, approved watch folders, asset packs, snapshots, and Git-aware diffs.
class_name PipelineCollaborationPanel
extends VBoxContainer

const WatchServiceScript = preload("res://pipeline/watch_folder_service.gd")
const AssetPackServiceScript = preload("res://pipeline/asset_pack_service.gd")
const ChangeServiceScript = preload("res://collaboration/project_change_service.gd")

var _session = null
var _source_path: LineEdit
var _part_id: LineEdit
var _snapshot_picker: OptionButton
var _output: RichTextLabel
var _status: Label
var _watcher = WatchServiceScript.new()


func _ready() -> void:
	name = "PipelineCollaborationPanel"; size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL; _build(); _refresh()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
	_refresh()


func _build() -> void:
	var title := Label.new(); title.text = "Pipeline Automation & Collaboration"; title.add_theme_font_size_override("font_size", 18); add_child(title)
	var hint := Label.new(); hint.text = "Headless CLI, safe artist-approved re-import, reusable templates/asset packs, snapshots, changed-asset summaries, conflict guidance, and Git status."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(hint)
	var watch_row := HFlowContainer.new(); add_child(watch_row)
	_source_path = LineEdit.new(); _source_path.tooltip_text = "Approved source-layer path"; _source_path.custom_minimum_size.x = 250; watch_row.add_child(_source_path)
	_part_id = LineEdit.new(); _part_id.tooltip_text = "Character part ID"; _part_id.custom_minimum_size.x = 130; watch_row.add_child(_part_id)
	var watch_button := Button.new(); watch_button.text = "Watch approved source"; watch_button.pressed.connect(_watch_source); watch_row.add_child(watch_button)
	var scan_button := Button.new(); scan_button.text = "Scan changes"; scan_button.pressed.connect(_scan); watch_row.add_child(scan_button)
	var apply_button := Button.new(); apply_button.text = "Apply approved"; apply_button.pressed.connect(_apply); watch_row.add_child(apply_button)
	var change_row := HFlowContainer.new(); add_child(change_row)
	_snapshot_picker = OptionButton.new(); _snapshot_picker.custom_minimum_size.x = 210; change_row.add_child(_snapshot_picker)
	var compare_button := Button.new(); compare_button.text = "Compare milestone"; compare_button.pressed.connect(_compare_snapshot); change_row.add_child(compare_button)
	var git_button := Button.new(); git_button.text = "Git status"; git_button.pressed.connect(_git_status); change_row.add_child(git_button)
	var pack_button := Button.new(); pack_button.text = "Export asset pack"; pack_button.pressed.connect(_export_pack); change_row.add_child(pack_button)
	var cli := Label.new(); cli.text = "CLI: godot --headless --path . --scene res://tools/studio_cli.tscn -- <command>\nCommands: validate · runtime-export · review-export · bulk-import · watch-scan/watch-apply · template-create · asset-pack-export/import"; cli.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(cli)
	_output = RichTextLabel.new(); _output.name = "PipelineCollaborationOutput"; _output.custom_minimum_size = Vector2(0, 205); _output.size_flags_vertical = Control.SIZE_EXPAND_FILL; _output.bbcode_enabled = false; add_child(_output)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_status)


func _refresh() -> void:
	_snapshot_picker.clear()
	if _session == null or not is_instance_valid(_session): _output.text = "Open a project to inspect its pipeline and history."; return
	var production: Dictionary = _session.get_production_suite_data()
	_watcher.configure(production.get("pipeline", {}).get("watch_folders", []) as Array)
	for raw_snapshot in _session.list_project_snapshots():
		var snapshot: Dictionary = raw_snapshot as Dictionary
		_snapshot_picker.add_item(str(snapshot.get("name", snapshot.get("id", "Snapshot"))))
		_snapshot_picker.set_item_metadata(_snapshot_picker.item_count - 1, str(snapshot.get("id", "")))
	_output.text = JSON.stringify({"watch_folders": _watcher.to_dict(), "snapshot_count": _snapshot_picker.item_count, "template": production.get("pipeline", {}).get("template_id", "blank"), "asset_pack_count": (production.get("pipeline", {}).get("asset_packs", []) as Array).size()}, "\t", true, false)
	_status.text = "Only sources explicitly marked approved can be re-imported; unapproved changes stay visible but untouched."


func _watch_source() -> void:
	if not _writable_project(): return
	var report: Dictionary = _watcher.add_source(_source_path.text.strip_edges(), _part_id.text.strip_edges(), true)
	if bool(report.get("success", false)): _persist_watchers("Added Approved Watch Source")
	else: _show(report, str(report.get("errors", ["Could not add source."])[0]))


func _scan() -> void:
	if _session == null or not is_instance_valid(_session): return
	_show(_watcher.scan_once(), "Scanned watched source layers without modifying your project.")


func _apply() -> void:
	if not _writable_project(): return
	var report: Dictionary = _watcher.apply_approved(_session)
	if (report.get("applied", []) as Array).size() > 0: _persist_watchers("Re-imported Artist-Approved Source Layers")
	_show(report, "Applied only approved artwork changes." if bool(report.get("success", false)) else "Some watched changes need review.")


func _compare_snapshot() -> void:
	if _session == null or not is_instance_valid(_session) or _snapshot_picker.selected < 0: return
	var id := str(_snapshot_picker.get_item_metadata(_snapshot_picker.selected))
	var report: Dictionary = ChangeServiceScript.new().compare_snapshot(_session, id)
	_show(report, "Compared current project with the selected milestone.")


func _git_status() -> void:
	if _session == null or not is_instance_valid(_session): return
	var report: Dictionary = ChangeServiceScript.new().git_status(_session.project_path)
	_show(report, "Read local Git status; no repository state was changed.")


func _export_pack() -> void:
	if _session == null or not is_instance_valid(_session): return
	var folder: String = str(_session.project_path).get_base_dir().path_join("asset_packs")
	var path: String = folder.path_join("%s_%d.assetpack" % [str(_session.project_path).get_file().get_basename().validate_filename(), Time.get_unix_time_from_system()])
	var report: Dictionary = AssetPackServiceScript.new().export_pack(_session.get_manifest_copy(), path)
	if bool(report.get("success", false)) and _writable_project():
		var production: Dictionary = _session.get_production_suite_data()
		var packs: Array = production["pipeline"].get("asset_packs", []) as Array
		packs.append({"path": path, "created_at": Time.get_unix_time_from_system(), "asset_count": int(report.get("asset_count", 0))})
		production["pipeline"]["asset_packs"] = packs
		_session.set_production_suite_data(production, "Exported Asset Pack")
	_show(report, "Exported a portable, manifest-first asset pack.")


func _persist_watchers(description: String) -> void:
	var production: Dictionary = _session.get_production_suite_data()
	production["pipeline"]["watch_folders"] = _watcher.to_dict()
	_session.set_production_suite_data(production, description)
	_refresh()


func _show(value: Dictionary, message: String) -> void: _output.text = JSON.stringify(value, "\t", true, false); _status.text = message
func _writable_project() -> bool: return _session != null and is_instance_valid(_session) and not _session.is_read_only()
func _on_session_changed(_description: String) -> void: _refresh()
