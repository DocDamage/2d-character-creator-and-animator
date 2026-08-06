# GodotRuntimeMapper -- Normalizes authoring data into portable Godot runtime mapping sections.
class_name GodotRuntimeMapper
extends RefCounted


static func build(content: Dictionary) -> Dictionary:
	var clips: Dictionary = content.get("clips", content.get("animations", {})) as Dictionary
	var states: Dictionary = (content.get("state_machine", {}) as Dictionary).get("states", {}) as Dictionary
	var animation_library: Dictionary = {}
	for clip_id in clips:
		var clip: Dictionary = clips[clip_id] as Dictionary
		animation_library[clip_id] = {"length": float(clip.get("duration", clip.get("length", 0.0))), "loop": bool(clip.get("loop", true)), "tracks": (clip.get("tracks", []) as Array).duplicate(true)}
	for state_id in states:
		var clip_id := str((states[state_id] as Dictionary).get("clip_id", ""))
		if not clip_id.is_empty() and not animation_library.has(clip_id): animation_library[clip_id] = {"length": 0.0, "loop": true, "tracks": []}
	return {
		"animation_library": animation_library,
		"animation_tree": (content.get("state_machine", {}) as Dictionary).duplicate(true),
		"meshes": (content.get("meshes", []) as Array).duplicate(true),
		"sprites": (content.get("sprites", []) as Array).duplicate(true),
		"markers": (content.get("markers", content.get("action_points", [])) as Array).duplicate(true),
		"collision_shapes": (content.get("collision_shapes", content.get("collisions", [])) as Array).duplicate(true),
		"weapons": (content.get("weapons", []) as Array).duplicate(true),
		"appearance": (content.get("appearance", {}) as Dictionary).duplicate(true),
		"baked_fallback": (content.get("baked_fallback", {}) as Dictionary).duplicate(true),
	}


static func validate(mapping: Dictionary) -> Array:
	var errors: Array = []
	for required in ["animation_library", "animation_tree", "meshes", "sprites", "markers", "collision_shapes", "weapons", "appearance", "baked_fallback"]:
		if not mapping.has(required): errors.append("missing Godot runtime mapping: " + required)
	return errors
