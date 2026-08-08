# LpcPixelCanvasModel -- Lossless raster editing with one undoable command per authoring operation.
class_name LpcPixelCanvasModel
extends RefCounted

const LayoutScript = preload("res://lpc/layout/lpc_sheet_layout.gd")
const PaletteMapperScript = preload("res://lpc/animation/lpc_palette_mapper.gd")
const DerivativeStoreScript = preload("res://lpc/pixels/lpc_derivative_store.gd")
const CelTimelineScript = preload("res://lpc/cels/lpc_cel_timeline.gd")

var image: Image
var source_context: Dictionary = {}
var current_derivative: Dictionary = {}
var exact_palette: Array[String] = []
var zoom := 8
var selection: Dictionary = {}
var clipboard: Dictionary = {}
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _stroke_before: Image
var _stroke_description := "Pixel stroke"


func open_image(next_image: Image, context: Dictionary = {}) -> bool:
	if next_image == null or next_image.is_empty(): return false
	image = next_image.duplicate(); source_context = context.duplicate(true); current_derivative = context.get("derivative", {}).duplicate(true)
	selection.clear(); _undo.clear(); _redo.clear(); _stroke_before = null
	return true


func open_native_frame(catalog: Dictionary, profile: Dictionary, instance_id: String, animation_id: String = "walk", direction_id: String = "down", logical_frame: int = 0) -> Dictionary:
	var selection_record: Dictionary = {}
	for raw in profile.get("selections", []):
		if raw is Dictionary and str((raw as Dictionary).get("instance_id", "")) == instance_id: selection_record = raw; break
	var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str(selection_record.get("asset_id", "")), {})
	var layout: Dictionary = (catalog.get("layouts", {}) as Dictionary).get(str(asset.get("layout_id", "")), {})
	var reference := LayoutScript.frame_ref(asset, layout, animation_id, direction_id, logical_frame)
	if asset.is_empty() or not bool(reference.get("success", false)): return {"success": false, "errors": reference.get("errors", ["Could not resolve a native LPC source frame."])}
	var source_path := str(catalog.get("source_root", "")).path_join(str(asset.get("source_relative_path", "")))
	var source := Image.load_from_file(source_path)
	var values: Array = reference.get("source_rect", [])
	if source == null or source.is_empty() or values.size() != 4: return {"success": false, "errors": ["Could not load the selected immutable LPC frame."]}
	var rect := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
	if rect.end.x > source.get_width() or rect.end.y > source.get_height(): return {"success": false, "errors": ["The LPC frame reference falls outside its source PNG."]}
	var frame := PaletteMapperScript.apply(source.get_region(rect), PaletteMapperScript.mapping_for(profile, str(asset.get("asset_id", ""))))
	open_image(frame, {"source_asset_id": asset.get("asset_id", ""), "source_hash": asset.get("source_sha256", ""), "source_frame_reference": reference})
	return {"success": true, "errors": [], "image": image}


func set_exact_palette(colors: Array) -> void:
	exact_palette.clear()
	for value in colors:
		var color: Color = value as Color if value is Color else Color(str(value))
		var key := color.to_html(true).to_lower()
		if key not in exact_palette: exact_palette.append(key)


func begin_stroke(description: String = "Pixel stroke") -> bool:
	if image == null or image.is_empty() or _stroke_before != null: return false
	_stroke_before = image.duplicate(); _stroke_description = description
	return true


func paint_pixel(point: Vector2i, color: Color, eraser: bool = false) -> bool:
	if image == null or _stroke_before == null or not _in_bounds(point): return false
	if not eraser and not exact_palette.is_empty() and color.to_html(true).to_lower() not in exact_palette: return false
	image.set_pixelv(point, Color(0, 0, 0, 0) if eraser else color)
	return true


func end_stroke() -> bool:
	if _stroke_before == null: return false
	var before := _stroke_before; _stroke_before = null
	return _record(before, _stroke_description)


func fill(point: Vector2i, color: Color) -> bool:
	if image == null or not _in_bounds(point) or (not exact_palette.is_empty() and color.to_html(true).to_lower() not in exact_palette): return false
	var before := image.duplicate()
	if selection.is_empty():
		_flood_fill(point, color)
	else:
		for key in selection:
			var p := _point(str(key)); if _in_bounds(p): image.set_pixelv(p, color)
	return _record(before, "Fill")


func select_contiguous(point: Vector2i) -> int:
	selection.clear()
	if image == null or not _in_bounds(point): return 0
	var target: Color = image.get_pixelv(point); var pending: Array[Vector2i] = [point]; var visited: Dictionary = {}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back(); var key: String = _key(current)
		if visited.has(key) or not _in_bounds(current) or image.get_pixelv(current) != target: continue
		visited[key] = true; selection[key] = true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: pending.append(current + offset)
	return selection.size()


