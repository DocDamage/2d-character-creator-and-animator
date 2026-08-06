# Unit Tests for Animation Timeline (Part 3: ANM-010 through ANM-014)
extends Node

const ClipSchemaScript = preload("res://animation/clips/clip_schema.gd")
const ClipRegistryScript = preload("res://animation/clips/clip_registry.gd")
const TrackSchemaScript = preload("res://animation/tracks/track_schema.gd")
const TrackRegistryScript = preload("res://animation/tracks/track_registry.gd")
const VisibilityTrackScript = preload("res://animation/tracks/visibility_track.gd")
const ZOrderTrackScript = preload("res://animation/tracks/z_order_track.gd")
const KeyFactoryScript = preload("res://animation/keys/key_factory.gd")
const PlaybackClockScript = preload("res://animation/timeline/playback_clock.gd")
const MarkerRegionScript = preload("res://animation/timeline/marker_region.gd")
const MarkerDataScript = preload("res://animation/timeline/marker_data.gd")
const RegionDataScript = preload("res://animation/timeline/region_data.gd")
const TimelinePersistenceScript = preload("res://animation/timeline/timeline_persistence.gd")


func run_part3_tests() -> int:
	var passes := 0
	passes += test_anm010_visibility_track()
	passes += test_anm011_z_order_track()
	passes += test_anm012_playback_clock_loop()
	passes += test_anm012_playback_clock_ping_pong()
	passes += test_anm013_markers_and_regions()
	passes += test_anm014_persistence_roundtrip()
	passes += test_anm014_persistence_validation()
	return passes


func test_anm010_visibility_track() -> int:
	var t = VisibilityTrackScript.new("vt-1", "sword", "object:sword.visible")
	t.add_visibility_key(0.0, true, "k1")
	t.add_visibility_key(1.0, false, "k2")
	if t.evaluate_visibility(0.5) == true and t.evaluate_visibility(1.5) == false:
		print("  PASS: ANM-010 VisibilityTrack evaluates boolean state at time")
		return 1
	printerr("  FAIL: ANM-010 VisibilityTrack: at 0.5=%s, at 1.5=%s" % [str(t.evaluate_visibility(0.5)), str(t.evaluate_visibility(1.5))])
	return 0


func test_anm011_z_order_track() -> int:
	var t = ZOrderTrackScript.new("zo-1", "sword_sprite", "object:sword.z_index")
	t.add_z_order_key(0.0, 2, "k1")
	t.add_z_order_key(0.5, 5, "k2")
	var z_early: int = t.evaluate_z_order(0.3)
	var z_late: int = t.evaluate_z_order(0.7)
	if z_early == 2 and z_late == 5:
		print("  PASS: ANM-011 ZOrderTrack evaluates integer z-order at time")
		return 1
	printerr("  FAIL: ANM-011 ZOrderTrack: at 0.3=%d, at 0.7=%d" % [z_early, z_late])
	return 0


func test_anm012_playback_clock_loop() -> int:
	var clock = PlaybackClockScript.new(1.0)
	clock.loop_mode = PlaybackClockScript.LoopMode.LOOP
	clock.loop_start = 0.0
	clock.loop_end = 1.0
	clock.play()
	clock.advance(0.8)
	clock.advance(0.5)
	if clock.current_time < 1.0 and clock.is_playing:
		print("  PASS: ANM-012 PlaybackClock wraps at loop boundary")
		return 1
	printerr("  FAIL: ANM-012 PlaybackClock loop: time=%f, playing=%s" % [clock.current_time, str(clock.is_playing)])
	return 0


func test_anm012_playback_clock_ping_pong() -> int:
	var clock = PlaybackClockScript.new(1.0)
	clock.loop_mode = PlaybackClockScript.LoopMode.PING_PONG
	clock.loop_start = 0.0
	clock.loop_end = 1.0
	clock.play()
	clock.advance(1.2)
	if clock.current_time <= 1.0 and clock._ping_pong_direction == -1:
		print("  PASS: ANM-012 PlaybackClock ping-pong reverses direction")
		return 1
	printerr("  FAIL: ANM-012 PlaybackClock ping-pong: dir=%d, t=%f" % [clock._ping_pong_direction, clock.current_time])
	return 0


func test_anm013_markers_and_regions() -> int:
	var mr = MarkerRegionScript.new()
	var m = MarkerDataScript.new("m1", "Attack Start", 0.5)
	var r = RegionDataScript.new("r1", "Loop Range", 0.0, 2.0)
	mr.add_marker(m)
	mr.add_region(r)

	var d: Dictionary = mr.to_dict()
	var mr2 = MarkerRegionScript.new()
	mr2.from_dict(d)

	var nearest = mr2.nearest_marker_at(0.6)
	if mr2._markers.size() == 1 and mr2._regions.size() == 1 and nearest != null and nearest.name == "Attack Start":
		print("  PASS: ANM-013 Markers and Regions round-trip and nearest_marker_at")
		return 1
	printerr("  FAIL: ANM-013 Markers/Regions: markers=%d, regions=%d, nearest=%s" % [mr2._markers.size(), mr2._regions.size(), str(nearest)])
	return 0


func test_anm014_persistence_roundtrip() -> int:
	var clip_reg = ClipRegistryScript.new()
	var clip = ClipSchemaScript.new("clip-1", "Run")
	clip.duration = 2.0
	clip_reg.register(clip)
	var treg = TrackRegistryScript.new("clip-1")
	var t = TrackSchemaScript.new("t1", "body", "bone:body.rotation")
	var factory = KeyFactoryScript.new()
	factory.create_key(t, 0.0, 0.0)
	factory.create_key(t, 1.0, 3.14)
	treg.add_track(t)
	var mreg = MarkerRegionScript.new()
	var mk = MarkerDataScript.new("m1", "Beat", 0.5)
	mreg.add_marker(mk)
	var track_regs := {"clip-1": treg}
	var marker_regs := {"clip-1": mreg}

	var data: Dictionary = TimelinePersistenceScript.serialize(clip_reg, track_regs, marker_regs)

	var result: Dictionary = TimelinePersistenceScript.deserialize(data)
	var loaded_reg = result.get("clip_registry")
	var loaded_tracks: Dictionary = result.get("track_registries")
	var loaded_markers: Dictionary = result.get("marker_registries")
	var errors: Array = result.get("errors")

	var ok: bool = errors.is_empty() and loaded_reg.count() == 1
	var loaded_treg = loaded_tracks.get("clip-1", null)
	ok = ok and loaded_treg != null and loaded_treg.count() == 1
	var loaded_mreg = loaded_markers.get("clip-1", null)
	ok = ok and loaded_mreg != null and loaded_mreg._markers.size() == 1

	if ok:
		print("  PASS: ANM-014 TimelinePersistence full round-trip (clips + tracks + markers)")
		return 1
	printerr("  FAIL: ANM-014 persistence errors=%s, clips=%d" % [str(errors), loaded_reg.count()])
	return 0


func test_anm014_persistence_validation() -> int:
	var bad_data := {"schema_version": "1.0.0", "clips": [{"clip_id": "", "clip_name": ""}]}
	var errs: Array = TimelinePersistenceScript.validate(bad_data)
	if errs.size() > 0:
		print("  PASS: ANM-014 TimelinePersistence validates invalid clip data")
		return 1
	printerr("  FAIL: ANM-014 persistence validation did not catch empty clip_id")
	return 0
