# RetargetPreviewPanel -- User-facing bound-context retarget preview action.
class_name RetargetPreviewPanel
extends VBoxContainer

const RetargetPoseTransferScript = preload("res://rigging/retargeting/retarget_pose_transfer.gd")
const PoseApplierScript = preload("res://rigging/poses/pose_applier.gd")
const RetargetBatchProcessorScript = preload("res://rigging/retargeting/retarget_batch_processor.gd")
const DocumentHistoryScript = preload("res://app/commands/document_history.gd")

@onready var preview_button: Button = %PreviewButton
@onready var status_label: Label = %RetargetStatusLabel

var _source_pose: Variant
var _target_profile: Variant
var _target_rig: Dictionary = {}
var _bone_map: Dictionary = {}
var _factors: Dictionary = {}
var _correction_layer: Variant


func _ready() -> void:
	if not preview_button.pressed.is_connected(preview_retarget):
		preview_button.pressed.connect(preview_retarget)
	_refresh()


func bind_context(source_pose: Variant, target_profile: Variant, target_rig: Dictionary, bone_map: Dictionary, factors: Dictionary, correction_layer: Variant = null) -> void:
	_source_pose = source_pose
	_target_profile = target_profile
	_target_rig = target_rig
	_bone_map = bone_map.duplicate(true)
	_factors = factors.duplicate(true)
	_correction_layer = correction_layer
	_refresh("Retarget context bound; preview is ready.")


func preview_retarget() -> Dictionary:
	if _source_pose == null or _target_profile == null or _target_rig.is_empty():
		return _result({"success": false, "message": "Bind source pose, target profile, and target rig before previewing."})
	var transferred: Dictionary = RetargetPoseTransferScript.preview(_source_pose, _target_profile, _bone_map, _factors, "__retarget_preview__", "Retarget Preview")
	if not transferred.get("success", false):
		return _result(transferred)
	if _correction_layer != null:
		var corrected: Dictionary = _correction_layer.apply_to_pose(transferred.get("pose"))
		if not corrected.get("success", false):
			return _result(corrected)
	var before := _capture_document_snapshot()
	var applied: Dictionary = PoseApplierScript.apply_to_rig(transferred.get("pose"), _target_rig)
	applied["unmapped_source_bones"] = transferred.get("unmapped_source_bones", [])
	var result := _result(applied, false)
	if result.get("success", false) and not DocumentHistoryScript.record_applied(self, before, _capture_document_snapshot(), "Previewed Retargeted Pose"):
		_mark_dirty()
	return result


func batch_retarget(source_poses: Array, target_library: Variant, id_prefix: String = "retargeted") -> Dictionary:
	if _target_profile == null:
		return _result({"success": false, "message": "Bind a retarget context before batch processing."})
	var result: Dictionary = RetargetBatchProcessorScript.retarget_to_library(source_poses, _target_profile, _bone_map, _factors, target_library, id_prefix)
	return _result(result)


func _refresh(message: String = "") -> void:
	if not is_node_ready():
		return
	preview_button.disabled = _source_pose == null or _target_profile == null or _target_rig.is_empty()
	status_label.text = message if not message.is_empty() else "Bind retarget context to preview a source pose on the target rig."


func _result(result: Dictionary, mark_dirty: bool = true) -> Dictionary:
	_refresh(str(result.get("message", "Retarget preview failed.")))
	if result.get("success", false) and mark_dirty:
		_mark_dirty()
	return result


func _capture_document_snapshot() -> Dictionary:
	return {"target_rig": _target_rig.duplicate(true)}


func _apply_document_snapshot(snapshot: Dictionary, description: String = "") -> void:
	if snapshot.is_empty():
		return
	_target_rig.clear()
	_target_rig.merge((snapshot.get("target_rig", {}) as Dictionary).duplicate(true), true)
	_refresh(description if not description.is_empty() else "Restored retarget preview state.")


func _mark_dirty() -> void:
	if AppState != null:
		AppState.mark_dirty()
