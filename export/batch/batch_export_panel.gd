# BatchExportPanel -- Focusable export queue for character and weapon runtime package variants.
class_name BatchExportPanel
extends Control

const ControllerScript = preload("res://export/batch/batch_export_controller.gd")

@onready var variant_id: LineEdit = $Margin/Root/Queue/VariantId
@onready var variant_type: OptionButton = $Margin/Root/Queue/VariantType
@onready var output_path: LineEdit = $Margin/Root/OutputPath
@onready var output: RichTextLabel = $Margin/Root/Output
@onready var status_label: Label = $Margin/Root/Status

var controller = null


func _ready() -> void:
	variant_type.add_item("character")
	variant_type.add_item("weapon")
	$Margin/Root/Queue/Add.pressed.connect(_on_add)
	$Margin/Root/Actions/Export.pressed.connect(_on_export)
	$Margin/Root/Actions/Cancel.pressed.connect(_on_cancel)
	bind_context(null)


func bind_context(existing_controller) -> void:
	controller = existing_controller if existing_controller != null else ControllerScript.new()
	_refresh("Ready to queue variants.")


func _on_add() -> void:
	if controller == null: return
	var item_id := variant_id.text.strip_edges()
	var kind := variant_type.get_item_text(variant_type.selected)
	var added: bool = controller.add_variant(item_id, kind, {"project_id": item_id, "variant_type": kind})
	_refresh("Queued " + item_id + "." if added else "Variant IDs must be unique and non-empty.")


func _on_export() -> void:
	if controller == null: return
	var result: Dictionary = controller.export_all(output_path.text.strip_edges(), _on_progress)
	var validation: Dictionary = controller.validate_results(result)
	output.text = "Exported: %d\nCancelled: %s\nArtifacts valid: %s" % [result.get("results", []).size(), str(result.get("cancelled", false)), str(validation.get("valid", false))]
	_refresh("Export complete." if result.get("success", false) else "Export stopped safely.")


func _on_cancel() -> void:
	if controller != null: controller.request_cancel(); _refresh("Cancellation requested.")


func _on_progress(done: int, total: int, _result: Dictionary) -> void:
	_refresh("Exported %d of %d variants." % [done, total])


func _refresh(message: String) -> void:
	if status_label == null: return
	var lower := message.to_lower()
	var is_error := "stopped" in lower or "must" in lower or "failed" in lower
	var is_success := "complete" in lower or "ready" in lower or "queued" in lower
	status_label.text = ("× " if is_error else ("✓ " if is_success else "i ")) + message
	if ThemeService != null:
		status_label.add_theme_color_override("font_color", ThemeService.get_color_token("error" if is_error else ("success" if is_success else "blue")))
