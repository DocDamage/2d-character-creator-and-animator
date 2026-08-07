# End-to-end coverage for the Authoring Completion milestone.  This uses real
# imported pixels and audio written into user:// test folders; it never creates
# or depends on generated character art.
extends Node

const FactoryScript = preload("res://character/authoring/character_project_factory.gd")
const SessionScript = preload("res://character/authoring/character_project_session.gd")
const EvaluatorScript = preload("res://animation/preview/animation_preview_evaluator.gd")
const PreviewControllerScript = preload("res://animation/preview/animation_preview_controller.gd")
const LayerPreviewScript = preload("res://character/authoring/character_layer_preview.gd")
const ReviewExporterScript = preload("res://export/review/review_package_exporter.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")
const WorkflowWizardScript = preload("res://app/bootstrap/project_workflow_wizard.gd")
const SnapshotServiceScript = preload("res://core/documents/project_snapshot_service.gd")


func run_tests() -> Dictionary:
	var root: String = "user://authoring_completion_tests/" + IDService.generate_short("completion")
	var project_path: String = root.path_join("artist_project.chrproj")
	var session = SessionScript.new()
	var errors: Array = []
	var setup: Dictionary = _create_import_project(root, project_path, session)
	if not bool(setup.get("success", false)):
		errors.append("Could not prepare authoring-completion test project: " + str(setup.get("errors", [])))
		_cleanup(root)
		return {"passed": 0, "failed": 1, "errors": errors}
	var body_b: String = str(setup.get("body_b", ""))
	var asset_a: String = str(setup.get("asset_a", ""))
	var audio_asset: String = str(setup.get("audio_asset", ""))

	var snapshot_ok := _test_snapshots(session, body_b)
	var appearance_ok := _test_appearances(session)
	var animation: Dictionary = _test_preview_and_animation(session, body_b, asset_a, audio_asset)
	var preview_ok: bool = bool(animation.get("success", false))
	var validation_ok := _test_validation_and_repair(session, str(animation.get("clip_id", "")))
	var review_ok := _test_review_packages(session, root)
	var wizard_ok := _test_workflow_metadata(session)

	if is_instance_valid(session): session.free()
	_cleanup(root)
	var checks := {
		"portable snapshots": snapshot_ok,
		"appearance sets": appearance_ok,
		"live preview and animation editing": preview_ok,
		"validation and auto repair": validation_ok,
		"review packages": review_ok,
		"guided workflow persistence": wizard_ok,
	}
	if _all_true(checks):
		print("  PASS: Authoring completion snapshots, appearances, live preview, readiness repair, workflow, and review packages")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Authoring completion checks failed: " + str(checks)]}


func _create_import_project(root: String, project_path: String, session) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
		return {"success": false, "errors": ["Could not create test folder."]}
	var first_png: String = root.path_join("body_red.png")
	var second_png: String = root.path_join("body_blue.png")
	var head_png: String = root.path_join("head_green.png")
	var wav_path: String = root.path_join("idle_cue.wav")
	if not _write_pixel_png(first_png, Color(0.95, 0.2, 0.2, 1.0)) or not _write_pixel_png(second_png, Color(0.2, 0.45, 1.0, 1.0)) or not _write_pixel_png(head_png, Color(0.2, 0.9, 0.4, 1.0)) or not _write_silent_wav(wav_path):
		return {"success": false, "errors": ["Could not write imported-art fixtures."]}
	if not SerializationService.save_project(FactoryScript.create_manifest("Artist Review", "blank"), project_path):
		return {"success": false, "errors": ["Could not save fixture project."]}
	var opened: Dictionary = session.open_project(project_path)
	if not bool(opened.get("success", false)):
		return opened
	session.set_canvas_settings(32, 32, 1.0)
	var first: Dictionary = session.import_part(first_png, "body", "Body Red")
	var second: Dictionary = session.import_part(second_png, "body", "Body Blue")
	var head: Dictionary = session.import_part(head_png, "head", "Head Green")
	var audio: Dictionary = session.import_audio_asset(wav_path, "Idle Cue")
	return {"success": bool(first.get("success", false)) and bool(second.get("success", false)) and bool(head.get("success", false)) and bool(audio.get("success", false)), "body_a": str(first.get("part_id", "")), "body_b": str(second.get("part_id", "")), "asset_a": str(first.get("asset_id", "")), "audio_asset": str(audio.get("asset_id", "")), "errors": first.get("errors", []) + second.get("errors", []) + head.get("errors", []) + audio.get("errors", [])}


