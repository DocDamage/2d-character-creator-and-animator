# Opens every legacy export artifact through an independent reader or decoder.
extends Node

const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")
const RuntimePackageExporterScript = preload("res://export/project_format/runtime_package_exporter.gd")
const TextureAtlasPackerScript = preload("res://export/atlases/texture_atlas_packer.gd")
const ImageSequenceExporterScript = preload("res://export/image_sequences/image_sequence_exporter.gd")
const SpritesheetExporterScript = preload("res://export/spritesheets/spritesheet_exporter.gd")
const GifExporterScript = preload("res://export/gif/gif_exporter.gd")
const VideoExporterScript = preload("res://export/video/video_exporter.gd")
const GodotResourceExporterScript = preload("res://export/godot/godot_resource_exporter.gd")


func run_tests() -> Dictionary:
	var root := "user://qa_export_artifacts_%d" % Time.get_ticks_usec()
	var frames := [{"id": "red", "image": _image(Color.RED)}, {"id": "blue", "image": _image(Color.BLUE)}]
	var package := RuntimePackageScript.create({"project_id": "qa_export_hero", "facing_grid": {"direction_set": 4}}, {"name": "QA Export Hero"})
	var package_path := root.path_join("hero.chrpack")
	var package_export := RuntimePackageExporterScript.new().export_project(package.get("content", {}) as Dictionary, package_path, package.get("metadata", {}) as Dictionary)
	var atlas_layout := TextureAtlasPackerScript.new().pack(frames, Vector2i(16, 16), 1, 1)
	var repeated_atlas_layout := TextureAtlasPackerScript.new().pack(frames, Vector2i(16, 16), 1, 1)
	var atlas_images := TextureAtlasPackerScript.new().render_pages(atlas_layout)
	var atlas_path := root.path_join("atlas_preview.png")
	var atlas_saved := not atlas_images.is_empty() and (atlas_images[0] as Image).save_png(atlas_path) == OK
	var sequence_png := ImageSequenceExporterScript.new().export_frames(frames, root.path_join("sequence_png"), "png", 12.0)
	var sequence_webp := ImageSequenceExporterScript.new().export_frames(frames, root.path_join("sequence_webp"), "webp", 12.0)
	var spritesheet_json := SpritesheetExporterScript.new().export_frames(frames, root.path_join("sprites_json"), {"padding": 1, "extrusion": 1, "manifest_format": "json"})
	var spritesheet_xml := SpritesheetExporterScript.new().export_frames(frames, root.path_join("sprites_xml"), {"padding": 1, "extrusion": 1, "manifest_format": "xml"})
	var gif := GifExporterScript.new().export_frames(frames, root.path_join("walk.gif"), 12.0)
	var video_exporter := VideoExporterScript.new()
	var mp4 := video_exporter.export_sequence(root.path_join("sequence_png/%04d.png"), root.path_join("walk.mp4"), 12.0)
	var webm := video_exporter.export_sequence(root.path_join("sequence_png/%04d.png"), root.path_join("walk.webm"), 12.0)
	var native := GodotResourceExporterScript.new().export_package(package, root.path_join("godot"), "hero")
	var package_loaded := RuntimePackageScript.load(package_path)
	var png_manifest := _json(root.path_join("sequence_png/manifest.json"))
	var webp_manifest := _json(root.path_join("sequence_webp/manifest.json"))
	var json_manifest := _json(root.path_join("sprites_json/spritesheet.json"))
	var native_resource := load(root.path_join("godot/hero.tres")) as Resource
	var native_scene := load(root.path_join("godot/hero.tscn")) as PackedScene
	var native_instance := native_scene.instantiate() if native_scene != null else null
	var spritesheet_checks := {
		"exports": bool(spritesheet_json.get("success", false)) and bool(spritesheet_xml.get("success", false)),
		"json": _spritesheet_json_valid(json_manifest),
		"extrusion": _spritesheet_has_extrusion(root.path_join("sprites_json/atlas_00.png"), json_manifest),
		"xml": _spritesheet_xml_valid(root.path_join("sprites_xml/spritesheet.xml")),
		"image": _image_has_size(root.path_join("sprites_json/atlas_00.png"), Vector2i(2048, 2048)),
	}
	var checks := {
		"package": bool(package_export.get("success", false)) and bool(package_loaded.get("success", false)) and str((package_loaded.get("package", {}) as Dictionary).get("content", {}).get("project_id", "")) == "qa_export_hero",
		"atlas": bool(atlas_layout.get("success", false)) and _layout_signature(atlas_layout) == _layout_signature(repeated_atlas_layout) and atlas_saved and _atlas_has_extrusion(atlas_layout, atlas_images) and _image_has_size(atlas_path, Vector2i(16, 16)),
		"sequences": bool(sequence_png.get("success", false)) and bool(sequence_webp.get("success", false)) and _sequence_manifest_valid(png_manifest, "png") and _sequence_manifest_valid(webp_manifest, "webp") and _image_has_size(root.path_join("sequence_png/0000.png"), Vector2i(8, 8)) and _image_has_size(root.path_join("sequence_webp/0001.webp"), Vector2i(8, 8)),
		"spritesheets": _all_true(spritesheet_checks),
		"gif": bool(gif.get("success", false)) and _has_magic(root.path_join("walk.gif"), 0, "GIF89a".to_ascii_buffer()) and _video_valid(root.path_join("walk.gif"), 8, 8),
		"mp4": bool(mp4.get("success", false)) and _has_magic(root.path_join("walk.mp4"), 4, "ftyp".to_ascii_buffer()) and _video_valid(root.path_join("walk.mp4"), 8, 8),
		"webm": bool(webm.get("success", false)) and _has_magic(root.path_join("walk.webm"), 0, PackedByteArray([0x1A, 0x45, 0xDF, 0xA3])) and _video_valid(root.path_join("walk.webm"), 8, 8),
		"native": bool(native.get("success", false)) and native_resource != null and native_scene != null and native_instance != null,
	}
	var passed := true
	for passed_check in checks.values():
		passed = passed and bool(passed_check)
	if native_instance != null:
		native_instance.free()
	if passed:
		print("  PASS: Runtime, image, spritesheet, GIF, video, and native Godot exports open through independent readers")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Export artifact validation failed: checks=%s spritesheet_checks=%s package=%s atlas=%s png=%s webp=%s sprite_json=%s sprite_xml=%s gif=%s mp4=%s webm=%s native=%s" % [checks, spritesheet_checks, package_export, atlas_layout, sequence_png, sequence_webp, spritesheet_json, spritesheet_xml, gif, mp4, webm, native]]}


