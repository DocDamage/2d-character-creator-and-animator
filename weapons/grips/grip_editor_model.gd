# GripEditorModel -- Undo-friendly non-visual model for interactive grip authoring.
class_name GripEditorModel
extends RefCounted

signal grip_changed(grip_id: String)

var weapon = null


func _init(p_weapon = null) -> void:
	weapon = p_weapon


func create_grip(grip_id: String, display_name: String, role: GripDefinition.Role) -> bool:
	if weapon == null:
		return false
	var grip := GripDefinition.new(grip_id, display_name, role)
	var added: bool = weapon.add_grip(grip)
	if added:
		grip_changed.emit(grip_id)
	return added


func set_transform(grip_id: String, position: Vector2, rotation: float) -> bool:
	var grip = _get_grip(grip_id)
	if grip == null:
		return false
	grip.local_position = position
	grip.local_rotation = rotation
	_save_grip(grip)
	return true


func set_hand_binding(grip_id: String, hand_side: String, hand_pose_id: String) -> bool:
	var grip = _get_grip(grip_id)
	if grip == null or hand_side not in ["left", "right", "either"]:
		return false
	grip.hand_side = hand_side
	grip.hand_pose_id = hand_pose_id
	_save_grip(grip)
	return true


func set_body_type_offset(grip_id: String, body_type_id: String, position: Vector2, rotation: float) -> bool:
	var grip = _get_grip(grip_id)
	if grip == null or body_type_id.is_empty():
		return false
	grip.body_type_offsets[body_type_id] = {"position": [position.x, position.y], "rotation": rotation}
	_save_grip(grip)
	return true


func _get_grip(grip_id: String):
	if weapon == null:
		return null
	return weapon.get_grip(grip_id)


func _save_grip(grip) -> void:
	weapon.grips[grip.grip_id] = grip.to_dict()
	grip_changed.emit(grip.grip_id)
