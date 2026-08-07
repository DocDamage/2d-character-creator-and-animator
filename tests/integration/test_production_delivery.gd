# End-to-end coverage for runtime delivery, motion productivity, pipeline, collaboration, QA, and presentation.
extends Node

const ProductionDataScript = preload("res://production/production_project_data.gd")
const MotionServiceScript = preload("res://animation/motion/motion_library_service.gd")
const SecondaryServiceScript = preload("res://animation/secondary/secondary_motion_library.gd")
const ContractBuilderScript = preload("res://runtime_plugin/preview/runtime_contract_builder.gd")
const PreviewScript = preload("res://runtime_plugin/preview/runtime_preview_evaluator.gd")
const EngineExporterScript = preload("res://export/engines/engine_runtime_package_exporter.gd")
const QaScript = preload("res://quality/gameplay/runtime_qa_suite.gd")
const AssetPackScript = preload("res://pipeline/asset_pack_service.gd")
const WatchScript = preload("res://pipeline/watch_folder_service.gd")
const TemplateScript = preload("res://pipeline/project_template_service.gd")
const ChangeScript = preload("res://collaboration/project_change_service.gd")
const PresentationScript = preload("res://presentation/presentation_package_exporter.gd")
const StateMachineScript = preload("res://animation/state_machine/state_machine_definition.gd")
const RuleGraphScript = preload("res://animation/rules/rule_graph.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")


class FakePresentationSession extends Node:
	var project_path := "user://production_delivery_test/demo.chrproj"
	var manifest: Dictionary = {}
	var production: Dictionary = {}
	var layer_path := ""
	func get_manifest_copy() -> Dictionary: return manifest.duplicate(true)
	func get_production_suite_data() -> Dictionary: return production.duplicate(true)
	func get_appearance_sets() -> Array: return [{"appearance_id": "default", "display_name": "Default Outfit"}]
	func get_appearance_preview_layers(_appearance_id: String) -> Array: return get_preview_layers()
	func get_preview_layers() -> Array: return [{"path": layer_path, "visible": true, "state": {"position": [0.0, 0.0], "scale": [1.0, 1.0], "pivot": [0.5, 0.5], "rotation_degrees": 0.0, "tint": [1.0, 1.0, 1.0, 1.0], "opacity": 1.0}}]
	func get_canvas_settings() -> Dictionary: return {"width": 32, "height": 32, "pixel_scale": 1.0}
	func get_animation_clips() -> Array: return (manifest.get("objects", {}).get("animations", {}) as Dictionary).values()


class FakeSnapshotSession extends Node:
	var snapshot_path := ""
	var manifest: Dictionary = {}
	func get_project_snapshot(_snapshot_id: String) -> Dictionary: return {"project_path": snapshot_path}
	func get_manifest_copy() -> Dictionary: return manifest.duplicate(true)