func _image(colour: Color) -> Image:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(2, 6):
		for x in range(2, 6):
			image.set_pixel(x, y, colour)
	return image


func _atlas_has_extrusion(layout: Dictionary, pages: Array) -> bool:
	if pages.is_empty() or (layout.get("pages", []) as Array).is_empty():
		return false
	var placement: Dictionary = ((layout.get("pages", []) as Array)[0].get("placements", []) as Array)[0]
	var rect: Array = placement.get("rect", [])
	if rect.size() != 4:
		return false
	var image := pages[0] as Image
	return image.get_pixel(int(rect[0]) - 1, int(rect[1])).is_equal_approx(image.get_pixel(int(rect[0]), int(rect[1])))


func _layout_signature(layout: Dictionary) -> String:
	var pages: Array = []
	for page in layout.get("pages", []) as Array:
		var placements: Array = []
		for placement in page.get("placements", []) as Array:
			placements.append({"id": placement.get("id", ""), "rect": placement.get("rect", []), "outer_rect": placement.get("outer_rect", [])})
		pages.append(placements)
	return JSON.stringify(pages)


func _image_has_size(path: String, expected: Vector2i) -> bool:
	var image := Image.load_from_file(path)
	return image != null and not image.is_empty() and image.get_size() == expected


func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	return json.get_data() as Dictionary if error == OK and json.get_data() is Dictionary else {}


func _spritesheet_json_valid(manifest: Dictionary) -> bool:
	var pages := manifest.get("pages", []) as Array
	if str(manifest.get("format", "")) != "spritesheet" or int(manifest.get("padding", 0)) != 1 or int(manifest.get("extrusion", 0)) != 1 or pages.size() != 1:
		return false
	var sprites := pages[0].get("sprites", {}) as Dictionary
	return sprites.has("red") and sprites.has("blue") and _rect_matches(sprites["red"].get("source_rect", []) as Array, [2, 2, 4, 4]) and _rect_matches(sprites["blue"].get("source_rect", []) as Array, [2, 2, 4, 4])


func _spritesheet_has_extrusion(path: String, manifest: Dictionary) -> bool:
	var image := Image.load_from_file(path)
	var pages := manifest.get("pages", []) as Array
	if image == null or pages.is_empty():
		return false
	var rect: Array = (pages[0].get("sprites", {}) as Dictionary).get("blue", {}).get("rect", [])
	return rect.size() == 4 and image.get_pixel(int(rect[0]) - 1, int(rect[1])).is_equal_approx(image.get_pixel(int(rect[0]), int(rect[1])))


func _sequence_manifest_valid(manifest: Dictionary, extension: String) -> bool:
	var frames := manifest.get("frames", []) as Array
	return str(manifest.get("format", "")) == "image_sequence" and is_equal_approx(float(manifest.get("fps", 0.0)), 12.0) and frames.size() == 2 and str(frames[0].get("file", "")) == "0000." + extension and str(frames[1].get("file", "")) == "0001." + extension


func _rect_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if int(actual[index]) != int(expected[index]):
			return false
	return true


func _spritesheet_xml_valid(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var content := file.get_as_text()
	file.close()
	return "<spritesheets>" in content and "<sprite id=\"red\"" in content and "<sprite id=\"blue\"" in content


func _has_magic(path: String, offset: int, expected: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	file.seek(offset)
	var actual := file.get_buffer(expected.size())
	file.close()
	return actual == expected


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _video_valid(path: String, width: int, height: int) -> bool:
	var output: Array = []
	var code := OS.execute("ffprobe", PackedStringArray(["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,width,height", "-of", "default=noprint_wrappers=1", ProjectSettings.globalize_path(path)]), output, true)
	var details := "\n".join(output)
	return code == 0 and "codec_name=" in details and "width=%d" % width in details and "height=%d" % height in details
