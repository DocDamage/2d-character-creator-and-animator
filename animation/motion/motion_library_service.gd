# MotionLibraryService -- Reusable clips, retarget presets, time-warps, and layer-set workflows.
class_name MotionLibraryService
extends RefCounted

const ProductionDataScript = preload("res://production/production_project_data.gd")
const BlendStackScript = preload("res://animation/blending/animation_blend_stack.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")


static func browse(manifest: Dictionary, production: Dictionary, query: String = "", tag: String = "") -> Array:
	var motions: Dictionary = ProductionDataScript.section(production, "motion_library").get("motions", {}) as Dictionary
	var clips: Dictionary = manifest.get("objects", {}).get("animations", {}) as Dictionary
	var result: Array = []
	for motion_id in motions:
		var motion: Dictionary = (motions[motion_id] as Dictionary).duplicate(true)
		var source_id := str(motion.get("source_clip_id", ""))
		motion["motion_id"] = motion_id
		motion["source_available"] = clips.has(source_id)
		motion["duration"] = float((clips.get(source_id, {}) as Dictionary).get("duration", motion.get("duration", 0.0)))
		var haystack := (str(motion.get("display_name", "")) + " " + source_id + " " + " ".join(_strings(motion.get("tags", [])))).to_lower()
		if not query.strip_edges().is_empty() and not haystack.contains(query.to_lower()): continue
		if not tag.strip_edges().is_empty() and tag not in _strings(motion.get("tags", [])): continue
		result.append(motion)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("display_name", a.get("motion_id", ""))) < str(b.get("display_name", b.get("motion_id", ""))))
	return result


static func add_motion(production: Dictionary, motion_id: String, source_clip_id: String, display_name: String = "", tags: Array = [], options: Dictionary = {}) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var library: Dictionary = data["motion_library"].duplicate(true)
	var motions: Dictionary = library.get("motions", {}).duplicate(true)
	var clean_id := motion_id.strip_edges().to_snake_case()
	if clean_id.is_empty() or source_clip_id.strip_edges().is_empty(): return {"success": false, "errors": ["A motion ID and source clip are required."]}
	if motions.has(clean_id): return {"success": false, "errors": ["A motion with that ID already exists."]}
	motions[clean_id] = {"motion_id": clean_id, "source_clip_id": source_clip_id.strip_edges(), "display_name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else clean_id.capitalize(), "tags": _strings(tags), "trim_start": maxf(0.0, float(options.get("trim_start", 0.0))), "trim_end": maxf(0.0, float(options.get("trim_end", 0.0))), "default_speed": maxf(0.01, float(options.get("default_speed", 1.0))), "time_warp_id": str(options.get("time_warp_id", "")), "retarget_preset_id": str(options.get("retarget_preset_id", ""))}
	library["motions"] = motions
	data["motion_library"] = library
	return {"success": true, "data": data, "motion": motions[clean_id]}


static func add_retarget_preset(production: Dictionary, preset_id: String, source_profile_id: String, target_profile_id: String, bone_map: Dictionary, options: Dictionary = {}) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var library: Dictionary = data["motion_library"].duplicate(true)
	var presets: Dictionary = library.get("retarget_presets", {}).duplicate(true)
	var clean_id := preset_id.strip_edges().to_snake_case()
	if clean_id.is_empty() or source_profile_id.strip_edges().is_empty() or target_profile_id.strip_edges().is_empty(): return {"success": false, "errors": ["Preset, source profile, and target profile are required."]}
	if presets.has(clean_id): return {"success": false, "errors": ["A retarget preset with that ID already exists."]}
	presets[clean_id] = {"preset_id": clean_id, "display_name": str(options.get("display_name", clean_id.capitalize())), "source_profile_id": source_profile_id.strip_edges(), "target_profile_id": target_profile_id.strip_edges(), "bone_map": bone_map.duplicate(true), "proportion_scale": maxf(0.01, float(options.get("proportion_scale", 1.0))), "corrections": (options.get("corrections", {}) as Dictionary).duplicate(true), "include_unmapped_tracks": bool(options.get("include_unmapped_tracks", true))}
	library["retarget_presets"] = presets
	data["motion_library"] = library
	return {"success": true, "data": data, "preset": presets[clean_id]}


static func set_time_warp(production: Dictionary, warp_id: String, points: Array) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var library: Dictionary = data["motion_library"].duplicate(true)
	var clean_id := warp_id.strip_edges().to_snake_case()
	var normalized := _warp_points(points)
	if clean_id.is_empty() or normalized.size() < 2: return {"success": false, "errors": ["A time-warp needs an ID and at least two points."]}
	var warps: Dictionary = library.get("time_warps", {}).duplicate(true)
	warps[clean_id] = {"warp_id": clean_id, "points": normalized}
	library["time_warps"] = warps
	data["motion_library"] = library
	return {"success": true, "data": data, "warp": warps[clean_id]}


static func add_layer_set(production: Dictionary, layer_set_id: String, layers: Array) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var library: Dictionary = data["motion_library"].duplicate(true)
	var clean_id := layer_set_id.strip_edges().to_snake_case()
	if clean_id.is_empty(): return {"success": false, "errors": ["A layer-set ID is required."]}
	var stack = BlendStackScript.new(clean_id)
	for raw_layer in layers:
		var layer: Dictionary = raw_layer as Dictionary
		if not stack.add_layer(str(layer.get("layer_id", "")), str(layer.get("clip_id", "")), str(layer.get("mode", "override")), float(layer.get("weight", 1.0)), layer.get("bone_mask", []) as Array, str(layer.get("sync_group", "")), bool(layer.get("weapon_overlay", false))): return {"success": false, "errors": ["Layer set contains an invalid or duplicate layer."]}
	var layer_sets: Dictionary = library.get("layer_sets", {}).duplicate(true)
	layer_sets[clean_id] = stack.to_dict()
	library["layer_sets"] = layer_sets
	data["motion_library"] = library
	return {"success": true, "data": data, "layer_set": layer_sets[clean_id]}


static func retarget_clip(source_clip: Dictionary, preset: Dictionary, target_clip_id: String = "", target_name: String = "") -> Dictionary:
	if source_clip.is_empty() or preset.is_empty(): return {"success": false, "errors": ["A source clip and retarget preset are required."]}
	var result := source_clip.duplicate(true)
	result["clip_id"] = target_clip_id.strip_edges() if not target_clip_id.strip_edges().is_empty() else str(source_clip.get("clip_id", "")) + "_retargeted"
	result["clip_name"] = target_name.strip_edges() if not target_name.strip_edges().is_empty() else str(source_clip.get("clip_name", "Clip")) + " Retargeted"
	var mapping: Dictionary = preset.get("bone_map", {}) as Dictionary
	var scale := maxf(0.01, float(preset.get("proportion_scale", 1.0)))
	var corrections: Dictionary = preset.get("corrections", {}) as Dictionary
	var tracks: Array = []
	for raw_track in source_clip.get("tracks", []) as Array:
		var track: Dictionary = (raw_track as Dictionary).duplicate(true)
		var source_id := str(track.get("object_id", ""))
		if mapping.has(source_id):
			var target_id := str(mapping[source_id])
			track["object_id"] = target_id
			track["property_path"] = str(track.get("property_path", "")).replace(source_id, target_id)
		elif not bool(preset.get("include_unmapped_tracks", true)):
			continue
		if int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE)) == TrackDefinitionScript.TrackType.TRANSFORM_POSITION:
			track["keys"] = _scaled_keys(track.get("keys", []) as Array, scale, corrections.get(str(track.get("object_id", "")), {}))
		tracks.append(track)
	result["tracks"] = tracks
	result["retarget_preset_id"] = str(preset.get("preset_id", ""))
	return {"success": true, "clip": result}


