# ReferenceMediaLibrary -- Validated reference-media collection with playhead and export filtering.
class_name ReferenceMediaLibrary
extends RefCounted

var _references: Dictionary = {}


func add_reference(reference) -> bool:
	if reference == null or not reference.validate(false).is_empty() or _references.has(reference.reference_id): return false
	_references[reference.reference_id] = reference
	return true


func get_reference(reference_id: String):
	return _references.get(reference_id, null)


func evaluate_playhead(time: float) -> Array:
	var result: Array = []
	for reference in list_references(): result.append(reference.evaluate_at_timeline_time(time))
	return result


func exportable_references() -> Array:
	var result: Array = []
	for reference in list_references():
		if not reference.exclude_from_export: result.append(reference.to_dict())
	return result


func find_missing() -> Array:
	var result: Array = []
	for reference in list_references():
		if reference.is_source_missing(): result.append({"reference_id": reference.reference_id, "repair_action": "choose_replacement_source"})
	return result


func list_references() -> Array:
	var result: Array = _references.values()
	result.sort_custom(func(a, b): return a.reference_id < b.reference_id)
	return result


func to_dict() -> Dictionary:
	var data: Array = []
	for reference in list_references(): data.append(reference.to_dict())
	return {"references": data}


func from_dict(data: Dictionary, reference_script) -> Array:
	_references.clear()
	var errors: Array = []
	for reference_data in data.get("references", []):
		var reference = reference_script.new().from_dict(reference_data)
		if add_reference(reference): continue
		errors.append("Could not restore reference media '%s'." % str(reference_data.get("reference_id", "")))
	return errors
