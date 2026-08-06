# SpritesheetExporter -- Trims frames, packs atlas pages, and writes JSON or XML manifests.
class_name SpritesheetExporter
extends RefCounted

const TextureAtlasPackerScript = preload("res://export/atlases/texture_atlas_packer.gd")


func export_frames(frames: Array, output_directory: String, options: Dictionary = {}) -> Dictionary:
	var prepared := _prepare_frames(frames, bool(options.get("trim", true)))
	var packer := TextureAtlasPackerScript.new()
	var layout := packer.pack(prepared, options.get("max_size", Vector2i(2048, 2048)), int(options.get("padding", 1)), int(options.get("extrusion", 0)))
	if not bool(layout.get("success", false)):
		return layout
	var absolute := ProjectSettings.globalize_path(output_directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return {"success": false, "errors": ["cannot create spritesheet directory"]}
	var images := packer.render_pages(layout)
	var page_files: Array = []
	for page_index in range(images.size()):
		var filename := "atlas_%02d.png" % page_index
		var result := (images[page_index] as Image).save_png(output_directory.path_join(filename))
		if result != OK:
			return {"success": false, "errors": ["cannot save atlas image"]}
		page_files.append(filename)
	var manifest := _manifest(layout, page_files)
	var manifest_format := str(options.get("manifest_format", "json")).to_lower()
	var manifest_path := output_directory.path_join("spritesheet." + manifest_format)
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["cannot save spritesheet manifest"]}
	file.store_string(_as_xml(manifest) if manifest_format == "xml" else JSON.stringify(manifest, "\t"))
	file.close()
	return {"success": true, "pages": page_files, "manifest": manifest_path, "layout": manifest}


func _prepare_frames(frames: Array, trim: bool) -> Array:
	var prepared: Array = []
	for index in range(frames.size()):
		var frame: Dictionary = (frames[index] as Dictionary).duplicate(true)
		var image: Image = frame.get("image")
		if image == null:
			continue
		frame["id"] = str(frame.get("id", index))
		if trim:
			var result := _trim(image)
			frame["image"] = result["image"]
			frame["source_rect"] = result["source_rect"]
		else:
			frame["source_rect"] = [0, 0, image.get_width(), image.get_height()]
		prepared.append(frame)
	return prepared


func _trim(image: Image) -> Dictionary:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return {"image": Image.create_empty(1, 1, false, Image.FORMAT_RGBA8), "source_rect": [0, 0, 0, 0]}
	var rect := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	return {"image": image.get_region(rect), "source_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}


func _manifest(layout: Dictionary, page_files: Array) -> Dictionary:
	var pages: Array = []
	for page_index in range((layout.get("pages", []) as Array).size()):
		var page: Dictionary = layout["pages"][page_index]
		var sprites: Dictionary = {}
		for placement in page.get("placements", []) as Array:
			sprites[str((placement as Dictionary).get("id", ""))] = {
				"rect": placement.get("rect", []),
				"source_rect": placement.get("source_rect", []),
			}
		pages.append({"image": page_files[page_index], "size": [page["size"].x, page["size"].y], "sprites": sprites})
	return {"format": "spritesheet", "padding": layout.get("padding", 0), "extrusion": layout.get("extrusion", 0), "pages": pages}


func _as_xml(manifest: Dictionary) -> String:
	var lines := ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<spritesheets>"]
	for page in manifest.get("pages", []) as Array:
		lines.append("  <page image=\"%s\">" % _xml(str(page.get("image", ""))))
		for sprite_id in (page.get("sprites", {}) as Dictionary).keys():
			var rect: Array = page["sprites"][sprite_id].get("rect", [])
			lines.append("    <sprite id=\"%s\" x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" />" % [_xml(str(sprite_id)), int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])])
		lines.append("  </page>")
	lines.append("</spritesheets>")
	return "\n".join(lines) + "\n"


func _xml(value: String) -> String:
	return value.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")
