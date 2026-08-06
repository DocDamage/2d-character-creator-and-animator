# Unit Tests for Animation Timeline (Part 1: ANM-001 through ANM-004)
extends Node

const ClipSchemaScript = preload("res://animation/clips/clip_schema.gd")
const ClipRegistryScript = preload("res://animation/clips/clip_registry.gd")
const ClipBrowserScript = preload("res://animation/clips/clip_browser.gd")
const TrackSchemaScript = preload("res://animation/tracks/track_schema.gd")
const TrackRegistryScript = preload("res://animation/tracks/track_registry.gd")
const KeyframeSchemaScript = preload("res://animation/keys/keyframe_schema.gd")
const DopeSheetScript = preload("res://animation/timeline/dope_sheet.gd")


func run_part1_tests() -> int:
	var passes := 0
	passes += test_anm001_clip_schema_roundtrip()
	passes += test_anm001_track_schema_roundtrip()
	passes += test_anm001_keyframe_schema_roundtrip()
	passes += test_anm001_clip_validation()
	passes += test_anm001_track_validation()
	passes += test_anm002_clip_browser_search()
	passes += test_anm002_clip_browser_activate()
	passes += test_anm003_dope_sheet_filter()
	passes += test_anm003_dope_sheet_expand()
	passes += test_anm003_dope_sheet_visible_keys()
	passes += test_anm004_per_object_tracks()
	return passes


func test_anm001_clip_schema_roundtrip() -> int:
	var clip = ClipSchemaScript.new("clip-001", "Walk")
	clip.duration = 2.0
	clip.fps = 24.0
	clip.loop_mode = ClipSchemaScript.LoopMode.LOOP
	var d := clip.to_dict()
	var clip2 = ClipSchemaScript.new()
	clip2.from_dict(d)
	if clip2.clip_id == "clip-001" and clip2.duration == 2.0 and clip2.loop_mode == ClipSchemaScript.LoopMode.LOOP:
		print("  PASS: ANM-001 AnimationClip schema round-trip")
		return 1
	printerr("  FAIL: ANM-001 AnimationClip schema round-trip")
	return 0


func test_anm001_track_schema_roundtrip() -> int:
	var t = TrackSchemaScript.new("trk-001", "upper_arm_r", "bone:upper_arm_r.rotation")
	t.muted = true
	var d := t.to_dict()
	var t2 = TrackSchemaScript.new()
	t2.from_dict(d)
	if t2.track_id == "trk-001" and t2.muted and t2.property_path == "bone:upper_arm_r.rotation":
		print("  PASS: ANM-001 TrackDefinition schema round-trip")
		return 1
	printerr("  FAIL: ANM-001 TrackDefinition schema round-trip")
	return 0


func test_anm001_keyframe_schema_roundtrip() -> int:
	var k = KeyframeSchemaScript.new("k-001", 0.5, 1.57)
	k.interpolation = TrackSchemaScript.Interpolation.SMOOTH
	var d := k.to_dict()
	var k2 = KeyframeSchemaScript.new()
	k2.from_dict(d)
	if k2.key_id == "k-001" and absf(k2.time - 0.5) < 0.0001 and k2.interpolation == TrackSchemaScript.Interpolation.SMOOTH:
		print("  PASS: ANM-001 KeyframeData schema round-trip")
		return 1
	printerr("  FAIL: ANM-001 KeyframeData schema round-trip")
	return 0


func test_anm001_clip_validation() -> int:
	var clip = ClipSchemaScript.new()
	var errs: Array = clip.validate()
	if errs.size() > 0:
		print("  PASS: ANM-001 AnimationClip validates required fields")
		return 1
	printerr("  FAIL: ANM-001 AnimationClip validation did not report missing clip_id")
	return 0


func test_anm001_track_validation() -> int:
	var t = TrackSchemaScript.new()
	var errs: Array = t.validate()
	if errs.size() >= 2:
		print("  PASS: ANM-001 TrackDefinition validates required fields")
		return 1
	printerr("  FAIL: ANM-001 TrackDefinition validation insufficient: %s" % str(errs))
	return 0


