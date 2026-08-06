# BatchMetadataEditor — Perform bulk updates across multiple asset metadata records
class_name BatchMetadataEditor
extends RefCounted


static func batch_set_category(p_registry: AssetRegistry, p_asset_ids: Array, p_category: String) -> int:
	if p_registry == null or p_asset_ids.is_empty() or p_category.is_empty():
		return 0
	
	var updated_count := 0
	for asset_id in p_asset_ids:
		if p_registry.update_asset(asset_id, {"category": p_category}):
			updated_count += 1
	return updated_count


static func batch_set_profile(p_registry: AssetRegistry, p_asset_ids: Array, p_profile: String) -> int:
	if p_registry == null or p_asset_ids.is_empty() or p_profile.is_empty():
		return 0
	
	var updated_count := 0
	for asset_id in p_asset_ids:
		var asset := p_registry.get_asset(asset_id)
		if asset.is_empty():
			continue
		var updated_asset: Dictionary
		if p_profile == AssetRegistry.PROFILE_PIXEL:
			updated_asset = PixelImportProfile.apply(asset)
		elif p_profile == AssetRegistry.PROFILE_SMOOTH:
			updated_asset = SmoothImportProfile.apply(asset)
		else:
			updated_asset = asset
			updated_asset["profile"] = p_profile
		
		if p_registry.update_asset(asset_id, updated_asset):
			updated_count += 1
	return updated_count


static func batch_add_tag(p_registry: AssetRegistry, p_asset_ids: Array, p_tag: String) -> int:
	if p_registry == null or p_asset_ids.is_empty() or p_tag.is_empty():
		return 0
	
	var updated_count := 0
	for asset_id in p_asset_ids:
		var asset := p_registry.get_asset(asset_id)
		if asset.is_empty():
			continue
		var updated := AssetFilterService.add_tag(asset, p_tag)
		if p_registry.update_asset(asset_id, {"tags": updated["tags"]}):
			updated_count += 1
	return updated_count


static func batch_remove_tag(p_registry: AssetRegistry, p_asset_ids: Array, p_tag: String) -> int:
	if p_registry == null or p_asset_ids.is_empty() or p_tag.is_empty():
		return 0
	
	var updated_count := 0
	for asset_id in p_asset_ids:
		var asset := p_registry.get_asset(asset_id)
		if asset.is_empty():
			continue
		var updated := AssetFilterService.remove_tag(asset, p_tag)
		if p_registry.update_asset(asset_id, {"tags": updated["tags"]}):
			updated_count += 1
	return updated_count
