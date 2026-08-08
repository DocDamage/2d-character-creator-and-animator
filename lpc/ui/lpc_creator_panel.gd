# LpcCreatorPanel -- Focused three-column creator for a validated LPC direct-start project.
class_name LpcCreatorPanel
extends Control

const ModelScript = preload("res://lpc/creator/lpc_creator_model.gd")

const LEFT_TYPES := ["body", "base", "face", "hair", "eyes", "mouth", "nose", "skin"]

signal profile_changed(profile: Dictionary, manifest: Dictionary, project_path: String)

var _model = ModelScript.new()
var _left_assets: ItemList
var _right_assets: ItemList
var _layers: ItemList
var _animation: OptionButton
var _direction: OptionButton
var _preview: TextureRect
var _status: Label
var _conflicts: RichTextLabel
var _save: Button
var _export: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not _model.changed.is_connected(_on_model_changed): _model.changed.connect(_on_model_changed)


func bind_context(catalog: Dictionary, profile: Dictionary, manifest: Dictionary = {}, project_path: String = "") -> Dictionary:
	var result := _model.bind_context(catalog, profile, manifest, project_path)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("errors", ["Could not open LPC creator."])[0]))
		return result
	_refresh_all()
	return result


func get_model():
	return _model


func _build() -> void:
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
	var title := Label.new(); title.text = "LPC CHARACTER CREATOR"; title.add_theme_font_size_override("font_size", 22); root.add_child(title)
	var subtitle := Label.new(); subtitle.text = "Native source playback is verified from the locked catalog. Missing art remains visible as a conflict."; subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(subtitle)
	var columns := HBoxContainer.new(); columns.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation", 10); root.add_child(columns)
	columns.add_child(_asset_column("Body & features", true))
	columns.add_child(_center_column())
	columns.add_child(_asset_column("Clothing & equipment", false))
	_conflicts = RichTextLabel.new(); _conflicts.bbcode_enabled = true; _conflicts.fit_content = true; _conflicts.custom_minimum_size.y = 52; root.add_child(_conflicts)
	var footer := HBoxContainer.new(); footer.alignment = BoxContainer.ALIGNMENT_END; footer.add_theme_constant_override("separation", 8); root.add_child(footer)
	var hide := Button.new(); hide.text = "Hide missing for clip"; hide.pressed.connect(_hide_conflicts); footer.add_child(hide)
	var credits := Button.new(); credits.text = "Credits"; credits.pressed.connect(_show_credits); footer.add_child(credits)
	_save = Button.new(); _save.text = "Save"; _save.pressed.connect(_save_project); footer.add_child(_save)
	_export = Button.new(); _export.text = "Export native PNGs"; _export.pressed.connect(_export_native); footer.add_child(_export)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(_status)
	_set_status("Open an LPC direct-start project to assemble a native character.")


func _asset_column(title: String, is_left: bool) -> Control:
	var panel := VBoxContainer.new(); panel.custom_minimum_size = Vector2(220, 0); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new(); label.text = title; label.add_theme_font_size_override("font_size", 16); panel.add_child(label)
	var list := ItemList.new(); list.size_flags_vertical = Control.SIZE_EXPAND_FILL; list.allow_reselect = true; list.item_activated.connect(_select_asset.bind(is_left)); panel.add_child(list)
	if is_left: _left_assets = list
	else: _right_assets = list
	return panel


func _center_column() -> Control:
	var center := VBoxContainer.new(); center.custom_minimum_size = Vector2(330, 0); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls := HBoxContainer.new(); center.add_child(controls)
	_animation = OptionButton.new(); _animation.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _animation.item_selected.connect(func(_index): _refresh_preview()); controls.add_child(_animation)
	_direction = OptionButton.new(); _direction.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _direction.item_selected.connect(func(_index): _refresh_preview()); controls.add_child(_direction)
	_preview = TextureRect.new(); _preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; _preview.custom_minimum_size = Vector2(300, 300); _preview.size_flags_vertical = Control.SIZE_EXPAND_FILL; center.add_child(_preview)
	var layer_label := Label.new(); layer_label.text = "Selected layers"; center.add_child(layer_label)
	_layers = ItemList.new(); _layers.custom_minimum_size.y = 110; _layers.item_activated.connect(_remove_layer); center.add_child(_layers)
	return center


func _refresh_all() -> void:
	_refresh_assets()
	_refresh_layers()
	_refresh_controls()
	_refresh_preview()


func _refresh_assets() -> void:
	if _left_assets == null or _right_assets == null: return
	_left_assets.clear(); _right_assets.clear()
	var result := _model.browse()
	for raw_item in result.get("items", []):
		var item: Dictionary = raw_item
		var list := _left_assets if str(item.get("type_name", "")).to_lower() in LEFT_TYPES else _right_assets
		var index := list.add_item("%s · %s" % [str(item.get("type_name", "Asset")).capitalize(), str(item.get("asset_id", ""))])
		list.set_item_metadata(index, str(item.get("asset_id", "")))


