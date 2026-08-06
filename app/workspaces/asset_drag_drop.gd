# AssetDragDrop — Utilities for handling OS file drag-in and internal canvas asset drag payloads
class_name AssetDragDrop
extends RefCounted

const DRAG_TYPE_ASSET := "asset_drag_payload"


static func create_asset_drag_payload(p_asset_data: Dictionary) -> Dictionary:
	return {
		"type": DRAG_TYPE_ASSET,
		"asset_id": p_asset_data.get("asset_id", ""),
		"path": p_asset_data.get("path", ""),
		"category": p_asset_data.get("category", ""),
		"asset_data": p_asset_data.duplicate(true)
	}


static func is_valid_asset_drag(p_drag_data: Variant) -> bool:
	if not (p_drag_data is Dictionary):
		return false
	var dict: Dictionary = p_drag_data
	return dict.get("type", "") == DRAG_TYPE_ASSET and dict.has("asset_id")


static func extract_asset_id(p_drag_data: Variant) -> String:
	if is_valid_asset_drag(p_drag_data):
		return (p_drag_data as Dictionary).get("asset_id", "")
	return ""


static func can_drop_files(p_files: PackedStringArray) -> bool:
	if p_files.is_empty():
		return false
	for file_path in p_files:
		if ImageImporter.is_supported_format(file_path):
			return true
	return false


static func import_dropped_files(p_files: PackedStringArray, p_registry: AssetRegistry) -> Array:
	var imported_assets: Array = []
	if p_registry == null:
		return imported_assets
	
	for file_path in p_files:
		if ImageImporter.is_supported_format(file_path):
			var res := ImageImporter.import_image(file_path, p_registry)
			if not res.is_empty() and res.has("asset_id"):
				imported_assets.append(res)
	
	return imported_assets
