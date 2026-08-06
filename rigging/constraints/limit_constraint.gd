# LimitConstraint — Distance limits and angle / rotation clamps
class_name LimitConstraint
extends ConstraintInterface

var min_distance: float = 0.0
var max_distance: float = 200.0
var min_angle: float = -PI
var max_angle: float = PI
var limit_rotation: bool = true
var limit_distance: bool = false


func _init() -> void:
	type = ConstraintType.LIMIT


func evaluate(p_rig: Dictionary, _delta: float) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(owner_bone_id):
		return
		
	var owner_bone: Dictionary = bones[owner_bone_id]
	
	if limit_rotation:
		var rot: float = owner_bone.get("local_rotation", 0.0)
		var clamped_rot := clampf(rot, min_angle, max_angle)
		owner_bone["local_rotation"] = lerp_angle(rot, clamped_rot, influence)
		
	if limit_distance and bones.has(target_bone_id):
		var target_bone: Dictionary = bones[target_bone_id]
		var pos: Vector2 = owner_bone.get("local_position", Vector2.ZERO)
		var target_pos: Vector2 = target_bone.get("local_position", Vector2.ZERO)
		var dist := pos.distance_to(target_pos)
		
		if dist < min_distance or dist > max_distance:
			var clamped_dist := clampf(dist, min_distance, max_distance)
			var dir := (pos - target_pos).normalized()
			var new_pos := target_pos + dir * clamped_dist
			owner_bone["local_position"] = pos.lerp(new_pos, influence)