func run_tests() -> Dictionary:
	var root := "user://production_delivery_test"
	_cleanup(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var source_path := root.path_join("source.png")
	var asset_ready := _write_png(source_path, Color("f97316"))
	var manifest := _manifest(source_path)
	var production := ProductionDataScript.defaults()
	var productivity_ok := _productivity(manifest, production)
	production = productivity_ok.get("production", production) as Dictionary
	var runtime_ok := _runtime(manifest, production, root)
	var pipeline_ok := _pipeline(manifest, source_path, root)
	var presentation_ok := _presentation(manifest, production, source_path, root)
	var all_ok := asset_ready and bool(productivity_ok.get("success", false)) and bool(runtime_ok.get("success", false)) and bool(pipeline_ok.get("success", false)) and bool(presentation_ok.get("success", false))
	_cleanup(root)
	if all_ok:
		print("  PASS: Production delivery runtime, motion, secondary, CLI services, diffs, QA, exports, and presentation packages")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Production delivery integration failed: %s" % JSON.stringify({"productivity": productivity_ok, "runtime": runtime_ok, "pipeline": pipeline_ok, "presentation": presentation_ok})]}


func _productivity(manifest: Dictionary, production: Dictionary) -> Dictionary:
	var motion: Dictionary = MotionServiceScript.add_motion(production, "attack_motion", "attack", "Attack", ["combat", "upper_body"])
	if not bool(motion.get("success", false)): return motion
	var retarget: Dictionary = MotionServiceScript.add_retarget_preset(motion["data"], "hero_to_hero", "hero", "hero", {"root": "root", "hand": "hand"})
	if not bool(retarget.get("success", false)): return retarget
	var warp: Dictionary = MotionServiceScript.set_time_warp(retarget["data"], "snappy", [{"input": 0.0, "output": 0.0}, {"input": 0.5, "output": 0.3}, {"input": 1.0, "output": 1.0}])
	var layers: Dictionary = MotionServiceScript.add_layer_set(warp["data"], "attack_overlay", [{"layer_id": "attack_add", "clip_id": "attack", "mode": "additive", "weight": 0.5, "sync_group": "combat"}])
	var spring: Dictionary = SecondaryServiceScript.add_chain(layers["data"], "hair", ["root", "hand"], {"kind": "hair"})
	var trail: Dictionary = SecondaryServiceScript.add_weapon_trail(spring["data"], "sword_trail", "sword", "muzzle", {"event_gate": "swing"})
	var impact: Dictionary = SecondaryServiceScript.add_impact_frame(trail["data"], "swing_impact", "attack", 0.1)
	var effect: Dictionary = SecondaryServiceScript.add_event_effect(impact["data"], "swing_spark", "swing", "muzzle")
	var retargeted: Dictionary = MotionServiceScript.retarget_clip((manifest["objects"]["animations"] as Dictionary)["attack"] as Dictionary, ((effect["data"] as Dictionary)["motion_library"] as Dictionary)["retarget_presets"]["hero_to_hero"] as Dictionary, "attack_retargeted")
	var warped := MotionServiceScript.map_time(0.5, ((effect["data"] as Dictionary)["motion_library"] as Dictionary)["time_warps"]["snappy"] as Dictionary)
	var data: Dictionary = effect.get("data", {}) as Dictionary
	data["presentation"]["expressions"]["focused"] = {"expression_id": "focused", "display_name": "Focused", "viseme": "A"}
	data["presentation"]["pose_boards"]["combat"] = {"board_id": "combat", "display_name": "Combat Board", "pose_ids": ["attack"]}
	return {"success": bool(effect.get("success", false)) and bool(retargeted.get("success", false)) and absf(warped - 0.3) < 0.001, "production": data}


func _runtime(manifest: Dictionary, production: Dictionary, root: String) -> Dictionary:
	var contract := ContractBuilderScript.build(manifest, production)
	var validation: Dictionary = ContractBuilderScript.validate(contract)
	var preview = PreviewScript.new()
	preview.load_contract(contract)
	var frame: Dictionary = preview.tick(0.2)
	var forced_frame: Dictionary = preview.tick(0.1, {"clip_id": "recovery", "force_clip": true})
	var output := root.path_join("runtime")
	var exported: Dictionary = EngineExporterScript.new().export_all(manifest, production, output)
	var exported_valid: Dictionary = EngineExporterScript.new().validate_export(output)
	var qa: Dictionary = QaScript.new().run(contract, {"clip_id": "attack", "fps": 12, "expected_action_points": ["muzzle"], "output_directory": root.path_join("qa")})
	var comparison: Dictionary = QaScript.new().compare_exported_package(contract, str(exported.get("package", "")), {"clip_id": "attack", "fps": 12})
	return {"success": bool(validation.get("valid", false)) and not (contract.get("facing_grid", {}).get("cells", {}) as Dictionary).is_empty() and str(frame.get("state", {}).get("state_id", "")) == "attack" and (frame.get("events", []) as Array).size() > 0 and (frame.get("rule_actions", []) as Array).size() > 0 and (frame.get("hitboxes", []) as Array).size() == 1 and (frame.get("action_points", []) as Array).size() == 1 and str(forced_frame.get("clip_id", "")) == "recovery" and (forced_frame.get("secondary_motion", {}).get("impact_frames", []) as Array).is_empty() and bool(exported.get("success", false)) and bool(exported_valid.get("valid", false)) and bool(qa.get("success", false)) and bool(comparison.get("matches", false)), "frame": frame, "forced_frame": forced_frame, "exported": exported, "qa": qa, "comparison": comparison}


func _pipeline(manifest: Dictionary, source_path: String, root: String) -> Dictionary:
	var template: Dictionary = TemplateScript.create("combat_2d", "Combat Template")
	var pack_path := root.path_join("hero.assetpack")
	var pack = AssetPackScript.new()
	var packed: Dictionary = pack.export_pack(manifest, pack_path)
	var inspected: Dictionary = pack.inspect_pack(pack_path)
	var extracted: Dictionary = pack.extract_pack(pack_path, root.path_join("unpacked"))
	var watcher = WatchScript.new()
	var added: Dictionary = watcher.add_source(source_path, "body", true)
	_write_png(source_path, Color("38bdf8"))
	var scan: Dictionary = watcher.scan_once()
	var changed := ChangeScript.new()
	var modified := manifest.duplicate(true)
	modified["project_name"] = "Changed Hero"
	var diff: Dictionary = changed.diff(manifest, modified)
	var snapshot_path := root.path_join("milestone.chrproj")
	var snapshot_file := FileAccess.open(ProjectSettings.globalize_path(snapshot_path), FileAccess.WRITE)
	if snapshot_file != null: snapshot_file.store_string(JSON.stringify(manifest)); snapshot_file.close()
	var snapshot_session := FakeSnapshotSession.new()
	add_child(snapshot_session)
	snapshot_session.snapshot_path = snapshot_path
	snapshot_session.manifest = modified
	var snapshot_diff: Dictionary = changed.compare_snapshot(snapshot_session, "milestone")
	snapshot_session.queue_free()
	var conflicts: Dictionary = changed.conflict_guidance(manifest, modified, ProductionDataScript.apply_to_manifest(manifest, ProductionDataScript.defaults()))
	return {"success": bool(template.get("success", false)) and bool(packed.get("success", false)) and bool(inspected.get("success", false)) and bool(extracted.get("success", false)) and bool(added.get("success", false)) and not (scan.get("changes", []) as Array).is_empty() and bool(diff.get("changed", false)) and bool(snapshot_diff.get("success", false)) and not (conflicts.get("safe_local_paths", []) as Array).is_empty(), "template": template, "packed": packed, "inspected": inspected, "extracted": extracted, "scan": scan, "diff": diff, "snapshot_diff": snapshot_diff, "conflicts": conflicts}


func _presentation(manifest: Dictionary, production: Dictionary, source_path: String, root: String) -> Dictionary:
	var fake := FakePresentationSession.new()
	add_child(fake)
	fake.manifest = manifest.duplicate(true)
	fake.production = production.duplicate(true)
	fake.layer_path = source_path
	var report: Dictionary = PresentationScript.new().export_package(fake, root.path_join("presentation"), {"approval_url": "https://example.com/approval"})
	fake.queue_free()
	var turntable_image := str(report.get("turntable", {}).get("sheet", {}).get("image", ""))
	return {"success": bool(report.get("success", false)) and FileAccess.file_exists(ProjectSettings.globalize_path(str(report.get("manifest", "")))) and FileAccess.file_exists(ProjectSettings.globalize_path(str(report.get("approval_page", "")))) and FileAccess.file_exists(ProjectSettings.globalize_path(turntable_image)) and (report.get("pose_boards", []) as Array).size() == 1, "report": report}


func _manifest(asset_path: String) -> Dictionary:
	var machine := StateMachineScript.new("combat", "Combat")
	machine.add_state("attack", "attack")
	var rules := RuleGraphScript.new("combat_rules", "Combat Rules")
	rules.add_rule("swing_rule", [{"type": "time_window", "start": 0.0, "end": 1.0}], [{"type": "trigger_event", "target": "rule_swing"}])
	var tracks := [
		{"track_id": "muzzle", "object_id": "hand", "property_path": "action_point.muzzle", "track_type": TrackDefinitionScript.TrackType.ACTION_POINT, "keys": [{"time": 0.0, "value": {"point_id": "muzzle", "display_name": "Muzzle", "local_position": [8.0, 0.0]}, "interpolation": 1}]},
		{"track_id": "hit", "object_id": "hand", "property_path": "hitbox.sword", "track_type": TrackDefinitionScript.TrackType.HITBOX, "keys": [{"time": 0.0, "value": [{"shape_id": "sword", "shape_type": 0, "local_position": [0.0, 0.0], "size": [12.0, 12.0]}], "interpolation": 0}]},
		{"track_id": "hurt", "object_id": "root", "property_path": "hurtbox.body", "track_type": TrackDefinitionScript.TrackType.HURTBOX, "keys": [{"time": 0.0, "value": [{"shape_id": "body", "shape_type": 0, "local_position": [2.0, 0.0], "size": [12.0, 12.0]}], "interpolation": 0}]},
		{"track_id": "event", "object_id": "hand", "property_path": "event.swing", "track_type": TrackDefinitionScript.TrackType.EVENT, "keys": [{"time": 0.1, "value": {"event_id": "swing", "event_name": "swing"}, "interpolation": 0}]},
		{"track_id": "viseme", "object_id": "face", "property_path": "viseme", "track_type": TrackDefinitionScript.TrackType.VISEME, "keys": [{"time": 0.0, "value": "A", "interpolation": 0}]},
	]
	return {"schema_version": "1.0.0", "project_id": "production_hero", "project_name": "Production Hero", "created_at": 1, "modified_at": 1, "objects": {"characters": {"hero": {"assembly": {"display_name": "Hero", "equipped_parts": {"body": "body"}}}}, "rigs": {"hero_rig": {"bones": {"root": {"name": "root", "parent_id": "", "local_position": [0.0, 0.0]}, "hand": {"name": "hand", "parent_id": "root", "local_position": [8.0, 0.0]}}}}, "animations": {"attack": {"clip_id": "attack", "clip_name": "Attack", "duration": 0.5, "fps": 24.0, "loop_mode": 1, "tracks": tracks}, "recovery": {"clip_id": "recovery", "clip_name": "Recovery", "duration": 0.25, "fps": 24.0, "loop_mode": 1, "tracks": []}}, "weapons": {"sword": {"weapon_id": "sword", "grips": {"main": {"bone_id": "hand"}}}}, "assets": {"body_asset": {"asset_id": "body_asset", "path": asset_path, "checksum": "source", "asset_type": "image"}}, "palettes": {}, "body_types": {}, "export_profiles": {}, "gameplay_metadata": {}}, "settings": {"default_facing_directions": 8, "default_fps": 24, "pixel_mode": false}, "facing_grid": {"grid_id": "hero_facing", "direction_set": 4, "cells": {"north": {"asset_id": "body_asset"}, "south": {"asset_id": "body_asset"}}}, "metadata": {"character_authoring": {"active_character_id": "hero", "active_rig_id": "hero_rig"}, "production_suite": {"runtime": {"state_machine": machine.to_dict(), "rule_graph": rules.to_dict()}}}}


func _write_png(path: String, color: Color) -> bool:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image.save_png(ProjectSettings.globalize_path(path)) == OK


func _cleanup(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute): return
	var directory := DirAccess.open(absolute)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute.path_join(entry)
			if directory.current_is_dir(): _cleanup_path(child)
			else: DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _cleanup_path(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir(): _cleanup_path(child)
			else: DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
