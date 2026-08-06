# IKBaker — Bakes IK solved poses into explicit FK keyframe channels across timelines
class_name IKBaker
extends RefCounted


static func bake_ik_to_fk(p_rig: Dictionary, p_stack: ConstraintStack, p_frame_count: int = 30) -> Array[Dictionary]:
	var baked_frames: Array[Dictionary] = []
	var dt := 1.0 / 30.0
	
	for f in range(p_frame_count):
		p_stack.evaluate_stack(p_rig, dt)
		var frame_snapshot := {}
		var bones: Dictionary = p_rig.get("bones", {})
		for b_id in bones:
			var bone: Dictionary = bones[b_id]
			frame_snapshot[b_id] = {
				"position": bone.get("local_position", Vector2.ZERO),
				"rotation": bone.get("local_rotation", 0.0),
				"scale": bone.get("local_scale", Vector2.ONE)
			}
		baked_frames.append({
			"frame": f,
			"time": f * dt,
			"pose": frame_snapshot
		})
		
	return baked_frames
