# ProjectReadinessValidator -- One source of truth for guided setup and export.
#
# The validator is intentionally conservative: an error means we cannot make a
# trustworthy package from imported artwork, while a warning keeps data intact
# and asks the artist to acknowledge the trade-off.
class_name ProjectReadinessValidator
extends RefCounted

const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")
const TrackFactoryScript = preload("res://animation/tracks/track_factory.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const ProjectScaleAdvisorScript = preload("res://quality/performance/project_scale_advisor.gd")


func validate(session, options: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	if session == null or not is_instance_valid(session) or session.model == null:
		errors.append(_issue("no_project", "error", "Open a character project before validating.", "project"))
		return _report(errors, warnings)
	_validate_slots_and_artwork(session, errors)
	_validate_rigs(session, errors)
	_validate_clips(session, errors, warnings)
	_validate_assets(session, warnings)
	_validate_metadata(session, warnings)
	if bool(options.get("require_clips", false)) and session.get_animation_clips().is_empty():
		errors.append(_issue("no_clips", "error", "Create at least one animation clip before exporting a review package.", "animation"))
	if bool(options.get("check_mp4", true)) and not _is_ffmpeg_available():
		warnings.append(_issue("ffmpeg_unavailable", "warning", "MP4 tooling is unavailable; the package will include GIFs, contact sheets, metadata, and ZIP only.", "export"))
	return _report(errors, warnings)


func auto_repair_all(session) -> Dictionary:
	if session == null or not is_instance_valid(session) or session.model == null:
		return {"success": false, "errors": ["Open a character project before repairing it."]}
	if session.is_read_only():
		return {"success": false, "errors": ["Bundled samples are read-only. Use Save As before Auto Repair All."]}
	var snapshot_report: Dictionary = session.create_project_snapshot("Before Auto Repair", "Automatic recovery point before deterministic repairs.")
	if not snapshot_report.get("success", false): return snapshot_report
	var before: Dictionary = session.call("_capture_document_snapshot")
	var repaired: Array = []
	var muted: Array = []
	_relink_registered_assets(session, repaired)
	_assign_unique_required_slots(session, repaired)
	_repair_resolvable_track_ids(session, repaired)
	_mute_orphaned_tracks(session, muted)
	if not repaired.is_empty() or not muted.is_empty():
		session.call("_commit_document_edit", before, "Auto Repaired Project")
	var report := validate(session)
	var next_issue: Dictionary = {}
	if not (report.get("errors", []) as Array).is_empty(): next_issue = report.errors[0]
	elif not (report.get("warnings", []) as Array).is_empty(): next_issue = report.warnings[0]
	return {"success": true, "errors": [], "snapshot": snapshot_report.get("snapshot", {}), "repaired": repaired, "muted_orphaned_tracks": muted, "report": report, "next_issue": next_issue}


func _validate_slots_and_artwork(session, errors: Array) -> void:
	var assembly = session.model.assembly
	for slot in session.get_slots():
		var selected: Array = assembly.equipped_by_slot.get(slot.slot_id, [])
		if bool(slot.required) and selected.is_empty():
			errors.append(_issue("required_slot:" + str(slot.slot_id), "error", "Required slot '%s' has no imported artwork assigned." % str(slot.display_name), "slot", {"slot_id": slot.slot_id, "auto_repairable": true}))
		for raw_part_id in selected:
			var part = session.part_registry.get_part(str(raw_part_id))
			if part == null:
				errors.append(_issue("missing_part:" + str(raw_part_id), "error", "An assigned layer no longer exists in the imported-part registry.", "layer", {"part_id": str(raw_part_id)}))
				continue
			var asset: Dictionary = session.asset_registry.get_asset(part.asset_id)
			var path := str(asset.get("path", ""))
			if path.is_empty() or not FileAccess.file_exists(path):
				errors.append(_issue("missing_art:" + part.part_id, "error", "Imported artwork for '%s' is missing." % part.display_name, "layer", {"part_id": part.part_id, "asset_id": part.asset_id, "auto_repairable": true}))


func _validate_rigs(session, errors: Array) -> void:
	for raw_rig in session.get_rigs():
		var rig: Dictionary = raw_rig
		for problem in RigSchemaScript.validate_rig(rig):
			errors.append(_issue("invalid_rig:" + str(rig.get("id", "")), "error", str(problem), "rig", {"rig_id": str(rig.get("id", ""))}))
		var bones: Dictionary = rig.get("bones", {})
		for bone_id in bones:
			var bone: Dictionary = bones[bone_id]
			var parent_id := str(bone.get("parent_id", ""))
			if not parent_id.is_empty() and not bones.has(parent_id):
				errors.append(_issue("invalid_bone_link:" + str(bone_id), "error", "Bone '%s' links to a missing parent bone." % str(bone.get("name", bone_id)), "bone", {"bone_id": bone_id}))


func _validate_clips(session, errors: Array, warnings: Array) -> void:
	for raw_clip in session.get_animation_clips():
		var clip: Dictionary = raw_clip
		var clip_id := str(clip.get("clip_id", ""))
		var duration := maxf(0.01, float(clip.get("duration", 1.0)))
		for raw_track in clip.get("tracks", []):
			var track: Dictionary = raw_track
			var track_id := str(track.get("track_id", ""))
			var muted := bool(track.get("muted", false))
			var target_valid := _track_target_exists(session, track)
			if not target_valid:
				var target_issue := _issue("orphaned_track:" + track_id, "warning" if muted else "error", "%s track '%s' targets an object that no longer exists." % ["Muted" if muted else "Active", str(track.get("display_name", track_id))], "track", {"clip_id": clip_id, "track_id": track_id, "auto_repairable": not muted})
				if muted: warnings.append(target_issue)
				else: errors.append(target_issue)
			var restored_track = TrackFactoryScript.from_dict(track)
			for problem in restored_track.validate():
				errors.append(_issue("invalid_track:" + track_id, "error", str(problem), "track", {"clip_id": clip_id, "track_id": track_id}))
			for raw_key in track.get("keys", []):
				var key: Dictionary = raw_key
				var key_time := float(key.get("time", -1.0))
				if key_time < 0.0 or key_time > duration + 0.0001:
					errors.append(_issue("invalid_key_time:" + str(key.get("key_id", "")), "error", "A keyframe in '%s' lies outside its clip duration." % str(track.get("display_name", track_id)), "key", {"clip_id": clip_id, "track_id": track_id, "key_id": str(key.get("key_id", ""))}))
				_validate_track_payload(session, track, key, errors)
			if bool(track.get("muted", false)):
				warnings.append(_issue("muted_track:" + track_id, "warning", "Muted track '%s' is preserved and will not play or export." % str(track.get("display_name", track_id)), "track", {"clip_id": clip_id, "track_id": track_id}))
		if bool(clip.get("has_unkeyed_edits", false)):
			warnings.append(_issue("unkeyed_edits:" + clip_id, "warning", "This animation has edits marked as unkeyed at the current playhead.", "animation", {"clip_id": clip_id}))


func _validate_track_payload(session, track: Dictionary, key: Dictionary, errors: Array) -> void:
	var kind := int(track.get("track_type", TrackDefinition.TrackType.ATTRIBUTE))
	var value: Variant = key.get("value", null)
	var track_id := str(track.get("track_id", ""))
	if kind == TrackDefinition.TrackType.IMAGE_SWAP:
		var asset_id: String = str((value as Dictionary).get("asset_id", "")) if value is Dictionary else str(value)
		if asset_id.is_empty() or not _valid_asset(session, asset_id):
			errors.append(_issue("invalid_image_swap:" + track_id, "error", "Image-swap key references artwork that is not registered or is missing.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", ""))}))
	elif kind == TrackDefinition.TrackType.VISIBILITY and not (value is bool):
		errors.append(_issue("invalid_visibility:" + track_id, "error", "Visibility keys must contain true or false.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", ""))}))
	elif kind == TrackDefinition.TrackType.Z_ORDER and not (value is int or value is float):
		errors.append(_issue("invalid_z_order:" + track_id, "error", "Z-order keys must contain a number.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", ""))}))
	elif kind == TrackDefinition.TrackType.TRANSFORM_ROTATION and not (value is int or value is float):
		errors.append(_issue("invalid_rotation:" + track_id, "error", "Rotation keys must contain a numeric angle.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", ""))}))
	elif kind == TrackDefinition.TrackType.TRANSFORM_POSITION or kind == TrackDefinition.TrackType.TRANSFORM_SCALE:
		if not _is_vector2_value(value):
			errors.append(_issue("invalid_transform:" + track_id, "error", "Position and scale keys require two numeric values.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", ""))}))
	elif kind == TrackDefinition.TrackType.AUDIO_CUE:
		if not (value is Dictionary):
			errors.append(_issue("invalid_audio_cue:" + track_id, "error", "Audio cue keys require imported audio metadata.", "key", {"track_id": track_id}))
		else:
			var audio_asset_id := str((value as Dictionary).get("audio_asset_id", ""))
			var asset: Dictionary = session.asset_registry.get_asset(audio_asset_id)
			if audio_asset_id.is_empty() or asset.is_empty() or str(asset.get("category", "")) != "audio" or not _valid_asset(session, audio_asset_id):
				errors.append(_issue("missing_audio_cue:" + track_id, "error", "Audio cue references unresolved imported audio.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", "")), "asset_id": audio_asset_id, "auto_repairable": true}))
	elif kind == TrackDefinition.TrackType.VISEME:
		if not (value is Dictionary) or str((value as Dictionary).get("viseme_id", "")).is_empty():
			errors.append(_issue("invalid_viseme:" + track_id, "error", "Viseme keys require a viseme identifier.", "key", {"track_id": track_id}))
		else:
			var viseme_asset_id := str((value as Dictionary).get("asset_id", (value as Dictionary).get("image_asset_id", (value as Dictionary).get("mouth_asset_id", ""))))
			if not viseme_asset_id.is_empty() and not _valid_asset(session, viseme_asset_id):
				errors.append(_issue("invalid_viseme_asset:" + track_id, "error", "Viseme keys with artwork overrides must reference imported artwork that is available.", "key", {"track_id": track_id, "key_id": str(key.get("key_id", "")), "asset_id": viseme_asset_id, "auto_repairable": true}))
	elif kind == TrackDefinition.TrackType.EVENT:
		if not (value is Dictionary) or str((value as Dictionary).get("event_name", "")).is_empty():
			errors.append(_issue("invalid_event:" + track_id, "error", "Event keys require a display name.", "key", {"track_id": track_id}))