func test_anm002_clip_browser_search() -> int:
	var reg = ClipRegistryScript.new()
	var c1 = ClipSchemaScript.new("c1", "Walk Cycle")
	var c2 = ClipSchemaScript.new("c2", "Run Cycle")
	reg.register(c1)
	reg.register(c2)
	var browser = ClipBrowserScript.new(reg)
	var results: Array = browser.search("walk")
	if results.size() == 1 and results[0].clip_id == "c1":
		print("  PASS: ANM-002 ClipBrowser search filters by name")
		return 1
	printerr("  FAIL: ANM-002 ClipBrowser search returned %d results" % results.size())
	return 0


func test_anm002_clip_browser_activate() -> int:
	var reg = ClipRegistryScript.new()
	var c = ClipSchemaScript.new("c1", "Idle")
	reg.register(c)
	var browser = ClipBrowserScript.new(reg)
	if browser.activate("c1") and browser.active_clip_id == "c1":
		print("  PASS: ANM-002 ClipBrowser activates and returns active clip")
		return 1
	printerr("  FAIL: ANM-002 ClipBrowser activate failed")
	return 0


func test_anm003_dope_sheet_filter() -> int:
	var clip = ClipSchemaScript.new("c1", "Idle")
	var reg = TrackRegistryScript.new("c1")
	var t = TrackSchemaScript.new("t1", "head", "bone:head.rotation")
	reg.add_track(t)
	var ds = DopeSheetScript.new(clip, reg)
	ds.filter_term = "head"
	var visible: Array = ds.get_visible_tracks()
	if visible.size() == 1:
		print("  PASS: ANM-003 DopeSheet filter returns matching tracks")
		return 1
	printerr("  FAIL: ANM-003 DopeSheet filter returned %d tracks" % visible.size())
	return 0


func test_anm003_dope_sheet_expand() -> int:
	var clip = ClipSchemaScript.new("c1", "Idle")
	var reg = TrackRegistryScript.new("c1")
	var ds = DopeSheetScript.new(clip, reg)
	ds.expand_track("t1")
	if ds.expanded_track_ids.has("t1"):
		ds.collapse_track("t1")
		if not ds.expanded_track_ids.has("t1"):
			print("  PASS: ANM-003 DopeSheet expand/collapse track rows")
			return 1
	printerr("  FAIL: ANM-003 DopeSheet expand/collapse failed")
	return 0


func test_anm003_dope_sheet_visible_keys() -> int:
	var clip = ClipSchemaScript.new("c1", "Idle")
	clip.duration = 2.0
	var reg = TrackRegistryScript.new("c1")
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	t.keys = [{"key_id": "k1","time":0.5,"value":0.0,"interpolation":1,"easing":0.5},
			   {"key_id": "k2","time":1.5,"value":1.0,"interpolation":1,"easing":0.5}]
	reg.add_track(t)
	var ds = DopeSheetScript.new(clip, reg)
	ds.set_view_range(0.0, 1.0)
	var visible: Array = ds.get_visible_keys(t)
	if visible.size() == 1 and visible[0].get("key_id") == "k1":
		print("  PASS: ANM-003 DopeSheet filters keys to visible range")
		return 1
	printerr("  FAIL: ANM-003 DopeSheet visible keys count was %d" % visible.size())
	return 0


func test_anm004_per_object_tracks() -> int:
	var reg = TrackRegistryScript.new("clip-1")
	var t1 = TrackSchemaScript.new("t1", "upper_arm_r", "bone:upper_arm_r.rotation")
	var t2 = TrackSchemaScript.new("t2", "upper_arm_r", "bone:upper_arm_r.position")
	var t3 = TrackSchemaScript.new("t3", "head", "bone:head.rotation")
	reg.add_track(t1)
	reg.add_track(t2)
	reg.add_track(t3)
	var arm_tracks: Array = reg.get_tracks_for_object("upper_arm_r")
	if arm_tracks.size() == 2 and reg.count() == 3:
		print("  PASS: ANM-004 TrackRegistry returns per-object tracks correctly")
		return 1
	printerr("  FAIL: ANM-004 per-object track count was %d" % arm_tracks.size())
	return 0
