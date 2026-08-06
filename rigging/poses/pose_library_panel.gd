# PoseLibraryPanel -- User-facing capture, saved-pose selection, and absolute apply controls.
class_name PoseLibraryPanel
extends VBoxContainer

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")
const PoseLibraryScript = preload("res://rigging/poses/pose_library.gd")
const PoseApplierScript = preload("res://rigging/poses/pose_applier.gd")
const PoseMirrorModelScript = preload("res://rigging/poses/pose_mirror_model.gd")
const PoseBlendModelScript = preload("res://rigging/poses/pose_blend_model.gd")
const PoseThumbnailModelScript = preload("res://rigging/poses/pose_thumbnail_model.gd")
const PoseSketchAssistModelScript = preload("res://rigging/poses/pose_sketch_assist_model.gd")

signal pose_saved(pose_id: String)
signal pose_applied(pose_id: String)

@onready var pose_id_input: LineEdit = %PoseIdInput
@onready var display_name_input: LineEdit = %DisplayNameInput
@onready var pose_mode: OptionButton = %PoseMode
@onready var pose_list: OptionButton = %PoseList
@onready var mirror_pairs_input: LineEdit = %MirrorPairsInput
@onready var blend_target_list: OptionButton = %BlendTargetList
@onready var blend_weight: HSlider = %BlendWeight
@onready var blend_weight_label: Label = %BlendWeightLabel
@onready var thumbnail_preview: TextureRect = %ThumbnailPreview
@onready var thumbnail_label: Label = %ThumbnailLabel
@onready var sketch_canvas: Control = %SketchCanvas
@onready var suggest_sketch_button: Button = %SuggestSketchButton
@onready var clear_sketch_button: Button = %ClearSketchButton
@onready var capture_button: Button = %CaptureButton
@onready var apply_button: Button = %ApplyButton
@onready var mirror_button: Button = %MirrorButton
@onready var save_blend_button: Button = %SaveBlendButton
@onready var preview_blend_button: Button = %PreviewBlendButton
@onready var status_label: Label = %PoseStatusLabel

var _library = PoseLibraryScript.new()
var _rig: Dictionary = {}


func _ready() -> void:
	if pose_mode.item_count == 0:
		pose_mode.add_item("Absolute")
		pose_mode.add_item("Additive offsets")
	if not capture_button.pressed.is_connected(capture_current_pose):
		capture_button.pressed.connect(capture_current_pose)
	if not apply_button.pressed.is_connected(apply_selected_pose):
		apply_button.pressed.connect(apply_selected_pose)
	if not mirror_button.pressed.is_connected(mirror_selected_pose):
		mirror_button.pressed.connect(mirror_selected_pose)
	if not save_blend_button.pressed.is_connected(save_selected_blend):
		save_blend_button.pressed.connect(save_selected_blend)
	if not preview_blend_button.pressed.is_connected(preview_selected_blend):
		preview_blend_button.pressed.connect(preview_selected_blend)
	if not blend_weight.value_changed.is_connected(_on_blend_weight_changed):
		blend_weight.value_changed.connect(_on_blend_weight_changed)
	if not pose_list.item_selected.is_connected(_on_pose_selected):
		pose_list.item_selected.connect(_on_pose_selected)
	if not suggest_sketch_button.pressed.is_connected(suggest_from_sketch):
		suggest_sketch_button.pressed.connect(suggest_from_sketch)
	if not clear_sketch_button.pressed.is_connected(_clear_sketch):
		clear_sketch_button.pressed.connect(_clear_sketch)
	_refresh()


func bind_rig(rig: Dictionary) -> void:
	_rig = rig
	_refresh("Rig '%s' ready." % str(_rig.get("name", _rig.get("id", "unnamed"))) if not _rig.is_empty() else "Bind a rig to capture or apply poses.")


func get_pose_library() -> Variant:
	return _library


func get_pose_thumbnail(pose_id: String) -> Dictionary:
	return PoseThumbnailModelScript.render_pose(_library.get_pose(pose_id))


