class_name ShopPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal panel_closed
signal transaction_completed(item_id: String, action: String)

enum Tab { BUY, SELL }

var _current_tab: int = Tab.BUY
var _floor_number: int = 1
var _shop_stock: Array = []
var _selected_item_id: String = ""
var _selected_equipment_index: int = -1

var _title_label: Label
var _gold_label: Label
var _close_button: Button
var _buy_tab_button: Button
var _sell_tab_button: Button
var _item_list_container: VBoxContainer
var _scroll_container: ScrollContainer
var _detail_name: Label
var _detail_desc: RichTextLabel
var _detail_stats: RichTextLabel
var _price_label: Label
var _action_container: HBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(820, 560)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(floor_number: int) -> void:
	_floor_number = floor_number
	_current_tab = Tab.BUY
	_selected_item_id = ""
	_selected_equipment_index = -1

	for child in get_children():
		child.queue_free()

	_generate_stock()
	_build_ui()
	_refresh_list()


func _generate_stock() -> void:
	_shop_stock.clear()
	var available: Array = DataManager.get_items_for_shop(_floor_number)

	for raw_item in available:
		var item: Dictionary = raw_item
		var item_type: String = String(item.get("type", ""))
		if item_type == "consumable":
			_shop_stock.append(_make_stock_entry(item))

	var equipment_pool: Array = []
	for raw_item in available:
		var item: Dictionary = raw_item
		var item_type: String = String(item.get("type", ""))
		if item_type in ["weapon", "armor"]:
			equipment_pool.append(item)

	equipment_pool.shuffle()
	var equip_count: int = min(randi_range(2, 3), equipment_pool.size())
	for index in range(equip_count):
		_shop_stock.append(_make_stock_entry(equipment_pool[index]))


func _make_stock_entry(item_data: Dictionary) -> Dictionary:
	return {
		"id": String(item_data.get("id", "")),
		"name": String(item_data.get("name", "")),
		"price": int(item_data.get("buy_price", 0)),
		"sell_price": int(item_data.get("sell_price", 0)),
		"rarity": String(item_data.get("rarity", "N")),
		"type": String(item_data.get("type", "")),
	}


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 20.0
	root.offset_top = 20.0
	root.offset_right = -20.0
	root.offset_bottom = -20.0
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.text = "魔法商店"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	_gold_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	header.add_child(_gold_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(36, 36)
	_close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(_close_button)

	_update_gold_display()

	var tab_container := HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	root.add_child(tab_container)

	_buy_tab_button = Button.new()
	_buy_tab_button.text = "購買"
	_buy_tab_button.custom_minimum_size = Vector2(100, 36)
	_buy_tab_button.pressed.connect(_on_tab_pressed.bind(Tab.BUY))
	tab_container.add_child(_buy_tab_button)

	_sell_tab_button = Button.new()
	_sell_tab_button.text = "販賣"
	_sell_tab_button.custom_minimum_size = Vector2(100, 36)
	_sell_tab_button.pressed.connect(_on_tab_pressed.bind(Tab.SELL))
	tab_container.add_child(_sell_tab_button)

	root.add_child(HSeparator.new())

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_stretch_ratio = 1.2
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll_container)

	_item_list_container = VBoxContainer.new()
	_item_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list_container.add_theme_constant_override("separation", 2)
	_scroll_container.add_child(_item_list_container)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.8
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
	_detail_name.text = ""
	_detail_name.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	detail_root.add_child(_detail_name)

	detail_root.add_child(HSeparator.new())

	_detail_desc = RichTextLabel.new()
	_detail_desc.bbcode_enabled = true
	_detail_desc.fit_content = true
	_detail_desc.scroll_active = false
	_detail_desc.custom_minimum_size.y = 60.0
	detail_root.add_child(_detail_desc)

	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.custom_minimum_size.y = 40.0
	detail_root.add_child(_detail_stats)

	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	_price_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	detail_root.add_child(_price_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_root.add_child(spacer)

	_action_container = HBoxContainer.new()
	_action_container.add_theme_constant_override("separation", 8)
	detail_root.add_child(_action_container)

	_clear_detail()


func _refresh_list() -> void:
	for child in _item_list_container.get_children():
		child.queue_free()

	_selected_item_id = ""
	_selected_equipment_index = -1
	_clear_detail()
	_update_gold_display()
	_update_tab_style()

	match _current_tab:
		Tab.BUY:
			_populate_buy_list()
		Tab.SELL:
			_populate_sell_list()


func _populate_buy_list() -> void:
	if _shop_stock.is_empty():
		_add_empty_label("（目前沒有商品）")
		return

	for raw_stock_entry in _shop_stock:
		var stock_entry: Dictionary = raw_stock_entry
		var item_id: String = String(stock_entry.get("id", ""))
		var item_name: String = String(stock_entry.get("name", item_id))
		var price: int = int(stock_entry.get("price", 0))
		var rarity: String = String(stock_entry.get("rarity", "N"))
		var item_type: String = String(stock_entry.get("type", ""))

		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0

		var type_tag: String = ""
		match item_type:
			"consumable":
				type_tag = "消"
			"weapon":
				type_tag = "武"
			"armor":
				type_tag = "防"
			_:
				type_tag = "?"

		row.text = "[%s][%s] %s    %dG" % [rarity, type_tag, item_name, price]
		row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))
		if not _can_buy_item(item_id, price):
			row.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)

		var bound_item_id: String = item_id
		row.pressed.connect(_on_item_selected.bind(bound_item_id))
		_item_list_container.add_child(row)


