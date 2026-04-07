class_name ExplorationManager
extends Node

const FloorGeneratorClass = preload("res://scripts/exploration/floor_generator.gd")
const NodeHandlerClass = preload("res://scripts/exploration/node_handler.gd")
const EventPanelClass = preload("res://scripts/exploration/event_panel.gd")
const InventoryPanelClass = preload("res://scripts/ui/inventory_panel.gd")

signal floor_entered(floor_number: int)
signal node_selected(node: Dictionary)
signal node_completed(node: Dictionary, result: String)
signal floor_completed(floor_number: int)
signal exploration_ended(reason: String)

var current_floor: int = 0
var floor_data: Dictionary = {}
var current_node_id: int = -1
var reachable_node_ids: Array = []
var _is_node_busy: bool = false
var _current_event_panel = null
var _inventory_panel = null
var _current_event_data: Dictionary = {}
var _current_event_options: Array = []
var _merchant_stock: Array = []

@onready var node_map_ui = $NodeMapUI
@onready var floor_info_label: Label = $FloorInfoLabel
@onready var action_log: RichTextLabel = $ActionLog
@onready var inventory_button: Button = $InventoryButton
@onready var return_button: Button = $ReturnButton


func _ready() -> void:
	node_map_ui.node_clicked.connect(_on_node_clicked)
	inventory_button.pressed.connect(_on_inventory_pressed)
	return_button.pressed.connect(return_to_safe_zone)
	_set_node_busy(false)


func enter_floor(floor_number: int) -> void:
	current_floor = floor_number
	floor_data = FloorGeneratorClass.generate_floor(floor_number)
	current_node_id = int(floor_data.get("entrance_id", 0))
	_current_event_data.clear()
	_current_event_options.clear()
	_merchant_stock.clear()
	_close_event_panel()
	_close_inventory_panel()
	_set_node_busy(false)

	if action_log != null:
		action_log.clear()

	_mark_node_visited(current_node_id)
	_update_reachable()
	_update_ui()

	floor_info_label.text = "%dF - %s" % [
		floor_number,
		String(floor_data.get("zone_name", "")),
	]
	add_log("進入 %dF - %s" % [floor_number, String(floor_data.get("zone_name", ""))], Color.GOLD)
	floor_entered.emit(floor_number)


func save_state() -> Dictionary:
	return {
		"floor_number": current_floor,
		"floor_data": floor_data.duplicate(true),
		"current_node_id": current_node_id,
		"reachable_node_ids": reachable_node_ids.duplicate(),
	}


func restore_state(state: Dictionary) -> void:
	current_floor = int(state.get("floor_number", 0))
	var saved_floor_data: Dictionary = Dictionary(state.get("floor_data", {}))
	floor_data = saved_floor_data.duplicate(true)
	current_node_id = int(state.get("current_node_id", -1))
	var saved_reachable: Array = Array(state.get("reachable_node_ids", []))
	reachable_node_ids = saved_reachable.duplicate()

	if action_log != null:
		action_log.clear()

	_close_event_panel()
	_close_inventory_panel()
	_set_node_busy(false)
	_update_ui()
	floor_info_label.text = "%dF - %s" % [current_floor, String(floor_data.get("zone_name", ""))]

	var battle_result: String = String(state.get("battle_result", ""))
	var current_node: Dictionary = _get_node(current_node_id)
	match battle_result:
		"victory":
			add_log("戰鬥勝利！繼續探索。", Color.GOLD)
			if String(current_node.get("type", "")) == "boss":
				_complete_floor()
			else:
				node_completed.emit(current_node, "victory")
		"defeat":
			add_log("戰鬥失敗…返回安全區。", Color.RED)
			return_to_safe_zone()
		"flee":
			add_log("成功逃跑，回到地圖。", Color.YELLOW)
			node_completed.emit(current_node, "flee")


func select_node(node_id: int) -> void:
	if _is_node_busy:
		return
	if not reachable_node_ids.has(node_id):
		add_log("無法前往該節點", Color.RED)
		return

	var node: Dictionary = _get_node(node_id)
	if node.is_empty():
		return

	current_node_id = node_id
	_mark_node_visited(node_id)
	node = _get_node(node_id)

	var node_type: String = String(node.get("type", ""))
	add_log("前往 %s 節點" % FloorGeneratorClass.get_node_type_name(node_type), Color.WHITE)

	_update_reachable()
	_update_ui()
	node_selected.emit(node)

	match node_type:
		"exit":
			_complete_floor()
		"boss":
			_handle_battle_node(true, true)
		"battle":
			_handle_battle_node(false, false)
		"elite":
			_handle_battle_node(true, false)
		"event":
			_handle_event_node()
		"chest":
			_handle_chest_node()
		"merchant":
			_handle_merchant_node()
		"rest":
			_handle_rest_node()
		"altar":
			_handle_altar_node()
		_:
			node_completed.emit(node, "unknown")


