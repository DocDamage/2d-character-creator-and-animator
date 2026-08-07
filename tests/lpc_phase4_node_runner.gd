extends Node

const TestLpcPhase4Script = preload("res://tests/integration/test_lpc_phase_4.gd")

func _ready() -> void:
	var test := TestLpcPhase4Script.new(); add_child(test)
	var result: Dictionary = test.run_all_tests()
	for error in result.get("errors", []): printerr("LPC PHASE 4: " + str(error))
	get_tree().quit(0 if int(result.get("failed", 0)) == 0 else 1)
