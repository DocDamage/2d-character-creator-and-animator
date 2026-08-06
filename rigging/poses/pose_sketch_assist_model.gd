# PoseSketchAssistModel -- Converts a simple gesture into a reviewable absolute-pose suggestion.
class_name PoseSketchAssistModel
extends RefCounted

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")


static func suggest_pose(pose_id: String, display_name: String, rig: Dictionary, sketch_points: Array) -> Dictionary:
	var clean_id := pose_id.strip_edges()
	var bones: Dictionary = rig.get("bones", {})
	if clean_id.is_empty():
		return _failure("A suggested pose ID is required.")
	if bones.is_empty():
		return _failure("Bind a rig with bones before using sketch assistance.")
	if sketch_points.size() < 2:
		return _failure("Draw at least two sketch points before generating a pose.")
	var points: Array[Vector2] = []
	for point in sketch_points:
		if not point is Vector2:
			return _failure("Sketch points must be two-dimensional positions.")
		points.append(point)
	var bone_ids: Array = bones.keys()
	bone_ids.sort()
	var source_bounds := _bounds_from_bones(bones, bone_ids)
	var sketch_bounds := _bounds_from_points(points)
	var pose := PoseDefinitionScript.new(clean_id, display_name.strip_edges() if not display_name.strip_edges().is_empty() else clean_id)
	pose.rig_profile_id = str(rig.get("id", ""))
	pose.tags = ["sketch-suggestion"]
	pose.metadata = {"suggested_from": "sketch", "sketch_point_count": points.size()}
	for index in range(bone_ids.size()):
		var bone_id := str(bone_ids[index])
		var point_index := roundi(float(index) / maxf(float(bone_ids.size() - 1), 1.0) * float(points.size() - 1))
		var bone: Dictionary = bones[bone_id]
		pose.set_bone_transform(bone_id, {
			"position": _map_point(points[point_index], sketch_bounds, source_bounds),
			"rotation": bone.get("local_rotation", 0.0),
			"scale": bone.get("local_scale", Vector2.ONE),
		})
	return {"success": true, "pose": pose, "message": "Generated a %d-bone sketch suggestion for review." % bone_ids.size()}


static func _bounds_from_bones(bones: Dictionary, bone_ids: Array) -> Rect2:
	var points: Array[Vector2] = []
	for bone_id in bone_ids:
		var bone: Dictionary = bones[bone_id]
		var value: Variant = bone.get("local_position", Vector2.ZERO)
		points.append(value if value is Vector2 else Vector2.ZERO)
	return _bounds_from_points(points)


static func _bounds_from_points(points: Array[Vector2]) -> Rect2:
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func _map_point(point: Vector2, source: Rect2, target: Rect2) -> Vector2:
	var ratio_x := (point.x - source.position.x) / maxf(source.size.x, 1.0)
	var ratio_y := (point.y - source.position.y) / maxf(source.size.y, 1.0)
	return target.position + Vector2(ratio_x * maxf(target.size.x, 100.0), ratio_y * maxf(target.size.y, 100.0))


static func _failure(message: String) -> Dictionary:
	return {"success": false, "message": message}
