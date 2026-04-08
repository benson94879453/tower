class_name TitleUI
extends Control

signal new_game_requested
signal load_game_requested(slot: int)
signal quit_requested

@onready var title_label: Label = $CenterContainer/TitleLabel
@onready var new_game_button: Button = $CenterContainer/MenuContainer/NewGameButton
@onready var load_game_button: Button = $CenterContainer/MenuContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/MenuContainer/QuitButton
@onready var save_info_label: Label = $CenterContainer/SaveInfoLabel


func _ready() -> void:
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