func complete_current_node(result: String) -> void:
	var node: Dictionary = _get_node(current_node_id)
	if node.is_empty():
		return
	node_completed.emit(node, result)


func return_to_safe_zone() -> void:
	_close_event_panel()
	_close_inventory_panel()
	_set_node_busy(false)
	add_log("返回安全區", Color.YELLOW)
	exploration_ended.emit("return")


func _on_inventory_pressed() -> void:
	if _is_node_busy or _inventory_panel != null:
		return

	_set_node_busy(true)
	_inventory_panel = InventoryPanelClass.new()
	_inventory_panel.position = Vector2(80, 40)
	add_child(_inventory_panel)
	_inventory_panel.setup(InventoryPanelClass.Mode.EXPLORATION)
	_inventory_panel.panel_closed.connect(_close_inventory_panel)
	_inventory_panel.item_action_performed.connect(_on_inventory_action)


func _close_inventory_panel() -> void:
	if _inventory_panel != null and is_instance_valid(_inventory_panel):
		_inventory_panel.queue_free()
	_inventory_panel = null
	if _current_event_panel == null:
		_set_node_busy(false)


func _on_inventory_action(item_id: String, action: String) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_name: String = String(item_data.get("name", item_id))
	add_log("%s：%s" % [item_name, action], Color.GREEN)


func _handle_battle_node(is_elite: bool, is_boss: bool) -> void:
	_set_node_busy(true)
	var enemy_ids: Array = NodeHandlerClass.generate_battle_enemies(current_floor, is_elite or is_boss)
	var config: Dictionary = NodeHandlerClass.build_battle_config(
		current_floor,
		String(floor_data.get("zone_element", "none")),
		is_boss
	)

	var enemy_names: Array = []
	for raw_enemy_id in enemy_ids:
		var enemy_id: String = String(raw_enemy_id)
		var enemy_data: Dictionary = DataManager.get_enemy(enemy_id)
		enemy_names.append(String(enemy_data.get("name", enemy_id)))

	add_log("遭遇敵人：%s" % ", ".join(enemy_names), Color.RED)
	GameManager.start_exploration_battle(enemy_ids, config, save_state())


func _handle_event_node() -> void:
	_set_node_busy(true)
	_current_event_data = NodeHandlerClass.pick_event(current_floor)

	var title: String = String(_current_event_data.get("name", "事件"))
	var description: String = String(_current_event_data.get("description", ""))
	var options_data: Array = Array(_current_event_data.get("options", []))
	var conditional_options: Array = Array(_current_event_data.get("conditional_options", []))

	_current_event_options.clear()
	var panel_options: Array = []

	for raw_option in options_data:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var enabled: bool = NodeHandlerClass.evaluate_option_condition(option)
		_current_event_options.append(option)
		panel_options.append({
			"text": String(option.get("text", "???")),
			"enabled": enabled,
		})

	for raw_option in conditional_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var enabled: bool = NodeHandlerClass.evaluate_option_condition(option)
		if enabled:
			_current_event_options.append(option)
			panel_options.append({
				"text": "%s（特殊）" % String(option.get("text", "???")),
				"enabled": true,
			})

	_show_event_panel(title, description, panel_options)


func _handle_chest_node() -> void:
	_set_node_busy(true)
	var reward: Dictionary = NodeHandlerClass.generate_chest_reward(current_floor)
	var rarity: String = String(reward.get("rarity", "N"))
	var gold: int = int(reward.get("gold", 0))
	var description: String = "發現了一個 %s 品質的寶箱！" % rarity
	var results_text: String = "獲得 %d 金幣" % gold

	add_log("打開寶箱：%s" % results_text, Color.YELLOW)
	_show_result_panel("寶箱", description + "\n" + results_text)