static func map_time(normalized_time: float, warp: Dictionary) -> float:
	var points: Array = _warp_points(warp.get("points", []) as Array)
	var input := clampf(normalized_time, 0.0, 1.0)
	for index in range(1, points.size()):
		var left: Dictionary = points[index - 1] as Dictionary
		var right: Dictionary = points[index] as Dictionary
		if input <= float(right.get("input", 1.0)):
			return lerpf(float(left.get("output", 0.0)), float(right.get("output", 1.0)), inverse_lerp(float(left.get("input", 0.0)), float(right.get("input", 1.0)), input))
	return 1.0


static func validate(manifest: Dictionary, production: Dictionary) -> Array:
	var clips: Array = (manifest.get("objects", {}).get("animations", {}) as Dictionary).keys()
	return ProductionDataScript.validate(production, clips)


static func _scaled_keys(keys: Array, scale: float, correction: Variant) -> Array:
	var result: Array = []
	var offset := _vector((correction as Dictionary).get("position_offset", [0.0, 0.0])) if correction is Dictionary else Vector2.ZERO
	for raw_key in keys:
		var key: Dictionary = (raw_key as Dictionary).duplicate(true)
		if key.get("value") is Array and (key["value"] as Array).size() >= 2:
			key["value"] = [float(key["value"][0]) * scale + offset.x, float(key["value"][1]) * scale + offset.y]
		result.append(key)
	return result


static func _warp_points(points: Array) -> Array:
	var result: Array = []
	for raw_point in points:
		var point: Dictionary = raw_point as Dictionary
		result.append({"input": clampf(float(point.get("input", point.get("x", 0.0))), 0.0, 1.0), "output": clampf(float(point.get("output", point.get("y", 0.0))), 0.0, 1.0)})
	if result.is_empty() or float((result[0] as Dictionary).get("input", 1.0)) > 0.0: result.append({"input": 0.0, "output": 0.0})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("input", 0.0)) < float(b.get("input", 0.0)))
	if float((result[result.size() - 1] as Dictionary).get("input", 0.0)) < 1.0: result.append({"input": 1.0, "output": 1.0})
	return result


static func _strings(values: Variant) -> Array:
	var result: Array = []
	if values is Array:
		for value in values:
			var clean := str(value).strip_edges()
			if not clean.is_empty() and clean not in result: result.append(clean)
	return result


static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
