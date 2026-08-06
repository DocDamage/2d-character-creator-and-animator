# PixelImportProfile — Import profile settings for pixel art assets
class_name PixelImportProfile
extends RefCounted

const PROFILE_NAME := "pixel"
const FILTER_MODE := CanvasItem.TEXTURE_FILTER_NEAREST
const MIPMAPS_ENABLED := false
const SNAP_TO_PIXEL := true
const ALPHA_THRESHOLD := 0.5


static func get_profile_data() -> Dictionary:
	return {
		"profile_name": PROFILE_NAME,
		"filter_mode": FILTER_MODE,
		"mipmaps": MIPMAPS_ENABLED,
		"snap_to_pixel": SNAP_TO_PIXEL,
		"alpha_threshold": ALPHA_THRESHOLD
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