func _test_snapshots(session, body_id: String) -> bool:
	CommandService.clear_history()
	var created: Dictionary = session.create_project_snapshot("Before rig rewrite", "Portable milestone before a transform edit.")
	if not bool(created.get("success", false)): return false
	var snapshot_id: String = str(created.get("id", ""))
	var loaded_snapshot: Dictionary = SerializationService.load_project(str(created.get("project_path", "")))
	var snapshot_assets: Dictionary = loaded_snapshot.get("objects", {}).get("assets", {}) as Dictionary
	var snapshot_asset_path: String = str((snapshot_assets.values()[0] as Dictionary).get("path", "")) if not snapshot_assets.is_empty() else ""
	var live_asset_path: String = str((session.asset_registry.list_assets()[0] as Dictionary).get("path", ""))
	var standalone_copy: bool = not snapshot_asset_path.is_empty() and FileAccess.file_exists(snapshot_asset_path) and snapshot_asset_path != live_asset_path
	var changed: bool = session.model.set_layer_position(body_id, Vector2(27.0, -9.0))
	var restored: Dictionary = session.restore_project_snapshot(snapshot_id)
	var state: Dictionary = session.model.get_layer_state(body_id)
	var asset_paths: Array = []
	for asset in session.asset_registry.list_assets():
		asset_paths.append(str((asset as Dictionary).get("path", "")))
	var portable_asset: bool = not asset_paths.is_empty() and FileAccess.file_exists(str(asset_paths[0])) and str(asset_paths[0]).contains("restored_")
	var snapshots: Array = session.list_project_snapshots()
	var has_pre_restore := false
	for raw_snapshot in snapshots:
		if str((raw_snapshot as Dictionary).get("kind", "")) == "before_restore": has_pre_restore = true
	var deleted: Dictionary = session.delete_project_snapshot(snapshot_id)
	var read_only_rejected: bool = not bool(SnapshotServiceScript.new().create("res://samples/read_only.chrproj", {"project_name": "Sample"}, "Nope").get("success", true))
	var ok: bool = standalone_copy and changed and bool(restored.get("success", false)) and (state.get("position", []) as Array) == [0.0, 0.0] and portable_asset and has_pre_restore and bool(deleted.get("success", false)) and read_only_rejected
	if not ok: print("  INFO snapshot debug: ", [created, changed, restored, state, asset_paths, has_pre_restore, deleted])
	return ok


func _test_appearances(session) -> bool:
	# save_outfit is a legacy API; reading Appearance Sets must migrate it
	# without changing its imported-part references.
	var saved_legacy: bool = session.model.save_outfit("legacy_outfit")
	var migrated: Array = session.get_appearance_sets()
	var created: Dictionary = session.create_appearance_set("Knight")
	var duplicate: Dictionary = session.duplicate_appearance_set(str(created.get("appearance_id", "")), "Mage")
	var renamed: bool = session.rename_appearance_set(str(duplicate.get("appearance_id", "")), "Mage Blue")
	var asset_count_before: int = session.asset_registry.list_assets().size()
	var generated_confirmation: Dictionary = session.generate_appearance_sets(65, "Variation", false)
	var generated: Dictionary = session.generate_appearance_sets(2, "Variation", true)
	var asset_count_after: int = session.asset_registry.list_assets().size()
	var applied: Dictionary = session.apply_appearance_set(str(created.get("appearance_id", "")))
	var deleted: bool = session.delete_appearance_set(str(duplicate.get("appearance_id", "")))
	var all_sets: Array = session.get_appearance_sets()
	var import_only := true
	for raw_set in all_sets:
		var appearance: Dictionary = raw_set
		if not (appearance.get("equipped_by_slot", {}) is Dictionary) or not (appearance.get("palette_values", {}) is Dictionary): import_only = false
	return saved_legacy and not migrated.is_empty() and bool(created.get("success", false)) and bool(duplicate.get("success", false)) and renamed and bool(generated_confirmation.get("requires_confirmation", false)) and int(generated.get("generated", 0)) > 0 and bool(generated.get("import_only", false)) and asset_count_before == asset_count_after and bool(applied.get("success", false)) and deleted and import_only


