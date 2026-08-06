# TimingTools — Batch key timing operations: scale, stretch, and ripple
# ANM-007: Implement timing scale, stretch, and ripple
class_name TimingTools
extends RefCounted

## Scale all keys in an array around the pivot time.
## Modifies the key dicts in-place. Returns the modified array.
static func scale_keys(keys: Array, pivot: float, factor: float) -> Array:
	if absf(factor) < 0.0001:
		return keys
	for k in keys:
		var t := float(k.get("time", 0.0))
		k["time"] = maxf(0.0, pivot + (t - pivot) * factor)
	return keys


## Stretch: remap all keys so that the key at old_end_time maps to new_end_time.
## All other keys are scaled proportionally.
static func stretch_keys(keys: Array, old_end_time: float, new_end_time: float) -> Array:
	if old_end_time <= 0.0:
		return keys
	var factor := new_end_time / old_end_time
	return scale_keys(keys, 0.0, factor)


## Ripple insert: shift keys at or after threshold by delta_time.
static func ripple_insert(keys: Array, threshold: float, delta_time: float) -> Array:
	for k in keys:
		var t := float(k.get("time", 0.0))
		if t >= threshold:
			k["time"] = maxf(0.0, t + delta_time)
	return keys


## Ripple delete: shift keys after threshold back by delta_time.
## Keys between threshold and threshold+delta_time are removed.
static func ripple_delete(keys: Array, threshold: float, delta_time: float) -> Array:
	var keep: Array = []
	for k in keys:
		var t := float(k.get("time", 0.0))
		if t < threshold:
			keep.append(k)
		elif t >= threshold + delta_time:
			k["time"] = maxf(0.0, t - delta_time)
			keep.append(k)
		# keys in [threshold, threshold+delta) are dropped
	return keep


## Sort key array by ascending time, in-place.
static func sort_keys(keys: Array) -> Array:
	keys.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	return keys


## Return the maximum key time in the array, or 0.0 if empty.
static func max_time(keys: Array) -> float:
	var m := 0.0
	for k in keys:
		m = maxf(m, float(k.get("time", 0.0)))
	return m
