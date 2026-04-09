class_name ForgePanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const ForgeLogicClass = preload("res://scripts/safe_zone/forge_logic.gd")

signal panel_closed
signal forge_action_performed(action: String, detail: String)

enum Tab { ENHANCE, DISMANTLE, CRAFT, SYNTHESIS }

var _current_tab: int = Tab.ENHANCE
var _floor_number: int = 1
var _selected_slot_key: String = ""
var _selected_equipment_index: int = -1
var _selected_recipe: Dictionary = {}

var _title_label: Label
var _gold_label: Label
var _close_button: Button
var _enhance_tab_button: Button
var _dismantle_tab_button: Button
var _craft_tab_button: Button
var _synthesis_tab_button: Button
var _item_list_container: VBoxContainer
var _scroll_container: ScrollContainer
var _detail_name: Label
var _detail_desc: RichTextLabel
var _detail_stats: RichTextLabel
var _price_label: Label
var _action_container: HBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(860, 580)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(floor_number: int = 1) -> void:
	_floor_number = floor_number
	_current_tab = Tab.ENHANCE
	_selected_slot_key = ""
	_selected_equipment_index = -1
	_selected_recipe = {}
	theme_type_variation = "CombatantPanel"
	for child in get_children():
		child.queue_free()
	_build_ui()
	_refresh_list()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 10.0
	root.offset_top = 10.0
	root.offset_right = -10.0
	root.offset_bottom = -10.0
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.text = "鍛造工坊"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	_gold_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	header.add_child(_gold_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(36, 36)
	_close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(_close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)

	_enhance_tab_button = Button.new()
	_enhance_tab_button.text = "強化"
	_enhance_tab_button.custom_minimum_size = Vector2(100, 36)
	_enhance_tab_button.pressed.connect(_on_tab_pressed.bind(Tab.ENHANCE))
	tabs.add_child(_enhance_tab_button)

	_dismantle_tab_button = Button.new()
	_dismantle_tab_button.text = "分解"
	_dismantle_tab_button.custom_minimum_size = Vector2(100, 36)
	_dismantle_tab_button.pressed.connect(_on_tab_pressed.bind(Tab.DISMANTLE))
	tabs.add_child(_dismantle_tab_button)

	_craft_tab_button = Button.new()
	_craft_tab_button.text = "製造"
	_craft_tab_button.custom_minimum_size = Vector2(100, 36)
	_craft_tab_button.pressed.connect(_on_tab_pressed.bind(Tab.CRAFT))
	tabs.add_child(_craft_tab_button)

	_synthesis_tab_button = Button.new()
	_synthesis_tab_button.text = "合成"
	_synthesis_tab_button.custom_minimum_size = Vector2(100, 36)
	_synthesis_tab_button.pressed.connect(_on_tab_pressed.bind(Tab.SYNTHESIS))
	tabs.add_child(_synthesis_tab_button)

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
	detail_panel.theme_type_variation = "EnemyPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.8
	detail_panel.custom_minimum_size.x = 260.0
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
	_detail_desc.custom_minimum_size.y = 60.0
	detail_root.add_child(_detail_desc)

	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.custom_minimum_size.y = 160.0
	detail_root.add_child(_detail_stats)

	_price_label = Label.new()
	_price_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	_price_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
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
	_selected_slot_key = ""
	_selected_equipment_index = -1
	_selected_recipe = {}
	_update_gold_display()
	_update_tab_style()
	_clear_detail()

	match _current_tab:
		Tab.ENHANCE:
			_populate_enhance_list()
		Tab.DISMANTLE:
			_populate_dismantle_list()
		Tab.CRAFT:
			_populate_recipe_list("craft")
		Tab.SYNTHESIS:
			_populate_recipe_list("synthesis")


func _populate_enhance_list() -> void:
	var entries: Array[Dictionary] = _get_equipped_entries()
	if entries.is_empty():
		_add_empty_label("（目前沒有已裝備的裝備）")
		return
	for entry in entries:
		var item_id: String = String(entry.get("id", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0
		row.text = "%s - [%s] %s%s" % [
			String(entry.get("slot_name", "裝備")),
			String(item_data.get("rarity", "N")),
			String(item_data.get("name", item_id)),
			_format_enhance(int(entry.get("enhance", 0))),
		]
		row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N"))))
		row.pressed.connect(_on_enhance_item_selected.bind(String(entry.get("slot_key", ""))))
		_item_list_container.add_child(row)


func _populate_dismantle_list() -> void:
	if PlayerManager.inventory == null:
		_add_empty_label("（背包中沒有可分解裝備）")
		return
	var equipment_list: Array[Dictionary] = PlayerManager.inventory.get_equipment_list()
	if equipment_list.is_empty():
		_add_empty_label("（背包中沒有可分解裝備）")
		return
	for entry in equipment_list:
		var item_id: String = String(entry.get("id", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0
		row.text = "[%s] %s%s" % [
			String(item_data.get("rarity", "N")),
			String(item_data.get("name", item_id)),
			_format_enhance(int(entry.get("enhance", 0))),
		]
		row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N"))))
		row.pressed.connect(_on_dismantle_item_selected.bind(int(entry.get("index", -1))))
		_item_list_container.add_child(row)


func _populate_recipe_list(recipe_type: String) -> void:
	var recipes: Array[Dictionary] = DataManager.get_recipes_by_type(recipe_type, _floor_number)
	if recipes.is_empty():
		var empty_type: String = "製造"
		if recipe_type != "craft":
			empty_type = "合成"
		_add_empty_label("（目前沒有可用的%s配方）" % empty_type)
		return
	for recipe in recipes:
		var result_id: String = String(recipe.get("result_id", ""))
		var item_data: Dictionary = DataManager.get_item(result_id)
		var can_result: Dictionary = {}
		if recipe_type == "craft":
			can_result = ForgeLogicClass.can_craft(recipe)
		else:
			can_result = ForgeLogicClass.can_synthesize(recipe)
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0
		row.text = "[%s] %s    %dG" % [
			String(item_data.get("rarity", "N")),
			String(recipe.get("result_name", result_id)),
			int(recipe.get("gold_cost", 0)),
		]
		if bool(can_result.get("can", false)):
			row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N"))))
		else:
			row.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		if recipe_type == "craft":
			row.pressed.connect(_on_craft_item_selected.bind(recipe.duplicate(true)))
		else:
			row.pressed.connect(_on_synthesis_item_selected.bind(recipe.duplicate(true)))
		_item_list_container.add_child(row)


func _show_enhance_detail(slot_key: String) -> void:
	var entry: Dictionary = _get_equipped_entry(slot_key)
	if entry.is_empty():
		_clear_detail()
		return
	var item_id: String = String(entry.get("id", ""))
	var current_level: int = int(entry.get("enhance", 0))
	var item_data: Dictionary = DataManager.get_item(item_id)
	var cost: Dictionary = ForgeLogicClass.get_enhance_cost(item_id, current_level)
	var check: Dictionary = ForgeLogicClass.can_enhance(item_id, current_level)
	_selected_slot_key = slot_key
	_selected_recipe = {}
	_apply_item_detail(item_id, _format_enhance(current_level), String(item_data.get("description", "")))
	var stat_lines: Array = _build_enhance_preview_lines(item_id, current_level)
	if not stat_lines.is_empty():
		_detail_stats.push_color(ThemeConstantsClass.HP_COLOR)
		_detail_stats.append_text("\n".join(stat_lines))
		_detail_stats.pop()
		_detail_stats.append_text("\n")
	if cost.is_empty():
		_detail_stats.push_color(ThemeConstantsClass.TEXT_SECONDARY)
		_detail_stats.append_text("已達最大強化等級")
		_detail_stats.pop()
		return
	_detail_stats.append_text("強化: +%d -> +%d\n成功率: %.0f%%\n" % [current_level, int(cost.get("target_level", current_level)), float(cost.get("success_rate", 0.0)) * 100.0])
	_detail_stats.append_text(_format_material_requirement(String(cost.get("material_id", "")), int(cost.get("material_count", 0))))
	for raw_extra in Array(cost.get("extra_materials", [])):
		if raw_extra is Dictionary:
			_detail_stats.append_text("\n" + _format_material_requirement(String(raw_extra.get("id", "")), int(raw_extra.get("count", 0))))
	_set_price_and_action("需求金幣: %d G（持有 %d G）" % [int(cost.get("gold_cost", 0)), _get_current_gold()], "強化", bool(check.get("can", false)), _on_enhance_pressed.bind(slot_key), String(check.get("reason", "")))


func _show_dismantle_detail(equipment_index: int) -> void:
	if PlayerManager.inventory == null:
		_clear_detail()
		return
	var entry: Dictionary = PlayerManager.inventory.get_equipment_at(equipment_index)
	if entry.is_empty():
		_clear_detail()
		return
	var item_id: String = String(entry.get("id", ""))
	var enhance: int = int(entry.get("enhance", 0))
	var result: Dictionary = ForgeLogicClass.get_dismantle_result(item_id, enhance)
	_selected_equipment_index = equipment_index
	_selected_recipe = {}
	_apply_item_detail(item_id, _format_enhance(enhance), String(DataManager.get_item(item_id).get("description", "")))
	_detail_stats.append_text("分解後可獲得：")
	for raw_material in Array(result.get("materials", [])):
		if raw_material is Dictionary:
			var material_data: Dictionary = DataManager.get_item(String(raw_material.get("id", "")))
			_detail_stats.append_text("\n%s x%d" % [String(material_data.get("name", raw_material.get("id", ""))), int(raw_material.get("count", 0))])
	_set_price_and_action("回收金幣: %d G" % int(result.get("gold", 0)), "分解", true, _on_dismantle_pressed.bind(equipment_index))


func _show_craft_detail(recipe: Dictionary) -> void:
	_show_recipe_detail(recipe, false)


func _show_synthesis_detail(recipe: Dictionary) -> void:
	_show_recipe_detail(recipe, true)


func _show_recipe_detail(recipe: Dictionary, is_synthesis: bool) -> void:
	_selected_slot_key = ""
	_selected_equipment_index = -1
	_selected_recipe = recipe.duplicate(true)
	var result_id: String = String(recipe.get("result_id", ""))
	_apply_item_detail(result_id, "", String(recipe.get("description", "")))
	var item_data: Dictionary = DataManager.get_item(result_id)
	var stats: Dictionary = Dictionary(item_data.get("stats", {}))
	if not stats.is_empty():
		var parts: Array = []
		for raw_key in stats.keys():
			parts.append("%s +%d" % [String(raw_key).to_upper(), int(stats.get(raw_key, 0))])
		_detail_stats.push_color(ThemeConstantsClass.HP_COLOR)
		_detail_stats.append_text("\n".join(parts))
		_detail_stats.pop()
		_detail_stats.append_text("\n")
	_detail_stats.append_text("\n必要素材：")
	for raw_mat in Array(recipe.get("materials", [])):
		if raw_mat is Dictionary:
			_detail_stats.append_text("\n" + _format_material_requirement(String(raw_mat.get("id", "")), int(raw_mat.get("count", 0))))
	var can_result: Dictionary = {}
	var action_text: String = "製造"
	var action_callable: Callable = _on_craft_pressed.bind(recipe.duplicate(true))
	if is_synthesis:
		can_result = ForgeLogicClass.can_synthesize(recipe)
		action_text = "合成"
		action_callable = _on_synthesis_pressed.bind(recipe.duplicate(true))
	else:
		can_result = ForgeLogicClass.can_craft(recipe)
	_set_price_and_action(
		"需求金幣: %d G（持有 %d G）" % [int(recipe.get("gold_cost", 0)), _get_current_gold()],
		action_text,
		bool(can_result.get("can", false)),
		action_callable,
		String(can_result.get("reason", ""))
	)


func _apply_item_detail(item_id: String, suffix: String, description: String) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	_detail_name.text = "%s%s" % [String(item_data.get("name", item_id)), suffix]
	_detail_name.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N"))))
	_detail_desc.clear()
	_detail_desc.append_text(description)
	_detail_stats.clear()
	_price_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _set_price_and_action(price_text: String, button_text: String, enabled: bool, callback: Callable, reason: String = "") -> void:
	_price_label.text = price_text
	var action_button := Button.new()
	action_button.text = button_text
	action_button.custom_minimum_size = Vector2(100, 40)
	action_button.disabled = not enabled
	action_button.pressed.connect(callback)
	_action_container.add_child(action_button)
	if not enabled and not reason.is_empty():
		var hint := Label.new()
		hint.text = _format_check_reason(reason)
		hint.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_action_container.add_child(hint)


func _clear_detail() -> void:
	_selected_slot_key = ""
	_selected_equipment_index = -1
	_selected_recipe = {}
	_detail_name.text = "選擇項目"
	_detail_name.remove_theme_color_override("font_color")
	_detail_desc.clear()
	match _current_tab:
		Tab.ENHANCE:
			_detail_desc.append_text("點擊左側已裝備裝備查看強化需求")
		Tab.DISMANTLE:
			_detail_desc.append_text("點擊左側背包裝備查看分解回收")
		Tab.CRAFT:
			_detail_desc.append_text("點擊左側配方查看製造需求")
		Tab.SYNTHESIS:
			_detail_desc.append_text("點擊左側配方查看合成需求")
	_detail_stats.clear()
	_price_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _on_enhance_pressed(slot_key: String) -> void:
	var entry: Dictionary = _get_equipped_entry(slot_key)
	if entry.is_empty():
		return
	var item_id: String = String(entry.get("id", ""))
	var current_level: int = int(entry.get("enhance", 0))
	var result: Dictionary = ForgeLogicClass.execute_enhance(item_id, current_level)
	if not bool(result.get("success", false)):
		forge_action_performed.emit("enhance_failed", "無法強化：%s" % _format_check_reason(String(result.get("reason", ""))))
	else:
		var item_name: String = String(DataManager.get_item(item_id).get("name", item_id))
		if bool(result.get("enhanced", false)):
			_set_slot_enhance(slot_key, int(result.get("target_level", current_level)))
			forge_action_performed.emit("enhance", "%s 強化成功，提升至 +%d" % [item_name, int(result.get("target_level", current_level))])
		else:
			forge_action_performed.emit("enhance_fail", "%s 強化失敗，維持 +%d" % [item_name, current_level])
	_refresh_list()
	_show_enhance_detail(slot_key)


func _on_dismantle_pressed(equipment_index: int) -> void:
	var result: Dictionary = ForgeLogicClass.execute_dismantle(equipment_index)
	if not bool(result.get("success", false)):
		return
	var detail: String = "%s%s 已分解，獲得 %d G" % [String(result.get("item_name", "")), _format_enhance(int(result.get("enhance", 0))), int(result.get("gold", 0))]
	for raw_material in Array(result.get("materials", [])):
		if raw_material is Dictionary:
			var material_data: Dictionary = DataManager.get_item(String(raw_material.get("id", "")))
			detail += " / %s x%d" % [String(material_data.get("name", raw_material.get("id", ""))), int(raw_material.get("count", 0))]
	forge_action_performed.emit("dismantle", detail)
	_refresh_list()


func _on_craft_pressed(recipe: Dictionary) -> void:
	var result: Dictionary = ForgeLogicClass.execute_craft(recipe)
	var action: String = "craft_failed"
	var detail: String = "無法製造：%s" % _format_check_reason(String(result.get("reason", "")))
	if bool(result.get("success", false)):
		action = "craft"
		detail = "製造成功：%s" % String(result.get("result_name", ""))
	forge_action_performed.emit(action, detail)
	_refresh_list()
	if not recipe.is_empty():
		_show_craft_detail(recipe)


func _on_synthesis_pressed(recipe: Dictionary) -> void:
	var result: Dictionary = ForgeLogicClass.execute_synthesize(recipe)
	var action: String = "synthesis_failed"
	var detail: String = "無法合成：%s" % _format_check_reason(String(result.get("reason", "")))
	if bool(result.get("success", false)):
		action = "synthesis"
		detail = "合成成功：%s" % String(result.get("result_name", ""))
	forge_action_performed.emit(action, detail)
	_refresh_list()
	if not recipe.is_empty():
		_show_synthesis_detail(recipe)


func _on_tab_pressed(tab: int) -> void:
	_current_tab = tab
	_refresh_list()


func _on_enhance_item_selected(slot_key: String) -> void:
	_show_enhance_detail(slot_key)


func _on_dismantle_item_selected(equipment_index: int) -> void:
	_show_dismantle_detail(equipment_index)


func _on_craft_item_selected(recipe: Dictionary) -> void:
	_show_craft_detail(recipe)


func _on_synthesis_item_selected(recipe: Dictionary) -> void:
	_show_synthesis_detail(recipe)


func _get_equipped_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if PlayerManager.player_data == null:
		return result
	if not PlayerManager.player_data.weapon_id.is_empty():
		result.append({"slot_key": "weapon", "slot_name": "武器", "id": PlayerManager.player_data.weapon_id, "enhance": PlayerManager.player_data.weapon_enhance})
	if not PlayerManager.player_data.armor_id.is_empty():
		result.append({"slot_key": "armor", "slot_name": "防具", "id": PlayerManager.player_data.armor_id, "enhance": PlayerManager.player_data.armor_enhance})
	for index in range(PlayerManager.player_data.accessory_ids.size()):
		var accessory_id: String = PlayerManager.player_data.accessory_ids[index]
		if accessory_id.is_empty():
			continue
		var enhance: int = 0
		if index < PlayerManager.player_data.accessory_enhances.size():
			enhance = int(PlayerManager.player_data.accessory_enhances[index])
		result.append({"slot_key": "accessory_%d" % index, "slot_name": "飾品%d" % (index + 1), "id": accessory_id, "enhance": enhance})
	return result


func _get_equipped_entry(slot_key: String) -> Dictionary:
	for entry in _get_equipped_entries():
		if String(entry.get("slot_key", "")) == slot_key:
			return entry
	return {}


func _set_slot_enhance(slot_key: String, level: int) -> void:
	if PlayerManager.player_data == null:
		return
	match slot_key:
		"weapon":
			PlayerManager.player_data.weapon_enhance = level
		"armor":
			PlayerManager.player_data.armor_enhance = level
		_:
			if slot_key.begins_with("accessory_"):
				var slot_index: int = int(slot_key.trim_prefix("accessory_"))
				while PlayerManager.player_data.accessory_enhances.size() <= slot_index:
					PlayerManager.player_data.accessory_enhances.append(0)
				PlayerManager.player_data.accessory_enhances[slot_index] = level
	PlayerManager._refresh_player_state()
	PlayerManager.equipment_changed.emit()


func _build_enhance_preview_lines(item_id: String, current_level: int) -> Array:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var base_stats: Dictionary = Dictionary(item_data.get("stats", {}))
	var stat_keys: Array = []
	for raw_key in base_stats.keys():
		var stat_key: String = String(raw_key)
		if not stat_keys.has(stat_key):
			stat_keys.append(stat_key)
	for raw_key in _get_enhance_bonus_map(item_id).keys():
		var stat_key: String = String(raw_key)
		if not stat_keys.has(stat_key):
			stat_keys.append(stat_key)
	var lines: Array = []
	for stat_key in stat_keys:
		var base_value: int = int(base_stats.get(stat_key, 0))
		lines.append("%s %d -> %d" % [stat_key.to_upper(), base_value + _get_enhance_total(item_id, current_level, stat_key), base_value + _get_enhance_total(item_id, current_level + 1, stat_key)])
	return lines


func _get_enhance_total(item_id: String, level: int, stat_name: String) -> int:
	if level <= 0:
		return 0
	return int(_get_enhance_bonus_map(item_id).get(stat_name, 0)) * level


func _get_enhance_bonus_map(item_id: String) -> Dictionary:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var per_level: Dictionary = Dictionary(item_data.get("enhance_bonus_per_level", {}))
	if per_level.is_empty():
		match String(item_data.get("type", "")):
			"weapon":
				return {"matk": 1}
			"armor":
				return {"pdef": 1, "mdef": 1}
			"accessory":
				return {"hp": 3}
	return per_level


func _format_material_requirement(material_id: String, required: int) -> String:
	var material_data: Dictionary = DataManager.get_item(material_id)
	return "%s x%d（持有 %d）" % [String(material_data.get("name", material_id)), required, PlayerManager.get_item_count(material_id)]


func _format_check_reason(reason: String) -> String:
	match reason:
		"max_level":
			return "已達最大強化等級"
		"no_gold":
			return "金幣不足"
		"no_material":
			return "素材不足"
		"no_recipe":
			return "沒有可用配方"
		_:
			return "條件不足"


func _format_enhance(level: int) -> String:
	if level <= 0:
		return ""
	return " +%d" % level


func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_item_list_container.add_child(label)


func _update_gold_display() -> void:
	_gold_label.text = "Gold: %d" % _get_current_gold()


func _update_tab_style() -> void:
	_enhance_tab_button.disabled = _current_tab == Tab.ENHANCE
	_dismantle_tab_button.disabled = _current_tab == Tab.DISMANTLE
	_craft_tab_button.disabled = _current_tab == Tab.CRAFT
	_synthesis_tab_button.disabled = _current_tab == Tab.SYNTHESIS


func _get_current_gold() -> int:
	if PlayerManager.player_data == null:
		return 0
	return PlayerManager.player_data.gold