func _test_preview_and_animation(session, body_id: String, swap_asset_id: String, audio_asset_id: String) -> Dictionary:
	var clip_created: Dictionary = session.create_animation_clip("Idle")
	if not bool(clip_created.get("success", false)): return {"success": false}
	var clip_id: String = str(clip_created.get("clip_id", ""))
	session.update_animation_clip(clip_id, {"duration": 1.0, "fps": 4.0, "loop_mode": 1}, "Configured Idle")
	var position_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".position", "Body Position", TrackDefinitionScript.TrackType.TRANSFORM_POSITION)
	var rotation_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".rotation_degrees", "Body Rotation", TrackDefinitionScript.TrackType.TRANSFORM_ROTATION)
	var scale_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".scale", "Body Scale", TrackDefinitionScript.TrackType.TRANSFORM_SCALE)
	var visibility_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".visible", "Body Visibility", TrackDefinitionScript.TrackType.VISIBILITY)
	var opacity_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".opacity", "Body Opacity", TrackDefinitionScript.TrackType.ATTRIBUTE)
	var attribute_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".attribute.material.tint_mode", "Body Material Attribute", TrackDefinitionScript.TrackType.ATTRIBUTE)
	var swap_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".image_swap", "Body Swap", TrackDefinitionScript.TrackType.IMAGE_SWAP)
	var z_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".z_order", "Body Order", TrackDefinitionScript.TrackType.Z_ORDER)
	var action_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".action_point", "Grip", TrackDefinitionScript.TrackType.ACTION_POINT)
	var hit_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".hitbox", "Hit", TrackDefinitionScript.TrackType.HITBOX)
	var hurt_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".hurtbox", "Hurt", TrackDefinitionScript.TrackType.HURTBOX)
	var event_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".event", "Footstep", TrackDefinitionScript.TrackType.EVENT)
	var audio_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".audio", "Cue", TrackDefinitionScript.TrackType.AUDIO_CUE)
	var viseme_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".viseme", "Mouth", TrackDefinitionScript.TrackType.VISEME)
	var parameter_track: Dictionary = session.add_animation_track(clip_id, body_id, "layer:" + body_id + ".script_parameter.recoil", "Recoil", TrackDefinitionScript.TrackType.SCRIPT_PARAMETER)
	var tracks_ok := bool(position_track.get("success", false)) and bool(rotation_track.get("success", false)) and bool(scale_track.get("success", false)) and bool(visibility_track.get("success", false)) and bool(opacity_track.get("success", false)) and bool(attribute_track.get("success", false)) and bool(swap_track.get("success", false)) and bool(z_track.get("success", false)) and bool(action_track.get("success", false)) and bool(hit_track.get("success", false)) and bool(hurt_track.get("success", false)) and bool(event_track.get("success", false)) and bool(audio_track.get("success", false)) and bool(viseme_track.get("success", false)) and bool(parameter_track.get("success", false))
	if not tracks_ok: return {"success": false, "clip_id": clip_id}
	var pos_id: String = str(position_track.get("track_id", ""))
	var first_key: Dictionary = session.add_animation_key(clip_id, pos_id, 0.0, [0.0, 0.0])
	var second_key: Dictionary = session.add_animation_key(clip_id, pos_id, 1.0, [12.0, 20.0])
	session.set_animation_key_interpolation(clip_id, pos_id, str(first_key.get("key_id", "")), TrackDefinitionScript.Interpolation.BEZIER, [0.2, 0.0], [-0.2, 0.0])
	session.add_animation_key(clip_id, str(rotation_track.get("track_id", "")), 0.0, 18.0)
	session.add_animation_key(clip_id, str(scale_track.get("track_id", "")), 0.0, [1.2, 0.8])
	session.add_animation_key(clip_id, str(visibility_track.get("track_id", "")), 0.0, true)
	session.add_animation_key(clip_id, str(opacity_track.get("track_id", "")), 0.0, 0.65)
	session.add_animation_key(clip_id, str(attribute_track.get("track_id", "")), 0.0, "flat")
	session.add_animation_key(clip_id, str(swap_track.get("track_id", "")), 0.0, swap_asset_id)
	session.add_animation_key(clip_id, str(z_track.get("track_id", "")), 0.0, 8)
	session.add_animation_key(clip_id, str(action_track.get("track_id", "")), 0.0, {"action_point_id": "grip", "display_name": "Grip", "local_position": [3.0, 4.0], "local_rotation": 0.2})
	var shape := {"shape_id": "hit_1", "display_name": "Hit", "shape_type": 0, "local_position": [2.0, 0.0], "size": [8.0, 6.0], "radius": 3.0, "enabled": true}
	session.add_animation_key(clip_id, str(hit_track.get("track_id", "")), 0.0, [shape])
	shape["shape_id"] = "hurt_1"
	shape["display_name"] = "Hurt"
	session.add_animation_key(clip_id, str(hurt_track.get("track_id", "")), 0.0, [shape])
	session.add_animation_key(clip_id, str(event_track.get("track_id", "")), 0.5, {"event_id": "step", "event_name": "Step", "event_type": "notify", "payload": {"foot": "left"}})
	session.add_animation_key(clip_id, str(audio_track.get("track_id", "")), 0.5, {"cue_id": "cue", "audio_asset_id": audio_asset_id, "volume_db": -3.0, "pan": 0.25})
	session.add_animation_key(clip_id, str(viseme_track.get("track_id", "")), 0.0, {"viseme_id": "AA", "mouth_attachment_id": body_id, "asset_id": swap_asset_id})
	session.add_animation_key(clip_id, str(parameter_track.get("track_id", "")), 0.0, 0.75)
	var evaluator = EvaluatorScript.new()
	var rest_before: Dictionary = session.model.get_layer_state(body_id)
	var frame: Dictionary = evaluator.evaluate(session, session.get_animation_clip(clip_id), 0.75, 0.25, true)
	var layer_state: Dictionary = {}
	for raw_layer in frame.get("layers", []):
		if str((raw_layer as Dictionary).get("part_id", "")) == body_id: layer_state = (raw_layer as Dictionary).get("state", {}) as Dictionary
	var rest_unchanged: bool = rest_before == session.model.get_layer_state(body_id)
	var overlay_preview = LayerPreviewScript.new()
	overlay_preview.size = Vector2(400.0, 400.0)
	add_child(overlay_preview)
	overlay_preview.set_canvas_settings(session.get_canvas_settings())
	overlay_preview.set_layers(frame.get("layers", []))
	overlay_preview.set_gameplay_overlays(frame.get("action_points", []), frame.get("hitboxes", []), frame.get("hurtboxes", []))
	var action_point: Dictionary = frame.get("action_points", [])[0] as Dictionary
	var action_center: Vector2 = overlay_preview.call("_overlay_center", action_point, overlay_preview.call("_get_canvas_rect"), overlay_preview.call("_get_view_scale")) as Vector2
	var overlay_pick: Dictionary = overlay_preview.call("_pick_gameplay_overlay", action_center) as Dictionary
	var overlay_pick_ok: bool = str(overlay_pick.get("kind", "")) == "action_point" and str(overlay_pick.get("overlay_id", "")) == "grip"
	overlay_preview.free()
	var evaluated_ok := not layer_state.is_empty() and float((layer_state.get("position", [0.0, 0.0]) as Array)[0]) > 0.0 and is_equal_approx(float(layer_state.get("rotation_degrees", 0.0)), 18.0) and is_equal_approx(float((layer_state.get("scale", [0.0, 0.0]) as Array)[0]), 1.2) and bool(layer_state.get("visible", false)) and is_equal_approx(float(layer_state.get("opacity", 0.0)), 0.65) and str((layer_state.get("attributes", {}) as Dictionary).get("material.tint_mode", "")) == "flat" and str((frame.get("image_swaps", {}) as Dictionary).get(body_id, "")) == swap_asset_id and int((frame.get("z_order", {}) as Dictionary).get(body_id, -1)) == 8 and (frame.get("action_points", []) as Array).size() == 1 and (frame.get("hitboxes", []) as Array).size() == 1 and (frame.get("hurtboxes", []) as Array).size() == 1 and overlay_pick_ok and (frame.get("viseme_state", []) as Array).size() == 1 and str(((frame.get("viseme_state", [])[0] as Dictionary).get("resolved_asset_id", ""))) == swap_asset_id and (frame.get("events", []) as Array).size() == 1 and (frame.get("audio_cues", []) as Array).size() == 1 and bool(((frame.get("audio_cues", [])[0] as Dictionary).get("resolvable", false))) and not (frame.get("script_parameters", {}) as Dictionary).is_empty() and (frame.get("preview_log", []) as Array).size() >= 2 and rest_unchanged
	var persisted_key: Dictionary = session.get_animation_track(clip_id, pos_id).get("keys", [])[0] as Dictionary
	var bezier_ok: bool = int(persisted_key.get("interpolation", -1)) == TrackDefinitionScript.Interpolation.BEZIER and (persisted_key.get("out_handle", []) as Array).size() == 2
	var controller = PreviewControllerScript.new()
	add_child(controller)
	controller.bind_session(session)
	controller.set_clip(clip_id)
	controller.set_time(0.25)
	controller.set_auto_key(true)
	var rest_rotation: float = float(session.model.get_layer_state(body_id).get("rotation_degrees", 0.0))
	var auto_key: Dictionary = controller.apply_property_edit(body_id, "layer:" + body_id + ".rotation_degrees", 31.0, Callable(session.model, "set_layer_rotation").bind(body_id, 31.0), TrackDefinitionScript.TrackType.TRANSFORM_ROTATION)
	var keyed: Dictionary = controller.get_keyed_state(body_id, "layer:" + body_id + ".rotation_degrees", 0.25)
	controller.free()
	CommandService.clear_history()
	var batch: Dictionary = session.edit_animation_keys_batch(clip_id, [{"track_id": pos_id, "key_id": str(first_key.get("key_id", "")), "time": 0.05}, {"track_id": pos_id, "key_id": str(second_key.get("key_id", "")), "time": 0.95}], "Moved Selected Keyframes")
	var batch_ok: bool = int(batch.get("changed", 0)) == 2 and CommandService.get_undo_count() == 1 and CommandService.get_undo_description() == "Moved Selected Keyframes" and CommandService.undo()
	var marker: Dictionary = session.add_animation_marker(clip_id, "Contact", 0.2)
	var region: Dictionary = session.add_animation_region(clip_id, "Loop", 0.2, 0.8)
	var marker_ok: bool = bool(marker.get("success", false)) and session.update_animation_marker(clip_id, str(marker.get("marker_id", "")), {"name": "Contact Updated", "time": 0.25})
	var region_ok: bool = bool(region.get("success", false)) and session.update_animation_region(clip_id, str(region.get("region_id", "")), {"name": "Loop Updated", "start_time": 0.2, "end_time": 0.75}) and session.set_animation_loop_region(clip_id, str(region.get("region_id", "")))
	var annotated_clip: Dictionary = session.get_animation_clip(clip_id)
	var annotations_ok: bool = marker_ok and region_ok and (annotated_clip.get("markers", []) as Array).size() == 1 and (annotated_clip.get("regions", []) as Array).size() == 1 and bool(annotated_clip.get("loop_region_enabled", false))
	session.add_animation_key(clip_id, str(event_track.get("track_id", "")), 0.22, {"event_id": "loop_step", "event_name": "Loop Step", "event_type": "notify"})
	var loop_frame: Dictionary = evaluator.evaluate(session, session.get_animation_clip(clip_id), 0.25, 0.75, true)
	var loop_events: Array = loop_frame.get("events", []) as Array
	var loop_event_ok: bool = loop_events.size() == 1 and str((loop_events[0] as Dictionary).get("event_id", "")) == "loop_step"
	var ok: bool = evaluated_ok and bezier_ok and bool(auto_key.get("success", false)) and bool(keyed.get("keyed", false)) and is_equal_approx(float(session.model.get_layer_state(body_id).get("rotation_degrees", 0.0)), rest_rotation) and batch_ok and annotations_ok and loop_event_ok
	if not ok: print("  INFO preview debug: ", [evaluated_ok, bezier_ok, auto_key, keyed, session.model.get_layer_state(body_id), rest_rotation, batch, CommandService.get_undo_count(), CommandService.get_undo_description(), frame])
	return {"success": ok, "clip_id": clip_id}


