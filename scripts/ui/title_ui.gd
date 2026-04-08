class_name TitleUI
extends Control

signal new_game_requested
signal load_game_requested(slot: int)
signal quit_requested

@onready var title_label: Label = $TitleLabel
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var load_game_button: Button = $MenuContainer/LoadGameButton
@onready var quit_button: Button = $MenuContainer/QuitButton
@onready var save_info_label: Label = $SaveInfoLabel

const CombatantVisualClass = preload("res://scripts/ui/combatant_visual.gd")


func _ready() -> void:
	_add_title_visual()
	new_game_button.pressed.connect(_request_new_game)
	load_game_button.pressed.connect(func(): _try_load_game())
	quit_button.pressed.connect(_request_quit)

	load_game_button.disabled = not SaveManager.has_save(1)
	if SaveManager.has_save(1):
		var info: Dictionary = SaveManager.get_save_info(1)
		save_info_label.text = "存檔: Lv.%d / %dF" % [
			int(info.get("level", 1)),
			int(info.get("highest_floor", 1)),
		]
	else:
		save_info_label.text = ""


func _try_load_game() -> void:
	if get_signal_connection_list("load_game_requested").is_empty():
		if GameManager != null:
			GameManager.load_saved_game(1)
		return
	load_game_requested.emit(1)


func _request_new_game() -> void:
	if get_signal_connection_list("new_game_requested").is_empty():
		if GameManager != null:
			GameManager.start_new_game()
		return
	new_game_requested.emit()


func _request_quit() -> void:
	if get_signal_connection_list("quit_requested").is_empty():
		if GameManager != null:
			GameManager.quit_game()
		return
	quit_requested.emit()


func _add_title_visual() -> void:
	var visual := CombatantVisualClass.new()
	visual.name = "TitleVisual"
	visual.custom_minimum_size = Vector2(160, 160)
	visual.is_player = true
	visual.element = "light"
	# Position it above title or centered
	visual.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	visual.position = Vector2(1920/2.0 - 80, 80) # Rough estimate for 1080p
	add_child(visual)
