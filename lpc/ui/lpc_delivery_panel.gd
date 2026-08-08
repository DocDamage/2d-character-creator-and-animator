# LpcDeliveryPanel -- Explicit baked/editable/hybrid LPC delivery controls and portable runtime handoff.
class_name LpcDeliveryPanel
extends Control

const ModelScript = preload("res://lpc/export/lpc_delivery_workspace_model.gd")

signal profile_saved(profile: Dictionary, manifest: Dictionary, project_path: String)

var _model = ModelScript.new()
var _profiles: OptionButton
var _clips: OptionButton
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _build()
func bind_context(catalog: Dictionary, profile: Dictionary, manifest: Dictionary = {}, project_path: String = "") -> Dictionary:
	var result := _model.bind_context(catalog, profile, manifest, project_path); _refresh_clips(); return result
func get_model(): return _model


func _build() -> void:
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
	var title := Label.new(); title.text = "DELIVER · BAKED & EDITABLE RUNTIME"; title.add_theme_font_size_override("font_size", 20); root.add_child(title)
	var row := HBoxContainer.new(); root.add_child(row)
	_profiles = OptionButton.new()
	for profile_id in ["BAKED_FRAMES", "EDITABLE_GODOT_RUNTIME", "HYBRID_RUNTIME"]:
		_profiles.add_item(profile_id)
	row.add_child(_profiles)
	_clips = OptionButton.new(); _clips.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(_clips)
	var export := Button.new(); export.text = "Export delivery"; export.pressed.connect(_export); row.add_child(export)
	var assess := Button.new(); assess.text = "Assess release"; assess.pressed.connect(_assess); row.add_child(assess)
	var save := Button.new(); save.text = "Save profile"; save.pressed.connect(_save); row.add_child(save)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _status.text = "Baked Frames is the reliable default. Editable Runtime rejects unsupported features; Hybrid Runtime records explicit baked fallback."; root.add_child(_status)


func _refresh_clips() -> void:
	if _clips == null: return
	_clips.clear()
	for raw in _model.profile.get("clips", []):
		if raw is Dictionary:
			var clip: Dictionary = raw
			var index := _clips.item_count
			_clips.add_item(str(clip.get("name", clip.get("clip_id", ""))))
			_clips.set_item_metadata(index, str(clip.get("clip_id", "")))
	if _clips.item_count > 0: _clips.select(0)
func _export() -> void:
	var profile_id := _profiles.get_item_text(_profiles.selected); var clip_id := str(_clips.get_selected_metadata()) if _clips.selected >= 0 else ""
	var root := "user://lpc_exports/" + str(_model.profile.get("project_uuid", "character")) + "/delivery/" + profile_id.to_lower()
	var result := _model.export_delivery(profile_id, root, {"clip_id": clip_id}); _status.text = "Exported %s: %s" % [profile_id, result.get("manifest", "")] if bool(result.get("success", false)) else str(result.get("errors", ["LPC delivery export failed."])[0])
func _assess() -> void:
	var clip_id := str(_clips.get_selected_metadata()) if _clips.selected >= 0 else ""
	var result := _model.assess_release_candidate({"clip_id": clip_id})
	_status.text = "Release candidate is ready for approval." if bool(result.get("release_ready", false)) else ("Release evidence recorded: " + str(result.get("warnings", result.get("errors", ["Assessment failed."]))[0]))
func _save() -> void:
	var saved := _model.save(); _status.text = "Saved delivery profile records." if bool(saved.get("success", false)) else str(saved.get("errors", ["Save failed."])[0])
	if bool(saved.get("success", false)): profile_saved.emit(_model.profile.duplicate(true), _model.manifest.duplicate(true), _model.project_path)
