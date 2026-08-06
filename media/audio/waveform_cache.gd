# WaveformCache -- Deterministic min/max peak-cache generator for sampled audio data.
class_name WaveformCache
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var audio_id: String = ""
var sample_count: int = 0
var bucket_count: int = 0
var peaks: Array = []


func build(audio_samples: Array, requested_buckets: int = 256) -> void:
	sample_count = audio_samples.size()
	bucket_count = clampi(requested_buckets, 1, max(1, sample_count))
	peaks.clear()
	if audio_samples.is_empty(): return
	for bucket in bucket_count:
		var start := int(floor(float(bucket) * sample_count / bucket_count))
		var end := int(ceil(float(bucket + 1) * sample_count / bucket_count))
		var minimum := 1.0
		var maximum := -1.0
		for index in range(start, min(end, sample_count)):
			var sample := clampf(float(audio_samples[index]), -1.0, 1.0)
			minimum = minf(minimum, sample)
			maximum = maxf(maximum, sample)
		peaks.append([minimum, maximum])


func peak_at_normalized_time(progress: float) -> Array:
	if peaks.is_empty(): return [0.0, 0.0]
	return (peaks[clampi(int(floor(clampf(progress, 0.0, 1.0) * (peaks.size() - 1))), 0, peaks.size() - 1)] as Array).duplicate()


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "audio_id": audio_id, "sample_count": sample_count, "bucket_count": bucket_count, "peaks": peaks.duplicate(true)}


func from_dict(data: Dictionary) -> WaveformCache:
	audio_id = str(data.get("audio_id", ""))
	sample_count = int(data.get("sample_count", 0))
	bucket_count = int(data.get("bucket_count", 0))
	peaks = (data.get("peaks", []) as Array).duplicate(true)
	return self


func validate() -> Array:
	var errors: Array = []
	if bucket_count != peaks.size(): errors.append("Waveform cache bucket count does not match peak data.")
	for peak in peaks:
		if not (peak is Array) or peak.size() != 2 or float(peak[0]) > float(peak[1]): errors.append("Waveform cache contains invalid peak data.")
	return errors
