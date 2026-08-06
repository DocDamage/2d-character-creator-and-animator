# ProjectCloner — Deep project cloning and Save-As utilities
# Path: core/documents/project_cloner.gd
class_name ProjectCloner
extends RefCounted


static func clone_project(data: Dictionary, new_name: String = "") -> Dictionary:
	var cloned := data.duplicate(true)
	var old_id: String = data.get("project_id", "")
	cloned["cloned_from"] = old_id

	var new_uuid := _generate_uuid()
	cloned["project_id"] = new_uuid

	if not new_name.is_empty():
		cloned["project_name"] = new_name

	var now := Time.get_unix_time_from_system()
	cloned["created_at"] = now
	cloned["modified_at"] = now

	_regenerate_object_ids(cloned)
	return cloned


static func save_as(data: Dictionary, target_path: String, new_name: String = "") -> bool:
	var cloned := clone_project(data, new_name)
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root != null and root.has_node("SerializationService"):
			return root.get_node("SerializationService").save_project(cloned, target_path)
	return false


static func _generate_uuid() -> String:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root != null and (main_loop as SceneTree).root.has_node("IDService"):
		return (main_loop as SceneTree).root.get_node("IDService").generate_uuid_v4()
	return "00000000-0000-4000-8000-%012x" % randi()


static func _generate_short_id(prefix: String) -> String:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root != null and (main_loop as SceneTree).root.has_node("IDService"):
		return (main_loop as SceneTree).root.get_node("IDService").generate_id(prefix)
	return prefix + "_" + str(randi())


static func _regenerate_object_ids(manifest: Dictionary) -> void:
	if not manifest.has("objects") or typeof(manifest["objects"]) != TYPE_DICTIONARY:
		return

	var objs: Dictionary = manifest["objects"]
	for category in objs.keys():
		var items = objs[category]
		if typeof(items) == TYPE_DICTIONARY:
			var new_category_dict := {}
			for item_key in (items as Dictionary).keys():
				var item = items[item_key]
				if typeof(item) == TYPE_DICTIONARY:
					var item_copy: Dictionary = (item as Dictionary).duplicate(true)
					var prefix := str(item_key).split("_")[0] if "_" in str(item_key) else "obj"
					var new_id := _generate_short_id(prefix)
					item_copy["id"] = new_id
					new_category_dict[new_id] = item_copy
				else:
					new_category_dict[item_key] = item
			objs[category] = new_category_dict