func _refresh_layers() -> void:
	if _layers == null: return
	_layers.clear()
	for raw_selection in _model.profile.get("selections", []):
		if not raw_selection is Dictionary: continue
		var selection: Dictionary = raw_selection
		var capability: Dictionary = _model.capability_status(str(selection.get("instance_id", "")))
		var index := _layers.add_item("%s  [%s]" % [str(selection.get("asset_id", "")), str(capability.get("status", "Frame Only"))])
		_layers.set_item_metadata(index, str(selection.get("instance_id", "")))


func _refresh_controls() -> void:
	if _animation == null or _direction == null: return
	var selected_animation := str(_animation.get_selected_metadata()) if _animation.item_count > 0 else ""
	_animation.clear()
	for animation_id in _model.native_animations():
		var index := _animation.item_count; _animation.add_item(animation_id.capitalize()); _animation.set_item_metadata(index, animation_id)
		if animation_id == selected_animation: _animation.select(index)
	if _animation.selected < 0 and _animation.item_count > 0: _animation.select(0)
	var selected_direction := str(_direction.get_selected_metadata()) if _direction.item_count > 0 else "down"
	_direction.clear()
	for direction_id in (_model.profile.get("direction_set", {}) as Dictionary).get("directions", ["up", "left", "down", "right"]):
		var index := _direction.item_count; _direction.add_item(str(direction_id).capitalize()); _direction.set_item_metadata(index, direction_id)
		if str(direction_id) == selected_direction: _direction.select(index)
	if _direction.selected < 0 and _direction.item_count > 0: _direction.select(0)
	_save.disabled = _model.project_path.is_empty(); _export.disabled = _animation.item_count == 0


func _refresh_preview() -> void:
	if _preview == null or _animation == null or _animation.selected < 0 or _direction == null or _direction.selected < 0:
		return
	var result := _model.preview(str(_animation.get_selected_metadata()), str(_direction.get_selected_metadata()), 0.0)
	if bool(result.get("success", false)):
		_preview.texture = ImageTexture.create_from_image(result.image as Image)
		_conflicts.text = "[color=#7ddc8b]Verified Native Preview[/color] · %s" % str(result.get("output_hash", "")).substr(0, 12)
		_set_status("Native preview is using the same render snapshot used by export.")
	else:
		_preview.texture = null
		var lines: Array[String] = []
		for conflict in result.get("conflicts", []): lines.append("• " + str((conflict as Dictionary).get("message", "Unresolved native-layer conflict.")))
		_conflicts.text = "[color=#f5c36a]Native clip requires a decision[/color]\n" + "\n".join(lines)
		if not lines.is_empty(): _set_status("Resolve or explicitly hide each unsupported layer; nothing is removed silently.")


func _select_asset(is_left: bool, index: int) -> void:
	var list := _left_assets if is_left else _right_assets
	var asset_id := str(list.get_item_metadata(index))
	var result := _model.select_asset(asset_id)
	_set_status("Selected " + asset_id if bool(result.get("success", false)) else str(result.get("errors", ["Selection failed."])[0]))
	_refresh_all()


func _remove_layer(index: int) -> void:
	var instance_id := str(_layers.get_item_metadata(index))
	if _model.remove_selection(instance_id): _set_status("Removed " + instance_id); _refresh_all()


func _hide_conflicts() -> void:
	if _animation.selected < 0: return
	var animation_id := str(_animation.get_selected_metadata())
	var preview := _model.preview(animation_id, str(_direction.get_selected_metadata()), 0.0)
	for conflict in preview.get("conflicts", []): _model.set_missing_animation_action(str((conflict as Dictionary).get("instance_id", "")), animation_id, "hide_for_clip")
	_refresh_all()


func _save_project() -> void:
	var saved := _model.save()
	_set_status("Saved LPC creator state." if bool(saved.get("success", false)) else str(saved.get("errors", ["Save failed."])[0]))


func _export_native() -> void:
	if _animation.selected < 0 or _direction.selected < 0: return
	var folder := "user://lpc_exports/" + str(_model.profile.get("project_uuid", "character"))
	var exported := _model.export_native(str(_animation.get_selected_metadata()), str(_direction.get_selected_metadata()), folder)
	_set_status("Exported %d verified native PNG frames." % int(exported.get("frame_count", 0)) if bool(exported.get("success", false)) else str(exported.get("errors", ["Export failed."])[0]))


func _show_credits() -> void:
	var manifest := _model.credit_manifest()
	_set_status("%d exact credit row(s) are ready for export." % (manifest.get("credits", []) as Array).size() if bool(manifest.get("success", false)) else str(manifest.get("errors", ["Credit resolution failed."])[0]))


func _on_model_changed(_description: String) -> void:
	_refresh_all()
	profile_changed.emit(_model.profile.duplicate(true), _model.manifest.duplicate(true), _model.project_path)


func _set_status(message: String) -> void:
	if _status != null: _status.text = message
