extends Node

const TestLpcPhase7Script = preload("res://tests/integration/test_lpc_phase_7.gd")

func _ready() -> void:
	var test := TestLpcPhase7Script.new(); add_child(test)
	var result: Dictionary = test.run_all_tests()
	for error in result.get("errors", []): printerr("LPC PHASE 7: " + str(error))
	get_tree().quit(0 if int(result.get("failed", 0)) == 0 else 1)
