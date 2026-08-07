extends Node

const TestLpcPhase5Script = preload("res://tests/integration/test_lpc_phase_5.gd")

func _ready() -> void:
	var test := TestLpcPhase5Script.new()
	add_child(test)
	var result: Dictionary = test.run_all_tests()
	for error in result.get("errors", []): printerr("LPC PHASE 5: " + str(error))
	get_tree().quit(0 if int(result.get("failed", 0)) == 0 else 1)
