class_name EventPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal option_selected(index: int)
signal panel_closed

var _title_label: Label
var _description_label: RichTextLabel
var _options_container: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(500, 300)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true


func setup(title: String, description: String, options: Array) -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.offset_left = 16.0
	root.offset_top = 16.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	root.add_child(_title_label)

	var separator := HSeparator.new()
	root.add_child(separator)

	_description_label = RichTextLabel.new()
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.custom_minimum_size.y = 60.0
	_description_label.scroll_active = false
	_description_label.text = description
	root.add_child(_description_label)

	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 6)
	root.add_child(_options_container)

	for index in range(options.size()):
		var option: Dictionary = options[index]
		var button := Button.new()
		button.text = String(option.get("text", option.get("name", "???")))
		button.custom_minimum_size.y = float(ThemeConstantsClass.BUTTON_MIN_HEIGHT)
		button.disabled = not bool(option.get("enabled", true))
		var option_index: int = index
		button.pressed.connect(func(): _on_option_pressed(option_index))
		_options_container.add_child(button)


func show_results(results_text: String) -> void:
	if _options_container == null or _description_label == null:
		return

	for child in _options_container.get_children():
		child.queue_free()

	_description_label.text = results_text

	var close_button := Button.new()
	close_button.text = "繼續"
	close_button.custom_minimum_size.y = float(ThemeConstantsClass.BUTTON_MIN_HEIGHT)
	close_button.pressed.connect(func(): panel_closed.emit())
	_options_container.add_child(close_button)


func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)