func _handle_merchant_node() -> void:
	_set_node_busy(true)
	_merchant_stock = NodeHandlerClass.generate_merchant_stock(current_floor)
	_current_event_options = _merchant_stock.duplicate(true)
	_current_event_options.append({"id": "leave", "name": "離開"})

	var panel_options: Array = []
	for raw_item in _merchant_stock:
		var item: Dictionary = raw_item
		var can_afford: bool = PlayerManager.player_data != null and PlayerManager.player_data.gold >= int(item.get("price", 0))
		panel_options.append({
			"text": "%s - %dG" % [String(item.get("name", "")), int(item.get("price", 0))],
			"enabled": can_afford,
		})
	panel_options.append({"text": "離開", "enabled": true})

	var current_gold: int = PlayerManager.player_data.gold if PlayerManager.player_data != null else 0
	_show_event_panel("旅行商人", "歡迎光臨！看看有什麼需要的？\n（持有 %dG）" % current_gold, panel_options)


func _handle_rest_node() -> void:
	_set_node_busy(true)
	var result: Dictionary = NodeHandlerClass.apply_rest()
	var text: String = "休息完畢，回復了 %d HP, %d MP\nHP: %d/%d  MP: %d/%d" % [
		int(result.get("hp_restored", 0)),
		int(result.get("mp_restored", 0)),
		int(result.get("current_hp", 0)),
		int(result.get("max_hp", 0)),
		int(result.get("current_mp", 0)),
		int(result.get("max_mp", 0)),
	]
	add_log(text, Color.GREEN)
	_show_result_panel("中繼點", "你在營火旁休息了一會兒。\n\n" + text)


func _handle_altar_node() -> void:
	_set_node_busy(true)
	var altar_options: Array = NodeHandlerClass.get_altar_options()
	_current_event_options.clear()

	var panel_options: Array = []
	for raw_option in altar_options:
		var option: Dictionary = raw_option
		var can_use: bool = true
		var cost_type: String = String(option.get("cost_type", "none"))
		match cost_type:
			"gold":
				can_use = PlayerManager.player_data != null and PlayerManager.player_data.gold >= int(option.get("cost_value", 0))
			"hp":
				can_use = PlayerManager.player_data != null and PlayerManager.player_data.current_hp > 1
			"mp":
				can_use = PlayerManager.player_data != null and PlayerManager.player_data.current_mp > 0

		_current_event_options.append(option)
		panel_options.append({
			"text": "%s - %s" % [String(option.get("name", "")), String(option.get("description", ""))],
			"enabled": can_use,
		})

	_show_event_panel("祭壇", "一座散發著神秘氣息的祭壇矗立在你面前。", panel_options)


func _show_event_panel(title: String, description: String, options: Array) -> void:
	_close_event_panel()
	_current_event_panel = EventPanelClass.new()
	add_child(_current_event_panel)
	_current_event_panel.setup(title, description, options)
	_current_event_panel.option_selected.connect(_on_event_option_selected)
	_current_event_panel.panel_closed.connect(_on_event_panel_closed)
	_current_event_panel.position = (get_viewport().get_visible_rect().size - _current_event_panel.custom_minimum_size) / 2.0


func _show_result_panel(title: String, text: String) -> void:
	_close_event_panel()
	_current_event_panel = EventPanelClass.new()
	add_child(_current_event_panel)
	_current_event_panel.setup(title, "", [])
	_current_event_panel.show_results(text)
	_current_event_panel.panel_closed.connect(_on_event_panel_closed)
	_current_event_panel.position = (get_viewport().get_visible_rect().size - _current_event_panel.custom_minimum_size) / 2.0


func _close_event_panel() -> void:
	if _current_event_panel != null and is_instance_valid(_current_event_panel):
		_current_event_panel.queue_free()
	_current_event_panel = null


