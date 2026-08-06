# Verifies that exported Godot resources load in a separate project containing
# only the distributable runtime addon and generated artifacts.
extends Node

const GodotResourceExporterScript = preload("res://export/godot/godot_resource_exporter.gd")


func run_tests() -> Dictionary:
	var root := "user://clean_consumer_%d" % Time.get_ticks_usec()
	var copied_fixture := _copy_tree("res://tests/fixtures/clean_consumer", root)
	var copied_addon := _copy_tree("res://addons/modular_character_runtime", root.path_join("addons/modular_character_runtime"))
	var export_result: Dictionary = GodotResourceExporterScript.new().export_package(_package(), root.path_join("generated"), "hero", "res://generated/hero.tres") if copied_fixture and copied_addon else {}
	var output: Array = []
	var exit_code := -1
	var editor_output: Array = []
	var editor_exit_code := -1
	if export_result.get("success", false):
		editor_exit_code = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path(root), "--editor", "--quit"]), editor_output, true)
		exit_code = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path(root), "--script", "res://test_consumer.gd"]), output, true)
	var editor_log := "\n".join(editor_output)
	var passed: bool = copied_fixture and copied_addon and bool(export_result.get("success", false)) and exit_code == 0 and editor_exit_code == 0 and "CLEAN_CONSUMER_PASS" in "\n".join(output) and not "SCRIPT ERROR" in editor_log and not "Failed to load" in editor_log
	if passed:
		print("  PASS: Generated .tres/.tscn load in a clean runtime-only Godot project")
		return {"passed": 1, "failed": 0, "errors": []}
	var details := "fixture=%s addon=%s export=%s exit=%s editor_exit=%s output=%s editor_output=%s" % [copied_fixture, copied_addon, export_result, exit_code, editor_exit_code, "\n".join(output), editor_log]
	return {"passed": 0, "failed": 1, "errors": ["Clean-consumer export failed: " + details]}


func _copy_tree(source: String, destination: String) -> bool:
	var directory := DirAccess.open(source)
	if directory == null or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination)) != OK:
		return false
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var from := source.path_join(entry)
			var to := destination.path_join(entry)
			if directory.current_is_dir():
				if not _copy_tree(from, to):
					directory.list_dir_end()
					return false
			elif not entry.ends_with(".uid") and DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) != OK:
				directory.list_dir_end()
				return false
		entry = directory.get_next()
	directory.list_dir_end()
	return true


func _package() -> Dictionary:
	return {
		"format": "chr_runtime_package",
		"format_version": "1.0.0",
		"content": {
			"project_id": "clean_consumer_hero",
			"facing_grid": {
				"grid_id": "hero_facing",
				"direction_set": 4,
				"cells": {"north": {"asset_id": "hero_north"}, "east": {"asset_id": "hero_east"}, "south": {"asset_id": "hero_south"}, "west": {"asset_id": "hero_west"}},
			},
			"state_machine": {
				"entry_state_id": "idle",
				"states": {"idle": {"clip_id": "idle", "loop": true}, "run": {"clip_id": "run", "loop": true}},
				"parameters": {"speed": {"default": 0.0}},
				"transitions": [{"transition_id": "idle_run", "from_state": "idle", "to_state": "run", "conditions": [{"type": "parameter", "parameter": "speed", "operator": ">", "value": 0.1}]}],
			},
			"rule_graph": {"rules": [{"rule_id": "run_event", "conditions": [{"type": "state", "value": "run"}], "actions": [{"type": "trigger_event", "target": "run"}]}]},
			"events": [{"time": 0.05, "event_id": "footstep"}],
			"rig": {"bones": {
				"root": {"name": "root", "parent_id": "", "local_position": [0.0, 0.0]},
				"mid": {"name": "mid", "parent_id": "root", "local_position": [20.0, 0.0]},
				"tip": {"name": "tip", "parent_id": "mid", "local_position": [20.0, 0.0]},
			}},
		},
	}
