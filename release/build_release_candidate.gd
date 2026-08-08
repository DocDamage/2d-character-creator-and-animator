# Builds both machine-testable Windows candidate forms from the same source tree.
extends Node

const ReleaseBuilderScript = preload("res://release/release_builder.gd")


func _ready() -> void:
	var builder = ReleaseBuilderScript.new()
	var portable := builder.build_portable_windows(
		"release/windows/PaperQuestCharacterStudio.exe",
		"release/windows/PaperQuestCharacterStudio-portable.zip"
	)
	if not bool(portable.get("success", false)):
		printerr(JSON.stringify({"portable": portable}, "\t"))
		get_tree().quit(1)
		return
	var single := builder.build_single_file_windows(
		"release/windows/PaperQuestCharacterStudio-single.exe"
	)
	var result := {"portable": portable, "single_file": single}
	print(JSON.stringify(result, "\t"))
	get_tree().quit(0 if bool(single.get("success", false)) else 1)
