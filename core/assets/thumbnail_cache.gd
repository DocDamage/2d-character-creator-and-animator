# ThumbnailCache — Generates, caches, and invalidates asset preview thumbnails
class_name ThumbnailCache
extends Node

signal thumbnail_generated(asset_id: String, texture: ImageTexture)

const DEFAULT_THUMB_SIZE := Vector2i(64, 64)
const DISK_CACHE_DIR := "user://cache/thumbnails/"

var _memory_cache: Dictionary = {} # asset_id -> ImageTexture


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("cache/thumbnails"):
		dir.make_dir_recursive("cache/thumbnails")


func get_thumbnail(p_asset_data: Dictionary, p_size: Vector2i = DEFAULT_THUMB_SIZE) -> ImageTexture:
	var asset_id: String = p_asset_data.get("asset_id", "")
	if asset_id.is_empty():
		return null
	
	if _memory_cache.has(asset_id):
		return _memory_cache[asset_id]
	
	var checksum: String = p_asset_data.get("checksum", asset_id)
	var disk_path := DISK_CACHE_DIR + checksum + "_" + str(p_size.x) + "x" + str(p_size.y) + ".png"
	
	if FileAccess.file_exists(disk_path):
		var img := Image.load_from_file(disk_path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_memory_cache[asset_id] = tex
			return tex
	
	var path: String = p_asset_data.get("path", "")
	if not FileAccess.file_exists(path):
		return _generate_fallback_thumbnail(p_size)
	
	var source_img := Image.load_from_file(path)
	if source_img == null or source_img.is_empty():
		return _generate_fallback_thumbnail(p_size)
	
	source_img.resize(p_size.x, p_size.y, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(source_img)
	_memory_cache[asset_id] = texture
	
	source_img.save_png(disk_path)
	thumbnail_generated.emit(asset_id, texture)
	return texture


func has_thumbnail(p_asset_id: String) -> bool:
	return _memory_cache.has(p_asset_id)


func invalidate_thumbnail(p_asset_id: String) -> void:
	if _memory_cache.has(p_asset_id):
		_memory_cache.erase(p_asset_id)


func clear_cache() -> void:
	_memory_cache.clear()


func get_cache_count() -> int:
	return _memory_cache.size()


func _generate_fallback_thumbnail(p_size: Vector2i) -> ImageTexture:
	var img := Image.create(p_size.x, p_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.25, 1.0))
	return ImageTexture.create_from_image(img)
