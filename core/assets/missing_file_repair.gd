# MissingFileRepair — Detects missing files and provides path relocation and rebasing utilities
class_name MissingFileRepair
extends RefCounted


static func find_missing_assets(p_registry: AssetRegistry) -> Array:
	var missing: Array = []
	if p_registry == null:
		return missing
	
	var all_assets := p_registry.list_assets()
	for asset in all_assets:
		var path: String = asset.get("path", "")
		if path.is_empty() or not FileAccess.file_exists(path):
			missing.append(asset.duplicate(true))
	return missing


static func relocate_asset(p_registry: AssetRegistry, p_asset_id: String, p_new_path: String) -> bool:
	if p_registry == null or p_asset_id.is_empty() or p_new_path.is_empty():
		return false
	
	if not FileAccess.file_exists(p_new_path):
		return false
	
	var updates := {"path": p_new_path}
	var inspect := ImageImporter.inspect_image(p_new_path)
	if inspect.get("valid", false):
		updates["width"] = inspect["width"]
		updates["height"] = inspect["height"]
		updates["checksum"] = inspect["checksum"]
	
	return p_registry.update_asset(p_asset_id, updates)


static func rebase_missing_assets_folder(p_registry: AssetRegistry, p_old_prefix: String, p_new_prefix: String) -> int:
	if p_registry == null or p_old_prefix.is_empty() or p_new_prefix.is_empty():
		return 0
	
	var repaired_count := 0
	var missing := find_missing_assets(p_registry)
	
	for asset in missing:
		var old_path: String = asset.get("path", "")
		if old_path.begins_with(p_old_prefix):
			var relative_suffix := old_path.substr(p_old_prefix.length())
			var candidate_path := p_new_prefix + relative_suffix
			if FileAccess.file_exists(candidate_path):
				if relocate_asset(p_registry, asset.get("asset_id", ""), candidate_path):
					repaired_count += 1
	
	return repaired_count
