# LpcRigPanel -- Focused UI for Prepare for Rig, rigid hand poses, weighted meshes, cages, and authored diagonals.
class_name LpcRigPanel
extends Control

const ModelScript = preload("res://lpc/rig/lpc_rig_workspace_model.gd")
const CageScript = preload("res://lpc/rig/lpc_cage_deformation.gd")

signal profile_saved(profile: Dictionary, manifest: Dictionary, project_path: String)

var _model = ModelScript.new()
var _layers: OptionButton
var _directions: OptionButton
var _preview: TextureRect
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _build()
	if not _model.changed.is_connected(_on_changed): _model.changed.connect(_on_changed)
func bind_context(catalog: Dictionary, profile: Dictionary, manifest: Dictionary = {}, project_path: String = "") -> Dictionary:
	var result := _model.bind_context(catalog, profile, manifest, project_path); _refresh_layers(); return result
func get_model(): return _model


func _build() -> void:
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
	var title := Label.new(); title.text = "RIG · CUTOUTS, WEIGHTS & DIRECTIONS"; title.add_theme_font_size_override("font_size", 20); root.add_child(title)
	var source := HBoxContainer.new(); root.add_child(source)
	_layers = OptionButton.new(); _layers.size_flags_horizontal = Control.SIZE_EXPAND_FILL; source.add_child(_layers)
	_directions = OptionButton.new()
	for direction_id in ["down", "up", "left", "right", "down_right", "down_left", "up_right", "up_left"]:
		_directions.add_item(direction_id)
	source.add_child(_directions)
	var prepare := Button.new(); prepare.text = "Prepare for rig"; prepare.pressed.connect(_prepare); source.add_child(prepare)
	var pose := HBoxContainer.new(); root.add_child(pose)
	var solve := Button.new(); solve.text = "Pose right hand"; solve.pressed.connect(func(): _status_from(_model.solve_hand_to_anchor("hand_right", Vector2(52, 48)), "Solved rigid two-bone hand anchor.")); pose.add_child(solve)
	var weighted := Button.new(); weighted.text = "Weight first piece"; weighted.pressed.connect(_weight_piece); pose.add_child(weighted)
	var cage := Button.new(); cage.text = "Add true cage"; cage.pressed.connect(_add_cage); pose.add_child(cage)
	var directions := HBoxContainer.new(); root.add_child(directions)
	var enable := Button.new(); enable.text = "Enable 8 directions"; enable.pressed.connect(func(): _status_from(_model.enable_eight_directions(), "Enabled explicit authored eight-direction completion.")); directions.add_child(enable)
	var author := Button.new(); author.text = "Mark selected rigged"; author.pressed.connect(func(): _status_from(_model.author_direction(_selected_direction(), "RIGGED"), "Recorded selected direction as a direction-specific rig.")); directions.add_child(author)
	var preview := Button.new(); preview.text = "Preview pose"; preview.pressed.connect(_preview_pose); directions.add_child(preview)
	var save := Button.new(); save.text = "Save"; save.pressed.connect(_save); directions.add_child(save)
	_preview = TextureRect.new(); _preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; _preview.custom_minimum_size = Vector2(320, 260); _preview.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(_preview)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _status.text = "Prepare a project-owned direction-specific cutout rig. Native frames stay available as explicit fallback."; root.add_child(_status)


func _refresh_layers() -> void:
	if _layers == null: return
	_layers.clear()
	for raw in _model.profile.get("selections", []):
		if raw is Dictionary: var selection: Dictionary = raw; var index := _layers.item_count; _layers.add_item(str(selection.get("asset_id", ""))); _layers.set_item_metadata(index, str(selection.get("instance_id", "")))
	if _layers.item_count > 0: _layers.select(0)
func _prepare() -> void:
	if _layers.selected < 0: return
	_status_from(_model.prepare_for_rig(str(_layers.get_selected_metadata()), {"target_direction_id": _selected_direction()}), "Created reversible project-owned cutout pieces and gap diagnostics.")
func _weight_piece() -> void:
	var adapter := _model.active_adapter(); var pieces: Array = adapter.get("pieces", []) if not adapter.is_empty() else []
	if pieces.is_empty(): _status.text = "Prepare a rig before creating a weighted mesh."; return
	_status_from(_model.create_weighted_mesh(str((pieces[0] as Dictionary).get("piece_id", ""))), "Created a weighted mesh with named nearest-bone initialization.")
func _add_cage() -> void:
	var meshes: Array = _model.profile.get("weighted_meshes", []); if meshes.is_empty(): _status.text = "Create a weighted mesh before adding a cage."; return
	var mesh: Dictionary = meshes[0]; var cage := CageScript.create([[0, 0], [64, 0], [64, 64], [0, 64]], {"vertices": [[0, 0], [64, 0], [68, 64], [0, 64]]})
	_status_from(_model.set_cage(str(mesh.get("mesh_id", "")), cage), "Added an ordered mean-value cage; radial pins remain a separate control.")
func _preview_pose() -> void:
	var result := _model.preview(); _status_from(result, "Previewed the evaluated rigid/weighted cutout pose.")
	if bool(result.get("success", false)) and result.get("image", null) is Image: _preview.texture = ImageTexture.create_from_image(result.image)
func _save() -> void:
	var saved := _model.save(); _status_from(saved, "Saved LPC rig, cutout, weight, and direction state.")
	if bool(saved.get("success", false)): profile_saved.emit(_model.profile.duplicate(true), _model.manifest.duplicate(true), _model.project_path)
func _selected_direction() -> String: return _directions.get_item_text(_directions.selected) if _directions != null and _directions.selected >= 0 else "down"
func _status_from(result: Dictionary, success: String) -> void: _status.text = success if bool(result.get("success", false)) else str(result.get("errors", ["LPC rig operation failed."])[0])
func _on_changed(_description: String) -> void: _preview_pose()
