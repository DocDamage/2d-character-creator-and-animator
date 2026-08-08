extends Node

const TestLpcPhase01Script = preload("res://tests/integration/test_lpc_phase_0_1.gd")


func _ready() -> void:
	var test := TestLpcPhase01Script.new()
	add_child(test)
	var result: Dictionary = test.run_all_tests()
	for error in result.get("errors", []): printerr("LPC PHASE 0-1: " + str(error))
	get_tree().quit(0 if int(result.get("failed", 0)) == 0 else 1)
