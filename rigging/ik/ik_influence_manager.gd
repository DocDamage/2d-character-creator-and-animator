# IKInfluenceManager — Controls FK/IK blending and smooth pose transitions
class_name IKInfluenceManager
extends RefCounted


static func blend_poses(p_fk_pose: Dictionary, p_ik_pose: Dictionary, p_influence: float) -> Dictionary:
	var blended := p_fk_pose.duplicate(true)
	var weight := clampf(p_influence, 0.0, 1.0)

	for b_id in p_fk_pose:
		if not p_ik_pose.has(b_id):
			continue
		var fk: Dictionary = p_fk_pose[b_id]
		var ik: Dictionary = p_ik_pose[b_id]
		var result: Dictionary = fk.duplicate(true)
		_blend_vector_channel(result, fk, ik, "position", weight, Vector2.ZERO)
		_blend_vector_channel(result, fk, ik, "local_position", weight, Vector2.ZERO)
		_blend_rotation_channel(result, fk, ik, "rotation", weight)
		_blend_rotation_channel(result, fk, ik, "local_rotation", weight)
		_blend_vector_channel(result, fk, ik, "scale", weight, Vector2.ONE)
		_blend_vector_channel(result, fk, ik, "local_scale", weight, Vector2.ONE)
		if is_equal_approx(weight, 1.0):
			for key in ik:
				if not result.has(key): result[key] = ik[key]
		blended[b_id] = result

	# IK pose data may include helper bones that are absent from the captured FK
	# pose.  Keeping them prevents partial rigs from losing a driven attachment.
	for b_id in p_ik_pose:
		if not blended.has(b_id) and weight > 0.0: blended[b_id] = (p_ik_pose[b_id] as Dictionary).duplicate(true)
	return blended


static func _blend_vector_channel(result: Dictionary, fk: Dictionary, ik: Dictionary, key: String, weight: float, fallback: Vector2) -> void:
	if not fk.has(key) or not ik.has(key): return
	result[key] = _vector(fk[key], fallback).lerp(_vector(ik[key], fallback), weight)


static func _blend_rotation_channel(result: Dictionary, fk: Dictionary, ik: Dictionary, key: String, weight: float) -> void:
	if not fk.has(key) or not ik.has(key): return
	result[key] = lerp_angle(float(fk[key]), float(ik[key]), weight)


static func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback
