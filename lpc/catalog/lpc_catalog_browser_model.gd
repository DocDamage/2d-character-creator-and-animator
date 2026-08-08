# LpcCatalogBrowserModel -- Staged, virtualized catalog queries with explicit selection readiness.
class_name LpcCatalogBrowserModel
extends RefCounted

const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")

var _catalog: Dictionary = {}
var _loaded_shards: Dictionary = {}


func load_catalog(catalog: Dictionary) -> Dictionary:
	_catalog = catalog.duplicate(true)
	_loaded_shards = {"index": true, "rows": true}
	if not (catalog.get("validation_errors", []) as Array).is_empty():
		return {"success": false, "errors": ["Catalog has validation errors and cannot be browsed."], "loaded_shards": loaded_shards()}
	return {"success": true, "errors": [], "loaded_shards": loaded_shards()}


func load_shard(shard_id: String) -> Dictionary:
	if _catalog.is_empty(): return {"success": false, "errors": ["Load a catalog before requesting a shard."]}
	if shard_id not in ["layouts", "palettes", "credits", "thumbnails"]:
		return {"success": false, "errors": ["Unknown catalog shard '%s'." % shard_id]}
	_loaded_shards[shard_id] = true
	return {"success": true, "shard_id": shard_id, "data": shard_data(shard_id), "errors": []}


func loaded_shards() -> Array[String]:
	var result: Array[String] = []
	for shard_id in _loaded_shards:
		if bool(_loaded_shards[shard_id]): result.append(str(shard_id))
	result.sort()
	return result


func search(query: String = "", filters: Dictionary = {}, offset: int = 0, limit: int = 60) -> Dictionary:
	if _catalog.is_empty(): return {"success": false, "errors": ["Load a catalog before searching."], "items": []}
	var normalized_query := query.strip_edges().to_lower()
	var family_id := str(filters.get("body_family_id", ""))
	var type_name := str(filters.get("type_name", "")).to_lower()
	var policy_id := str(filters.get("policy_id", ""))
	var items: Array = []
	for raw_row in _catalog.get("rows", []):
		if not raw_row is Dictionary: continue
		var row: Dictionary = raw_row
		var asset_id := str(row.get("asset_id", ""))
		var asset: Dictionary = (_catalog.get("assets", {}) as Dictionary).get(asset_id, {})
		if asset.is_empty(): continue
		if not normalized_query.is_empty() and not _searchable_text(asset).contains(normalized_query): continue
		if not family_id.is_empty() and family_id not in asset.get("body_family_ids", []): continue
		if not type_name.is_empty() and str(asset.get("type_name", "")).to_lower() != type_name: continue
		if not policy_id.is_empty() and not LicenseResolverScript.resolve_asset(asset, policy_id).get("success", false): continue
		items.append(_light_item(asset))
	items.sort_custom(func(a, b): return str(a.get("asset_id", "")) < str(b.get("asset_id", "")))
	var start := clampi(offset, 0, items.size())
	var end := clampi(start + clampi(limit, 1, 250), start, items.size())
	return {"success": true, "errors": [], "items": items.slice(start, end), "total": items.size(), "offset": start, "limit": limit, "has_more": end < items.size()}


func selection_status(asset_ids: Array, policy_id: String) -> Dictionary:
	if not _loaded_shards.get("credits", false):
		return {"ready": false, "errors": ["Load credit and license data before selecting catalog art."], "credit_manifest": {}}
	if not _loaded_shards.get("layouts", false):
		return {"ready": false, "errors": ["Load layout data before selecting catalog art."], "credit_manifest": {}}
	var assets: Array = []
	var errors: Array[String] = []
	for asset_id in asset_ids:
		var asset: Dictionary = (_catalog.get("assets", {}) as Dictionary).get(str(asset_id), {})
		if asset.is_empty(): errors.append("Unknown asset '%s'." % asset_id)
		else: assets.append(asset)
	if not errors.is_empty(): return {"ready": false, "errors": errors, "credit_manifest": {}}
	var manifest := LicenseResolverScript.exact_credit_manifest(assets, policy_id)
	return {"ready": bool(manifest.get("success", false)), "errors": manifest.get("errors", []), "credit_manifest": manifest}


func shard_data(shard_id: String) -> Variant:
	match shard_id:
		"layouts": return (_catalog.get("layouts", {}) as Dictionary).duplicate(true)
		"palettes": return (_catalog.get("palettes", []) as Array).duplicate(true)
		"credits":
			var credits: Dictionary = {}
			for asset_id in (_catalog.get("assets", {}) as Dictionary):
				var asset: Dictionary = (_catalog.get("assets", {}) as Dictionary)[asset_id]
				credits[asset_id] = {"credits": asset.get("credits", []), "license_options": asset.get("license_options", [])}
			return credits
		"thumbnails":
			var paths: Dictionary = {}
			for asset_id in (_catalog.get("assets", {}) as Dictionary): paths[asset_id] = str(((_catalog.get("assets", {}) as Dictionary)[asset_id] as Dictionary).get("source_relative_path", ""))
			return paths
	return {}


func _light_item(asset: Dictionary) -> Dictionary:
	return {"asset_id": str(asset.get("asset_id", "")), "type_name": str(asset.get("type_name", "")), "body_family_ids": (asset.get("body_family_ids", []) as Array).duplicate(), "layer_group": str(asset.get("layer_group", "")), "thumbnail_path": str(asset.get("source_relative_path", "")), "layout_id": str(asset.get("layout_id", ""))}


func _searchable_text(asset: Dictionary) -> String:
	var terms: Array[String] = [str(asset.get("asset_id", "")), str(asset.get("upstream_item_id", "")), str(asset.get("type_name", "")), str(asset.get("layer_group", ""))]
	for alias in asset.get("upstream_aliases", []): terms.append(str(alias))
	return " ".join(terms).to_lower()
