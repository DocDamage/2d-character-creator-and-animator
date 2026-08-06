# CharacterPaletteDefinition -- Named serializable color-channel collection for character parts.
class_name CharacterPaletteDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var palette_id: String = ""
var display_name: String = ""
var channels: Dictionary = {}


func _init(p_id: String = "", p_name: String = "") -> void:
	palette_id = p_id.strip_edges()
	display_name = p_name.strip_edges()


func set_channel(channel_id: String, value: Variant) -> bool:
	if channel_id.strip_edges().is_empty(): return false
	channels[channel_id.strip_edges()] = value
	return true


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "palette_id": palette_id, "display_name": display_name, "channels": channels.duplicate(true)}


func from_dict(data: Dictionary) -> CharacterPaletteDefinition:
	palette_id = str(data.get("palette_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	channels = (data.get("channels", {}) as Dictionary).duplicate(true)
	return self


func validate() -> Array:
	var errors: Array = []
	if palette_id.is_empty(): errors.append("Character palette requires palette_id.")
	if display_name.is_empty(): errors.append("Character palette '%s' requires display_name." % palette_id)
	if channels.is_empty(): errors.append("Character palette '%s' requires at least one channel." % palette_id)
	return errors
