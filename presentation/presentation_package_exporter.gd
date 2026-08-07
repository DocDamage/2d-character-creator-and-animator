# PresentationPackageExporter -- Client-facing turntable data, visemes, outfit sheets, pose boards, and approvals.
class_name PresentationPackageExporter
extends RefCounted

const RendererScript = preload("res://export/review/character_raster_renderer.gd")
const RuntimeContractBuilderScript = preload("res://runtime_plugin/preview/runtime_contract_builder.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")


func export_package(session, output_directory: String = "", options: Dictionary = {}) -> Dictionary:
	if session == null or not is_instance_valid(session): return {"success": false, "errors": ["Open a character project before exporting a presentation package."]}
	var root := _destination(session, output_directory)
	if DirAccess.make_dir_recursive_absolute(_absolute(root)) != OK: return {"success": false, "errors": ["Could not create presentation-package directory."]}
	var manifest: Dictionary = session.get_manifest_copy() if session.has_method("get_manifest_copy") else session.manifest.duplicate(true)
	var production: Dictionary = session.get_production_suite_data() if session.has_method("get_production_suite_data") else {}
	var contract := RuntimeContractBuilderScript.build(manifest, production)
	var outfits := _outfit_sheets(session, root)
	var turntable := _turntable(session, manifest, contract, production, root)
	var expressions := _expressions(session, production)
	var pose_boards := _pose_boards(production, root)
	var approval := _approval(options, contract, root)
	var payload := {"format": "modular_character_presentation", "version": "1.0.0", "project_name": str(manifest.get("project_name", "Untitled")), "created_at": Time.get_datetime_string_from_system(true), "turntable": turntable, "expressions": expressions, "outfit_sheets": outfits, "pose_boards": pose_boards, "approval": approval, "runtime_contract": "character.runtime.json"}
	if not _write_json(root.path_join("presentation_manifest.json"), payload) or not _write_json(root.path_join("character.runtime.json"), contract): return {"success": false, "errors": ["Could not write presentation metadata."]}
	if not _write_text(root.path_join("approval.html"), _approval_html(payload)): return {"success": false, "errors": ["Could not write approval page."]}
	return {"success": true, "folder": root, "manifest": root.path_join("presentation_manifest.json"), "approval_page": root.path_join("approval.html"), "outfit_sheets": outfits, "turntable": turntable, "pose_boards": pose_boards, "errors": []}


func _outfit_sheets(session, root: String) -> Array:
	var appearances: Array = session.get_appearance_sets() if session.has_method("get_appearance_sets") else []
	if appearances.is_empty(): appearances = [{"appearance_id": "current", "display_name": "Current Appearance"}]
	var renderer = RendererScript.new()
	var frames: Array = []
	for raw_appearance in appearances:
		var appearance: Dictionary = raw_appearance as Dictionary
		var appearance_id := str(appearance.get("appearance_id", ""))
		var layers: Array = session.get_appearance_preview_layers(appearance_id) if session.has_method("get_appearance_preview_layers") else session.get_preview_layers()
		var image: Image = renderer.render_layers(layers, session.get_canvas_settings(), "neutral")
		if image != null and not image.is_empty(): frames.append({"id": appearance_id if not appearance_id.is_empty() else "current", "name": str(appearance.get("display_name", appearance_id)), "image": image})
	if frames.is_empty(): return []
	var sheet := _contact_sheet(frames)
	var path := root.path_join("outfits/outfit_batch_sheet.png")
	if DirAccess.make_dir_recursive_absolute(_absolute(path).get_base_dir()) != OK or sheet.save_png(_absolute(path)) != OK: return []
	var entries: Array = []
	for frame in frames: entries.append({"appearance_id": frame["id"], "display_name": frame["name"]})
	_write_json(root.path_join("outfits/outfit_batch_sheet.json"), {"items": entries, "image": path.get_file()})
	return [{"image": path, "items": entries}]


func _turntable(session, manifest: Dictionary, contract: Dictionary, production: Dictionary, root: String) -> Dictionary:
	var grid: Dictionary = contract.get("facing_grid", contract.get("facing_grids", {})) as Dictionary
	if not grid.has("cells") and not grid.is_empty():
		var ids: Array = grid.keys(); ids.sort()
		grid = grid[ids[0]] as Dictionary if not ids.is_empty() and grid[ids[0]] is Dictionary else {}
	var directions: Array = []
	for direction_id in grid.get("cells", {}) as Dictionary: directions.append(str(direction_id))
	directions.sort()
	var authored: Dictionary = production.get("presentation", {}).get("turntables", {}) as Dictionary
	var stops: Array = directions.duplicate() if not directions.is_empty() else ["front"]
	var renderer = RendererScript.new()
	var frames: Array = []
	for direction_id in stops:
		var layers := _layers_for_direction(session, manifest, grid.get("cells", {}).get(direction_id, {}) as Dictionary)
		var image: Image = renderer.render_layers(layers, session.get_canvas_settings(), "neutral")
		if image != null and not image.is_empty(): frames.append({"direction_id": direction_id, "image": image})
	var sheet_path := ""
	var entries: Array = []
	if not frames.is_empty():
		var sheet := _contact_sheet(frames)
		sheet_path = root.path_join("turntable/turntable_sheet.png")
		if DirAccess.make_dir_recursive_absolute(_absolute(sheet_path).get_base_dir()) == OK and sheet.save_png(_absolute(sheet_path)) == OK:
			for frame in frames: entries.append({"direction_id": str((frame as Dictionary).get("direction_id", ""))})
			_write_json(root.path_join("turntable/turntable_sheet.json"), {"image": sheet_path.get_file(), "directions": entries})
		else: sheet_path = ""
	return {"mode": "authored_facing_grid" if not directions.is_empty() else "single_view", "directions": stops, "turntable_definitions": authored.duplicate(true), "sheet": {"image": sheet_path, "directions": entries}, "note": "Turntable frames are composited only from approved imported layers and facing assignments; no generated artwork is baked into this package."}