func _populate_sell_list() -> void:
	if PlayerManager.inventory == null:
		_add_empty_label("（背包為空）")
		return

	var all_items: Array = PlayerManager.inventory.get_all_items()
	var shown: int = 0
	for raw_entry in all_items:
		var entry: Dictionary = raw_entry
		var item_id: String = String(entry.get("id", ""))
		var item_count: int = int(entry.get("count", 0))
		var equipment_index: int = int(entry.get("equipment_index", -1))
		if item_id.is_empty() or item_count <= 0:
			continue

		var item_data: Dictionary = DataManager.get_item(item_id)
		var sell_price: int = int(item_data.get("sell_price", 0))
		if sell_price <= 0:
			continue

		var item_name: String = String(item_data.get("name", item_id))
		var rarity: String = String(item_data.get("rarity", "N"))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0
		if bool(entry.get("is_equipment", false)):
			var enhance: int = int(entry.get("enhance", 0))
			row.text = "[%s] %s%s    %dG" % [rarity, item_name, _format_enhance(enhance), sell_price]
		else:
			row.text = "[%s] %s  x%d    %dG" % [rarity, item_name, item_count, sell_price]
		row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))

		var bound_item_id: String = item_id
		row.pressed.connect(_on_item_selected.bind(bound_item_id, equipment_index))
		_item_list_container.add_child(row)
		shown += 1

	if shown == 0:
		_add_empty_label("（沒有可販賣的道具）")


func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_item_list_container.add_child(label)


