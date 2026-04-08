class_name InventoryPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal panel_closed
signal item_action_performed(item_id: String, action: String)

enum Mode { SAFE_ZONE, EXPLORATION }

var _mode: int = Mode.SAFE_ZONE
var _selected_item_id: String = ""
var _selected_equipment_index: int = -1
var _current_filter: String = "all"

var _title_label: Label
var _close_button: Button
var _category_container: HBoxContainer
var _item_list_container: VBoxContainer
var _scroll_container: ScrollContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_desc: RichTextLabel
var _detail_stats: RichTextLabel
var _action_container: HBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(680, 480)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(mode: int) -> void:
	_mode = mode
	_selected_item_id = ""
	_selected_equipment_index = -1
	_current_filter = "all"
	
	theme_type_variation = "CombatantPanel"

	for child in get_children():
		child.queue_free()

	_build_ui()
	_refresh_item_list()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 16.0
	root.offset_top = 16.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	add_child(root)

	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.2
	left_panel.add_theme_constant_override("separation", 8)
	root.add_child(left_panel)

	var header := HBoxContainer.new()
	left_panel.add_child(header)

	_title_label = Label.new()
	_title_label.text = "背包"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(36, 36)
	_close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(_close_button)

	_category_container = HBoxContainer.new()
	_category_container.add_theme_constant_override("separation", 4)
	left_panel.add_child(_category_container)

	var categories: Array = [
		{"key": "all", "label": "全部"},
		{"key": "consumable", "label": "消耗品"},
		{"key": "equipment", "label": "裝備"},
		{"key": "material", "label": "素材"},
	]
	for raw_category in categories:
		var category: Dictionary = raw_category
		var button := Button.new()
		button.text = String(category.get("label", ""))
		button.custom_minimum_size.y = 32.0
		var category_key: String = String(category.get("key", "all"))
		button.pressed.connect(_on_category_pressed.bind(category_key))
		_category_container.add_child(button)

	left_panel.add_child(HSeparator.new())

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(_scroll_container)

	_item_list_container = VBoxContainer.new()
	_item_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list_container.add_theme_constant_override("separation", 2)
	_scroll_container.add_child(_item_list_container)

	_detail_panel = PanelContainer.new()
	_detail_panel.theme_type_variation = "EnemyPanel"
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 0.8
	_detail_panel.custom_minimum_size.x = 220.0
	root.add_child(_detail_panel)

	var detail_root := VBoxContainer.new()
	detail_root.add_theme_constant_override("separation", 8)
	detail_root.anchor_right = 1.0
	detail_root.anchor_bottom = 1.0
	detail_root.offset_left = 12.0
	detail_root.offset_top = 12.0
	detail_root.offset_right = -12.0
	detail_root.offset_bottom = -12.0
	_detail_panel.add_child(detail_root)

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

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_root.add_child(spacer)

	_action_container = HBoxContainer.new()
	_action_container.add_theme_constant_override("separation", 8)
	detail_root.add_child(_action_container)

	_clear_detail()


func _refresh_item_list() -> void:
	for child in _item_list_container.get_children():
		child.queue_free()

	if PlayerManager.inventory == null:
		_clear_detail()
		return

	var all_items: Array = PlayerManager.inventory.get_all_items()
	var shown_count: int = 0

	for raw_entry in all_items:
		var entry: Dictionary = raw_entry
		var item_id: String = String(entry.get("id", ""))
		var item_count: int = int(entry.get("count", 0))
		var equipment_index: int = int(entry.get("equipment_index", -1))
		if item_id.is_empty() or item_count <= 0:
			continue

		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_type: String = String(item_data.get("type", ""))
		var category: String = _type_to_filter(item_type)
		if _current_filter != "all" and category != _current_filter:
			continue

		var item_name: String = String(item_data.get("name", item_id))
		var rarity: String = String(item_data.get("rarity", "N"))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0

		if category == "equipment":
			var enhance: int = int(entry.get("enhance", 0))
			row.text = "[%s] %s%s" % [rarity, item_name, _format_enhance(enhance)]
		else:
			row.text = "[%s] %s  x%d" % [rarity, item_name, item_count]

		row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))
		if _is_equipped(item_id):
			row.text += "  [E]"

		var bound_item_id: String = item_id
		row.pressed.connect(_on_item_selected.bind(bound_item_id, equipment_index))
		_item_list_container.add_child(row)
		shown_count += 1

	if shown_count == 0:
		var empty_label := Label.new()
		empty_label.text = "（空）"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_item_list_container.add_child(empty_label)

	if _selected_equipment_index >= 0:
		if not PlayerManager.inventory.get_equipment_at(_selected_equipment_index).is_empty():
			_show_detail(_selected_item_id, _selected_equipment_index)
		else:
			_clear_detail()
	elif not _selected_item_id.is_empty() and PlayerManager.has_item(_selected_item_id):
		_show_detail(_selected_item_id)
	else:
		_clear_detail()


