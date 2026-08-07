# MotionLibraryPanel -- Motion reuse, retargeting, additive layers, time-warp, and secondary-motion authoring.
class_name MotionLibraryPanel
extends VBoxContainer

const MotionServiceScript = preload("res://animation/motion/motion_library_service.gd")
const SecondaryServiceScript = preload("res://animation/secondary/secondary_motion_library.gd")

var _session = null
var _motion_id: LineEdit
var _search: LineEdit
var _output: RichTextLabel
var _status: Label


func _ready() -> void:
	name = "MotionLibraryPanel"; size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL; _build(); _refresh()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
	_refresh()


func _build() -> void:
	var title := Label.new(); title.text = "Motion Library & Secondary Motion"; title.add_theme_font_size_override("font_size", 18); add_child(title)
	var copy := Label.new(); copy.text = "Reuse clips with tagged motion entries, retarget presets, blend layers, time-warps, and exportable spring/trail/impact/event parameters."; copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(copy)
	var row := HFlowContainer.new(); add_child(row)
	_motion_id = LineEdit.new(); _motion_id.tooltip_text = "Motion ID"; _motion_id.custom_minimum_size.x = 130; row.add_child(_motion_id)
	var add_motion := Button.new(); add_motion.text = "Add active clip"; add_motion.pressed.connect(_add_motion); row.add_child(add_motion)
	var retarget := Button.new(); retarget.text = "Add retarget preset"; retarget.pressed.connect(_add_retarget); row.add_child(retarget)
	var warp := Button.new(); warp.text = "Add time-warp"; warp.pressed.connect(_add_warp); row.add_child(warp)
	var layer := Button.new(); layer.text = "Add additive layer"; layer.pressed.connect(_add_layer); row.add_child(layer)
	var secondary_row := HFlowContainer.new(); add_child(secondary_row)
	var spring := Button.new(); spring.text = "Add spring chain"; spring.pressed.connect(_add_spring); secondary_row.add_child(spring)
	var trail := Button.new(); trail.text = "Add weapon trail"; trail.pressed.connect(_add_trail); secondary_row.add_child(trail)
	var impact := Button.new(); impact.text = "Add impact frame"; impact.pressed.connect(_add_impact); secondary_row.add_child(impact)
	var effect := Button.new(); effect.text = "Add event effect"; effect.pressed.connect(_add_effect); secondary_row.add_child(effect)
	var search_row := HBoxContainer.new(); add_child(search_row)
	_search = LineEdit.new(); _search.tooltip_text = "Search motion library"; _search.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _search.text_changed.connect(func(_text): _refresh()); search_row.add_child(_search)
	_output = RichTextLabel.new(); _output.name = "MotionLibraryOutput"; _output.custom_minimum_size = Vector2(0, 210); _output.size_flags_vertical = Control.SIZE_EXPAND_FILL; _output.bbcode_enabled = false; add_child(_output)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_status)


func _refresh() -> void:
	if _session == null or not is_instance_valid(_session): _output.text = "Open a project to curate reusable motions."; return
	var production: Dictionary = _session.get_production_suite_data()
	var motions := MotionServiceScript.browse(_session.get_manifest_copy(), production, _search.text if _search != null else "")
	var secondary: Dictionary = production.get("secondary_motion", {}) as Dictionary
	_output.text = JSON.stringify({"motions": motions, "retarget_presets": production.get("motion_library", {}).get("retarget_presets", {}), "layer_sets": production.get("motion_library", {}).get("layer_sets", {}), "time_warps": production.get("motion_library", {}).get("time_warps", {}), "secondary_motion": secondary, "authored_parameters_only": true}, "\t", true, false)
	_status.text = "%d reusable motion(s) · %d spring/cloth/hair chain(s) · %d trail(s) · %d event effect(s)" % [motions.size(), (secondary.get("chains", {}) as Dictionary).size(), (secondary.get("weapon_trails", {}) as Dictionary).size(), (secondary.get("event_effects", {}) as Dictionary).size()]


