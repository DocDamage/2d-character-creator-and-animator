# SmoothImportProfile — Import profile settings for smooth/vector/high-res art assets
class_name SmoothImportProfile
extends RefCounted

const PROFILE_NAME := "smooth"
const FILTER_MODE := CanvasItem.TEXTURE_FILTER_LINEAR
const MIPMAPS_ENABLED := true
const SNAP_TO_PIXEL := false
const ANTI_ALIASING := true


static func get_profile_data() -> Dictionary:
	return {
		"profile_name": PROFILE_NAME,
		"filter_mode": FILTER_MODE,
		"mipmaps": MIPMAPS_ENABLED,
		"snap_to_pixel": SNAP_TO_PIXEL,
		"anti_aliasing": ANTI_ALIASING
	}


static func apply(p_asset_data: Dictionary) -> Dictionary:
	var updated := p_asset_data.duplicate(true)
	updated["profile"] = PROFILE_NAME
	if not updated.has("metadata"):
		updated["metadata"] = {}
	updated["metadata"]["texture_filter"] = FILTER_MODE
	updated["metadata"]["mipmaps"] = MIPMAPS_ENABLED
	updated["metadata"]["snap_to_pixel"] = SNAP_TO_PIXEL
	return updated
