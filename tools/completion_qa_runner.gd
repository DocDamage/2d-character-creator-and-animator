# Completion QA Runner — A Run Script-safe launcher for the scoped QA scene.
# Godot does not initialize project autoloads for a raw `--script` run, while the
# acceptance checks depend on those autoloads. Launch the scene in a child Godot
# process so both the editor's Run Script command and CLI invocation work.
extends SceneTree

const RUNNER_SCENE := "res://tests/completion_qa_runner.tscn"


func _initialize() -> void:
	var output: Array = []
	var arguments := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--scene", RUNNER_SCENE,
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	for line in output:
		print(str(line))
	quit(exit_code)
