# Unit Tests for Animation Timeline (Part 2: ANM-005 through ANM-009)
extends Node

const TrackSchemaScript = preload("res://animation/tracks/track_schema.gd")
const TrackRegistryScript = preload("res://animation/tracks/track_registry.gd")
const ImageSwapTrackScript = preload("res://animation/tracks/image_swap_track.gd")
const KeyFactoryScript = preload("res://animation/keys/key_factory.gd")
const AutoKeyScript = preload("res://animation/keys/auto_key_controller.gd")
const KeyEditorScript = preload("res://animation/keys/key_editor.gd")
const TimingToolsScript = preload("res://animation/keys/timing_tools.gd")
const PlaybackClockScript = preload("res://animation/timeline/playback_clock.gd")


func run_part2_tests() -> int:
	var passes := 0
	passes += test_anm005_key_factory_creates_key()
	passes += test_anm005_key_factory_no_overwrite()
	passes += test_anm005_key_factory_duplicate_time()
	passes += test_anm005_auto_key_controller()
	passes += test_anm006_key_editor_move()
	passes += test_anm006_key_editor_scale()
	passes += test_anm007_timing_tools_scale()
	passes += test_anm007_timing_tools_stretch()
	passes += test_anm007_timing_tools_ripple_insert()
	passes += test_anm007_timing_tools_ripple_delete()
	passes += test_anm008_cross_clip_copy_paste()
	passes += test_anm009_image_swap_track()
	return passes


func test_anm005_key_factory_creates_key() -> int:
	var factory = KeyFactoryScript.new()
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	var k: Dictionary = factory.create_key(t, 0.5, 1.57)
	if not k.is_empty() and t.keys.size() == 1 and absf(float(k.get("time")) - 0.5) < 0.0001:
		print("  PASS: ANM-005 KeyFactory creates key at correct time")
		return 1
	printerr("  FAIL: ANM-005 KeyFactory key creation failed")
	return 0


func test_anm005_key_factory_no_overwrite() -> int:
	var factory = KeyFactoryScript.new()
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	factory.create_key(t, 0.5, 1.0)
	var k2: Dictionary = factory.create_key_no_overwrite(t, 0.5, 2.0)
	if t.keys.size() == 1 and float(k2.get("value", -1)) == 1.0:
		print("  PASS: ANM-005 KeyFactory no-overwrite preserves existing key")
		return 1
	printerr("  FAIL: ANM-005 KeyFactory no-overwrite failed, keys=%d" % t.keys.size())
	return 0


func test_anm005_key_factory_duplicate_time() -> int:
	var factory = KeyFactoryScript.new()
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	factory.create_key(t, 1.0, 0.0)
	factory.create_key(t, 1.0, 3.14)
	if t.keys.size() == 1 and absf(float(t.keys[0].get("value")) - 3.14) < 0.001:
		print("  PASS: ANM-005 KeyFactory replaces duplicate-time key")
		return 1
	printerr("  FAIL: ANM-005 KeyFactory duplicate-time handling, keys=%d" % t.keys.size())
	return 0


func test_anm005_auto_key_controller() -> int:
	var factory = KeyFactoryScript.new()
	var clock = PlaybackClockScript.new(2.0)
	clock.current_time = 0.75
	var auto_key = AutoKeyScript.new(factory, clock)
	auto_key.set_enabled(true)
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	var k: Dictionary = auto_key.on_property_changed(t, 2.5)
	if not k.is_empty() and absf(float(k.get("time")) - 0.75) < 0.0001:
		print("  PASS: ANM-005 AutoKeyController records key at clock time")
		return 1
	printerr("  FAIL: ANM-005 AutoKeyController failed: %s" % str(k))
	return 0


func test_anm006_key_editor_move() -> int:
	var factory = KeyFactoryScript.new()
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	factory.create_key(t, 0.5, 1.0)
	factory.create_key(t, 1.0, 2.0)
	var editor = KeyEditorScript.new()
	editor.select_key(t, t.keys[0].get("key_id"))
	editor.move_selected(0.25)
	if absf(float(t.keys[0].get("time")) - 0.75) < 0.0001:
		print("  PASS: ANM-006 KeyEditor moves selected key by delta")
		return 1
	printerr("  FAIL: ANM-006 KeyEditor move time was %f" % float(t.keys[0].get("time")))
	return 0


func test_anm006_key_editor_scale() -> int:
	var factory = KeyFactoryScript.new()
	var t = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	factory.create_key(t, 1.0, 0.0)
	var editor = KeyEditorScript.new()
	editor.select_key(t, t.keys[0].get("key_id"))
	editor.scale_selected(0.0, 2.0)
	if absf(float(t.keys[0].get("time")) - 2.0) < 0.0001:
		print("  PASS: ANM-006 KeyEditor scales selected key time")
		return 1
	printerr("  FAIL: ANM-006 KeyEditor scale time was %f" % float(t.keys[0].get("time")))
	return 0


