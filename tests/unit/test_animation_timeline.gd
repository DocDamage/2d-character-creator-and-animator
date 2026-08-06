# Unit Tests for Timeline and Animation Data (Milestone 7 -- ANM-001 through ANM-014)
# QA-ANM-001: Verify timeline behavior end-to-end
extends Node

const Part1Script = preload("res://tests/unit/test_animation_timeline_part1.gd")
const Part2Script = preload("res://tests/unit/test_animation_timeline_part2.gd")
const Part3Script = preload("res://tests/unit/test_animation_timeline_part3.gd")


func run_tests() -> int:
	print("--- Running Animation Timeline Tests (Milestone 7) ---")
	var passes := 0

	var part1 = Part1Script.new()
	add_child(part1)
	passes += part1.run_part1_tests()
	part1.queue_free()

	var part2 = Part2Script.new()
	add_child(part2)
	passes += part2.run_part2_tests()
	part2.queue_free()

	var part3 = Part3Script.new()
	add_child(part3)
	passes += part3.run_part3_tests()
	part3.queue_free()

	print("--- Animation Timeline Tests Finished: %d PASS ---" % passes)
	return passes
