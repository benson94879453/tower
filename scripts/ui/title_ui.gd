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


func _ready() -> void:
	new_game_button.pressed.connect(func(): new_game_requested.emit())
	load_game_button.pressed.connect(func(): _try_load_game())
	quit_button.pressed.connect(func(): quit_requested.emit())

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
	load_game_requested.emit(1)
