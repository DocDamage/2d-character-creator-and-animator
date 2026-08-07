# LpcDirectStartPanel -- Focused phase-1 LPC library, policy, body-family, and resume flow.
class_name LpcDirectStartPanel
extends Control

const DirectStartScript = preload("res://lpc/startup/lpc_direct_start_service.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")
const MAIN_WINDOW_SCENE := "res://app/shared_ui/main_window.tscn"

var _status: Label
var _library: Label
var _policy: OptionButton
var _body: OptionButton
var _name: LineEdit
var _create: Button
var _resume: Button
var _file_dialog: FileDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _build() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.03, 0.05, 0.08, 0.92)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 480)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28); margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28); margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "LPC CHARACTER CREATOR"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose a locked local LPC library, policy, and compatible body family. Source art stays immutable."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)
	_library = Label.new(); _library.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(_library)
	var library_actions := HBoxContainer.new(); library_actions.add_theme_constant_override("separation", 8); box.add_child(library_actions)
	var locate := Button.new(); locate.text = "Locate library"; locate.pressed.connect(_locate_library); library_actions.add_child(locate)
	var rebuild := Button.new(); rebuild.text = "Rebuild catalog"; rebuild.pressed.connect(_rebuild_catalog); library_actions.add_child(rebuild)
	var policy_row := HBoxContainer.new(); policy_row.add_theme_constant_override("separation", 12); box.add_child(policy_row)
	var policy_label := Label.new(); policy_label.text = "License policy"; policy_label.custom_minimum_size = Vector2(130, 0); policy_row.add_child(policy_label)
	_policy = OptionButton.new(); _policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _policy.item_selected.connect(func(_index): _refresh_bodies()); policy_row.add_child(_policy)
	var body_row := HBoxContainer.new(); body_row.add_theme_constant_override("separation", 12); box.add_child(body_row)
	var body_label := Label.new(); body_label.text = "Body family"; body_label.custom_minimum_size = Vector2(130, 0); body_row.add_child(body_label)
	_body = OptionButton.new(); _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body_row.add_child(_body)
	var name_row := HBoxContainer.new(); name_row.add_theme_constant_override("separation", 12); box.add_child(name_row)
	var name_label := Label.new(); name_label.text = "Project label"; name_label.custom_minimum_size = Vector2(130, 0); name_row.add_child(name_label)
	_name = LineEdit.new(); _name.text = "LPC Character"; _name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; name_row.add_child(_name)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _status.custom_minimum_size = Vector2(0, 56); box.add_child(_status)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_END; actions.add_theme_constant_override("separation", 8); box.add_child(actions)
	var advanced := Button.new(); advanced.text = "Open Advanced Studio"; advanced.pressed.connect(func(): queue_free()); actions.add_child(advanced)
	_resume = Button.new(); _resume.text = "Resume latest LPC project"; _resume.pressed.connect(_resume_latest); actions.add_child(_resume)
	_create = Button.new(); _create.text = "Create LPC project"; _create.pressed.connect(_create_project); actions.add_child(_create)
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Locate locked LPC source library"
	_file_dialog.dir_selected.connect(_selected_library)
	add_child(_file_dialog)


func _refresh() -> void:
	_populate_policies()
	var status: Dictionary = DirectStartScript.library_status()
	_library.text = "Library: " + (str(status.get("root", "Not located")) if bool(status.get("available", false)) else str(status.get("message", "Not located")))
	_status.text = str(status.get("message", ""))
	_refresh_bodies()
	var resume := DirectStartScript.latest_resumable()
	_resume.disabled = not bool(resume.get("success", false))


func _populate_policies() -> void:
	var current: Variant = _policy.get_selected_metadata() if _policy.item_count > 0 else "full_source"
	_policy.clear()
	for profile in LicenseResolverScript.list_profiles():
		var index := _policy.item_count
		_policy.add_item(str(profile.get("name", "Policy")))
		_policy.set_item_metadata(index, str(profile.get("id", "full_source")))
		if str(profile.get("id", "")) == str(current): _policy.select(index)
	if _policy.item_count > 0 and _policy.selected < 0: _policy.select(0)


func _refresh_bodies() -> void:
	if _body == null or _policy == null: return
	var selected_id := str(_body.get_selected_metadata()) if _body.item_count > 0 else ""
	_body.clear()
	var policy_id := _selected_policy()
	for family in DirectStartScript.compatible_body_families(policy_id):
		var index := _body.item_count
		var eligible := bool(family.get("eligible", false))
		_body.add_item(str(family.get("name", family.get("id", "Unknown"))) + ("" if eligible else " (unavailable)"))
		_body.set_item_metadata(index, str(family.get("id", "")))
		_body.set_item_disabled(index, not eligible)
		if eligible and str(family.get("id", "")) == selected_id: _body.select(index)
	if _body.selected < 0:
		for index in range(_body.item_count):
			if not _body.is_item_disabled(index): _body.select(index); break
	_create.disabled = _body.selected < 0


func _locate_library() -> void:
	_file_dialog.popup_centered_ratio(0.72)


func _selected_library(path: String) -> void:
	var result := DirectStartScript.set_library_root(path)
	if not result.get("success", false): _status.text = str(result.get("errors", ["Could not locate library."])[0]); return
	_rebuild_catalog()


func _rebuild_catalog() -> void:
	_status.text = "Building a deterministic catalog from the locked local source…"
	var result := DirectStartScript.rebuild_catalog()
	_status.text = "Locked catalog ready." if result.get("success", false) else str(result.get("errors", ["Catalog build failed."])[0])
	_refresh()


func _create_project() -> void:
	if _body.selected < 0: return
	var label := _name.text.strip_edges()
	if label.is_empty(): label = "LPC Character"
	var folder := ProjectSettings.globalize_path("user://projects")
	DirAccess.make_dir_recursive_absolute(folder)
	var base := _safe_filename(label)
	var target := folder.path_join(base + ".chrproj")
	var suffix := 2
	while FileAccess.file_exists(target):
		target = folder.path_join(base + " " + str(suffix) + ".chrproj")
		suffix += 1
	var result := DirectStartScript.create_project(target, label, str(_body.get_selected_metadata()), _selected_policy())
	if not result.get("success", false): _status.text = str(result.get("errors", ["Project creation failed."])[0]); return
	_status.text = "Created %s. Opening the editable project…" % label
	_open_project(target)


func _resume_latest() -> void:
	var result := DirectStartScript.latest_resumable()
	if not result.get("success", false): _status.text = str(result.get("errors", ["No resumable LPC project."])[0]); return
	_open_project(str(result.get("path", "")))


func _open_project(path: String) -> void:
	if AppState != null: AppState.open_project(path)
	get_tree().change_scene_to_file(MAIN_WINDOW_SCENE)


func _selected_policy() -> String:
	return str(_policy.get_selected_metadata()) if _policy != null and _policy.selected >= 0 else "full_source"


func _safe_filename(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.is_valid_identifier() or character in [" ", "-", "_"] else "_"
	return result.strip_edges().substr(0, 80) if not result.strip_edges().is_empty() else "LPC Character"
