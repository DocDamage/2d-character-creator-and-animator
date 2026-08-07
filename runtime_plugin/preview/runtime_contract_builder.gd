# RuntimeContractBuilder -- One deterministic contract shared by preview, QA, and exports.
class_name RuntimeContractBuilder
extends RefCounted

const ProductionDataScript = preload("res://production/production_project_data.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")

const CONTRACT_VERSION := "1.0.0"


static func build(manifest: Dictionary, production_data: Dictionary = {}) -> Dictionary:
	var objects: Dictionary = manifest.get("objects", {}) as Dictionary
	var metadata: Dictionary = manifest.get("metadata", {}) as Dictionary
	var production := ProductionDataScript.merge(metadata.get("production_suite", {}), production_data)
	var clips := _clips(objects.get("animations", {}))
	var rig := _active_rig(objects.get("rigs", {}), metadata)
	var contract := {
		"contract": "modular_character_runtime", "contract_version": CONTRACT_VERSION,
		"project_id": str(manifest.get("project_id", "")), "project_name": str(manifest.get("project_name", "Untitled")),
		"source_schema_version": str(manifest.get("schema_version", "")), "clips": clips,
		"clip_durations": _clip_durations(clips), "runtime_tracks": _runtime_tracks(clips),
		"state_machine": _runtime_section(production, objects, metadata, "state_machine"),
		"rule_graph": _runtime_section(production, objects, metadata, "rule_graph"),
		"rig": rig, "weapons": _records_as_array(objects.get("weapons", {})),
		"facing_grid": _facing_grid(manifest, objects, metadata),
		"appearance": _appearance(objects, metadata), "gameplay": _gameplay(clips),
		"secondary_motion": (production.get("secondary_motion", {}) as Dictionary).duplicate(true),
		"motion_library": (production.get("motion_library", {}) as Dictionary).duplicate(true),
		"runtime_profiles": (production.get("runtime", {}).get("profiles", {}) as Dictionary).duplicate(true),
		"active_profile_id": str(production.get("runtime", {}).get("active_profile_id", "godot")),
		"authored_parameters_only": true,
	}
	contract["content_hash"] = JSON.stringify(contract, "", true, false).sha256_text()
	return contract


static func validate(contract: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	if str(contract.get("contract", "")) != "modular_character_runtime":
		errors.append("unexpected runtime contract")
	if str(contract.get("project_id", "")).is_empty():
		warnings.append("runtime contract has no project ID")
	var clips: Dictionary = contract.get("clips", {}) as Dictionary
	if clips.is_empty(): warnings.append("runtime contract has no animation clips")
	for clip_id in clips:
		var clip: Dictionary = clips[clip_id] as Dictionary
		if float(clip.get("duration", 0.0)) <= 0.0:
			errors.append("clip '%s' needs a positive duration" % clip_id)
		if not clip.get("tracks", []) is Array:
			errors.append("clip '%s' tracks must be an array" % clip_id)
	var machine: Dictionary = contract.get("state_machine", {}) as Dictionary
	if not machine.is_empty():
		var entry := str(machine.get("entry_state_id", ""))
		var states: Dictionary = machine.get("states", {}) as Dictionary
		if entry.is_empty() or not states.has(entry):
			errors.append("state machine entry state is missing")
		for state_id in states:
			var clip_id := str((states[state_id] as Dictionary).get("clip_id", ""))
			if not clip_id.is_empty() and not clips.has(clip_id):
				errors.append("state '%s' references missing clip '%s'" % [state_id, clip_id])
	var bones: Array = (contract.get("rig", {}).get("bones", {}) as Dictionary).keys()
	var production := {"secondary_motion": contract.get("secondary_motion", {}), "motion_library": contract.get("motion_library", {})}
	errors.append_array(ProductionDataScript.validate(production, clips.keys(), bones))
	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings, "summary": _summary(contract)}


static func _clips(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if raw is Dictionary:
		for clip_id in (raw as Dictionary):
			if (raw as Dictionary)[clip_id] is Dictionary:
				var clip: Dictionary = ((raw as Dictionary)[clip_id] as Dictionary).duplicate(true)
				clip["clip_id"] = str(clip.get("clip_id", clip_id))
				result[str(clip_id)] = clip
	return result


static func _clip_durations(clips: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for clip_id in clips: result[clip_id] = maxf(0.001, float((clips[clip_id] as Dictionary).get("duration", 1.0)))
	return result


static func _runtime_tracks(clips: Dictionary) -> Array:
	var result: Array = []
	for clip_id in clips:
		for raw_track in (clips[clip_id] as Dictionary).get("tracks", []) as Array:
			var track: Dictionary = raw_track as Dictionary
			result.append({"clip_id": clip_id, "track_id": str(track.get("track_id", "")), "target": str(track.get("property_path", "")), "track_type": int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE)), "keys": (track.get("keys", []) as Array).duplicate(true)})
	return result


