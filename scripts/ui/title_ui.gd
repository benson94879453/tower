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
@onready var slot_panel: PanelContainer = $SlotPanel
@onready var slot_list: VBoxContainer = $SlotPanel/Padding/Content/SlotScroll/SlotList
@onready var slot_close_button: Button = $SlotPanel/Padding/Content/CloseButton

const CombatantVisualClass = preload("res://scripts/ui/combatant_visual.gd")
const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

var _slot_panel_mode: String = ""


func _ready() -> void:
	_add_title_visual()
	new_game_button.pressed.connect(_request_new_game)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_request_quit)
	slot_close_button.pressed.connect(_close_slot_panel)
	slot_panel.visible = false

	_update_save_info_summary()


func _update_save_info_summary() -> void:
	var any_save := false
	var latest_slot := -1
	var latest_time := ""
	for slot in range(1, SaveManager.MAX_SLOTS + 1):
		if SaveManager.has_save(slot):
			any_save = true
			var info: Dictionary = SaveManager.get_save_info(slot)
			var ts: String = String(info.get("timestamp", ""))
			if ts > latest_time:
				latest_time = ts
				latest_slot = slot

	load_game_button.disabled = not any_save
	if any_save and latest_slot >= 0:
		var info: Dictionary = SaveManager.get_save_info(latest_slot)
		save_info_label.text = "最新存檔: 欄位 %d - Lv.%d / %dF" % [
			latest_slot,
			int(info.get("level", 1)),
			int(info.get("highest_floor", 1)),
		]
	else:
		save_info_label.text = ""


func _on_load_game_pressed() -> void:
	_show_slot_panel("load")


func _show_slot_panel(mode: String) -> void:
	_slot_panel_mode = mode
	slot_panel.visible = true

	for child in slot_list.get_children():
		child.queue_free()

	var panel_title: Label = get_node_or_null("SlotPanel/Padding/Content/SlotTitle")
	if panel_title:
		panel_title.text = "選擇存檔讀取" if mode == "load" else "選擇存檔位置"

	for slot in range(1, SaveManager.MAX_SLOTS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 48.0
		slot_list.add_child(row)

		var info_label := Label.new()
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if SaveManager.has_save(slot):
			var info: Dictionary = SaveManager.get_save_info(slot)
			var ts: String = String(info.get("timestamp", ""))
			var date_part: String = ts.split("T")[0] if ts.find("T") >= 0 else ts
			info_label.text = "欄位 %d: Lv.%d / %dF / %s" % [
				slot,
				int(info.get("level", 1)),
				int(info.get("highest_floor", 1)),
				date_part,
			]
		else:
			info_label.text = "欄位 %d: (空)" % slot
			info_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		row.add_child(info_label)

		var action_btn := Button.new()
		if mode == "load":
			action_btn.text = "讀取"
			action_btn.disabled = not SaveManager.has_save(slot)
		else:
			action_btn.text = "存檔"
		action_btn.custom_minimum_size = Vector2(64, 36)
		var bound_slot := slot
		action_btn.pressed.connect(_on_slot_action.bind(bound_slot))
		row.add_child(action_btn)


func _on_slot_action(slot: int) -> void:
	_close_slot_panel()
	_try_load_game(slot)


func _close_slot_panel() -> void:
	slot_panel.visible = false


func _try_load_game(slot: int) -> void:
	if get_signal_connection_list("load_game_requested").is_empty():
		if GameManager != null:
			GameManager.load_saved_game(slot)
		return
	load_game_requested.emit(slot)


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
	visual.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	visual.position = Vector2(1920/2.0 - 80, 80)
	add_child(visual)