func select_noncontiguous(point: Vector2i) -> int:
	selection.clear()
	if image == null or not _in_bounds(point): return 0
	var target := image.get_pixelv(point)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y) == target: selection[_key(Vector2i(x, y))] = true
	return selection.size()


func select_all() -> void:
	selection.clear()
	if image == null: return
	for y in range(image.get_height()): for x in range(image.get_width()): selection[_key(Vector2i(x, y))] = true


func copy_selection() -> Dictionary:
	if image == null or selection.is_empty(): return {}
	var bounds := _selection_bounds(); var copy := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8); copy.fill(Color(0, 0, 0, 0))
	for key in selection:
		var source := _point(str(key)); copy.set_pixelv(source - bounds.position, image.get_pixelv(source))
	clipboard = {"image": copy, "origin": [bounds.position.x, bounds.position.y]}
	return clipboard


func paste(at: Vector2i, copy_only: bool = true) -> bool:
	if image == null or not clipboard.get("image", null) is Image: return false
	var before := image.duplicate(); var copied: Image = clipboard.image
	for y in range(copied.get_height()):
		for x in range(copied.get_width()):
			var target := at + Vector2i(x, y); if _in_bounds(target): image.set_pixelv(target, copied.get_pixel(x, y))
	return _record(before, "Paste" if copy_only else "Move selection")


func move_selection(delta: Vector2i) -> bool:
	if selection.is_empty() or copy_selection().is_empty(): return false
	var before := image.duplicate(); var bounds := _selection_bounds()
	for key in selection: image.set_pixelv(_point(str(key)), Color(0, 0, 0, 0))
	var copied: Image = clipboard.image
	for y in range(copied.get_height()):
		for x in range(copied.get_width()):
			var target := bounds.position + delta + Vector2i(x, y); if _in_bounds(target): image.set_pixelv(target, copied.get_pixel(x, y))
	var next: Dictionary = {}
	for key in selection: next[_key(_point(str(key)) + delta)] = true
	selection = next
	return _record(before, "Move selection")


func undo() -> bool:
	if _undo.is_empty(): return false
	var command: Dictionary = _undo.pop_back(); _redo.append(command); image = command.before.duplicate(); return true


func redo() -> bool:
	if _redo.is_empty(): return false
	var command: Dictionary = _redo.pop_back(); _undo.append(command); image = command.after.duplicate(); return true


func commit_to_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	if image == null or image.is_empty(): return {"success": false, "errors": ["Open an image before committing a cel."]}
	var metadata := source_context.duplicate(true); metadata["parent_derivative"] = current_derivative; metadata["operation"] = str(options.get("operation", "pixel_edit")); metadata["creation_tool"] = "lpc_pixel_editor"
	var stored := DerivativeStoreScript.store_image(profile, image, metadata)
	if not bool(stored.get("success", false)): return stored
	var next := DerivativeStoreScript.attach(profile, stored.record)
	if bool(options.get("create_cel", true)):
		var cel_result := CelTimelineScript.add_cel(next, stored.record, options)
		if not bool(cel_result.get("success", false)): return cel_result
		next = cel_result.profile
	current_derivative = stored.record.duplicate(true)
	return {"success": true, "errors": [], "profile": next, "derivative": stored.record, "cel": CelTimelineScript.evaluate(next, str(options.get("target_id", "")), int(options.get("frame", 0))).get("cels", [])}


func export_png(path: String) -> bool:
	return image != null and not image.is_empty() and image.save_png(path) == OK


func import_png(path: String) -> bool:
	var imported := Image.load_from_file(path)
	return open_image(imported, source_context) if imported != null and not imported.is_empty() else false


func palette_audit() -> Dictionary:
	return DerivativeStoreScript.palette_audit(image) if image != null else {}


func command_count() -> int:
	return _undo.size()


func _flood_fill(start: Vector2i, color: Color) -> void:
	var target: Color = image.get_pixelv(start); if target == color: return
	var pending: Array[Vector2i] = [start]; var visited: Dictionary = {}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back(); var key: String = _key(current)
		if visited.has(key) or not _in_bounds(current) or image.get_pixelv(current) != target: continue
		visited[key] = true; image.set_pixelv(current, color)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: pending.append(current + offset)


func _record(before: Image, description: String) -> bool:
	if before.get_data() == image.get_data(): return false
	_undo.append({"before": before, "after": image.duplicate(), "description": description}); _redo.clear(); return true


func _selection_bounds() -> Rect2i:
	var min_x := image.get_width(); var min_y := image.get_height(); var max_x := -1; var max_y := -1
	for key in selection:
		var point := _point(str(key)); min_x = mini(min_x, point.x); min_y = mini(min_y, point.y); max_x = maxi(max_x, point.x); max_y = maxi(max_y, point.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _in_bounds(point: Vector2i) -> bool:
	return image != null and point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height()


func _key(point: Vector2i) -> String: return "%d:%d" % [point.x, point.y]
func _point(value: String) -> Vector2i:
	var parts := value.split(":"); return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i.ZERO
