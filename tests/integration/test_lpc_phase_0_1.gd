# TestLpcPhase01 -- End-to-end synthetic locked-source acceptance for LPC phases 0 and 1.
class_name TestLpcPhase01
extends Node

const SourceLockScript = preload("res://lpc/source/lpc_source_lock.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const CatalogBrowserModelScript = preload("res://lpc/catalog/lpc_catalog_browser_model.gd")
const LayoutScript = preload("res://lpc/layout/lpc_sheet_layout.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")
const RasterizerScript = preload("res://lpc/render/lpc_strict_triangle_rasterizer.gd")
const ReferenceRendererScript = preload("res://lpc/render/lpc_reference_renderer.gd")
const DirectStartScript = preload("res://lpc/startup/lpc_direct_start_service.gd")
const NameSequenceScript = preload("res://lpc/project/lpc_name_sequence.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const ProfileScript = preload("res://lpc/project/lpc_project_profile.gd")


func run_all_tests() -> Dictionary:
	var result := _exercise_direct_start_workflow()
	if result.get("success", false):
		print("  PASS: LPC phases 0–1 build a locked catalog, render strictly, and create/reopen/recover a direct-start project")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 0–1 end-to-end workflow failed: %s" % str(result.get("errors", [])))
	return {"passed": 0, "failed": 1, "errors": result.get("errors", [])}


func _exercise_direct_start_workflow() -> Dictionary:
	var id := IDService.generate_short("lpc01")
	var test_root := "user://lpc_phase01_" + id
	var source_root := test_root.path_join("source")
	var sprite_path := source_root.path_join("sprites/body.png")
	var project_path := test_root.path_join("Ranger.chrproj")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root.path_join("sprites")))
	var original_state := NameSequenceScript.load_state()
	var source_ok := _write_source_fixture(source_root, sprite_path)
	var lock_result := SourceLockScript.load_file(source_root.path_join(SourceLockScript.LOCK_FILE_NAME))
	var built := CatalogBuilderScript.build(source_root)
	var cached := CatalogBuilderScript.write_cache(built.get("catalog", {})) if built.get("success", false) else {}
	var source_unchanged := _hash(sprite_path)
	var licensing := LicenseResolverScript.resolve_asset(((built.get("catalog", {}).get("assets", {}) as Dictionary).get("body_human", {}) as Dictionary), "drm_friendly") if built.get("success", false) else {}
	var credits := LicenseResolverScript.exact_credit_manifest([((built.get("catalog", {}).get("assets", {}) as Dictionary).get("body_human", {}) as Dictionary)], "drm_friendly") if built.get("success", false) else {}
	var browser := CatalogBrowserModelScript.new()
	var browser_loaded := browser.load_catalog(built.get("catalog", {})) if built.get("success", false) else {}
	var page := browser.search("human", {"body_family_id": "human", "policy_id": "drm_friendly"}, 0, 10) if browser_loaded.get("success", false) else {}
	var selection_before := browser.selection_status(["body_human"], "drm_friendly") if browser_loaded.get("success", false) else {}
	if browser_loaded.get("success", false): browser.load_shard("layouts"); browser.load_shard("credits")
	var selection_after := browser.selection_status(["body_human"], "drm_friendly") if browser_loaded.get("success", false) else {}
	var layout := LayoutScript.standard_adapter()
	var frame := LayoutScript.frame_ref({"asset_id": "body_human", "source_sha256": _hash(sprite_path)}, layout, "walk", "down", 0)
	var raster := _exercise_strict_raster()
	var reference := _exercise_reference_renderer()
	var located := DirectStartScript.set_library_root(source_root)
	var rebuilt := DirectStartScript.rebuild_catalog()
	var bodies := DirectStartScript.compatible_body_families("drm_friendly")
	var created := DirectStartScript.create_project(project_path, "Ranger", "human", "drm_friendly") if rebuilt.get("success", false) else {}
	var opened := ProjectStoreScript.open(project_path, false) if created.get("success", false) else {}
	var autosaved := ProjectStoreScript.autosave(project_path, opened.get("manifest", {}), opened.get("profile", {})) if opened.get("success", false) else {}
	var resumed := DirectStartScript.latest_resumable() if created.get("success", false) else {}
	var manifest: Dictionary = (opened.get("manifest", {}) as Dictionary).duplicate(true) if bool(opened.get("success", false)) else {}
	var migration: Dictionary = {}
	if not manifest.is_empty():
		var legacy_profile := ProfileScript.from_manifest(manifest)
		legacy_profile["profile_schema_version"] = "0.1.0"
		legacy_profile["policy_profile"] = str((legacy_profile.get("policy", {}) as Dictionary).get("profile_id", "drm_friendly"))
		legacy_profile.erase("policy")
		manifest = ProfileScript.apply_to_manifest(manifest, legacy_profile)
		SerializationService.save_project(manifest, project_path)
		migration = ProjectStoreScript.open(project_path, true)
	var profile_valid: bool = bool(opened.get("success", false)) and ProfileScript.validate(opened.get("profile", {})).is_empty()
	var state_restored := NameSequenceScript.save_state(original_state)
	if RecentProjectsService != null: RecentProjectsService.remove_project(project_path)
	var errors: Array[String] = []
	if not source_ok: errors.append("Synthetic source fixture could not be written.")
	if not lock_result.get("success", false): errors.append_array(lock_result.get("errors", []))
	if not built.get("success", false): errors.append_array(built.get("errors", []))
	if not cached.get("success", false): errors.append("Catalog cache was not written.")
	if not licensing.get("success", false): errors.append("Alternative license resolution failed.")
	if not credits.get("success", false) or (credits.get("credits", []) as Array).is_empty(): errors.append("Exact credit manifest generation failed.")
	if not page.get("success", false) or int(page.get("total", 0)) != 1 or bool(selection_before.get("ready", true)) or not bool(selection_after.get("ready", false)): errors.append("Staged catalog browsing and selection gating failed.")
	if not frame.get("success", false) or frame.get("source_rect", []) != [0, 640, 64, 64]: errors.append("Standard layout frame reference was incorrect.")
	if not raster.get("success", false) or raster.get("overlap_pixels", -1) != 0 or not raster.get("audit", {}).get("source_color_subset", false): errors.append("Strict triangle rasterization failed its crack/palette audit.")
	if not reference.get("success", false) or int(reference.get("layer_count", 0)) != 2: errors.append("Reference layer renderer did not compose deterministically.")
	if not located.get("success", false) or not rebuilt.get("success", false): errors.append("Direct-start library location/catalog rebuild failed.")
	if bodies.is_empty() or not bool((bodies[0] as Dictionary).get("eligible", false)): errors.append("Compatible body-family filtering failed.")
	if not created.get("success", false): errors.append_array(created.get("errors", ["LPC project creation failed."]))
	if not opened.get("success", false) or not profile_valid: errors.append("LPC project could not be reopened with a valid profile.")
	if not autosaved.get("success", false) or not FileAccess.file_exists(str(autosaved.get("path", ""))): errors.append("LPC project autosave/recovery artifact is missing.")
	if not resumed.get("success", false): errors.append("Direct start did not find the latest resumable LPC project.")
	if not migration.get("success", false) or not migration.get("migrated", false) or not FileAccess.file_exists(str(migration.get("migration_backup", ""))): errors.append("LPC profile migration did not run with a durable backup.")
	if _hash(sprite_path) != source_unchanged: errors.append("Catalog/project workflows modified immutable LPC source art.")
	if not state_restored: errors.append("LPC test state could not be restored.")
	return {"success": errors.is_empty(), "errors": errors}


