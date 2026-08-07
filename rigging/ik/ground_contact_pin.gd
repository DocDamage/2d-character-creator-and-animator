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

	# Contacts are authored in canvas/world coordinates.  Converting that target
	# back through the parent avoids feet snapping to the wrong place whenever a
	# character root is translated, rotated, or scaled.
	var manager := BoneManager.new()
	manager.initialize(p_rig)
	var current_position := manager.get_global_transform(owner_bone_id).origin
	manager.set_global_position(owner_bone_id, current_position.lerp(pinned_position, clampf(influence, 0.0, 1.0)))