func _validate_assets(session, warnings: Array) -> void:
	var report: Dictionary = session.get_asset_health_report()
	if int(report.get("duplicate_groups", 0)) > 0:
		warnings.append(_issue("duplicate_assets", "warning", "%d duplicate imported-asset group%s detected." % [int(report.get("duplicate_groups", 0)), "s" if int(report.get("duplicate_groups", 0)) != 1 else ""], "assets"))
	if int(report.get("unused_count", 0)) > 0:
		warnings.append(_issue("unused_assets", "warning", "%d imported asset%s are currently unused." % [int(report.get("unused_count", 0)), "s" if int(report.get("unused_count", 0)) != 1 else ""], "assets"))
	var preflight: Dictionary = report.get("preflight", {}) as Dictionary
	var preflight_errors: Array = preflight.get("errors", []) as Array
	var preflight_warnings: Array = preflight.get("warnings", []) as Array
	if not preflight_errors.is_empty() or not preflight_warnings.is_empty():
		# Missing referenced art and audio remain blocking errors above.  Other
		# import-audit findings are preserved as warnings so unused source files
		# never stop a legitimate export.
		warnings.append(_issue("import_preflight", "warning", "Import audit found %d issue%s. Review artwork size, transparency, provenance, and changed-on-disk files before handoff." % [preflight_errors.size() + preflight_warnings.size(), "s" if preflight_errors.size() + preflight_warnings.size() != 1 else ""], "assets", {"error_count": preflight_errors.size(), "warning_count": preflight_warnings.size()}))
	var scale: Dictionary = session.get_project_scale_report()
	for raw_issue in scale.get("issues", []):
		var scale_issue: Dictionary = raw_issue
		warnings.append(_issue("scale_" + str(scale_issue.get("id", "advisory")), "warning", str(scale_issue.get("message", "Project scale needs review.")), "performance", {"scale_context": scale_issue}))


