# LpcAnimationPanel -- Focused typed-clip authoring surface for hybrid source/cel playback.
class_name LpcAnimationPanel
extends Control

const ModelScript = preload("res://lpc/animation/lpc_clip_authoring_model.gd")

signal profile_saved(profile: Dictionary, manifest: Dictionary, project_path: String)

var _model = ModelScript.new()
var _clips: OptionButton
var _time: HSlider
var _preview: TextureRect
var _tracks: RichTextLabel
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _build()
	if not _model.changed.is_connected(_on_changed): _model.changed.connect(_on_changed)


func bind_context(catalog: Dictionary, profile: Dictionary, manifest: Dictionary = {}, project_path: String = "") -> Dictionary:
	var result := _model.bind_context(catalog, profile, manifest, project_path); _refresh(); return result


func get_model(): return _model


func _build() -> void:
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
	var title := Label.new(); title.text = "ANIMATE · HYBRID CLIPS"; title.add_theme_font_size_override("font_size", 20); root.add_child(title)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 8); root.add_child(bar)
	_clips = OptionButton.new(); _clips.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _clips.item_selected.connect(func(_index): _preview_clip()); bar.add_child(_clips)
	var create := Button.new(); create.text = "New clip"; create.pressed.connect(_create_clip); bar.add_child(create)
	var source := Button.new(); source.text = "Add source track"; source.pressed.connect(_add_source_track); bar.add_child(source)
	var cel := Button.new(); cel.text = "Add cel track"; cel.pressed.connect(_add_cel_track); bar.add_child(cel)
	var save := Button.new(); save.text = "Save"; save.pressed.connect(_save); bar.add_child(save)
	var export := Button.new(); export.text = "Export hybrid PNGs"; export.pressed.connect(_export); bar.add_child(export)
	_time = HSlider.new(); _time.min_value = 0.0; _time.max_value = 1.0; _time.step = 0.01; _time.value_changed.connect(func(_value): _preview_clip()); root.add_child(_time)
	_preview = TextureRect.new(); _preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; _preview.custom_minimum_size = Vector2(320, 260); _preview.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(_preview)
	_tracks = RichTextLabel.new(); _tracks.bbcode_enabled = true; _tracks.fit_content = true; _tracks.custom_minimum_size.y = 90; root.add_child(_tracks)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(_status)
	_status.text = "Create a typed clip, then author source-frame, cel-swap, transform, visibility, z-order, palette, rig, mesh, event, and direction tracks."


func _refresh() -> void:
	if _clips == null: return
	var wanted := str(_clips.get_selected_metadata()) if _clips.item_count > 0 else str((_model.profile.get("hybrid_animation_state", {}) as Dictionary).get("selected_clip_id", ""))
	_clips.clear()
	for raw in _model.profile.get("clips", []):
		if not raw is Dictionary: continue
		var clip: Dictionary = raw; var index := _clips.item_count; _clips.add_item(str(clip.get("name", clip.get("clip_id", "Clip")))); _clips.set_item_metadata(index, str(clip.get("clip_id", "")))
		if str(clip.get("clip_id", "")) == wanted: _clips.select(index)
	if _clips.selected < 0 and _clips.item_count > 0: _clips.select(0)
	var clip := _active_clip(); _time.max_value = float(clip.get("duration", 1.0)) if not clip.is_empty() else 1.0; _time.value = minf(_time.value, _time.max_value)
	_tracks.text = _track_text(clip); _preview_clip()


func _create_clip() -> void:
	var result := _model.create_clip("Hybrid Clip %d" % (( _model.profile.get("clips", []) as Array).size() + 1), {"duration": 0.9, "fps": 10.0})
	_status.text = "Created typed hybrid clip." if bool(result.get("success", false)) else str(result.get("errors", ["Could not create clip."])[0])


func _add_source_track() -> void:
	var clip := _active_clip(); var target := _first_layer()
	if clip.is_empty() or target.is_empty(): return
	var result := _model.add_track(str(clip.get("clip_id", "")), "source_frame", target)
	if bool(result.get("success", false)): _model.set_key(str(clip.get("clip_id", "")), str((result.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"animation_id": "walk"})


func _add_cel_track() -> void:
	var clip := _active_clip(); var target := _first_layer()
	if clip.is_empty() or target.is_empty(): return
	var result := _model.add_track(str(clip.get("clip_id", "")), "image_cel_swap", target)
	if bool(result.get("success", false)):
		var derivative_id := str((((_model.profile.get("derivative_references", []) as Array)[0] as Dictionary).get("derivative_id", ""))) if not (_model.profile.get("derivative_references", []) as Array).is_empty() else ""
		if not derivative_id.is_empty(): _model.set_key(str(clip.get("clip_id", "")), str((result.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"derivative_id": derivative_id})


func _preview_clip() -> void:
	var clip := _active_clip(); if clip.is_empty(): _preview.texture = null; return
	var result := _model.preview(str(clip.get("clip_id", "")), _time.value)
	if bool(result.get("success", false)):
		_preview.texture = ImageTexture.create_from_image(result.image as Image); _status.text = "Verified hybrid preview · %s" % str(result.get("output_hash", "")).substr(0, 12)
	else: _status.text = str(result.get("errors", ["Hybrid preview failed."])[0])


func _save() -> void:
	var result := _model.save(); _status.text = "Saved typed hybrid clips." if bool(result.get("success", false)) else str(result.get("errors", ["Save failed."])[0])
	if bool(result.get("success", false)): profile_saved.emit(_model.profile.duplicate(true), _model.manifest.duplicate(true), _model.project_path)


func _export() -> void:
	var clip := _active_clip(); if clip.is_empty(): return
	var result := _model.export_clip(str(clip.get("clip_id", "")), "user://lpc_exports/" + str(_model.profile.get("project_uuid", "character")) + "/hybrid")
	_status.text = "Exported %d hybrid frames." % int(result.get("frame_count", 0)) if bool(result.get("success", false)) else str(result.get("errors", ["Export failed."])[0])


func _active_clip() -> Dictionary:
	if _clips == null or _clips.selected < 0: return {}
	for raw in _model.profile.get("clips", []): if raw is Dictionary and str((raw as Dictionary).get("clip_id", "")) == str(_clips.get_selected_metadata()): return raw
	return {}
func _first_layer() -> String:
	for raw in _model.profile.get("selections", []): if raw is Dictionary: return str((raw as Dictionary).get("instance_id", ""))
	return ""
func _track_text(clip: Dictionary) -> String:
	if clip.is_empty(): return "[color=#9aa8b8]No typed LPC clip yet.[/color]"
	var lines: Array[String] = ["[b]%s[/b] · %.2fs · %.0f fps" % [clip.get("name", ""), float(clip.get("duration", 0.0)), float(clip.get("fps", 0.0))]]
	for raw in clip.get("tracks", []): if raw is Dictionary: lines.append("• %s → %s" % [(raw as Dictionary).get("track_type", ""), (raw as Dictionary).get("target_id", "")])
	return "\n".join(lines)
func _on_changed(_description: String) -> void: _refresh()
