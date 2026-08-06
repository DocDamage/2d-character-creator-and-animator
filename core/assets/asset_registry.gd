# AssetRegistry — Manages asset metadata, IDs, categories, and query lookups
class_name AssetRegistry
extends Node

signal asset_registered(asset_id: String, data: Dictionary)
signal asset_unregistered(asset_id: String)
signal asset_updated(asset_id: String, data: Dictionary)

const CATEGORY_SOURCE_ART := "source_art"
const CATEGORY_REFERENCE := "reference"
const CATEGORY_AUDIO := "audio"
const CATEGORY_PREVIEW := "preview"
const CATEGORY_EXPORT := "export"

const PROFILE_PIXEL := "pixel"
const PROFILE_SMOOTH := "smooth"

var _assets: Dictionary = {} # asset_id -> Dictionary
var _path_map: Dictionary = {} # relative_path -> asset_id


func register_asset(p_path: String, p_category: String = CATEGORY_SOURCE_ART, p_metadata: Dictionary = {}) -> Dictionary:
	if p_path.is_empty():
		return {}
	
	if _path_map.has(p_path):
		var existing_id: String = _path_map[p_path]
		return get_asset(existing_id)
	
	var asset_id: String = IDService.generate_id("ast")
	var asset_data: Dictionary = {
		"asset_id": asset_id,
		"path": p_path,
		"name": p_path.get_file().get_basename(),
		"category": p_category if not p_category.is_empty() else CATEGORY_SOURCE_ART,
		"profile": p_metadata.get("profile", PROFILE_PIXEL),
		"width": p_metadata.get("width", 0),
		"height": p_metadata.get("height", 0),
		"checksum": p_metadata.get("checksum", ""),
		"tags": p_metadata.get("tags", []),
		"favorite": p_metadata.get("favorite", false),
		"metadata": p_metadata.get("metadata", {}),
		"created_at": Time.get_datetime_string_from_system()
	}
	
	_assets[asset_id] = asset_data
	_path_map[p_path] = asset_id
	asset_registered.emit(asset_id, asset_data)
	return asset_data


func unregister_asset(p_asset_id: String) -> bool:
	if not _assets.has(p_asset_id):
		return false
	
	var asset_data: Dictionary = _assets[p_asset_id]
	var path: String = asset_data.get("path", "")
	_assets.erase(p_asset_id)
	if _path_map.has(path):
		_path_map.erase(path)
	
	asset_unregistered.emit(p_asset_id)
	return true


func get_asset(p_asset_id: String) -> Dictionary:
	return _assets.get(p_asset_id, {}).duplicate(true)


func get_asset_by_path(p_path: String) -> Dictionary:
	if _path_map.has(p_path):
		return get_asset(_path_map[p_path])
	return {}


func has_asset(p_asset_id: String) -> bool:
	return _assets.has(p_asset_id)


func list_assets(p_category_filter: String = "") -> Array:
	var result: Array = []
	for asset_id in _assets:
		var data: Dictionary = _assets[asset_id]
		if p_category_filter.is_empty() or data.get("category", "") == p_category_filter:
			result.append(data.duplicate(true))
	return result


func update_asset(p_asset_id: String, p_updates: Dictionary) -> bool:
	if not _assets.has(p_asset_id):
		return false
	
	var asset_data: Dictionary = _assets[p_asset_id]
	for key in p_updates:
		if key == "asset_id":
			continue
		if key == "path" and p_updates[key] != asset_data["path"]:
			_path_map.erase(asset_data["path"])
			_path_map[p_updates[key]] = p_asset_id
		asset_data[key] = p_updates[key]
	
	asset_updated.emit(p_asset_id, asset_data)
	return true


func clear_registry() -> void:
	_assets.clear()
	_path_map.clear()


func to_dict() -> Dictionary:
	return {
		"assets": _assets.duplicate(true)
	}


func from_dict(p_data: Dictionary) -> void:
	clear_registry()
	var assets_dict: Dictionary = p_data.get("assets", {})
	for asset_id in assets_dict:
		var item: Dictionary = assets_dict[asset_id]
		_assets[asset_id] = item.duplicate(true)
		var path: String = item.get("path", "")
		if not path.is_empty():
			_path_map[path] = asset_id
