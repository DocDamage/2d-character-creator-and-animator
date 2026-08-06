@tool
extends EditorImportPlugin

const ChrprojImporterScript = preload("res://runtime_plugin/importer/chrproj_importer.gd")


func _get_importer_name() -> String:
	return "modular_character.chrproj"


func _get_visible_name() -> String:
	return "Modular Character Project"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["chrproj"])


func _get_save_extension() -> String:
	return "tres"


func _get_resource_type() -> String:
	return "CharacterRuntimeData"


func _get_import_order() -> int:
	return 0


func _get_priority() -> float:
	return 1.0


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _import(source_file: String, save_path: String, _options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var importer := ChrprojImporterScript.new()
	var result := importer.import_file(source_file, save_path + ".tres", {"imported_by": _get_importer_name()})
	return OK if bool(result.get("success", false)) else ERR_CANT_CREATE
