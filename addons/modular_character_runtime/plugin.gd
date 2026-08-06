@tool
extends EditorPlugin

const ChrprojEditorImporterScript = preload("res://addons/modular_character_runtime/runtime/chrproj_editor_importer.gd")

var _importer: EditorImportPlugin


func _enter_tree() -> void:
	_importer = ChrprojEditorImporterScript.new()
	add_import_plugin(_importer)


func _exit_tree() -> void:
	if _importer != null:
		remove_import_plugin(_importer)
		_importer = null
