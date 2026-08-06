# IKInfluenceManager — Controls FK/IK blending and smooth pose transitions
class_name IKInfluenceManager
extends RefCounted


static func blend_poses(p_fk_pose: Dictionary, p_ik_pose: Dictionary, p_influence: float) -> Dictionary:
	var blended := {}
	var weight := clampf(p_influence, 0.0, 1.0)
	
	for b_id in p_fk_pose:
		if not p_ik_pose.has(b_id):
			blended[b_id] = p_fk_pose[b_id]
			continue
			
		var fk: Dictionary = p_fk_pose[b_id]
		var ik: Dictionary = p_ik_pose[b_id]
		
		var fk_pos: Vector2 = fk.get("position", Vector2.ZERO)
		var ik_pos: Vector2 = ik.get("position", Vector2.ZERO)
		var fk_rot: float = fk.get("rotation", 0.0)
		var ik_rot: float = ik.get("rotation", 0.0)
		
		blended[b_id] = {
			"position": fk_pos.lerp(ik_pos, weight),
			"rotation": lerp_angle(fk_rot, ik_rot, weight)
		}
		
	return blended
