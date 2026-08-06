# AssetReports — Scans registry for duplicate files and unreferenced assets
class_name AssetReports
extends RefCounted


static func find_duplicate_assets(p_registry: AssetRegistry) -> Dictionary:
	var duplicates: Dictionary = {} # checksum -> Array of asset dictionaries
	if p_registry == null:
		return duplicates
	
	var checksum_map: Dictionary = {} # checksum -> Array of assets
	var assets := p_registry.list_assets()
	
	for asset in assets:
		var checksum: String = asset.get("checksum", "")
		if checksum.is_empty():
			continue
		if not checksum_map.has(checksum):
			checksum_map[checksum] = []
		checksum_map[checksum].append(asset)
	
	for checksum in checksum_map:
		var group: Array = checksum_map[checksum]
		if group.size() > 1:
			duplicates[checksum] = group
	
	return duplicates


static func find_unused_assets(p_registry: AssetRegistry, p_referenced_ids: Array) -> Array:
	var unused: Array = []
	if p_registry == null:
		return unused
	
	var ref_set: Dictionary = {}
	for id in p_referenced_ids:
		ref_set[id] = true
	
	var assets := p_registry.list_assets()
	for asset in assets:
		var id: String = asset.get("asset_id", "")
		if not ref_set.has(id):
			unused.append(asset.duplicate(true))
	
	return unused


static func generate_report(p_registry: AssetRegistry, p_referenced_ids: Array = []) -> Dictionary:
	if p_registry == null:
		return {}
	
	var all_assets := p_registry.list_assets()
	var duplicates := find_duplicate_assets(p_registry)
	var unused := find_unused_assets(p_registry, p_referenced_ids)
	var missing := MissingFileRepair.find_missing_assets(p_registry)
	
	return {
		"total_assets": all_assets.size(),
		"duplicate_groups": duplicates.size(),
		"unused_count": unused.size(),
		"missing_count": missing.size(),
		"duplicates": duplicates,
		"unused": unused,
		"missing": missing
	}
