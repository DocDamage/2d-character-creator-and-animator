# LipSyncImporter -- Imports reviewable timecoded visemes from JSON or tab-delimited text.
class_name LipSyncImporter
extends RefCounted

static func parse_text(content: String, format_hint: String = "") -> Dictionary:
	var hint := format_hint.to_lower()
	if hint == "json" or content.strip_edges().begins_with("["):
		return _parse_json(content)
	return _parse_tsv(content)


static func apply_to_track(track, imported: Dictionary, mouth_map: Dictionary = {}) -> Dictionary:
	if track == null: return {"success": false, "errors": ["A viseme track is required."], "count": 0}
	var errors: Array = imported.get("errors", []).duplicate()
	var count := 0
	for cue in imported.get("cues", []):
		var viseme_id := str(cue.get("viseme_id", ""))
		var mouth_id := str(mouth_map.get(viseme_id, cue.get("mouth_attachment_id", "")))
		if viseme_id.is_empty() or mouth_id.is_empty(): errors.append("Viseme cue requires viseme_id and mouth attachment."); continue
		track.add_viseme(float(cue.get("time", 0.0)), viseme_id, mouth_id, str(cue.get("key_id", "viseme_%d" % count)))
		count += 1
	return {"success": errors.is_empty(), "errors": errors, "count": count}


static func _parse_json(content: String) -> Dictionary:
	var parsed = JSON.parse_string(content)
	if not (parsed is Array): return {"cues": [], "errors": ["Lip-sync JSON must be an array."]}
	return _normalize_cues(parsed)


static func _parse_tsv(content: String) -> Dictionary:
	var raw: Array = []
	for line in content.split("\n", false):
		var cells := line.strip_edges().split("\t")
		if cells.size() >= 2: raw.append({"time": cells[0], "viseme_id": cells[1], "mouth_attachment_id": cells[2] if cells.size() > 2 else ""})
	return _normalize_cues(raw)


static func _normalize_cues(raw: Array) -> Dictionary:
	var cues: Array = []
	var errors: Array = []
	for index in raw.size():
		var cue = raw[index] as Dictionary
		var time := float(cue.get("time", -1.0))
		if time < 0.0 or str(cue.get("viseme_id", "")).is_empty(): errors.append("Lip-sync cue %d is invalid." % index); continue
		cues.append({"time": time, "viseme_id": str(cue.get("viseme_id", "")), "mouth_attachment_id": str(cue.get("mouth_attachment_id", "")), "key_id": str(cue.get("key_id", "import_%d" % index))})
	cues.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return {"cues": cues, "errors": errors}
