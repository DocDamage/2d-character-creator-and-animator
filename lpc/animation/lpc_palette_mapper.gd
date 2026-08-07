# LpcPaletteMapper -- Applies only explicit exact color lookups to a copied LPC frame.
class_name LpcPaletteMapper
extends RefCounted


static func apply(source: Image, mapping: Dictionary) -> Image:
	var output := source.duplicate()
	if mapping.is_empty():
		return output
	for y in range(output.get_height()):
		for x in range(output.get_width()):
			var color: Color = output.get_pixel(x, y)
			var replacement: Variant = _replacement(mapping, color)
			if replacement != null:
				output.set_pixel(x, y, replacement)
	return output


static func mapping_for(profile: Dictionary, asset_id: String) -> Dictionary:
	var palettes: Dictionary = profile.get("palette_state", {})
	var value: Variant = palettes.get(asset_id, palettes.get("default", {}))
	if value is Dictionary:
		var entry: Dictionary = value
		return (entry.get("mappings", entry.get("map", entry)) as Dictionary).duplicate(true)
	return {}


static func audit(source: Image, output: Image) -> Dictionary:
	var source_colors: Dictionary = _colors(source)
	var output_colors: Dictionary = _colors(output)
	var extras: Array[String] = []
	for color in output_colors:
		if not source_colors.has(color):
			extras.append(str(color))
	extras.sort()
	return {"source_color_subset": extras.is_empty(), "unexpected_colors": extras, "source_color_count": source_colors.size(), "output_color_count": output_colors.size()}


static func _replacement(mapping: Dictionary, color: Color) -> Variant:
	var value: Variant = mapping.get(color.to_html(true).to_lower(), mapping.get("#" + color.to_html(true).to_lower(), null))
	if value == null:
		return null
	if value is Color:
		return value as Color
	var text := str(value).strip_edges()
	if text.begins_with("#"):
		text = text.substr(1)
	if text.length() not in [6, 8]:
		return null
	return Color(text)


static func _colors(image: Image) -> Dictionary:
	var colors: Dictionary = {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			colors[image.get_pixel(x, y).to_html(true).to_lower()] = true
	return colors