func _validate_metadata(session, warnings: Array) -> void:
	var authoring: Dictionary = session.manifest.get("metadata", {}).get("character_authoring", {})
	if (authoring.get("canvas", {}) as Dictionary).is_empty():
		warnings.append(_issue("optional_canvas_metadata", "warning", "Canvas metadata is incomplete; a default canvas will be used.", "project"))


func _track_target_exists(session, track: Dictionary) -> bool:
	var object_id := str(track.get("object_id", ""))
	if object_id in ["project", "character", "events", "audio", "metadata", ""]:
		return not object_id.is_empty()
	if session.part_registry.get_part(object_id) != null: return true
	for rig in session.get_rigs():
		if (rig.get("bones", {}) as Dictionary).has(object_id): return true
	return false


func _valid_asset(session, asset_id: String) -> bool:
	var asset: Dictionary = session.asset_registry.get_asset(asset_id)
	var path := str(asset.get("path", ""))
	return not asset.is_empty() and not path.is_empty() and FileAccess.file_exists(path)


func _relink_registered_assets(session, repaired: Array) -> void:
	var assets: Array = session.asset_registry.list_assets()
	for missing in assets:
		var missing_path := str((missing as Dictionary).get("path", ""))
		if not missing_path.is_empty() and FileAccess.file_exists(missing_path): continue
		var candidates: Array = []
		for candidate in assets:
			var data: Dictionary = candidate
			if str(data.get("asset_id", "")) == str((missing as Dictionary).get("asset_id", "")): continue
			if not FileAccess.file_exists(str(data.get("path", ""))): continue
			var same_checksum: bool = not str((missing as Dictionary).get("checksum", "")).is_empty() and str(data.get("checksum", "")) == str((missing as Dictionary).get("checksum", ""))
			var candidate_path: String = str(data.get("path", ""))
			var same_name: bool = candidate_path.get_file().to_lower() == missing_path.get_file().to_lower()
			if same_checksum or same_name: candidates.append(data)
		if candidates.size() == 1:
			session.asset_registry.update_asset(str((missing as Dictionary).get("asset_id", "")), {"path": str((candidates[0] as Dictionary).get("path", ""))})
			repaired.append({"kind": "asset_relink", "asset_id": str((missing as Dictionary).get("asset_id", "")), "path": str((candidates[0] as Dictionary).get("path", ""))})


