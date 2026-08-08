# LpcPhaseFixtureFactory -- Synthetic, redistributable locked-source fixtures shared by LPC acceptance tests.
class_name LpcPhaseFixtureFactory
extends RefCounted

const SourceLockScript = preload("res://lpc/source/lpc_source_lock.gd")


static func create(test_root: String) -> Dictionary:
	var source_root := test_root.path_join("source")
	var sprites := source_root.path_join("sprites")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sprites)) != OK:
		return {"success": false, "errors": ["Could not create synthetic LPC fixture folders."]}
	var files := {"body_human": sprites.path_join("body.png"), "shirt_blue": sprites.path_join("shirt.png"), "cape_partial": sprites.path_join("cape.png")}
	if not _write_sheet(str(files.body_human), Color("b85757")) or not _write_sheet(str(files.shirt_blue), Color("396bca")) or not _write_sheet(str(files.cape_partial), Color("d2a942")):
		return {"success": false, "errors": ["Could not write synthetic LPC sheets."]}
	var lock := {"lock_schema_version": "1.0.0", "upstream_repository_url": "https://example.invalid/locked-lpc", "upstream_commit_sha": "0123456789abcdef0123456789abcdef01234567", "catalog_adapter_version": "1.0.0", "accepted_source_tree_paths": ["sprites"], "expected_root_hashes": {}, "palette_policy_version": "1.0.0", "layout_policy_version": "1.0.0", "license_policy_version": "1.0.0", "build_timestamp": "2026-08-07T00:00:00Z", "build_tool_version": "fixture", "catalog_signature": "synthetic-phase-fixture"}
	var source := {"body_families": [{"id": "human", "name": "Human"}], "palettes": [], "aliases": {"base": "body_human"}, "assets": [_asset("body_human", "body", "base", 0, 0, "sprites/body.png", ["walk", "slash"]), _asset("shirt_blue", "shirt", "torso", 1, 10, "sprites/shirt.png", ["walk", "slash"]), _asset("cape_partial", "cape", "back", 2, 20, "sprites/cape.png", ["slash"])]}
	if not _write_json(source_root.path_join(SourceLockScript.LOCK_FILE_NAME), lock) or not _write_json(source_root.path_join("lpc_catalog_source.json"), source):
		return {"success": false, "errors": ["Could not write synthetic LPC catalog metadata."]}
	return {"success": true, "source_root": source_root, "files": files, "errors": []}


static func hash(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(file.get_buffer(file.get_length()))
	var value := context.finish().hex_encode(); file.close(); return value


static func _asset(asset_id: String, type_name: String, group: String, layer_number: int, z: int, source_path: String, animations: Array) -> Dictionary:
	return {"asset_id": asset_id, "upstream_item_id": asset_id, "type_name": type_name, "source_relative_path": source_path, "body_family_ids": ["human"], "layer_group": group, "layer_number": layer_number, "z_order": {"default": z, "overrides": {}}, "supported_animations": animations, "direction_ids": ["up", "left", "down", "right"], "layout_id": "lpc_standard_v1", "palette": {"material": "", "allowed_palette_ids": []}, "credits": [{"credit_id": "artist", "author": "Synthetic Artist", "source_url": "https://example.invalid/source", "notice": "Synthetic redistributable test fixture"}], "license_options": [{"credit_id": "artist", "license_id": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/"}], "deformation": {"capabilities": ["FRAME_NATIVE", "FRAME_EDITABLE", "FRAME_WARPABLE"]}, "rig_adapter": {"available": false}}


static func _write_sheet(path: String, base: Color) -> bool:
	var image := Image.create(64 * 13, 64 * 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row in range(24):
		for column in range(13):
			var shade := 0.76 + 0.015 * float((row + column) % 10)
			var color := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
			image.fill_rect(Rect2i(column * 64, row * 64, 64, 64), color)
	return image.save_png(path) == OK


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t")); file.close(); return true