func _test_validation_and_repair(session, clip_id: String) -> bool:
	var clean_report: Dictionary = session.get_readiness_report({"require_clips": true})
	var orphan: Dictionary = session.add_animation_track(clip_id, "missing_bone", "bone:missing_bone.position", "Missing Target", TrackDefinitionScript.TrackType.TRANSFORM_POSITION)
	if not bool(orphan.get("success", false)): return false
	session.add_animation_key(clip_id, str(orphan.get("track_id", "")), 0.0, [0.0, 0.0])
	var blocked: Dictionary = session.get_readiness_report({"require_clips": true})
	var repaired: Dictionary = session.auto_repair_all()
	var after: Dictionary = session.get_readiness_report({"require_clips": true})
	var muted_track: Dictionary = session.get_animation_track(clip_id, str(orphan.get("track_id", "")))
	return bool(clean_report.get("can_export", false)) and not bool(blocked.get("can_export", true)) and bool(repaired.get("success", false)) and (repaired.get("snapshot", {}) as Dictionary).has("id") and bool(muted_track.get("muted", false)) and bool(muted_track.get("orphaned_preserved", false)) and bool(after.get("can_export", false))


func _test_review_packages(session, root: String) -> bool:
	var exporter = ReviewExporterScript.new()
	var output: String = root.path_join("review_complete")
	var report: Dictionary = exporter.export_package(session, output, {"include_mp4": false, "warnings_confirmed": true, "background": "transparent"})
	var first_item: Dictionary = (report.get("items", [])[0] as Dictionary) if not (report.get("items", []) as Array).is_empty() else {}
	var gif_bytes := FileAccess.get_file_as_bytes(str(first_item.get("gif", "")))
	var complete_ok: bool = bool(report.get("success", false)) and FileAccess.file_exists(output.path_join("review_manifest.json")) and FileAccess.file_exists(str(report.get("zip", ""))) and FileAccess.file_exists(str(first_item.get("contact_sheet", ""))) and gif_bytes.size() >= 6 and gif_bytes.slice(0, 6).get_string_from_ascii() == "GIF89a"
	var cancelled_output: String = root.path_join("review_cancelled")
	var cancelled: Dictionary = exporter.export_package(session, cancelled_output, {"include_mp4": false, "warnings_confirmed": true, "cancel_callable": Callable(self, "_cancel_always")})
	var cancelled_ok: bool = bool(cancelled.get("cancelled", false)) and FileAccess.file_exists(cancelled_output.path_join("incomplete_manifest.json")) and not FileAccess.file_exists(cancelled_output.get_base_dir().path_join(cancelled_output.get_file() + ".zip"))
	return complete_ok and cancelled_ok


