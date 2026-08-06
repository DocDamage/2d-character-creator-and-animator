# MarkerRegion -- Per-clip registry of MarkerData and RegionData objects
# ANM-013: Implement markers and regions
class_name MarkerRegion
extends RefCounted

const MarkerDataScript = preload("res://animation/timeline/marker_data.gd")
const RegionDataScript = preload("res://animation/timeline/region_data.gd")

## Schema version.
const SCHEMA_VERSION := "1.0.0"

## Markers indexed by marker_id (String -> MarkerData).
var _markers: Dictionary = {}

## Regions indexed by region_id (String -> RegionData).
var _regions: Dictionary = {}


## Add a marker. Returns false if the marker_id is already registered.
func add_marker(m) -> bool:
	if m == null or m.marker_id.is_empty():
		return false
	if _markers.has(m.marker_id):
		return false
	_markers[m.marker_id] = m
	return true


## Remove a marker by ID. Returns true if found and removed.
func remove_marker(marker_id: String) -> bool:
	if _markers.has(marker_id):
		_markers.erase(marker_id)
		return true
	return false


## Retrieve a marker by ID.
func get_marker(marker_id: String):
	return _markers.get(marker_id, null)


## List all markers sorted ascending by time.
func list_markers() -> Array:
	var result := _markers.values()
	result.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return result


## Find the nearest marker at or before time t. Returns null if none.
func nearest_marker_at(t: float):
	var best = null
	for m in _markers.values():
		if float(m.time) <= t and (best == null or float(m.time) > float(best.time)):
			best = m
	return best


## Add a region. Returns false if the region_id is already registered.
func add_region(r) -> bool:
	if r == null or r.region_id.is_empty():
		return false
	if _regions.has(r.region_id):
		return false
	_regions[r.region_id] = r
	return true


## Remove a region by ID. Returns true if found and removed.
func remove_region(region_id: String) -> bool:
	if _regions.has(region_id):
		_regions.erase(region_id)
		return true
	return false


## Retrieve a region by ID.
func get_region(region_id: String):
	return _regions.get(region_id, null)


## List all regions.
func list_regions() -> Array:
	return _regions.values()


## Serialize markers and regions to a Dictionary.
func to_dict() -> Dictionary:
	var markers_arr: Array = []
	for m in _markers.values():
		markers_arr.append(m.to_dict())
	var regions_arr: Array = []
	for r in _regions.values():
		regions_arr.append(r.to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"markers": markers_arr,
		"regions": regions_arr
	}


## Load from a serialized Dictionary.
func from_dict(d: Dictionary) -> void:
	_markers.clear()
	_regions.clear()
	for md in d.get("markers", []):
		var m = MarkerDataScript.new()
		m.from_dict(md as Dictionary)
		add_marker(m)
	for rd in d.get("regions", []):
		var r = RegionDataScript.new()
		r.from_dict(rd as Dictionary)
		add_region(r)
