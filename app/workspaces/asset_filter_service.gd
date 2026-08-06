# AssetFilterService — Logic for searching, tagging, favoriting, and filtering asset lists
class_name AssetFilterService
extends RefCounted


static func filter_assets(
	p_assets: Array,
	p_query: String = "",
	p_category: String = "",
	p_profile: String = "",
	p_favorites_only: bool = false,
	p_tags: Array = [],
	p_sort_by: String = "name"
) -> Array:
	var result: Array = []
	var query_lower := p_query.strip_edges().to_lower()
	
	for asset in p_assets:
		if not (asset is Dictionary):
			continue
		
		# Category check
		if not p_category.is_empty() and p_category != "all":
			if asset.get("category", "") != p_category:
				continue
		
		# Profile check
		if not p_profile.is_empty() and p_profile != "all":
			if asset.get("profile", "") != p_profile:
				continue
		
		# Favorites check
		if p_favorites_only and not asset.get("favorite", false):
			continue
		
		# Tags check
		if not p_tags.is_empty():
			var asset_tags: Array = asset.get("tags", [])
			var has_all_tags := true
			for required_tag in p_tags:
				if not (required_tag in asset_tags):
					has_all_tags = false
					break
			if not has_all_tags:
				continue
		
		# Query text search check
		if not query_lower.is_empty():
			var name: String = asset.get("name", "").to_lower()
			var path: String = asset.get("path", "").to_lower()
			var tags_str: String = " ".join(asset.get("tags", [])).to_lower()
			if not (query_lower in name or query_lower in path or query_lower in tags_str):
				continue
		
		result.append(asset.duplicate(true))
	
	# Sorting
	if p_sort_by == "name":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("name", "").casecmp_to(b.get("name", "")) < 0
		)
	elif p_sort_by == "category":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("category", "").casecmp_to(b.get("category", "")) < 0
		)
	elif p_sort_by == "created_at":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("created_at", "").casecmp_to(b.get("created_at", "")) < 0
		)
	
	return result


static func toggle_favorite(p_asset_data: Dictionary) -> Dictionary:
	var updated := p_asset_data.duplicate(true)
	updated["favorite"] = not updated.get("favorite", false)
	return updated


static func add_tag(p_asset_data: Dictionary, p_tag: String) -> Dictionary:
	var updated := p_asset_data.duplicate(true)
	var tag_clean := p_tag.strip_edges().to_lower()
	if tag_clean.is_empty():
		return updated
	var tags: Array = updated.get("tags", []).duplicate()
	if not (tag_clean in tags):
		tags.append(tag_clean)
	updated["tags"] = tags
	return updated


static func remove_tag(p_asset_data: Dictionary, p_tag: String) -> Dictionary:
	var updated := p_asset_data.duplicate(true)
	var tag_clean := p_tag.strip_edges().to_lower()
	var tags: Array = updated.get("tags", []).duplicate()
	if tag_clean in tags:
		tags.erase(tag_clean)
	updated["tags"] = tags
	return updated
