# LargeProjectStressSuite -- Deterministic scale fixture and bounded work measurements.
class_name LargeProjectStressSuite
extends RefCounted

const ProfilerScript = preload("res://quality/performance/performance_profiler.gd")
const ProjectScaleAdvisorScript = preload("res://quality/performance/project_scale_advisor.gd")


func run(character_count: int = 100, weapon_count: int = 20, clip_count: int = 50) -> Dictionary:
	var profiler = ProfilerScript.new()
	var population: Array = []
	var sample: Dictionary = profiler.profile("large_project_fixture", func():
		for index in range(maxi(0, character_count)): population.append({"character_id": "npc_%03d" % index, "weapon_id": "weapon_%02d" % (index % maxi(1, weapon_count)), "clip_id": "clip_%02d" % (index % maxi(1, clip_count))})
		return population.size()
	)
	var scale: Dictionary = ProjectScaleAdvisorScript.analyze_synthetic({"layers": character_count * 2, "tracks": clip_count * 8, "keys": clip_count * character_count * 4, "appearance_sets": maxi(1, int(character_count / 2)), "review_frames": clip_count * character_count * 12})
	return {"characters": population, "weapons": weapon_count, "clips": clip_count, "sample": sample, "budget": profiler.budget_report(500000), "scale": scale}
