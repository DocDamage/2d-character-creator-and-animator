# LargeProjectStressSuite -- Deterministic scale fixture and bounded work measurements.
class_name LargeProjectStressSuite
extends RefCounted

const ProfilerScript = preload("res://quality/performance/performance_profiler.gd")


func run(character_count: int = 100, weapon_count: int = 20, clip_count: int = 50) -> Dictionary:
	var profiler = ProfilerScript.new()
	var population: Array = []
	var sample: Dictionary = profiler.profile("large_project_fixture", func():
		for index in range(maxi(0, character_count)): population.append({"character_id": "npc_%03d" % index, "weapon_id": "weapon_%02d" % (index % maxi(1, weapon_count)), "clip_id": "clip_%02d" % (index % maxi(1, clip_count))})
		return population.size()
	)
	return {"characters": population, "weapons": weapon_count, "clips": clip_count, "sample": sample, "budget": profiler.budget_report(500000)}
