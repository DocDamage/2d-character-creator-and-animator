# CharacterLayerList -- Layer list with direct operating-system artwork drop support.
class_name CharacterLayerList
extends ItemList

signal files_dropped(paths: Array)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not _extract_image_paths(data).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var paths := _extract_image_paths(data)
	if not paths.is_empty(): files_dropped.emit(paths)


func _extract_image_paths(data: Variant) -> Array:
	var paths: Array = []
	if data is PackedStringArray or data is Array:
		for value in data:
			var path := str(value)
			if _is_supported_drop_path(path): paths.append(path)
	elif data is Dictionary:
		var dict: Dictionary = data
		for value in dict.get("files", []):
			var path := str(value)
			if _is_supported_drop_path(path): paths.append(path)
		var path := str(dict.get("path", ""))
		if _is_supported_drop_path(path) and path not in paths: paths.append(path)
	return paths


func _is_supported_drop_path(path: String) -> bool:
	if ImageImporter.is_supported_format(path):
		return true
	var absolute := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	return DirAccess.dir_exists_absolute(absolute)