func _layers_for_direction(session, manifest: Dictionary, cell: Dictionary) -> Array:
	var asset_id := str(cell.get("asset_id", ""))
	var asset: Dictionary = manifest.get("objects", {}).get("assets", {}).get(asset_id, {}) as Dictionary
	var path := str(asset.get("path", ""))
	if not path.is_empty() and FileAccess.file_exists(_absolute(path)):
		return [{"path": path, "visible": true, "state": {"position": [0.0, 0.0], "scale": [1.0, 1.0], "pivot": [0.5, 0.5], "rotation_degrees": 0.0, "tint": [1.0, 1.0, 1.0, 1.0], "opacity": 1.0}}]
	return session.get_preview_layers() if session.has_method("get_preview_layers") else []


func _pose_boards(production: Dictionary, root: String) -> Array:
	var authored: Dictionary = production.get("presentation", {}).get("pose_boards", {}) as Dictionary
	var results: Array = []
	var ids: Array = authored.keys()
	ids.sort()
	for board_id in ids:
		var board: Dictionary = (authored[board_id] as Dictionary).duplicate(true)
		board["board_id"] = str(board.get("board_id", board_id))
		var path := root.path_join("pose_boards/%s.json" % str(board_id).validate_filename())
		if _write_json(path, board): results.append({"board_id": board["board_id"], "display_name": str(board.get("display_name", board_id)), "pose_ids": board.get("pose_ids", []), "path": path})
	return results


func _expressions(session, production: Dictionary) -> Dictionary:
	var entries: Dictionary = (production.get("presentation", {}).get("expressions", {}) as Dictionary).duplicate(true)
	var visemes: Array = []
	for raw_clip in session.get_animation_clips() if session.has_method("get_animation_clips") else []:
		var clip: Dictionary = raw_clip as Dictionary
		for raw_track in clip.get("tracks", []) as Array:
			var track: Dictionary = raw_track as Dictionary
			if int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE)) != TrackDefinitionScript.TrackType.VISEME: continue
			for raw_key in track.get("keys", []) as Array:
				visemes.append({"clip_id": str(clip.get("clip_id", "")), "time": float((raw_key as Dictionary).get("time", 0.0)), "value": (raw_key as Dictionary).get("value")})
	return {"expressions": entries, "visemes": visemes}


func _approval(options: Dictionary, contract: Dictionary, root: String) -> Dictionary:
	var requested := str(options.get("approval_url", "")).strip_edges()
	var secure_url := requested if requested.begins_with("https://") else ""
	return {"status": "pending", "approval_url": secure_url, "package_path": root, "contract_hash": str(contract.get("content_hash", "")), "instructions": "Review the package, record a decision in your project tracker, and preserve this contract hash with the approval."}


func _contact_sheet(frames: Array) -> Image:
	var first: Image = (frames[0] as Dictionary).get("image") as Image
	var width := mini(256, first.get_width())
	var height := mini(256, first.get_height())
	var columns := mini(4, frames.size())
	var rows := int(ceil(float(frames.size()) / float(columns)))
	var output := Image.create(width * columns, height * rows, false, Image.FORMAT_RGBA8)
	output.fill(Color("20242d"))
	for index in range(frames.size()):
		var image: Image = (frames[index] as Dictionary).get("image") as Image
		var thumb := image.duplicate(); thumb.resize(width, height, Image.INTERPOLATE_NEAREST)
		output.blit_rect(thumb, Rect2i(Vector2i.ZERO, thumb.get_size()), Vector2i((index % columns) * width, int(index / columns) * height))
	return output


func _approval_html(payload: Dictionary) -> String:
	var name := str(payload.get("project_name", "Character Project")).xml_escape()
	var approval: Dictionary = payload.get("approval", {}) as Dictionary
	var url := str(approval.get("approval_url", ""))
	var link := "<a href=\"%s\" rel=\"noopener noreferrer\">Open approval link</a>" % url.xml_escape() if not url.is_empty() else "No external approval link was configured. Use this package with your normal review workflow."
	return "<!doctype html><html><head><meta charset=\"utf-8\"><title>%s approval</title></head><body><h1>%s</h1><p>%s</p><p>Runtime contract hash: <code>%s</code></p><p>See <code>presentation_manifest.json</code> for turntable stops, visemes, outfit sheets, and pose-board references.</p></body></html>" % [name, name, link, str(approval.get("contract_hash", "")).xml_escape()]


func _destination(session, requested: String) -> String:
	if not requested.strip_edges().is_empty(): return requested.strip_edges()
	return session.project_path.get_base_dir().path_join("presentations").path_join("%s_%d" % [session.project_path.get_file().get_basename().validate_filename(), Time.get_unix_time_from_system()])


func _write_json(path: String, data: Dictionary) -> bool: return _write_text(path, JSON.stringify(data, "\t", true, false))
func _write_text(path: String, value: String) -> bool:
	var absolute := _absolute(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return false
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null: return false
	file.store_string(value); file.close(); return true
func _absolute(path: String) -> String: return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