func _show_detail(item_id: String, equipment_index: int = -1) -> void:
	_selected_item_id = item_id
	_selected_equipment_index = equipment_index
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		_clear_detail()
		return

	var item_name: String = String(item_data.get("name", item_id))
	var rarity: String = String(item_data.get("rarity", "N"))
	var description: String = String(item_data.get("description", ""))
	var enhance: int = 0
	if equipment_index >= 0 and PlayerManager.inventory != null:
		var equipment_entry: Dictionary = PlayerManager.inventory.get_equipment_at(equipment_index)
		enhance = int(equipment_entry.get("enhance", 0))

	_detail_name.text = "%s%s" % [item_name, _format_enhance(enhance)]
	_detail_name.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))

	_detail_desc.clear()
	_detail_desc.append_text(description)

	_detail_stats.clear()
	var stats: Dictionary = Dictionary(item_data.get("stats", {}))
	if not stats.is_empty():
		var parts: Array = []
		for raw_key in stats.keys():
			parts.append("%s +%d" % [String(raw_key).to_upper(), int(stats.get(raw_key, 0))])
		_detail_stats.push_color(ThemeConstantsClass.HP_COLOR)
		_detail_stats.append_text("\n".join(parts))
		_detail_stats.pop()

	for child in _action_container.get_children():
		child.queue_free()

	match _current_tab:
		Tab.BUY:
			var buy_price: int = _get_stock_price(item_id)
			_price_label.text = "價格: %d G" % buy_price

			var buy_button := Button.new()
			buy_button.text = "購買"
			buy_button.custom_minimum_size = Vector2(100, 40)
			buy_button.disabled = not _can_buy_item(item_id, buy_price)
			var buy_item_id: String = item_id
			buy_button.pressed.connect(_on_buy_pressed.bind(buy_item_id))
			_action_container.add_child(buy_button)
		Tab.SELL:
			var sell_price: int = int(item_data.get("sell_price", 0))
			_price_label.text = "賣出: %d G" % sell_price

			var sell_button := Button.new()
			sell_button.text = "販賣"
			sell_button.custom_minimum_size = Vector2(100, 40)
			sell_button.disabled = sell_price <= 0
			var sell_item_id: String = item_id
			sell_button.pressed.connect(_on_sell_pressed.bind(sell_item_id, equipment_index))
			_action_container.add_child(sell_button)


func _clear_detail() -> void:
	_selected_item_id = ""
	_selected_equipment_index = -1
	_detail_name.text = "選擇商品"
	_detail_name.remove_theme_color_override("font_color")
	_detail_desc.clear()
	if _current_tab == Tab.BUY:
		_detail_desc.append_text("點擊左側商品查看詳情")
	else:
		_detail_desc.append_text("點擊左側道具查看賣出價")
	_detail_stats.clear()
	_price_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _on_buy_pressed(item_id: String) -> void:
	var price: int = _get_stock_price(item_id)
	if not _can_buy_item(item_id, price):
		return
	if not PlayerManager.spend_gold(price):
		return
	if not PlayerManager.add_item(item_id):
		PlayerManager.add_gold(price)
		return
	transaction_completed.emit(item_id, "buy")
	_refresh_list()
	_show_detail(item_id)


func _on_sell_pressed(item_id: String, equipment_index: int = -1) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var sell_price: int = int(item_data.get("sell_price", 0))
	if sell_price <= 0:
		return
	if equipment_index >= 0 and PlayerManager.inventory != null:
		if PlayerManager.inventory.get_equipment_at(equipment_index).is_empty():
			return
		PlayerManager.inventory.remove_equipment_at(equipment_index)
		PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()
	elif not PlayerManager.remove_item(item_id):
		return
	PlayerManager.add_gold(sell_price)
	transaction_completed.emit(item_id, "sell")
	_refresh_list()


func _on_tab_pressed(tab: int) -> void:
	_current_tab = tab
	_refresh_list()


func _on_item_selected(item_id: String, equipment_index: int = -1) -> void:
	_show_detail(item_id, equipment_index)


func _update_gold_display() -> void:
	var gold: int = PlayerManager.player_data.gold if PlayerManager.player_data != null else 0
	_gold_label.text = "Gold: %d" % gold


func _update_tab_style() -> void:
	_buy_tab_button.disabled = _current_tab == Tab.BUY
	_sell_tab_button.disabled = _current_tab == Tab.SELL


func _get_stock_price(item_id: String) -> int:
	for raw_stock_entry in _shop_stock:
		var stock_entry: Dictionary = raw_stock_entry
		if String(stock_entry.get("id", "")) == item_id:
			return int(stock_entry.get("price", 0))
	return 0


func _can_buy_item(item_id: String, price: int) -> bool:
	if PlayerManager.player_data == null or price <= 0:
		return false
	if PlayerManager.player_data.gold < price:
		return false

	var item_data: Dictionary = DataManager.get_item(item_id)
	if String(item_data.get("type", "")) == "consumable":
		var max_stack: int = int(item_data.get("max_stack", 99))
		if PlayerManager.get_item_count(item_id) >= max_stack:
			return false

	return true


func _format_enhance(level: int) -> String:
	if level <= 0:
		return ""
	return " +%d" % level
