# PerformanceProfiler -- Bounded timing, chunk planning, and scrub/solver budget diagnostics.
class_name PerformanceProfiler
extends RefCounted

var samples: Array = []


func profile(label: String, work: Callable) -> Dictionary:
	var started := Time.get_ticks_usec()
	var value = work.call() if work.is_valid() else null
	var sample := {"label": label, "microseconds": Time.get_ticks_usec() - started, "value": value}
	samples.append(sample)
	return sample


func plan_progressive_load(item_count: int, chunk_size: int = 32) -> Array:
	var chunks: Array = []
	for start in range(0, maxi(0, item_count), maxi(1, chunk_size)): chunks.append({"start": start, "count": mini(chunk_size, item_count - start)})
	return chunks


func budget_report(max_microseconds: int) -> Dictionary:
	var slow: Array = []
	for sample in samples:
		if int((sample as Dictionary).get("microseconds", 0)) > max_microseconds: slow.append(sample)
	return {"valid": slow.is_empty(), "budget_microseconds": max_microseconds, "slow_samples": slow, "samples": samples.duplicate(true)}
