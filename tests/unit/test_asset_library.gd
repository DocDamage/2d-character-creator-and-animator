# Unit Tests for Asset Library (Milestone 3 — AST-001 through AST-012)
extends Node

var _registry: AssetRegistry
var _thumb_cache: ThumbnailCache


func run_tests() -> int:
	print("--- Running Asset Library Tests (Milestone 3) ---")
	var pass_count := 0
	
	_registry = AssetRegistry.new()
	add_child(_registry)
	_thumb_cache = ThumbnailCache.new()
	add_child(_thumb_cache)
	
	pass_count += test_asset_registry()
	pass_count += test_import_profiles()
	pass_count += test_thumbnail_cache()
	pass_count += test_asset_filter_service()
	pass_count += test_drag_drop()
	pass_count += test_missing_file_repair()
	pass_count += test_external_file_refresh()
	pass_count += test_asset_reports()
	pass_count += test_batch_metadata_editor()
	
	# The runner exits in this frame, so these test-only nodes need immediate
	# teardown rather than deferred deletion.
	_thumb_cache.free()
	_registry.free()
	
	print("--- Asset Library Tests Finished: %d PASS ---" % pass_count)
	return pass_count


func test_asset_registry() -> int:
	var passes := 0
	_registry.clear_registry()
	
	var asset1 := _registry.register_asset("res://tests/fixtures/baseline/valid_project.chrproj", AssetRegistry.CATEGORY_SOURCE_ART, {"width": 100, "height": 100})
	if not asset1.is_empty() and asset1.get("asset_id", "").begins_with("ast_"):
		print("  PASS: AssetRegistry registered asset with valid ID prefix")
		passes += 1
	
	var fetched := _registry.get_asset(asset1["asset_id"])
	if fetched.get("name", "") == "valid_project":
		print("  PASS: AssetRegistry retrieved asset metadata correctly")
		passes += 1
	
	var updated := _registry.update_asset(asset1["asset_id"], {"tags": ["character", "body"]})
	if updated and _registry.get_asset(asset1["asset_id"]).get("tags", []).size() == 2:
		print("  PASS: AssetRegistry updated asset tags successfully")
		passes += 1
	
	var unreg := _registry.unregister_asset(asset1["asset_id"])
	if unreg and not _registry.has_asset(asset1["asset_id"]):
		print("  PASS: AssetRegistry unregistered asset successfully")
		passes += 1
	
	return passes


func test_import_profiles() -> int:
	var passes := 0
	var dummy_asset := {"asset_id": "ast_test", "path": "test.png"}
	
	var pixel_applied := PixelImportProfile.apply(dummy_asset)
	if pixel_applied.get("profile", "") == "pixel" and pixel_applied["metadata"]["snap_to_pixel"] == true:
		print("  PASS: PixelImportProfile applied correctly")
		passes += 1
	
	var smooth_applied := SmoothImportProfile.apply(dummy_asset)
	if smooth_applied.get("profile", "") == "smooth" and smooth_applied["metadata"]["mipmaps"] == true:
		print("  PASS: SmoothImportProfile applied correctly")
		passes += 1
	
	return passes


func test_thumbnail_cache() -> int:
	var passes := 0
	var dummy_asset := {"asset_id": "ast_thumb_1", "path": "invalid_path.png"}
	var thumb := _thumb_cache.get_thumbnail(dummy_asset)
	if thumb != null:
		print("  PASS: ThumbnailCache generated fallback texture for missing image")
		passes += 1
	
	_thumb_cache.invalidate_thumbnail("ast_thumb_1")
	if not _thumb_cache.has_thumbnail("ast_thumb_1"):
		print("  PASS: ThumbnailCache invalidation removed entry")
		passes += 1
	
	return passes


