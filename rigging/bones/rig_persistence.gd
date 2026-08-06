# RigPersistence — Internally handles saving, loading, and verifying rig data state
class_name RigPersistence
extends RefCounted


static func serialize_rig(p_rig: Dictionary) -> String:
	var dict_data := RigSchema.to_json_dict(p_rig)
	return JSON.stringify(dict_data, "  ")


static func deserialize_rig(p_json_str: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(p_json_str)
	if err != OK:
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return RigSchema.from_json_dict(data)


static func save_rig_to_file(p_rig: Dictionary, p_path: String) -> bool:
	var file := FileAccess.open(p_path, FileAccess.WRITE)
	if file == null:
		return false
	var content := serialize_rig(p_rig)
	file.store_string(content)
	file.close()
	return true


static func load_rig_from_file(p_path: String) -> Dictionary:
	if not FileAccess.file_exists(p_path):
		return {}
	var file := FileAccess.open(p_path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	return deserialize_rig(content)
