# ExternalFileRefresh — Scans for disk modifications and refreshes asset data while preserving IDs
class_name ExternalFileRefresh
extends RefCounted


static func check_modified_assets(p_registry: AssetRegistry) -> Array:
	var modified: Array = []
	if p_registry == null:
		return modified
	
	var assets := p_registry.list_assets()
	for asset in assets:
		var path: String = asset.get("path", "")
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		
		var inspect := ImageImporter.inspect_image(path)
		if not inspect.get("valid", false):
			continue
		
		var stored_checksum: String = asset.get("checksum", "")
		var current_checksum: String = inspect.get("checksum", "")
		
		if stored_checksum != current_checksum:
			modified.append({
				"asset_id": asset.get("asset_id", ""),
				"path": path,
				"new_width": inspect["width"],
				"new_height": inspect["height"],
				"new_checksum": current_checksum
			})
	
	return modified


static func refresh_modified_assets(p_registry: AssetRegistry, p_thumbnail_cache: ThumbnailCache = null) -> int:
	if p_registry == null:
		return 0
	
	var modified_list := check_modified_assets(p_registry)
	var refreshed_count := 0
	
	for item in modified_list:
		var asset_id: String = item["asset_id"]
		var updates := {
			"width": item["new_width"],
			"height": item["new_height"],
			"checksum": item["new_checksum"]
		}
		
		if p_registry.update_asset(asset_id, updates):
			refreshed_count += 1
			if p_thumbnail_cache != null:
				p_thumbnail_cache.invalidate_thumbnail(asset_id)
	
	return refreshed_count