func test_asset_filter_service() -> int:
	var passes := 0
	var sample_assets := [
		{"asset_id": "1", "name": "head_sprite", "category": "source_art", "favorite": true, "tags": ["head", "body"]},
		{"asset_id": "2", "name": "sword_icon", "category": "source_art", "favorite": false, "tags": ["weapon"]},
		{"asset_id": "3", "name": "bg_music", "category": "audio", "favorite": true, "tags": ["audio"]}
	]
	
	var filtered_cat := AssetFilterService.filter_assets(sample_assets, "", "audio")
	if filtered_cat.size() == 1 and filtered_cat[0]["name"] == "bg_music":
		print("  PASS: AssetFilterService filtered by category correctly")
		passes += 1
	
	var filtered_fav := AssetFilterService.filter_assets(sample_assets, "", "", "", true)
	if filtered_fav.size() == 2:
		print("  PASS: AssetFilterService filtered by favorites correctly")
		passes += 1
	
	var tag_added := AssetFilterService.add_tag(sample_assets[1], "sharp")
	if "sharp" in tag_added.get("tags", []):
		print("  PASS: AssetFilterService added tag correctly")
		passes += 1
	
	return passes


func test_drag_drop() -> int:
	var passes := 0
	var payload := AssetDragDrop.create_asset_drag_payload({"asset_id": "ast_drag_1", "path": "a.png"})
	if AssetDragDrop.is_valid_asset_drag(payload) and AssetDragDrop.extract_asset_id(payload) == "ast_drag_1":
		print("  PASS: AssetDragDrop payload creation and extraction succeeded")
		passes += 1
	return passes


func test_missing_file_repair() -> int:
	var passes := 0
	_registry.clear_registry()
	var missing_asset := _registry.register_asset("non_existent_path.png", AssetRegistry.CATEGORY_SOURCE_ART)
	var missing_list := MissingFileRepair.find_missing_assets(_registry)
	if missing_list.size() == 1 and missing_list[0]["asset_id"] == missing_asset["asset_id"]:
		print("  PASS: MissingFileRepair detected missing asset correctly")
		passes += 1
	return passes


func test_external_file_refresh() -> int:
	var passes := 0
	_registry.clear_registry()
	_registry.register_asset("res://tests/fixtures/baseline/valid_project.chrproj", AssetRegistry.CATEGORY_SOURCE_ART, {"checksum": "old_hash"})
	var modified := ExternalFileRefresh.check_modified_assets(_registry)
	if modified.size() == 1:
		print("  PASS: ExternalFileRefresh detected modified asset checksum")
		passes += 1
	return passes


func test_asset_reports() -> int:
	var passes := 0
	_registry.clear_registry()
	var a1 := _registry.register_asset("res://tests/fixtures/baseline/valid_project.chrproj", AssetRegistry.CATEGORY_SOURCE_ART, {"checksum": "hash_xyz"})
	var a2 := _registry.register_asset("res://tests/fixtures/baseline/valid_project.chrproj_dup", AssetRegistry.CATEGORY_SOURCE_ART, {"checksum": "hash_xyz"})
	
	var dups := AssetReports.find_duplicate_assets(_registry)
	if dups.has("hash_xyz") and dups["hash_xyz"].size() == 2:
		print("  PASS: AssetReports detected duplicate asset checksum group")
		passes += 1
	
	var unused := AssetReports.find_unused_assets(_registry, [a1["asset_id"]])
	if unused.size() == 1 and unused[0]["asset_id"] == a2["asset_id"]:
		print("  PASS: AssetReports identified unused asset correctly")
		passes += 1
	
	return passes


func test_batch_metadata_editor() -> int:
	var passes := 0
	_registry.clear_registry()
	var a1 := _registry.register_asset("res://tests/fixtures/baseline/valid_project.chrproj", AssetRegistry.CATEGORY_SOURCE_ART)
	var count := BatchMetadataEditor.batch_set_category(_registry, [a1["asset_id"]], AssetRegistry.CATEGORY_PREVIEW)
	if count == 1 and _registry.get_asset(a1["asset_id"]).get("category", "") == AssetRegistry.CATEGORY_PREVIEW:
		print("  PASS: BatchMetadataEditor updated asset category in bulk")
		passes += 1
	return passes