func _show_detail(item_id: String, equipment_index: int = -1) -> void:
	_selected_item_id = item_id
	_selected_equipment_index = equipment_index
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		_clear_detail()
		return

	var item_name: String = String(item_data.get("name", item_id))
	var item_type: String = String(item_data.get("type", ""))
	var rarity: String = String(item_data.get("rarity", "N"))
	var description: String = String(item_data.get("description", ""))
	var enhance: int = 0
	if equipment_index >= 0:
		var equipment_entry: Dictionary = PlayerManager.inventory.get_equipment_at(equipment_index)
		enhance = int(equipment_entry.get("enhance", 0))

	_detail_name.text = "%s%s" % [item_name, _format_enhance(enhance)]
	_detail_name.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))

	_detail_desc.clear()
	_detail_desc.append_text(description)

	_detail_stats.clear()
	var stats: Dictionary = Dictionary(item_data.get("stats", {}))
	if not stats.is_empty():
		var stat_parts: Array = []
		for raw_stat_key in stats.keys():
			var stat_key: String = String(raw_stat_key)
			stat_parts.append("%s +%d" % [stat_key.to_upper(), int(stats.get(raw_stat_key, 0))])
		_detail_stats.push_color(ThemeConstantsClass.HP_COLOR)
		_detail_stats.append_text("\n".join(stat_parts))
		_detail_stats.pop()

	if _is_equipped(item_id):
		_detail_stats.push_color(ThemeConstantsClass.EXP_COLOR)
		_detail_stats.append_text("\n[已裝備]")
		_detail_stats.pop()

	var sell_price: int = int(item_data.get("sell_price", 0))
	if sell_price > 0:
		_detail_stats.push_color(ThemeConstantsClass.TEXT_SECONDARY)
		_detail_stats.append_text("\n賣出: %d G" % sell_price)
		_detail_stats.pop()

	_build_action_buttons(item_id, item_type, item_data, equipment_index)


func _clear_detail() -> void:
	_selected_item_id = ""
	_selected_equipment_index = -1
	_detail_name.text = "選擇道具"
	_detail_name.remove_theme_color_override("font_color")
	_detail_desc.clear()
	_detail_desc.append_text("點擊左側道具查看詳情")
	_detail_stats.clear()
	for child in _action_container.get_children():
		child.queue_free()


func _build_action_buttons(item_id: String, item_type: String, item_data: Dictionary, equipment_index: int) -> void:
	for child in _action_container.get_children():
		child.queue_free()

	if item_type == "consumable":
		var can_use: bool = true
		if _mode == Mode.EXPLORATION:
			can_use = bool(item_data.get("usable_in_explore", false))

		var use_button := Button.new()
		use_button.text = "使用"
		use_button.custom_minimum_size = Vector2(80, 36)
		use_button.disabled = not can_use
		var use_item_id: String = item_id
		use_button.pressed.connect(_on_use_pressed.bind(use_item_id))
		_action_container.add_child(use_button)

	if item_type in ["weapon", "armor", "accessory"]:
		if _mode == Mode.SAFE_ZONE:
			if _is_equipped(item_id):
				var unequip_button := Button.new()
				unequip_button.text = "卸下"
				unequip_button.custom_minimum_size = Vector2(80, 36)
				var unequip_item_id: String = item_id
				unequip_button.pressed.connect(_on_unequip_pressed.bind(unequip_item_id, item_type))
				_action_container.add_child(unequip_button)
			else:
				var equip_button := Button.new()
				equip_button.text = "裝備"
				equip_button.custom_minimum_size = Vector2(80, 36)
				var equip_item_id: String = item_id
				equip_button.pressed.connect(_on_equip_pressed.bind(equip_item_id, item_type, equipment_index))
				_action_container.add_child(equip_button)
		else:
			var locked_label := Label.new()
			locked_label.text = "探索中無法換裝"
			locked_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
			locked_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_SMALL)
			_action_container.add_child(locked_label)