func _test_workflow_metadata(session) -> bool:
	var before: Dictionary = session.get_workflow_state()
	var changed: bool = session.set_workflow_state({"current_step": 4, "deferred": true}, "Saved Guided Setup Progress")
	var after: Dictionary = session.get_workflow_state()
	var wizard = WorkflowWizardScript.new()
	add_child(wizard)
	wizard.bind_session(session)
	var import_ready: bool = bool(wizard.call("_step_is_complete", 1))
	var layer_review_ready: bool = bool(wizard.call("_step_is_complete", 2))
	var rig_blocked: bool = not bool(wizard.call("_step_is_complete", 3))
	var idle_ready: bool = bool(wizard.call("_step_is_complete", 4))
	wizard.free()
	return bool(before.get("new_project", false)) and not bool(before.get("completed", true)) and changed and int(after.get("current_step", -1)) == 4 and bool(after.get("deferred", false)) and import_ready and layer_review_ready and rig_blocked and idle_ready


func _write_pixel_png(path: String, color: Color) -> bool:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	image.fill_rect(Rect2i(1, 1, 6, 6), color)
	return image.save_png(path) == OK


func _write_silent_wav(path: String) -> bool:
	var data := PackedByteArray()
	data.resize(46)
	for index in range(data.size()): data[index] = 0
	for index in range(4): data[index] = "RIFF".to_ascii_buffer()[index]
	_put_u32(data, 4, 38)
	for index in range(4): data[8 + index] = "WAVE".to_ascii_buffer()[index]
	for index in range(4): data[12 + index] = "fmt ".to_ascii_buffer()[index]
	_put_u32(data, 16, 16)
	_put_u16(data, 20, 1)
	_put_u16(data, 22, 1)
	_put_u32(data, 24, 8000)
	_put_u32(data, 28, 16000)
	_put_u16(data, 32, 2)
	_put_u16(data, 34, 16)
	for index in range(4): data[36 + index] = "data".to_ascii_buffer()[index]
	_put_u32(data, 40, 2)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(data)
	file.close()
	return true


func _put_u16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = value & 0xFF
	data[offset + 1] = (value >> 8) & 0xFF


func _put_u32(data: PackedByteArray, offset: int, value: int) -> void:
	for index in range(4): data[offset + index] = (value >> (index * 8)) & 0xFF


func _cancel_always() -> bool:
	return true


func _all_true(checks: Dictionary) -> bool:
	for key in checks:
		if not bool(checks[key]): return false
	return true


func _cleanup(root: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(absolute): _delete_tree(absolute)


func _delete_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir(): _delete_tree(child)
			else: DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