func _write_source_fixture(source_root: String, sprite_path: String) -> bool:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(0, 0, 64, 64), Color("d77a61"))
	image.fill_rect(Rect2i(16, 16, 32, 32), Color("273a58"))
	if image.save_png(sprite_path) != OK: return false
	var lock := {
		"lock_schema_version": "1.0.0", "upstream_repository_url": "https://example.invalid/locked-lpc", "upstream_commit_sha": "0123456789abcdef0123456789abcdef01234567", "catalog_adapter_version": "1.0.0",
		"accepted_source_tree_paths": ["sprites"], "expected_root_hashes": {}, "palette_policy_version": "1.0.0", "layout_policy_version": "1.0.0", "license_policy_version": "1.0.0", "build_timestamp": "2026-08-07T00:00:00Z", "build_tool_version": "test", "catalog_signature": "synthetic-lock"
	}
	var source := {
		"body_families": [{"id": "human", "name": "Human"}], "palettes": [], "aliases": {"human_base": "body_human"},
		"assets": [{"asset_id": "body_human", "upstream_item_id": "body_human", "type_name": "body", "source_relative_path": "sprites/body.png", "body_family_ids": ["human"], "layer_group": "base", "layer_number": 0, "z_order": {"default": 0, "overrides": {}}, "supported_animations": ["walk"], "direction_ids": ["up", "left", "down", "right"], "layout_id": "lpc_standard_v1", "palette": {"material": "", "allowed_palette_ids": []}, "credits": [{"credit_id": "artist", "author": "Synthetic Artist", "source_url": "https://example.invalid/source", "notice": "Synthetic fixture"}], "license_options": [{"credit_id": "artist", "license_id": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/"}], "deformation": {"capabilities": ["FRAME_NATIVE"]}, "rig_adapter": {"available": false}}]
	}
	return _write_json(source_root.path_join(SourceLockScript.LOCK_FILE_NAME), lock) and _write_json(source_root.path_join("lpc_catalog_source.json"), source)


func _exercise_strict_raster() -> Dictionary:
	var source := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4): source.set_pixel(x, y, Color(float(x) / 4.0, float(y) / 4.0, 0.5, 1.0))
	return RasterizerScript.bake(source, [Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)], [Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)], [0, 1, 2, 0, 2, 3], Vector2i(4, 4))


func _exercise_reference_renderer() -> Dictionary:
	var bottom := Image.create(2, 2, false, Image.FORMAT_RGBA8); bottom.fill(Color("ff0000"))
	var top := Image.create(2, 2, false, Image.FORMAT_RGBA8); top.fill(Color("00ff00"))
	return ReferenceRendererScript.render([{"layer_id": "top", "z": 2, "image": top}, {"layer_id": "bottom", "z": 1, "image": bottom}], Vector2i(2, 2))


func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return true


func _hash(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	var value := context.finish().hex_encode()
	file.close()
	return value