func _on_use_pressed(item_id: String) -> void:
	var result: Dictionary = PlayerManager.use_item(item_id)
	if bool(result.get("success", false)):
		var effect_parts: Array = Array(result.get("effects", []))
		var effects_text: String = ", ".join(effect_parts)
		item_action_performed.emit(item_id, "使用：%s" % effects_text)
	_refresh_item_list()


func _on_equip_pressed(item_id: String, item_type: String, equipment_index: int) -> void:
	var equip_enhance: int = 0
	if equipment_index >= 0 and PlayerManager.inventory != null:
		var equip_entry: Dictionary = PlayerManager.inventory.get_equipment_at(equipment_index)
		equip_enhance = int(equip_entry.get("enhance", 0))

	var old_id: String = ""
	match item_type:
		"weapon":
			old_id = PlayerManager.equip_weapon(item_id, equip_enhance)
		"armor":
			old_id = PlayerManager.equip_armor(item_id, equip_enhance)
		"accessory":
			old_id = PlayerManager.equip_accessory(item_id, 0, equip_enhance)

	var old_enhance: int = PlayerManager.get_last_unequip_enhance()

	if equipment_index >= 0 and PlayerManager.inventory != null:
		PlayerManager.inventory.remove_equipment_at(equipment_index)
		PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()
	else:
		PlayerManager.remove_item(item_id)
	if not old_id.is_empty():
		PlayerManager.inventory.add_equipment(old_id, old_enhance)
		PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	item_action_performed.emit(item_id, "裝備")
	_refresh_item_list()


func _on_unequip_pressed(item_id: String, item_type: String) -> void:
	var removed_item_id: String = item_id
	match item_type:
		"weapon":
			removed_item_id = PlayerManager.unequip_weapon()
		"armor":
			removed_item_id = PlayerManager.unequip_armor()
		"accessory":
			for slot_index in range(PlayerManager.player_data.accessory_ids.size()):
				if PlayerManager.player_data.accessory_ids[slot_index] == item_id:
					removed_item_id = PlayerManager.unequip_accessory(slot_index)
					break

	if not removed_item_id.is_empty():
		var old_enhance: int = PlayerManager.get_last_unequip_enhance()
		PlayerManager.inventory.add_equipment(removed_item_id, old_enhance)
		PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	item_action_performed.emit(item_id, "卸下")
	_refresh_item_list()


func _on_category_pressed(category: String) -> void:
	_current_filter = category
	_refresh_item_list()


func _on_item_selected(item_id: String, equipment_index: int = -1) -> void:
	_show_detail(item_id, equipment_index)


static func _type_to_filter(item_type: String) -> String:
	match item_type:
		"consumable":
			return "consumable"
		"weapon", "armor", "accessory":
			return "equipment"
		"material", "familiar_core", "key_item", "magic_book":
			return "material"
		_:
			return "consumable"


func _is_equipped(item_id: String) -> bool:
	if PlayerManager.player_data == null:
		return false
	if PlayerManager.player_data.weapon_id == item_id:
		return true
	if PlayerManager.player_data.armor_id == item_id:
		return true
	if PlayerManager.player_data.accessory_ids.has(item_id):
		return true
	return false


func _format_enhance(level: int) -> String:
	if level <= 0:
		return ""
	return " +%d" % level
