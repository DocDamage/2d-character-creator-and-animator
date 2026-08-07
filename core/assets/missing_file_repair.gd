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


## Plans only unambiguous repairs.  Callers retain control over whether a
## candidate is copied into a project, which keeps repair portable and avoids
## silently binding a project to an arbitrary external folder.
static func plan_deterministic_repairs(p_registry: AssetRegistry, candidate_paths: Array, categories: Array = []) -> Dictionary:
	var repairs: Array = []
	var ambiguous: Array = []
	var unresolved: Array = []
	if p_registry == null:
		return {"repairs": repairs, "ambiguous": ambiguous, "unresolved": unresolved}
	var by_checksum: Dictionary = {}
	var by_filename: Dictionary = {}
	var sorted_paths: Array[String] = []
	for raw_path in candidate_paths:
		var path := str(raw_path).strip_edges()
		if not path.is_empty() and not sorted_paths.has(path): sorted_paths.append(path)
	sorted_paths.sort()
	for path in sorted_paths:
		var inspection: Dictionary = ImageImporter.inspect_image(path)
		if not bool(inspection.get("valid", false)):
			continue
		var candidate := {"path": path, "checksum": str(inspection.get("checksum", "")), "filename": path.get_file().to_lower()}
		var checksum := str(candidate.checksum)
		if not checksum.is_empty():
			if not by_checksum.has(checksum): by_checksum[checksum] = []
			by_checksum[checksum].append(candidate)
		if not by_filename.has(candidate.filename): by_filename[candidate.filename] = []
		by_filename[candidate.filename].append(candidate)
	for raw_asset in find_missing_assets(p_registry):
		var asset: Dictionary = raw_asset
		if not categories.is_empty() and str(asset.get("category", "")) not in categories:
			continue
		var asset_id := str(asset.get("asset_id", ""))
		var expected_checksum := str(asset.get("checksum", ""))
		var filename := str(asset.get("path", "")).get_file().to_lower()
		var checksum_matches: Array = by_checksum.get(expected_checksum, []) if not expected_checksum.is_empty() else []
		if not checksum_matches.is_empty():
			# Identical checksums are safe replacements.  Choosing the sorted first
			# source makes the plan deterministic while the session copies the bytes
			# into its own asset folder.
			repairs.append({"asset_id": asset_id, "candidate_path": str((checksum_matches[0] as Dictionary).get("path", "")), "match_type": "checksum"})
			continue
		var filename_matches: Array = by_filename.get(filename, [])
		if filename_matches.size() == 1:
			repairs.append({"asset_id": asset_id, "candidate_path": str((filename_matches[0] as Dictionary).get("path", "")), "match_type": "unique_filename"})
		elif filename_matches.size() > 1:
			ambiguous.append({"asset_id": asset_id, "filename": filename, "candidate_paths": filename_matches.map(func(item): return str((item as Dictionary).get("path", "")))})
		else:
			unresolved.append({"asset_id": asset_id, "filename": filename})
	return {"repairs": repairs, "ambiguous": ambiguous, "unresolved": unresolved}