func _on_event_option_selected(index: int) -> void:
	var node: Dictionary = _get_node(current_node_id)
	var node_type: String = String(node.get("type", ""))

	if index < 0 or index >= _current_event_options.size():
		_close_event_panel()
		_set_node_busy(false)
		node_completed.emit(node, "completed")
		return

	var option: Dictionary = _current_event_options[index]
	match node_type:
		"event":
			var outcomes: Array = NodeHandlerClass.execute_event_results(option)
			var results_lines: Array = []
			var trigger_battle: bool = false
			var battle_enemy_id: String = ""
			for raw_outcome in outcomes:
				var outcome: Dictionary = raw_outcome
				var text: String = String(outcome.get("text", ""))
				results_lines.append(text)
				add_log(text, Color.CYAN)
				if String(outcome.get("type", "")) == "battle":
					trigger_battle = true
					battle_enemy_id = String(outcome.get("enemy_id", ""))

			if trigger_battle and not battle_enemy_id.is_empty():
				_close_event_panel()
				_handle_event_battle(battle_enemy_id)
			else:
				_current_event_panel.show_results("\n".join(results_lines))
		"altar":
			var altar_result: Dictionary = NodeHandlerClass.execute_altar(String(option.get("id", "")))
			var altar_text: String = String(altar_result.get("text", "無法進行獻祭。"))
			if bool(altar_result.get("success", false)):
				add_log(altar_text, Color.MAGENTA)
			else:
				add_log("無法進行獻祭：%s" % String(altar_result.get("reason", "")), Color.RED)
			_current_event_panel.show_results(altar_text)
		"merchant":
			if String(option.get("id", "")) == "leave":
				_close_event_panel()
				_set_node_busy(false)
				node_completed.emit(node, "completed")
				return
			var buy_result: Dictionary = NodeHandlerClass.buy_item(option)
			if bool(buy_result.get("success", false)):
				var item_name: String = String(buy_result.get("item_name", ""))
				var price: int = int(buy_result.get("price", 0))
				add_log("購買了 %s（%dG）" % [item_name, price], Color.GREEN)
				_current_event_panel.show_results("購買成功！\n%s 已入手。" % item_name)
			else:
				add_log("金幣不足！", Color.RED)
				_current_event_panel.show_results("金幣不足，無法購買。")


func _handle_event_battle(enemy_id: String) -> void:
	var config: Dictionary = NodeHandlerClass.build_battle_config(
		current_floor,
		String(floor_data.get("zone_element", "none")),
		false
	)
	GameManager.start_exploration_battle([enemy_id], config, save_state())


func _on_event_panel_closed() -> void:
	_close_event_panel()
	_set_node_busy(false)
	node_completed.emit(_get_node(current_node_id), "completed")


func _complete_floor() -> void:
	add_log("樓層完成！", Color.GOLD)

	if PlayerManager.player_data != null:
		if current_floor >= PlayerManager.player_data.highest_floor:
			PlayerManager.player_data.highest_floor = current_floor + 1

		if bool(floor_data.get("is_boss_floor", false)):
			var next_safe: int = current_floor + 1
			if _is_safe_floor(next_safe):
				if not PlayerManager.player_data.unlocked_teleports.has(next_safe):
					PlayerManager.player_data.unlocked_teleports.append(next_safe)
					add_log("傳送門已解鎖：%dF！" % next_safe, Color("#FFD700"))

	floor_completed.emit(current_floor)


func _is_safe_floor(floor_number: int) -> bool:
	var config: Dictionary = DataManager.get_floor_config()
	var safe_floors: Array = Array(config.get("safe_floors", []))
	for raw_floor in safe_floors:
		if int(raw_floor) == floor_number:
			return true
	return false


func _update_reachable() -> void:
	reachable_node_ids.clear()
	var current: Dictionary = _get_node(current_node_id)
	if current.is_empty():
		return
	var connections: Array = Array(current.get("connections", []))
	for raw_connection_id in connections:
		reachable_node_ids.append(int(raw_connection_id))


func _update_ui() -> void:
	if node_map_ui != null:
		node_map_ui.update_map(floor_data, current_node_id, reachable_node_ids)
		if node_map_ui.has_method("set_interaction_locked"):
			node_map_ui.set_interaction_locked(_is_node_busy)


func _get_node(node_id: int) -> Dictionary:
	var nodes: Array = Array(floor_data.get("nodes", []))
	for raw_node in nodes:
		var node: Dictionary = raw_node
		if int(node.get("id", -1)) == node_id:
			return node
	return {}


func _find_node_index(node_id: int) -> int:
	var nodes: Array = Array(floor_data.get("nodes", []))
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		if int(node.get("id", -1)) == node_id:
			return index
	return -1


func _mark_node_visited(node_id: int) -> void:
	var nodes: Array = Array(floor_data.get("nodes", []))
	var node_index: int = _find_node_index(node_id)
	if node_index < 0:
		return
	var node: Dictionary = nodes[node_index]
	node["visited"] = true
	nodes[node_index] = node
	floor_data["nodes"] = nodes


func _set_node_busy(is_busy: bool) -> void:
	_is_node_busy = is_busy
	if inventory_button != null:
		inventory_button.disabled = is_busy
	if node_map_ui != null and node_map_ui.has_method("set_interaction_locked"):
		node_map_ui.set_interaction_locked(is_busy)


func _on_node_clicked(node_id: int) -> void:
	select_node(node_id)


func add_log(text: String, color: Color = Color.WHITE) -> void:
	if action_log == null:
		return
	action_log.push_color(color)
	action_log.append_text(text + "\n")
	action_log.pop()
