# GodotResourceExporter -- Produces native Godot data resources and a ready-to-instance player scene.
class_name GodotResourceExporter
extends RefCounted

# Exported resources must resolve only against the distributable runtime addon,
# never authoring-project scripts.
const CharacterRuntimeDataScript = preload("res://addons/modular_character_runtime/runtime/character_runtime_data.gd")
const CharacterPlayer2DScript = preload("res://addons/modular_character_runtime/runtime/character_player_2d.gd")
const RuntimeMapperScript = preload("res://export/godot/godot_runtime_mapper.gd")


func export_package(package: Dictionary, output_directory: String, base_name: String = "character", consumer_resource_path: String = "") -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory)) != OK:
		return {"success": false, "errors": ["cannot create Godot export directory"]}
	var mapped_package := package.duplicate(true)
	var content: Dictionary = mapped_package.get("content", {}).duplicate(true)
	content["godot_runtime"] = RuntimeMapperScript.build(content)
	mapped_package["content"] = content
	var data := CharacterRuntimeDataScript.new()
	data.configure(mapped_package)
	var resource_path := output_directory.path_join(base_name + ".tres")
	var resource_error := ResourceSaver.save(data, resource_path)
	if resource_error != OK:
		return {"success": false, "errors": ["cannot save runtime resource"]}
	if not consumer_resource_path.is_empty():
		data.take_over_path(consumer_resource_path)
	var player := CharacterPlayer2DScript.new()
	player.name = "CharacterPlayer2D"
	player.runtime_data = data
	var scene := PackedScene.new()
	var pack_error := scene.pack(player)
	player.free()
	if pack_error != OK:
		return {"success": false, "errors": ["cannot pack player scene"]}
	var scene_path := output_directory.path_join(base_name + ".tscn")
	var scene_error := ResourceSaver.save(scene, scene_path)
	if scene_error != OK:
		return {"success": false, "errors": ["cannot save player scene"]}
	return {"success": true, "resource": resource_path, "scene": scene_path, "mapping": content.get("godot_runtime", {})}