static func _gameplay(clips: Dictionary) -> Dictionary:
	var result := {"events": [], "action_points": [], "hitboxes": [], "hurtboxes": []}
	for clip_id in clips:
		for raw_track in (clips[clip_id] as Dictionary).get("tracks", []) as Array:
			var track: Dictionary = raw_track as Dictionary
			var type := int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE))
			var key := ""
			if type == TrackDefinitionScript.TrackType.EVENT: key = "events"
			elif type == TrackDefinitionScript.TrackType.ACTION_POINT: key = "action_points"
			elif type == TrackDefinitionScript.TrackType.HITBOX: key = "hitboxes"
			elif type == TrackDefinitionScript.TrackType.HURTBOX: key = "hurtboxes"
			if not key.is_empty():
				(result[key] as Array).append({"clip_id": clip_id, "track_id": str(track.get("track_id", "")), "object_id": str(track.get("object_id", "")), "keys": (track.get("keys", []) as Array).duplicate(true)})
	return result


static func _active_rig(raw: Variant, metadata: Dictionary) -> Dictionary:
	if not raw is Dictionary: return {}
	var rigs: Dictionary = raw as Dictionary
	var authoring: Dictionary = metadata.get("character_authoring", {}) as Dictionary
	var preferred := str(authoring.get("active_rig_id", ""))
	if not preferred.is_empty() and rigs.get(preferred) is Dictionary: return (rigs[preferred] as Dictionary).duplicate(true)
	var ids: Array = rigs.keys()
	ids.sort()
	return (rigs[ids[0]] as Dictionary).duplicate(true) if not ids.is_empty() else {}


static func _appearance(objects: Dictionary, metadata: Dictionary) -> Dictionary:
	var characters: Dictionary = objects.get("characters", {}) as Dictionary
	var authoring: Dictionary = metadata.get("character_authoring", {}) as Dictionary
	var character_id := str(authoring.get("active_character_id", ""))
	var character: Dictionary = characters.get(character_id, {}) as Dictionary
	var assembly: Dictionary = character.get("assembly", character) as Dictionary
	return {"character_id": character_id, "equipment": (assembly.get("equipped_parts", assembly.get("equipment", {})) as Dictionary).duplicate(true), "display_name": str(assembly.get("display_name", ""))}


static func _facing_grid(manifest: Dictionary, objects: Dictionary, metadata: Dictionary) -> Dictionary:
	for source in [manifest, objects, metadata]:
		for key in ["facing_grid", "facing_grids"]:
			var value: Variant = (source as Dictionary).get(key, {})
			if value is Dictionary and not (value as Dictionary).is_empty(): return (value as Dictionary).duplicate(true)
	return {}


static func _runtime_section(production: Dictionary, objects: Dictionary, metadata: Dictionary, section_id: String) -> Dictionary:
	var runtime: Dictionary = production.get("runtime", {}) as Dictionary
	var value: Variant = runtime.get(section_id, {})
	if value is Dictionary and not (value as Dictionary).is_empty(): return (value as Dictionary).duplicate(true)
	if objects.get(section_id) is Dictionary: return (objects.get(section_id) as Dictionary).duplicate(true)
	if metadata.get(section_id) is Dictionary: return (metadata.get(section_id) as Dictionary).duplicate(true)
	return {}


static func _records_as_array(value: Variant) -> Array:
	var result: Array = []
	if value is Dictionary:
		var ids: Array = (value as Dictionary).keys()
		ids.sort()
		for record_id in ids:
			if (value as Dictionary)[record_id] is Dictionary:
				var record: Dictionary = ((value as Dictionary)[record_id] as Dictionary).duplicate(true)
				record["weapon_id"] = str(record.get("weapon_id", record_id))
				result.append(record)
	return result


static func _summary(contract: Dictionary) -> Dictionary:
	var gameplay: Dictionary = contract.get("gameplay", {}) as Dictionary
	return {"clips": (contract.get("clips", {}) as Dictionary).size(), "bones": (contract.get("rig", {}).get("bones", {}) as Dictionary).size(), "weapons": (contract.get("weapons", []) as Array).size(), "events": (gameplay.get("events", []) as Array).size(), "hitbox_tracks": (gameplay.get("hitboxes", []) as Array).size(), "action_point_tracks": (gameplay.get("action_points", []) as Array).size()}