func _add_motion() -> void:
	if not _ready_project(): return
	var clip_id := _active_clip_id()
	if clip_id.is_empty(): _status.text = "Create an animation clip before adding it to the motion library."; return
	var id := _motion_id.text.strip_edges() if not _motion_id.text.strip_edges().is_empty() else clip_id + "_motion"
	var report: Dictionary = MotionServiceScript.add_motion(_session.get_production_suite_data(), id, clip_id, id.capitalize(), ["reusable"])
	_commit(report, "Added Reusable Motion")


func _add_retarget() -> void:
	if not _ready_project(): return
	var bones: Array = (_session.get_active_rig().get("bones", {}) as Dictionary).keys(); bones.sort()
	var mapping: Dictionary = {}; for bone in bones: mapping[str(bone)] = bone
	var report: Dictionary = MotionServiceScript.add_retarget_preset(_session.get_production_suite_data(), "current_rig_retarget", "current_rig", "current_rig", mapping)
	_commit(report, "Added Retarget Preset")


func _add_warp() -> void:
	if not _ready_project(): return
	var report: Dictionary = MotionServiceScript.set_time_warp(_session.get_production_suite_data(), "snappy", [{"input": 0.0, "output": 0.0}, {"input": 0.5, "output": 0.35}, {"input": 1.0, "output": 1.0}])
	_commit(report, "Added Time Warp")


func _add_layer() -> void:
	if not _ready_project(): return
	var clip_id := _active_clip_id()
	if clip_id.is_empty(): return
	var report: Dictionary = MotionServiceScript.add_layer_set(_session.get_production_suite_data(), "additive_overlay", [{"layer_id": "overlay", "clip_id": clip_id, "mode": "additive", "weight": 0.5, "bone_mask": [], "sync_group": "locomotion"}])
	_commit(report, "Added Additive Motion Layer")


func _add_spring() -> void:
	if not _ready_project(): return
	var bones: Array = (_session.get_active_rig().get("bones", {}) as Dictionary).keys(); bones.sort()
	if bones.is_empty(): _status.text = "Add a rig before creating a spring chain."; return
	var report: Dictionary = SecondaryServiceScript.add_chain(_session.get_production_suite_data(), "hair_spring", bones.slice(0, mini(3, bones.size())), {"kind": "hair"})
	_commit(report, "Added Secondary Motion Chain")


func _add_trail() -> void:
	if not _ready_project(): return
	var report: Dictionary = SecondaryServiceScript.add_weapon_trail(_session.get_production_suite_data(), "weapon_trail", "weapon", "muzzle", {"event_gate": "swing"})
	_commit(report, "Added Dynamic Weapon Trail")


func _add_impact() -> void:
	if not _ready_project(): return
	var clip_id := _active_clip_id(); if clip_id.is_empty(): return
	var report: Dictionary = SecondaryServiceScript.add_impact_frame(_session.get_production_suite_data(), "impact_frame", clip_id, 0.1)
	_commit(report, "Added Impact Frame")


func _add_effect() -> void:
	if not _ready_project(): return
	var report: Dictionary = SecondaryServiceScript.add_event_effect(_session.get_production_suite_data(), "impact_vfx", "impact", "muzzle", {"effect_type": "particle"})
	_commit(report, "Added Event-Driven Effect")


func _commit(report: Dictionary, description: String) -> void:
	if not bool(report.get("success", false)): _status.text = str(report.get("errors", ["Could not update motion data."])[0]); return
	var saved: Dictionary = _session.set_production_suite_data(report.get("data", {}) as Dictionary, description)
	_status.text = description + ("." if bool(saved.get("success", false)) else " could not be saved.")
	_refresh()


func _active_clip_id() -> String: return _session.get_active_animation_id() if _session != null and _session.has_method("get_active_animation_id") else ""
func _ready_project() -> bool: return _session != null and is_instance_valid(_session) and not _session.is_read_only()
func _on_session_changed(_description: String) -> void: _refresh()