func suggest_from_sketch() -> Dictionary:
	if _rig.is_empty():
		return _result_with_status({"success": false, "message": "Bind a rig before using sketch assistance."})
	var suggestion: Dictionary = PoseSketchAssistModelScript.suggest_pose(pose_id_input.text, display_name_input.text, _rig, sketch_canvas.call("get_points") as Array)
	if not suggestion.get("success", false):
		return _result_with_status(suggestion)
	return save_pose(suggestion.get("pose"))


func save_pose(pose: Variant) -> Dictionary:
	var result: Dictionary = _library.save_pose(pose)
	_refresh("Saved pose '%s'." % str(result.get("pose_id", "")) if result.get("success", false) else _errors_text(result))
	if result.get("success", false):
		pose_saved.emit(str(result.get("pose_id", "")))
		_mark_dirty()
	return result


func capture_current_pose() -> Dictionary:
	if _rig.is_empty():
		return _result_with_status({"success": false, "message": "Bind a rig before capturing a pose."})
	var pose_id := pose_id_input.text.strip_edges()
	var display_name := display_name_input.text.strip_edges()
	var pose := PoseDefinitionScript.new(pose_id, display_name if not display_name.is_empty() else pose_id)
	pose.mode = pose_mode.selected
	var captured: Dictionary = PoseApplierScript.capture_from_rig(pose, _rig)
	if not captured.get("success", false):
		return _result_with_status(captured)
	var saved := save_pose(pose)
	saved["captured_bone_ids"] = captured.get("captured_bone_ids", [])
	return saved


func apply_selected_pose() -> Dictionary:
	if pose_list.selected < 0:
		return _result_with_status({"success": false, "message": "Select a saved pose to apply."})
	return apply_pose(pose_list.get_item_text(pose_list.selected))


func apply_pose(pose_id: String) -> Dictionary:
	if _rig.is_empty():
		return _result_with_status({"success": false, "message": "Bind a rig before applying a pose."})
	var pose = _library.get_pose(pose_id)
	if pose == null:
		return _result_with_status({"success": false, "message": "Saved pose '%s' was not found." % pose_id})
	var result: Dictionary = PoseApplierScript.apply_to_rig(pose, _rig)
	_refresh(str(result.get("message", "Pose application failed.")))
	if result.get("success", false):
		pose_applied.emit(pose_id)
		_mark_dirty()
	return result


func mirror_selected_pose() -> Dictionary:
	if pose_list.selected < 0:
		return _result_with_status({"success": false, "message": "Select a saved pose to mirror."})
	return mirror_pose(pose_list.get_item_text(pose_list.selected), pose_id_input.text, display_name_input.text, mirror_pairs_input.text)


func mirror_pose(source_id: String, target_id: String, target_name: String, pair_text: String) -> Dictionary:
	var source_pose = _library.get_pose(source_id)
	if source_pose == null:
		return _result_with_status({"success": false, "message": "Saved pose '%s' was not found." % source_id})
	var pairs := _parse_bone_pairs(pair_text)
	if pairs.is_empty():
		return _result_with_status({"success": false, "message": "Enter one or more bone pairs as left:right."})
	var mirrored: Dictionary = PoseMirrorModelScript.mirror_pose(source_pose, target_id, target_name, pairs)
	if not mirrored.get("success", false):
		return _result_with_status(mirrored)
	var saved := save_pose(mirrored.get("pose"))
	if saved.get("success", false):
		_select_pose(str(saved.get("pose_id", "")))
	return saved


func save_selected_blend() -> Dictionary:
	if pose_list.selected < 0 or blend_target_list.selected < 0:
		return _result_with_status({"success": false, "message": "Select two saved poses to blend."})
	return blend_poses(pose_list.get_item_text(pose_list.selected), blend_target_list.get_item_text(blend_target_list.selected), pose_id_input.text, display_name_input.text, blend_weight.value)


