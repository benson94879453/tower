class_name TavernPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal panel_closed
signal quest_action_performed(action: String, detail: String)

enum Tab { BOARD, ACTIVE }

const MAX_ACTIVE_QUESTS := 3

var _current_floor: int = 1
var _current_tab: int = Tab.BOARD
var _selected_quest_id: String = ""
var _status_message: String = ""

var _meta_label: Label
var _board_tab_button: Button
var _active_tab_button: Button
var _list_container: VBoxContainer
var _detail_name: Label
var _detail_desc: RichTextLabel
var _detail_stats: RichTextLabel
var _footer_label: Label
var _action_container: HBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(860, 580)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(safe_floor: int) -> void:
	_current_floor = safe_floor
	_current_tab = Tab.BOARD
	_selected_quest_id = ""
	_status_message = ""

	if QuestManager != null:
		QuestManager.on_item_changed()
		if QuestManager.get_bounty_board().is_empty():
			QuestManager.refresh_bounty_board(safe_floor)

	for child in get_children():
		child.queue_free()

	_build_ui()
	_refresh_list()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 16.0
	root.offset_top = 16.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_label := Label.new()
	title_label.text = "冒險者酒館"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(title_label)

	_meta_label = Label.new()
	_meta_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	_meta_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	header.add_child(_meta_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)

	_board_tab_button = _create_tab_button("懸賞板", Tab.BOARD)
	tabs.add_child(_board_tab_button)

	_active_tab_button = _create_tab_button("進行中", Tab.ACTIVE)
	tabs.add_child(_active_tab_button)

	root.add_child(HSeparator.new())

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.15
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 2)
	scroll.add_child(_list_container)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.85
	detail_panel.custom_minimum_size.x = 280.0
	content.add_child(detail_panel)

	var detail_root := VBoxContainer.new()
	detail_root.add_theme_constant_override("separation", 8)
	detail_root.anchor_right = 1.0
	detail_root.anchor_bottom = 1.0
	detail_root.offset_left = 12.0
	detail_root.offset_top = 12.0
	detail_root.offset_right = -12.0
	detail_root.offset_bottom = -12.0
	detail_panel.add_child(detail_root)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	detail_root.add_child(_detail_name)
	detail_root.add_child(HSeparator.new())

	_detail_desc = RichTextLabel.new()
	_detail_desc.bbcode_enabled = true
	_detail_desc.fit_content = true
	_detail_desc.scroll_active = false
	_detail_desc.custom_minimum_size.y = 100.0
	detail_root.add_child(_detail_desc)

	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.custom_minimum_size.y = 200.0
	detail_root.add_child(_detail_stats)

	_footer_label = Label.new()
	_footer_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	_footer_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	detail_root.add_child(_footer_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_root.add_child(spacer)

	_action_container = HBoxContainer.new()
	_action_container.add_theme_constant_override("separation", 8)
	detail_root.add_child(_action_container)

	_clear_detail()


func _refresh_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	_update_tab_style()

	var entries: Array[Dictionary] = _get_current_entries()
	if entries.is_empty():
		_selected_quest_id = ""
		_update_meta_label(entries)
		_add_empty_label(_get_empty_text())
		_clear_detail()
		return

	var available_ids: Array[String] = []
	for entry in entries:
		available_ids.append(String(entry.get("id", "")))
	if not available_ids.has(_selected_quest_id):
		_selected_quest_id = available_ids[0]

	for entry in entries:
		var quest_id: String = String(entry.get("id", ""))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 38.0
		row.text = _build_list_text(entry)
		row.add_theme_color_override("font_color", _get_row_color(entry))
		if quest_id == _selected_quest_id:
			row.disabled = true
		row.pressed.connect(_on_entry_selected.bind(quest_id))
		_list_container.add_child(row)

	_update_meta_label(entries)
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_quest_id.is_empty():
		_clear_detail()
		return

	var quest_data: Dictionary = _get_selected_entry()
	if quest_data.is_empty():
		_clear_detail()
		return

	_show_quest_detail(quest_data)


func _show_quest_detail(quest_data: Dictionary) -> void:
	var quest_type: String = String(quest_data.get("type", ""))
	var title_color: Color = _get_quest_type_color(quest_type)
	_prepare_detail(String(quest_data.get("name", "未命名任務")), title_color)

	_append_lines(_detail_desc, [
		"類型: %s" % _format_quest_type(quest_type),
		"說明: %s" % String(quest_data.get("description", "")),
	])

	var lines: Array[String] = ["目標"]
	var objective_states: Array[Dictionary] = []
	if _current_tab == Tab.ACTIVE:
		objective_states = Array(quest_data.get("objective_states", []))
	else:
		objective_states = _build_preview_objective_states(quest_data)

	for objective_state in objective_states:
		lines.append("- %s" % String(objective_state.get("label", "")))

	lines.append("")
	lines.append("獎勵")
	lines.append_array(_build_reward_lines(Dictionary(quest_data.get("rewards", {}))))
	_append_lines(_detail_stats, lines)

	if _current_tab == Tab.BOARD:
		_show_board_actions(quest_data)
	else:
		_show_active_actions(quest_data)


func _show_board_actions(quest_data: Dictionary) -> void:
	var accept_state: Dictionary = _build_accept_state(String(quest_data.get("id", "")))
	_footer_label.text = String(accept_state.get("message", ""))

	var accept_button := Button.new()
	accept_button.text = "接取" if bool(accept_state.get("can_accept", false)) else "接取 - %s" % String(accept_state.get("message", ""))
	accept_button.custom_minimum_size = Vector2(120, 40)
	accept_button.disabled = not bool(accept_state.get("can_accept", false))
	accept_button.pressed.connect(_on_accept_pressed.bind(String(quest_data.get("id", ""))))
	_action_container.add_child(accept_button)


func _show_active_actions(quest_data: Dictionary) -> void:
	var is_complete: bool = bool(quest_data.get("is_complete", false))
	_footer_label.text = "狀態: 可回報" if is_complete else "狀態: 進行中"

	if is_complete:
		var complete_button := Button.new()
		complete_button.text = "領取獎勵"
		complete_button.custom_minimum_size = Vector2(120, 40)
		complete_button.pressed.connect(_on_complete_pressed.bind(String(quest_data.get("id", ""))))
		_action_container.add_child(complete_button)
	else:
		var abandon_button := Button.new()
		abandon_button.text = "放棄"
		abandon_button.custom_minimum_size = Vector2(120, 40)
		abandon_button.pressed.connect(_on_abandon_pressed.bind(String(quest_data.get("id", ""))))
		_action_container.add_child(abandon_button)


func _prepare_detail(title: String, color: Color) -> void:
	_detail_name.text = title
	_detail_name.add_theme_color_override("font_color", color)
	_detail_desc.clear()
	_detail_stats.clear()
	_footer_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _clear_detail() -> void:
	_detail_name.text = "選擇任務"
	_detail_name.remove_theme_color_override("font_color")
	_detail_desc.clear()
	_detail_desc.append_text("選擇左側任務以查看詳細資訊。")
	_detail_stats.clear()
	_footer_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _get_current_entries() -> Array[Dictionary]:
	if QuestManager == null:
		return []

	match _current_tab:
		Tab.BOARD:
			var result: Array[Dictionary] = []
			for quest_data in QuestManager.get_bounty_board():
				result.append(Dictionary(quest_data).duplicate(true))
			for quest_data in QuestManager.get_available_side_quests(_current_floor):
				result.append(Dictionary(quest_data).duplicate(true))
			return result
		Tab.ACTIVE:
			return QuestManager.get_active_quests()
		_:
			return []


func _get_selected_entry() -> Dictionary:
	for entry in _get_current_entries():
		if String(entry.get("id", "")) == _selected_quest_id:
			return entry
	return {}


func _build_list_text(entry: Dictionary) -> String:
	var quest_name: String = String(entry.get("name", String(entry.get("id", ""))))
	if _current_tab == Tab.BOARD:
		return "[%s] %s" % [_format_quest_type(String(entry.get("type", ""))), quest_name]
	return "%s (%s)" % [quest_name, _build_active_summary(entry)]


func _build_active_summary(entry: Dictionary) -> String:
	var objective_states: Array = Array(entry.get("objective_states", []))
	if bool(entry.get("is_complete", false)):
		return "完成！"
	if objective_states.size() == 1 and objective_states[0] is Dictionary:
		var state: Dictionary = objective_states[0]
		return "%d/%d" % [int(state.get("current", 0)), int(state.get("target", 1))]

	var completed_count: int = 0
	for raw_state in objective_states:
		if raw_state is Dictionary and bool(Dictionary(raw_state).get("completed", false)):
			completed_count += 1
	return "%d/%d" % [completed_count, objective_states.size()]


func _get_row_color(entry: Dictionary) -> Color:
	if _current_tab == Tab.BOARD:
		return _get_quest_type_color(String(entry.get("type", "")))
	return Color("#7AD1A8") if bool(entry.get("is_complete", false)) else ThemeConstantsClass.TEXT_PRIMARY


func _update_meta_label(entries: Array[Dictionary]) -> void:
	var text: String = ""
	match _current_tab:
		Tab.BOARD:
			text = "可接取: %d" % entries.size()
		Tab.ACTIVE:
			text = "進行中: %d / %d" % [entries.size(), MAX_ACTIVE_QUESTS]
	if not _status_message.is_empty():
		text += "  %s" % _status_message
	_meta_label.text = text


func _create_tab_button(text: String, tab: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 36)
	button.pressed.connect(_on_tab_selected.bind(tab))
	return button


func _on_tab_selected(tab: int) -> void:
	if _current_tab == tab:
		return
	_current_tab = tab
	_status_message = ""
	_selected_quest_id = ""
	_refresh_list()


func _on_entry_selected(quest_id: String) -> void:
	_selected_quest_id = quest_id
	_refresh_detail()


func _on_accept_pressed(quest_id: String) -> void:
	var result: Dictionary = QuestManager.accept_quest(quest_id)
	if bool(result.get("success", false)):
		_status_message = "已接取任務。"
		_current_tab = Tab.ACTIVE
		_selected_quest_id = quest_id
		quest_action_performed.emit("accepted", quest_id)
	else:
		_status_message = _format_accept_reason(String(result.get("reason", "")))
	_refresh_list()


func _on_abandon_pressed(quest_id: String) -> void:
	QuestManager.abandon_quest(quest_id)
	_status_message = "已放棄任務。"
	quest_action_performed.emit("abandoned", quest_id)
	_refresh_list()


func _on_complete_pressed(quest_id: String) -> void:
	var result: Dictionary = QuestManager.complete_quest(quest_id)
	if bool(result.get("success", false)):
		_status_message = "已領取任務獎勵。"
		quest_action_performed.emit("completed", quest_id)
	else:
		_status_message = _format_complete_reason(result)
	_refresh_list()


func _update_tab_style() -> void:
	_board_tab_button.disabled = _current_tab == Tab.BOARD
	_active_tab_button.disabled = _current_tab == Tab.ACTIVE


func _build_accept_state(quest_id: String) -> Dictionary:
	if QuestManager == null:
		return {"can_accept": false, "message": "任務系統未就緒"}

	if QuestManager.get_active_quests().size() >= MAX_ACTIVE_QUESTS:
		return {"can_accept": false, "message": "任務已滿"}

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return {"can_accept": false, "message": "資料遺失"}
	if PlayerManager.player_data != null and PlayerManager.player_data.completed_quests.has(quest_id) and not bool(quest_data.get("repeatable", false)):
		return {"can_accept": false, "message": "已完成"}
	for active_quest in QuestManager.get_active_quests():
		if String(active_quest.get("id", "")) == quest_id:
			return {"can_accept": false, "message": "已接取"}
	return {"can_accept": true, "message": "可接取"}


func _build_preview_objective_states(quest_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var objectives: Array = Array(quest_data.get("objectives", []))
	for objective_index in range(objectives.size()):
		var objective: Dictionary = Dictionary(objectives[objective_index])
		var target: int = _get_objective_target(objective)
		result.append({
			"objective_index": objective_index,
			"current": 0,
			"target": target,
			"completed": false,
			"label": _build_preview_objective_label(objective, target),
		})
	return result


func _build_preview_objective_label(objective: Dictionary, target: int) -> String:
	match String(objective.get("type", "")):
		"kill":
			var enemy_id: String = String(objective.get("target_id", ""))
			return "討伐 %s ×%d" % [String(DataManager.get_enemy(enemy_id).get("name", enemy_id)), target]
		"collect":
			var item_id: String = String(objective.get("item_id", ""))
			return "收集 %s ×%d" % [String(DataManager.get_item(item_id).get("name", item_id)), target]
		"reach_floor":
			return "抵達 %dF" % int(objective.get("floor", 0))
		"kill_boss":
			return "擊敗 %dF Boss" % int(objective.get("floor", 0))
		_:
			return "完成任務目標"


func _get_objective_target(objective: Dictionary) -> int:
	return max(int(objective.get("count", 1)), 1)


func _build_reward_lines(rewards: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var gold: int = max(int(rewards.get("gold", 0)), 0)
	if gold > 0:
		lines.append("- 金幣: %d" % gold)

	var exp_amount: int = max(int(rewards.get("exp", 0)), 0)
	if exp_amount > 0:
		lines.append("- EXP: %d" % exp_amount)

	for raw_item in Array(rewards.get("items", [])):
		if raw_item is not Dictionary:
			continue
		var item_reward: Dictionary = Dictionary(raw_item)
		var item_id: String = String(item_reward.get("id", ""))
		var item_name: String = String(DataManager.get_item(item_id).get("name", item_id))
		lines.append("- %s ×%d" % [item_name, max(int(item_reward.get("count", 0)), 0)])

	for raw_skill_id in Array(rewards.get("skills", [])):
		var skill_id: String = String(raw_skill_id)
		var skill_name: String = String(DataManager.get_skill(skill_id).get("name", skill_id))
		lines.append("- 技能: %s" % skill_name)

	if lines.is_empty():
		lines.append("- 無")
	return lines


func _format_quest_type(quest_type: String) -> String:
	match quest_type:
		"bounty":
			return "懸賞"
		"side":
			return "支線"
		_:
			return "任務"


func _get_quest_type_color(quest_type: String) -> Color:
	match quest_type:
		"bounty":
			return Color("#F2C14E")
		"side":
			return Color("#7AD1A8")
		_:
			return ThemeConstantsClass.TEXT_PRIMARY


func _format_accept_reason(reason: String) -> String:
	match reason:
		"already_active":
			return "這個任務已經接了。"
		"max_quests":
			return "任務已滿。"
		"already_completed":
			return "這個任務已經完成。"
		"not_found":
			return "找不到任務資料。"
		_:
			return "無法接取任務。"


func _format_complete_reason(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"missing_items":
			return "交付素材不足。"
		"not_ready":
			return "任務條件尚未完成。"
		"not_found":
			return "找不到任務資料。"
		_:
			return "領取獎勵失敗。"


func _append_lines(target: RichTextLabel, lines: Array[String]) -> void:
	for line in lines:
		target.append_text("%s\n" % line)


func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_list_container.add_child(label)


func _get_empty_text() -> String:
	match _current_tab:
		Tab.BOARD:
			return "（目前沒有可接取的任務）"
		Tab.ACTIVE:
			return "（目前沒有進行中的任務）"
		_:
			return "（目前沒有資料）"
