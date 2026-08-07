# ProductionProjectData -- Canonical, authored-only extension data for delivery workflows.
class_name ProductionProjectData
extends RefCounted

const SCHEMA_VERSION := "1.0.0"


static func defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"motion_library": {
			"motions": {}, "retarget_presets": {}, "layer_sets": {}, "time_warps": {},
		},
		"secondary_motion": {
			"chains": {}, "weapon_trails": {}, "impact_frames": {}, "event_effects": {},
		},
		"runtime": {
			"active_profile_id": "godot", "profiles": _default_profiles(),
			"state_machine": {}, "rule_graph": {}, "equipment": {},
		},
		"pipeline": {"watch_folders": [], "template_id": "blank", "asset_packs": []},
		"presentation": {"expressions": {}, "pose_boards": {}, "turntables": {}, "approval": {}},
		"collaboration": {"milestone_notes": {}},
	}


static func normalize(value: Variant) -> Dictionary:
	var result := defaults()
	if value is Dictionary:
		_merge(result, value as Dictionary)
	result["schema_version"] = SCHEMA_VERSION
	return result


static func merge(base: Variant, overlay: Variant) -> Dictionary:
	var result := normalize(base)
	if overlay is Dictionary: _merge(result, overlay as Dictionary)
	result["schema_version"] = SCHEMA_VERSION
	return result


static func from_manifest(manifest: Dictionary) -> Dictionary:
	return normalize((manifest.get("metadata", {}) as Dictionary).get("production_suite", {}))


static func apply_to_manifest(manifest: Dictionary, value: Dictionary) -> Dictionary:
	var result := manifest.duplicate(true)
	var metadata: Dictionary = (result.get("metadata", {}) as Dictionary).duplicate(true)
	metadata["production_suite"] = normalize(value)
	result["metadata"] = metadata
	return result


static func validate(value: Dictionary, available_clip_ids: Array = [], available_bone_ids: Array = []) -> Array:
	var errors: Array = []
	var data := normalize(value)
	var motions: Dictionary = data.get("motion_library", {}).get("motions", {})
	for motion_id in motions:
		var motion: Dictionary = motions[motion_id] as Dictionary
		var clip_id := str(motion.get("source_clip_id", ""))
		if str(motion_id).is_empty() or clip_id.is_empty():
			errors.append("motion library entries require an ID and source clip")
		elif not available_clip_ids.is_empty() and clip_id not in available_clip_ids:
			errors.append("motion '%s' references missing clip '%s'" % [motion_id, clip_id])
	for chain_id in (data.get("secondary_motion", {}).get("chains", {}) as Dictionary):
		var chain: Dictionary = data["secondary_motion"]["chains"][chain_id] as Dictionary
		var bones: Array = chain.get("bone_ids", []) as Array
		if bones.is_empty():
			errors.append("secondary-motion chain '%s' needs at least one bone" % chain_id)
		for bone_id in bones:
			if not available_bone_ids.is_empty() and str(bone_id) not in available_bone_ids:
				errors.append("secondary-motion chain '%s' references missing bone '%s'" % [chain_id, bone_id])
	for trail_id in (data.get("secondary_motion", {}).get("weapon_trails", {}) as Dictionary):
		var trail: Dictionary = data["secondary_motion"]["weapon_trails"][trail_id] as Dictionary
		if str(trail.get("action_point_id", "")).is_empty(): errors.append("weapon trail '%s' needs an action point" % trail_id)
	for impact_id in (data.get("secondary_motion", {}).get("impact_frames", {}) as Dictionary):
		var impact: Dictionary = data["secondary_motion"]["impact_frames"][impact_id] as Dictionary
		var impact_clip_id := str(impact.get("clip_id", ""))
		if impact_clip_id.is_empty(): errors.append("impact frame '%s' needs a clip" % impact_id)
		elif not available_clip_ids.is_empty() and impact_clip_id not in available_clip_ids: errors.append("impact frame '%s' references missing clip '%s'" % [impact_id, impact_clip_id])
	for effect_id in (data.get("secondary_motion", {}).get("event_effects", {}) as Dictionary):
		var effect: Dictionary = data["secondary_motion"]["event_effects"][effect_id] as Dictionary
		if str(effect.get("event_name", "")).is_empty(): errors.append("event effect '%s' needs an event name" % effect_id)
	for preset_id in (data.get("motion_library", {}).get("retarget_presets", {}) as Dictionary):
		var preset: Dictionary = data["motion_library"]["retarget_presets"][preset_id] as Dictionary
		if str(preset.get("source_profile_id", "")).is_empty() or str(preset.get("target_profile_id", "")).is_empty():
			errors.append("retarget preset '%s' needs source and target profiles" % preset_id)
	for layer_set_id in (data.get("motion_library", {}).get("layer_sets", {}) as Dictionary):
		var layer_set: Dictionary = data["motion_library"]["layer_sets"][layer_set_id] as Dictionary
		for raw_layer in layer_set.get("layers", []) as Array:
			var layer: Dictionary = raw_layer as Dictionary
			var layer_clip_id := str(layer.get("clip_id", ""))
			if layer_clip_id.is_empty(): errors.append("blend layer in '%s' needs a clip" % layer_set_id)
			elif not available_clip_ids.is_empty() and layer_clip_id not in available_clip_ids: errors.append("blend layer in '%s' references missing clip '%s'" % [layer_set_id, layer_clip_id])
	return errors


static func section(value: Dictionary, section_id: String) -> Dictionary:
	return (normalize(value).get(section_id, {}) as Dictionary).duplicate(true)


static func set_section(value: Dictionary, section_id: String, section_value: Dictionary) -> Dictionary:
	var result := normalize(value)
	result[section_id] = section_value.duplicate(true)
	return result


static func _default_profiles() -> Dictionary:
	return {
		"godot": {"profile_id": "godot", "engine": "godot", "display_name": "Godot Runtime", "include_sample_controller": true},
		"unity": {"profile_id": "unity", "engine": "unity", "display_name": "Unity Runtime", "include_sample_controller": true},
		"unreal": {"profile_id": "unreal", "engine": "unreal", "display_name": "Unreal Runtime", "include_sample_controller": true},
	}


static func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		var next: Variant = source[key]
		if next is Dictionary and target.get(key) is Dictionary:
			var nested: Dictionary = target[key]
			_merge(nested, next as Dictionary)
			target[key] = nested
		else:
			target[key] = next.duplicate(true) if next is Dictionary or next is Array else next