func preview_selected_blend() -> Dictionary:
	if _rig.is_empty():
		return _result_with_status({"success": false, "message": "Bind a rig before previewing a blend."})
	if pose_list.selected < 0 or blend_target_list.selected < 0:
		return _result_with_status({"success": false, "message": "Select two saved poses to blend."})
	var blended := _make_blend(pose_list.get_item_text(pose_list.selected), blend_target_list.get_item_text(blend_target_list.selected), "__blend_preview__", "Blend Preview", blend_weight.value)
	if not blended.get("success", false):
		return _result_with_status(blended)
	var applied: Dictionary = PoseApplierScript.apply_to_rig(blended.get("pose"), _rig)
	_refresh(str(applied.get("message", "Blend preview failed.")))
	if applied.get("success", false):
		_mark_dirty()
	return applied


func blend_poses(from_id: String, to_id: String, result_id: String, result_name: String, weight: float) -> Dictionary:
	var blended := _make_blend(from_id, to_id, result_id, result_name, weight)
	if not blended.get("success", false):
		return _result_with_status(blended)
	var saved := save_pose(blended.get("pose"))
	if saved.get("success", false):
		_select_pose(str(saved.get("pose_id", "")))
	return saved


func _refresh(message: String = "") -> void:
	if not is_node_ready():
		return
	pose_list.clear()
	blend_target_list.clear()
	for pose_id in _library.get_pose_ids() as Array[String]:
		pose_list.add_item(pose_id)
		blend_target_list.add_item(pose_id)
	var rig_ready := not _rig.is_empty()
	capture_button.disabled = not rig_ready
	apply_button.disabled = not rig_ready or pose_list.item_count == 0
	mirror_button.disabled = pose_list.item_count == 0
	save_blend_button.disabled = pose_list.item_count < 2
	preview_blend_button.disabled = not rig_ready or pose_list.item_count < 2
	suggest_sketch_button.disabled = not rig_ready
	blend_weight_label.text = "Blend weight: %d%%" % roundi(blend_weight.value * 100.0)
	if not message.is_empty():
		status_label.text = message
	elif not rig_ready:
		status_label.text = "Bind a rig to capture or apply poses."
	else:
		status_label.text = "%d saved pose(s) for this rig." % pose_list.item_count
	_update_thumbnail()


func _result_with_status(result: Dictionary) -> Dictionary:
	_refresh(str(result.get("message", _errors_text(result))))
	return result


func _parse_bone_pairs(pair_text: String) -> Dictionary:
	var pairs: Dictionary = {}
	for entry in pair_text.split(";", false):
		var ids := entry.split(":", false)
		if ids.size() != 2:
			return {}
		var left := ids[0].strip_edges()
		var right := ids[1].strip_edges()
		if left.is_empty() or right.is_empty() or left == right or pairs.has(left) or pairs.has(right):
			return {}
		pairs[left] = right
		pairs[right] = left
	return pairs


func _select_pose(pose_id: String) -> void:
	var index := _library.get_pose_ids().find(pose_id)
	if index >= 0:
		pose_list.select(index)
		_update_thumbnail()


func _make_blend(from_id: String, to_id: String, result_id: String, result_name: String, weight: float) -> Dictionary:
	var from_pose = _library.get_pose(from_id)
	var to_pose = _library.get_pose(to_id)
	return PoseBlendModelScript.blend_poses(from_pose, to_pose, result_id, result_name, weight)


func _on_blend_weight_changed(value: float) -> void:
	if is_node_ready():
		blend_weight_label.text = "Blend weight: %d%%" % roundi(value * 100.0)


func _on_pose_selected(_index: int) -> void:
	_update_thumbnail()


func _update_thumbnail() -> void:
	if pose_list.item_count == 0 or pose_list.selected < 0:
		thumbnail_preview.texture = null
		thumbnail_label.text = "Select a saved pose to preview its thumbnail."
		return
	var result := get_pose_thumbnail(pose_list.get_item_text(pose_list.selected))
	thumbnail_preview.texture = result.get("texture", null) as Texture2D
	thumbnail_label.text = str(result.get("message", "Thumbnail unavailable."))


func _clear_sketch() -> void:
	sketch_canvas.call("clear_sketch")


func _errors_text(result: Dictionary) -> String:
	var errors: Array = result.get("errors", []) as Array
	return "; ".join(errors) if not errors.is_empty() else "Pose operation failed."


func _mark_dirty() -> void:
	if AppState != null:
		AppState.mark_dirty()