func test_anm007_timing_tools_scale() -> int:
	var keys := [{"key_id":"k1","time":1.0,"value":0,"interpolation":1,"easing":0.5}]
	TimingToolsScript.scale_keys(keys, 0.0, 2.0)
	if absf(float(keys[0].get("time")) - 2.0) < 0.0001:
		print("  PASS: ANM-007 TimingTools scale doubles key time")
		return 1
	printerr("  FAIL: ANM-007 TimingTools scale time was %f" % float(keys[0].get("time")))
	return 0


func test_anm007_timing_tools_stretch() -> int:
	var keys := [{"key_id":"k1","time":0.5,"value":0,"interpolation":1,"easing":0.5}]
	TimingToolsScript.stretch_keys(keys, 1.0, 2.0)
	if absf(float(keys[0].get("time")) - 1.0) < 0.0001:
		print("  PASS: ANM-007 TimingTools stretch maps 0.5 to 1.0")
		return 1
	printerr("  FAIL: ANM-007 TimingTools stretch time was %f" % float(keys[0].get("time")))
	return 0


func test_anm007_timing_tools_ripple_insert() -> int:
	var keys := [
		{"key_id":"k1","time":0.0,"value":0,"interpolation":1,"easing":0.5},
		{"key_id":"k2","time":1.0,"value":1,"interpolation":1,"easing":0.5}
	]
	TimingToolsScript.ripple_insert(keys, 0.5, 1.0)
	if absf(float(keys[0].get("time")) - 0.0) < 0.0001 and absf(float(keys[1].get("time")) - 2.0) < 0.0001:
		print("  PASS: ANM-007 TimingTools ripple insert shifts keys at or after threshold")
		return 1
	printerr("  FAIL: ANM-007 TimingTools ripple insert: t[1]=%f" % float(keys[1].get("time")))
	return 0


func test_anm007_timing_tools_ripple_delete() -> int:
	var keys := [
		{"key_id":"k1","time":0.0,"value":0,"interpolation":1,"easing":0.5},
		{"key_id":"k2","time":1.0,"value":1,"interpolation":1,"easing":0.5},
		{"key_id":"k3","time":2.0,"value":2,"interpolation":1,"easing":0.5}
	]
	keys = TimingToolsScript.ripple_delete(keys, 0.5, 1.0)
	if keys.size() == 2 and absf(float(keys[1].get("time")) - 1.0) < 0.0001:
		print("  PASS: ANM-007 TimingTools ripple delete removes and shifts correctly")
		return 1
	printerr("  FAIL: ANM-007 TimingTools ripple delete: count=%d" % keys.size())
	return 0


func test_anm008_cross_clip_copy_paste() -> int:
	var factory = KeyFactoryScript.new()
	var src_reg = TrackRegistryScript.new("clip-src")
	var src_track = TrackSchemaScript.new("t1", "arm", "bone:arm.rotation")
	factory.create_key(src_track, 0.5, 1.0)
	src_reg.add_track(src_track)

	var dst_reg = TrackRegistryScript.new("clip-dst")
	var dst_track = TrackSchemaScript.new("t2", "arm", "bone:arm.rotation")
	dst_reg.add_track(dst_track)

	var editor = KeyEditorScript.new()
	editor.select_key(src_track, src_track.keys[0].get("key_id"))
	var cb: Dictionary = editor.copy_to_clipboard()
	var pasted: int = editor.paste_from_clipboard(cb, dst_reg, factory, 0.25)
	if pasted == 1 and dst_track.keys.size() == 1 and absf(float(dst_track.keys[0].get("time")) - 0.75) < 0.001:
		print("  PASS: ANM-008 Cross-clip copy/paste with time offset")
		return 1
	printerr("  FAIL: ANM-008 Cross-clip paste: pasted=%d, key_time=%s" % [pasted, str(dst_track.keys)])
	return 0


func test_anm009_image_swap_track() -> int:
	var t = ImageSwapTrackScript.new("ist-1", "head_slot", "sprite:head.texture")
	t.add_image_key(0.0, "asset-default", "k1")
	t.add_image_key(0.5, "asset-blink", "k2")
	var at_zero: String = t.evaluate_image(0.25)
	var at_half: String = t.evaluate_image(0.6)
	if at_zero == "asset-default" and at_half == "asset-blink":
		print("  PASS: ANM-009 ImageSwapTrack evaluates correct asset at time")
		return 1
	printerr("  FAIL: ANM-009 ImageSwapTrack evaluate: %s / %s" % [at_zero, at_half])
	return 0
