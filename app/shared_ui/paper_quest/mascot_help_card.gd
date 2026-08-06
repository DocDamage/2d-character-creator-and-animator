class_name MascotHelpCard
extends PanelContainer

@export var title := "Pip's guide"
@export_multiline var message := "Choose a workspace to continue your quest."
@export var dismissible := true

@onready var _title_label: Label = get_node_or_null("Margin/Row/Copy/Title")
@onready var _message_label: Label = get_node_or_null("Margin/Row/Copy/Message")
@onready var _dismiss_button: Button = get_node_or_null("Margin/Row/Copy/Dismiss")

func _ready() -> void:
	if _title_label != null:
		_title_label.text = title
	if _message_label != null:
		_message_label.text = message
	if _dismiss_button != null:
		_dismiss_button.visible = dismissible
		_dismiss_button.pressed.connect(_dismiss)
	tooltip_text = "%s: %s" % [title, message]

func set_message(new_title: String, new_message: String) -> void:
	title = new_title
	message = new_message
	if is_node_ready():
		_title_label.text = title
		_message_label.text = message

func _dismiss() -> void:
	visible = false
