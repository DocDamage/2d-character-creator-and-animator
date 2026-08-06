# GroundContactPin — Anchors foot / tip bone to ground contact position during poses
class_name GroundContactPin
extends ConstraintInterface

var pinned_position: Vector2 = Vector2.ZERO
var is_pinned: bool = false


func _init() -> void:
	type = ConstraintType.CONTACT_PIN


func pin_at(p_pos: Vector2) -> void:
	pinned_position = p_pos
	is_pinned = true


func unpin() -> void:
	is_pinned = false


func evaluate(p_rig: Dictionary, _delta: float) -> void:
	if not is_pinned or not enabled or influence <= 0.0:
		return
		
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(owner_bone_id):
		return
		
	var bone: Dictionary = bones[owner_bone_id]
	var current_pos: Vector2 = bone.get("local_position", Vector2.ZERO)
	bone["local_position"] = current_pos.lerp(pinned_position, influence)
