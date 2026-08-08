extends Node

const TestLpcPhase6Script = preload("res://tests/integration/test_lpc_phase_6.gd")

func _ready() -> void:
	var test := TestLpcPhase6Script.new(); add_child(test)
	var result: Dictionary = test.run_all_tests()
	for error in result.get("errors", []): printerr("LPC PHASE 6: " + str(error))
	get_tree().quit(0 if int(result.get("failed", 0)) == 0 else 1)
