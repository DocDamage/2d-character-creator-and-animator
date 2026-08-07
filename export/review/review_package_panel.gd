# ReviewPackagePanel -- Artist-facing review/handoff export surface.
class_name ReviewPackagePanel
extends VBoxContainer

const ExporterScript = preload("res://export/review/review_package_exporter.gd")

signal status_changed(message: String)

var _session = null
var _exporter = ExporterScript.new()
var _background_picker: OptionButton
var _estimate_label: Label
var _status_label: Label
var _export_button: Button
var _cancel_button: Button
var _reveal_button: Button
var _last_output := ""
var _cancel_requested := false
var _warning_dialog: ConfirmationDialog


func _ready() -> void:
	name = "ReviewPackagePanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_refresh()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed): _session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed): _session.session_changed.connect(_on_session_changed)
	_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Review Package"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	var copy := Label.new()
	copy.text = "Render every saved clip × Appearance Set from imported artwork. Creates GIFs, contact sheets, timing metadata, an MP4 when ffmpeg is available, and a ZIP handoff."
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(copy)
	var background_row := HBoxContainer.new()
	add_child(background_row)
	var label := Label.new()
	label.text = "Background"
	background_row.add_child(label)
	_background_picker = OptionButton.new()
	_background_picker.name = "ReviewBackground"
	_background_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [["Neutral opaque", "neutral"], ["Checkerboard", "checkerboard"], ["Transparent (PNG only)", "transparent"]]:
		_background_picker.add_item(str(entry[0]))
		_background_picker.set_item_metadata(_background_picker.item_count - 1, str(entry[1]))
	background_row.add_child(_background_picker)
	_estimate_label = Label.new()
	_estimate_label.name = "ReviewEstimate"
	_estimate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_estimate_label)
	var actions := HBoxContainer.new()
	add_child(actions)
	_export_button = Button.new()
	_export_button.name = "ExportReviewPackage"
	_export_button.text = "Export review package"
	_export_button.pressed.connect(func(): _begin_export(false))
	actions.add_child(_export_button)
	_cancel_button = Button.new()
	_cancel_button.name = "CancelReviewPackage"
	_cancel_button.text = "Cancel"
	_cancel_button.disabled = true
	_cancel_button.pressed.connect(func(): _cancel_requested = true; _status_label.text = "Cancelling after the current frame…")
	actions.add_child(_cancel_button)
	_reveal_button = Button.new()
	_reveal_button.name = "RevealReviewPackage"
	_reveal_button.text = "Reveal output"
	_reveal_button.disabled = true
	_reveal_button.pressed.connect(func(): if not _last_output.is_empty(): OS.shell_open(_last_output))
	actions.add_child(_reveal_button)
	_status_label = Label.new()
	_status_label.name = "ReviewStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_warning_dialog = ConfirmationDialog.new()
	_warning_dialog.title = "Export with warnings?"
	_warning_dialog.dialog_text = "The readiness report has warnings. Export will preserve them in the package manifest. Continue?"
	_warning_dialog.confirmed.connect(func(): _begin_export(true))
	add_child(_warning_dialog)


func _refresh() -> void:
	if _estimate_label == null: return
	if _session == null or not is_instance_valid(_session):
		_estimate_label.text = "Open a project to estimate review output."
		_status_label.text = "No project selected."
		_export_button.disabled = true
		return
	var estimate: Dictionary = _exporter.get_estimate(_session)
	_estimate_label.text = "%d clip/appearance item%s · %d frame%s · approximately %s · approximately %.0f seconds" % [int(estimate.get("items", 0)), "s" if int(estimate.get("items", 0)) != 1 else "", int(estimate.get("frames", 0)), "s" if int(estimate.get("frames", 0)) != 1 else "", _format_bytes(int(estimate.get("estimated_bytes", 0))), float(estimate.get("estimated_seconds", 0.0))]
	var report: Dictionary = _session.get_readiness_report({"require_clips": true})
	_status_label.text = "Resolve %d blocking issue%s before export." % [(report.get("errors", []) as Array).size(), "s" if (report.get("errors", []) as Array).size() != 1 else ""] if not bool(report.get("can_export", false)) else "Ready to render. Warnings will need confirmation."
	_export_button.disabled = false


func _begin_export(warnings_confirmed: bool) -> void:
	if _session == null or not is_instance_valid(_session): return
	_cancel_requested = false
	_export_button.disabled = true
	_cancel_button.disabled = false
	_status_label.text = "Preparing review package… Press Esc to cancel during rendering."
	var background := str(_background_picker.get_item_metadata(_background_picker.selected))
	var report: Dictionary = _exporter.export_package(_session, "", {"background": background, "warnings_confirmed": warnings_confirmed, "cancel_callable": Callable(self, "_is_cancel_requested"), "progress_callable": Callable(self, "_on_export_progress")})
	_cancel_button.disabled = true
	_export_button.disabled = false
	if bool(report.get("requires_warning_confirmation", false)):
		_warning_dialog.popup_centered()
		return
	if bool(report.get("cancelled", false)):
		_last_output = str(report.get("folder", ""))
		_reveal_button.disabled = _last_output.is_empty()
		_status_label.text = "Cancelled. The output folder has an incomplete manifest and no ZIP."
	elif report.get("success", false):
		_last_output = str(report.get("folder", ""))
		_reveal_button.disabled = false
		_status_label.text = "Review package complete: %s" % _last_output
	else:
		_status_label.text = str(report.get("errors", ["Review package failed."])[0])
	status_changed.emit(_status_label.text)


func _is_cancel_requested() -> bool:
	# The exporter performs deterministic CPU work on the main thread so it can
	# safely reuse the live document.  Flush buffered input here to make Escape
	# a reliable cancellation path even while a long package is rendering.
	Input.flush_buffered_events()
	if Input.is_key_pressed(KEY_ESCAPE): _cancel_requested = true
	return _cancel_requested


func _on_export_progress(progress: Dictionary) -> void:
	if _status_label == null: return
	_status_label.text = "Rendering %d / %d frames · %s" % [int(progress.get("completed", 0)), int(progress.get("total", 0)), str(progress.get("label", ""))]


func _on_session_changed(_description: String) -> void:
	_refresh()


func _format_bytes(bytes: int) -> String:
	if bytes < 1024 * 1024: return "%d KB" % maxi(1, bytes / 1024)
	if bytes < 1024 * 1024 * 1024: return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))
	return "%.2f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))
