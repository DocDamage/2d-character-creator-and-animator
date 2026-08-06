# Integration tests for Phase 6 Godot mapping and portable runtime-node parity.
extends Node

const MapperScript = preload("res://export/godot/godot_runtime_mapper.gd")
const PortablePlayerScript = preload("res://addons/modular_character_runtime/runtime/character_player_2d.gd")
const PortableImporterScript = preload("res://addons/modular_character_runtime/runtime/chrproj_importer.gd")


func run_tests() -> int:
	var content := _content()
	var mapping: Dictionary = MapperScript.build(content)
	var package := {"content": content.duplicate(true)}
	package.content["godot_runtime"] = mapping
	var player = PortablePlayerScript.new()
	add_child(player)
	var loaded: bool = player.load_package(package)
	player.set_debug_views_enabled(true)
	var report: Dictionary = player.get_debug_snapshot()
	var grip: Dictionary = player.resolve_grip_target("sword", "main")
	var appearance: Dictionary = player.save_appearance()
	player.restore_appearance({"palette": "red", "equipment": {"main_hand": {"weapon_id": "sword"}}})
	var restored: Dictionary = player.get_appearance()
	var imported: Dictionary = PortableImporterScript.new().import_data(content, "user://phase6_runtime_import.tres")
	var valid := MapperScript.validate(mapping).is_empty()
	player._process(0.1)
	report = player.get_debug_snapshot()
	var report_ok: bool = int(report.get("runtime_nodes", {}).get("animations", 0)) == 1 and bool(report.get("runtime_nodes", {}).get("animation_tree", false)) and int(report.get("runtime_nodes", {}).get("meshes", 0)) == 1 and int(report.get("runtime_nodes", {}).get("sprites", 0)) == 1 and int(report.get("runtime_nodes", {}).get("markers", 0)) == 1 and int(report.get("runtime_nodes", {}).get("collision_shapes", 0)) == 1 and bool(report.get("tracks", {}).get("body.visible", false)) and absf(float(report.get("tracks", {}).get("curve.damage", 0.0)) - 1.0) < 0.001
	player.free()
	if loaded and valid and report_ok and grip.get("valid", false) and appearance.get("palette") == "blue" and restored.get("palette") == "red" and restored.get("equipment", {}).get("main_hand", {}).get("weapon_id") == "sword" and imported.get("success", false) and imported.get("report", {}).get("has_rig", false):
		print("  PASS: GDT-001 through GDT-011 map clips, weighted meshes, nodes, appearance, grips, rules, and debug runtime data")
		return 1
	printerr("  FAIL: Godot runtime mapping did not build portable parity nodes: %s" % str(report))
	return 0


func _content() -> Dictionary:
	return {"clips": {"idle": {"duration": 0.5, "loop": true}}, "state_machine": {"entry_state_id": "idle", "states": {"idle": {"clip_id": "idle", "loop": true}}, "transitions": [], "parameters": {}}, "rule_graph": {"rules": [{"rule_id": "window", "conditions": [{"type": "time_window", "start": 0.0, "end": 1.0}], "actions": [{"type": "trigger_event", "target": "ready"}]}]}, "runtime_tracks": [{"target": "body.visible", "keys": [{"time": 0.0, "value": true}, {"time": 0.5, "value": false}]}, {"target": "curve.damage", "interpolation": "linear", "keys": [{"time": 0.0, "value": 0.0}, {"time": 1.0, "value": 10.0}]}], "rig": {"bones": {"root": {"name": "root", "parent_id": "", "local_position": [0.0, 0.0]}, "mid": {"name": "mid", "parent_id": "root", "local_position": [10.0, 0.0]}}}, "meshes": [{"vertices": [{"position": [0.0, 0.0]}, {"position": [10.0, 0.0]}, {"position": [0.0, 10.0]}], "bone_ids": ["root"], "weights": [1.0, 1.0, 1.0]}], "sprites": [{"sprite_id": "body", "position": [0.0, 0.0]}], "markers": [{"marker_id": "muzzle", "position": [5.0, 0.0]}], "collision_shapes": [{"shape_id": "hurt", "shape_type": "rectangle", "size": [12.0, 18.0]}], "weapons": [{"weapon_id": "sword", "grips": {"main": {"bone_id": "mid"}}}], "appearance": {"palette": "blue", "equipment": {"main_hand": {"weapon_id": "sword"}}}, "baked_fallback": {"sprite_id": "fallback"}}