func _assign_unique_required_slots(session, repaired: Array) -> void:
	for slot in session.get_slots():
		if not bool(slot.required): continue
		if not (session.model.assembly.equipped_by_slot.get(slot.slot_id, []) as Array).is_empty(): continue
		var candidates: Array = session.part_registry.list_parts({"slot_id": str(slot.slot_id), "body_type_id": session.model.assembly.body_type_id})
		if candidates.size() == 1:
			var candidate = candidates[0]
			if session.model.assembly.equip_part(candidate.part_id).get("success", false):
				repaired.append({"kind": "required_slot_assignment", "slot_id": slot.slot_id, "part_id": candidate.part_id})


func _repair_resolvable_track_ids(session, repaired: Array) -> void:
	var store: Dictionary = session.manifest.get("objects", {}).get("animations", {})
	for clip_id in store:
		var clip: Dictionary = store[clip_id]
		var tracks: Array = clip.get("tracks", []).duplicate(true)
		var changed := false
		for index in range(tracks.size()):
			var track: Dictionary = tracks[index]
			if not str(track.get("object_id", "")).is_empty(): continue
			var path := str(track.get("property_path", ""))
			var recovered := ""
			if path.begins_with("layer:"): recovered = path.trim_prefix("layer:").get_slice(".", 0)
			elif path.begins_with("bone:"): recovered = path.trim_prefix("bone:").get_slice(".", 0)
			if recovered.is_empty(): continue
			var candidate_track: Dictionary = track.duplicate(true)
			candidate_track["object_id"] = recovered
			if not _track_target_exists(session, candidate_track): continue
			track = candidate_track
			tracks[index] = track
			changed = true
			repaired.append({"kind": "track_target_relink", "track_id": str(track.get("track_id", "")), "object_id": recovered})
		if changed:
			clip["tracks"] = tracks
			store[clip_id] = clip
	session.manifest.objects["animations"] = store


func _mute_orphaned_tracks(session, muted: Array) -> void:
	var store: Dictionary = session.manifest.get("objects", {}).get("animations", {})
	for clip_id in store:
		var clip: Dictionary = store[clip_id]
		var tracks: Array = clip.get("tracks", []).duplicate(true)
		var changed := false
		for index in range(tracks.size()):
			var track: Dictionary = tracks[index]
			if bool(track.get("muted", false)) or _track_target_exists(session, track): continue
			track["muted"] = true
			track["orphaned_preserved"] = true
			tracks[index] = track
			changed = true
			muted.append({"clip_id": str(clip_id), "track_id": str(track.get("track_id", ""))})
		if changed:
			clip["tracks"] = tracks
			store[clip_id] = clip
	session.manifest.objects["animations"] = store


func _is_ffmpeg_available() -> bool:
	var exporter = preload("res://export/video/video_exporter.gd").new()
	return exporter.is_available()


func _is_vector2_value(value: Variant) -> bool:
	if value is Vector2: return true
	if not (value is Array) or (value as Array).size() < 2: return false
	return ((value as Array)[0] is int or (value as Array)[0] is float) and ((value as Array)[1] is int or (value as Array)[1] is float)


func _issue(id: String, severity: String, message: String, target: String, context: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "severity": severity, "message": message, "target": target}
	for key in context: result[key] = context[key]
	return result


func _report(errors: Array, warnings: Array) -> Dictionary:
	return {"success": errors.is_empty(), "can_export": errors.is_empty(), "errors": errors, "warnings": warnings, "issue_count": errors.size() + warnings.size(), "requires_warning_confirmation": errors.is_empty() and not warnings.is_empty()}
