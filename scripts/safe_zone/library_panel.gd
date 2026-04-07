class_name LibraryPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal panel_closed

enum Tab { FAMILIARS, ITEMS, SKILLS, ENEMIES }

const STAT_ORDER := ["hp", "mp", "matk", "mdef", "patk", "pdef", "speed"]

var _current_tab: int = Tab.FAMILIARS
var _selected_id: String = ""

var _meta_label: Label
var _familiar_tab_button: Button
var _item_tab_button: Button
var _skill_tab_button: Button
var _enemy_tab_button: Button
var _list_container: VBoxContainer
var _detail_name: Label
var _detail_desc: RichTextLabel
var _detail_stats: RichTextLabel
var _footer_label: Label
var _action_container: HBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(760, 520)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup() -> void:
	_current_tab = Tab.FAMILIARS
	_selected_id = ""

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
	title_label.text = "圖書館"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(title_label)

	_meta_label = Label.new()
	_meta_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	_meta_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	header.add_child(_meta_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)

	_familiar_tab_button = _create_tab_button("使魔", Tab.FAMILIARS)
	tabs.add_child(_familiar_tab_button)

	_item_tab_button = _create_tab_button("道具", Tab.ITEMS)
	tabs.add_child(_item_tab_button)

	_skill_tab_button = _create_tab_button("技能", Tab.SKILLS)
	tabs.add_child(_skill_tab_button)

	_enemy_tab_button = _create_tab_button("怪物", Tab.ENEMIES)
	tabs.add_child(_enemy_tab_button)

	root.add_child(HSeparator.new())

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.2
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 2)
	scroll.add_child(_list_container)

	var detail_panel := PanelContainer.new()
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
	_detail_desc.custom_minimum_size.y = 80.0
	detail_root.add_child(_detail_desc)

	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.custom_minimum_size.y = 180.0
	detail_root.add_child(_detail_stats)

	_footer_label = Label.new()
	_footer_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	_footer_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
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
		_selected_id = ""
		_meta_label.text = "收集: 0 / 0"
		_add_empty_label("（尚無資料）")
		_clear_detail()
		return

	var available_ids: Array[String] = []
	for entry in entries:
		available_ids.append(String(entry.get("id", "")))
	if not available_ids.has(_selected_id):
		_selected_id = available_ids[0]

	for entry in entries:
		var entry_id: String = String(entry.get("id", ""))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0
		row.text = _build_list_text(entry)
		row.add_theme_color_override("font_color", _get_row_color(entry))
		if entry_id == _selected_id:
			row.disabled = true
		row.pressed.connect(_on_entry_selected.bind(entry_id))
		_list_container.add_child(row)

	_update_meta_label(entries)
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_id.is_empty():
		_clear_detail()
		return

	match _current_tab:
		Tab.FAMILIARS:
			_show_familiar_detail(DataManager.get_familiar(_selected_id))
		Tab.ITEMS:
			_show_item_detail(DataManager.get_item(_selected_id))
		Tab.SKILLS:
			_show_skill_detail(DataManager.get_skill(_selected_id))
		Tab.ENEMIES:
			_show_enemy_detail(DataManager.get_enemy(_selected_id))


func _show_familiar_detail(familiar_data: Dictionary) -> void:
	if familiar_data.is_empty():
		_clear_detail()
		return
	if not _is_familiar_discovered(String(familiar_data.get("id", ""))):
		_show_hidden_detail("尚未解鎖這筆使魔資料。")
		return

	_prepare_detail(
		String(familiar_data.get("name", "???")),
		ThemeConstantsClass.get_element_color(String(familiar_data.get("element", "none")))
	)
	_append_lines(_detail_desc, [
		"屬性: %s" % _format_element_name(String(familiar_data.get("element", "none"))),
		"定位: %s" % _format_role_name(String(familiar_data.get("type", ""))),
		"來源: %s" % String(familiar_data.get("obtain_source", "未知")),
	])

	var lines: Array[String] = _build_base_growth_lines(familiar_data)
	lines.append("")
	lines.append("初始技能")
	lines.append_array(_build_skill_name_lines(Array(familiar_data.get("default_skills", []))))
	lines.append("")
	lines.append_array(_build_evolution_lines(familiar_data))
	_append_lines(_detail_stats, lines)
	_footer_label.text = "最高等級: Lv.%d" % int(familiar_data.get("max_level", 1))


func _show_item_detail(item_data: Dictionary) -> void:
	if item_data.is_empty():
		_clear_detail()
		return
	if not _is_item_discovered(String(item_data.get("id", ""))):
		_show_hidden_detail("尚未解鎖這筆道具資料。")
		return

	_prepare_detail(
		String(item_data.get("name", "???")),
		ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N")))
	)
	_append_lines(_detail_desc, [
		"類型: %s" % _format_item_type(String(item_data.get("type", ""))),
		"稀有度: %s" % String(item_data.get("rarity", "N")),
		"描述: %s" % String(item_data.get("description", "")),
	])

	var lines: Array[String] = []
	var stats: Dictionary = Dictionary(item_data.get("stats", {}))
	if not stats.is_empty():
		lines.append("能力加成")
		var stat_keys: Array = stats.keys()
		stat_keys.sort()
		for raw_key in stat_keys:
			lines.append("- %s +%d" % [String(raw_key).to_upper(), int(stats.get(raw_key, 0))])

	var effects: Array = Array(item_data.get("effects", []))
	if not effects.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append("效果")
		for raw_effect in effects:
			if raw_effect is not Dictionary:
				continue
			var effect: Dictionary = raw_effect
			lines.append(_format_item_effect_line(effect))

	if lines.is_empty():
		lines.append("（無額外效果）")
	_append_lines(_detail_stats, lines)
	_footer_label.text = "買價: %d G / 賣價: %d G" % [
		int(item_data.get("buy_price", 0)),
		int(item_data.get("sell_price", 0)),
	]


func _show_skill_detail(skill_data: Dictionary) -> void:
	if skill_data.is_empty():
		_clear_detail()
		return

	var skill_id: String = String(skill_data.get("id", ""))
	var learned: bool = _is_skill_learned(skill_id)
	_prepare_detail(
		String(skill_data.get("name", "???")),
		ThemeConstantsClass.get_element_color(String(skill_data.get("element", "none")))
	)
	_append_lines(_detail_desc, [
		"屬性: %s" % _format_element_name(String(skill_data.get("element", "none"))),
		"類型: %s" % _format_skill_type(String(skill_data.get("type", ""))),
		"描述: %s" % String(skill_data.get("description", "")),
	])

	var lines: Array[String] = [
		"MP 消耗: %d" % int(skill_data.get("mp_cost", 0)),
		"命中率: %d%%" % int(skill_data.get("hit_rate", 100)),
		"PP: %d" % int(skill_data.get("pp_max", 0)),
		"冷卻: %d" % int(skill_data.get("cooldown", 0)),
	]

	var effects: Array = Array(skill_data.get("effects", []))
	if not effects.is_empty():
		lines.append("")
		lines.append("效果")
		for raw_effect in effects:
			if raw_effect is not Dictionary:
				continue
			var effect: Dictionary = raw_effect
			lines.append(_format_skill_effect_line(effect, skill_data))
	_append_lines(_detail_stats, lines)
	_footer_label.text = "已學會" if learned else "未學會"


func _show_enemy_detail(enemy_data: Dictionary) -> void:
	if enemy_data.is_empty():
		_clear_detail()
		return
	if not _is_enemy_discovered(String(enemy_data.get("id", ""))):
		_show_hidden_detail("尚未遭遇這個怪物。")
		return

	_prepare_detail(
		String(enemy_data.get("name", "???")),
		ThemeConstantsClass.get_element_color(String(enemy_data.get("element", "none")))
	)
	_append_lines(_detail_desc, [
		"屬性: %s" % _format_element_name(String(enemy_data.get("element", "none"))),
		"等級: Lv.%d" % int(enemy_data.get("level", 1)),
	])

	var lines: Array[String] = ["能力值"]
	var stats: Dictionary = Dictionary(enemy_data.get("stats", {}))
	for stat_key in STAT_ORDER:
		lines.append("- %s: %d" % [stat_key.to_upper(), int(stats.get(stat_key, 0))])

	lines.append("")
	lines.append("技能")
	lines.append_array(_build_skill_name_lines(Array(enemy_data.get("skills", []))))

	var drops: Array = Array(enemy_data.get("drops", []))
	if not drops.is_empty():
		lines.append("")
		lines.append("掉落")
		for raw_drop in drops:
			if raw_drop is not Dictionary:
				continue
			var drop: Dictionary = raw_drop
			var item_id: String = String(drop.get("id", ""))
			var item_data: Dictionary = DataManager.get_item(item_id)
			lines.append(
				"- %s（%.0f%%）" % [
					String(item_data.get("name", item_id)),
					float(drop.get("rate", 0.0)) * 100.0,
				]
			)
	_append_lines(_detail_stats, lines)

	var floor_range: Array = Array(enemy_data.get("floor_range", []))
	if floor_range.size() >= 2:
		_footer_label.text = "出現樓層: %dF - %dF" % [int(floor_range[0]), int(floor_range[1])]
	else:
		_footer_label.text = ""


func _show_hidden_detail(message: String) -> void:
	_prepare_detail("???", ThemeConstantsClass.TEXT_SECONDARY)
	_detail_desc.append_text(message)
	_detail_stats.clear()
	_footer_label.text = ""


func _prepare_detail(title: String, color: Color) -> void:
	_detail_name.text = title
	_detail_name.add_theme_color_override("font_color", color)
	_detail_desc.clear()
	_detail_stats.clear()
	_footer_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _clear_detail() -> void:
	_detail_name.text = "選擇項目"
	_detail_name.remove_theme_color_override("font_color")
	_detail_desc.clear()
	_detail_desc.append_text("選擇左側項目以查看圖鑑資訊。")
	_detail_stats.clear()
	_footer_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _get_current_entries() -> Array[Dictionary]:
	match _current_tab:
		Tab.FAMILIARS:
			return DataManager.get_all_familiars()
		Tab.ITEMS:
			return DataManager.get_all_items()
		Tab.SKILLS:
			return DataManager.get_all_skills()
		Tab.ENEMIES:
			return DataManager.get_all_enemies()
		_:
			return []


func _build_list_text(entry: Dictionary) -> String:
	var entry_id: String = String(entry.get("id", ""))
	match _current_tab:
		Tab.FAMILIARS:
			if not _is_familiar_discovered(entry_id):
				return "???"
			return "[%s] %s" % [
				_format_element_name(String(entry.get("element", "none"))),
				String(entry.get("name", entry_id)),
			]
		Tab.ITEMS:
			if not _is_item_discovered(entry_id):
				return "???"
			return "[%s] %s" % [
				String(entry.get("rarity", "N")),
				String(entry.get("name", entry_id)),
			]
		Tab.SKILLS:
			var learned: bool = _is_skill_learned(entry_id)
			return "%s[%s] %s" % [
				"★" if learned else "",
				_format_element_name(String(entry.get("element", "none"))),
				String(entry.get("name", entry_id)),
			]
		Tab.ENEMIES:
			if not _is_enemy_discovered(entry_id):
				return "???"
			return "[%s] %s" % [
				_format_element_name(String(entry.get("element", "none"))),
				String(entry.get("name", entry_id)),
			]
		_:
			return entry_id


func _get_row_color(entry: Dictionary) -> Color:
	var entry_id: String = String(entry.get("id", ""))
	match _current_tab:
		Tab.FAMILIARS:
			if not _is_familiar_discovered(entry_id):
				return ThemeConstantsClass.TEXT_SECONDARY
			return ThemeConstantsClass.get_element_color(String(entry.get("element", "none")))
		Tab.ITEMS:
			if not _is_item_discovered(entry_id):
				return ThemeConstantsClass.TEXT_SECONDARY
			return ThemeConstantsClass.get_rarity_border(String(entry.get("rarity", "N")))
		Tab.SKILLS:
			if _is_skill_learned(entry_id):
				return ThemeConstantsClass.get_element_color(String(entry.get("element", "none")))
			return ThemeConstantsClass.TEXT_PRIMARY
		Tab.ENEMIES:
			if not _is_enemy_discovered(entry_id):
				return ThemeConstantsClass.TEXT_SECONDARY
			return ThemeConstantsClass.get_element_color(String(entry.get("element", "none")))
		_:
			return ThemeConstantsClass.TEXT_PRIMARY


func _update_meta_label(entries: Array[Dictionary]) -> void:
	var discovered_count: int = 0
	match _current_tab:
		Tab.FAMILIARS:
			for entry in entries:
				if _is_familiar_discovered(String(entry.get("id", ""))):
					discovered_count += 1
		Tab.ITEMS:
			for entry in entries:
				if _is_item_discovered(String(entry.get("id", ""))):
					discovered_count += 1
		Tab.SKILLS:
			for entry in entries:
				if _is_skill_learned(String(entry.get("id", ""))):
					discovered_count += 1
		Tab.ENEMIES:
			for entry in entries:
				if _is_enemy_discovered(String(entry.get("id", ""))):
					discovered_count += 1
	_meta_label.text = "收集: %d / %d" % [discovered_count, entries.size()]


func _create_tab_button(text: String, tab: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 36)
	button.pressed.connect(_on_tab_pressed.bind(tab))
	return button


func _on_tab_pressed(tab: int) -> void:
	_current_tab = tab
	_refresh_list()


func _on_entry_selected(entry_id: String) -> void:
	_selected_id = entry_id
	_refresh_list()


func _update_tab_style() -> void:
	_familiar_tab_button.disabled = _current_tab == Tab.FAMILIARS
	_item_tab_button.disabled = _current_tab == Tab.ITEMS
	_skill_tab_button.disabled = _current_tab == Tab.SKILLS
	_enemy_tab_button.disabled = _current_tab == Tab.ENEMIES


func _is_familiar_discovered(familiar_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.discovered_familiar_ids.has(familiar_id)


func _is_item_discovered(item_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.discovered_item_ids.has(item_id)


func _is_enemy_discovered(enemy_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.discovered_enemy_ids.has(enemy_id)


func _is_skill_learned(skill_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.learned_skill_ids.has(skill_id)


func _build_base_growth_lines(familiar_data: Dictionary) -> Array[String]:
	var lines: Array[String] = ["基礎能力"]
	var base_stats: Dictionary = Dictionary(familiar_data.get("base_stats", {}))
	var growth: Dictionary = Dictionary(familiar_data.get("growth_per_level", {}))
	for stat_key in STAT_ORDER:
		lines.append(
			"- %s: %d（成長 +%d）" % [
				stat_key.to_upper(),
				int(base_stats.get(stat_key, 0)),
				int(growth.get(stat_key, 0)),
			]
		)
	return lines


func _build_skill_name_lines(skill_ids: Array) -> Array[String]:
	var lines: Array[String] = []
	for raw_skill_id in skill_ids:
		var skill_id: String = String(raw_skill_id).strip_edges()
		if skill_id.is_empty():
			continue
		var skill_data: Dictionary = DataManager.get_skill(skill_id)
		lines.append("- %s" % String(skill_data.get("name", skill_id)))
	if lines.is_empty():
		lines.append("- （無）")
	return lines


func _build_evolution_lines(familiar_data: Dictionary) -> Array[String]:
	var lines: Array[String] = ["進化條件"]
	var evolution: Dictionary = Dictionary(familiar_data.get("evolution", {}))
	if evolution.is_empty():
		lines.append("- 無進化")
		return lines

	var target_id: String = String(evolution.get("target_id", ""))
	var target_data: Dictionary = DataManager.get_familiar(target_id)
	lines.append("- 目標: %s" % String(target_data.get("name", target_id)))
	lines.append("- 需求等級: Lv.%d" % int(evolution.get("required_level", 1)))

	var items: Array = Array(evolution.get("required_items", []))
	if items.is_empty():
		lines.append("- 需求道具: 無")
	else:
		for raw_item in items:
			if raw_item is not Dictionary:
				continue
			var item: Dictionary = raw_item
			var item_id: String = String(item.get("id", ""))
			var item_data: Dictionary = DataManager.get_item(item_id)
			lines.append("- %s x%d" % [String(item_data.get("name", item_id)), int(item.get("count", 0))])
	return lines


func _format_element_name(element: String) -> String:
	match element:
		"fire":
			return "火"
		"ice":
			return "冰"
		"water":
			return "水"
		"thunder":
			return "雷"
		"wind":
			return "風"
		"earth":
			return "土"
		"light":
			return "光"
		"dark":
			return "暗"
		_:
			return "無"


func _format_role_name(role: String) -> String:
	match role:
		"attack":
			return "攻擊型"
		"defense":
			return "防禦型"
		"support":
			return "支援型"
		_:
			return role if not role.is_empty() else "未知"


func _format_item_type(item_type: String) -> String:
	match item_type:
		"consumable":
			return "消耗品"
		"material":
			return "素材"
		"familiar_core":
			return "使魔核心"
		"weapon":
			return "武器"
		"armor":
			return "防具"
		"accessory":
			return "飾品"
		"key_item":
			return "關鍵道具"
		"magic_book":
			return "魔導書"
		_:
			return item_type if not item_type.is_empty() else "未知"


func _format_skill_type(skill_type: String) -> String:
	match skill_type:
		"magic":
			return "魔法"
		"physical":
			return "物理"
		"support":
			return "輔助"
		"passive":
			return "被動"
		"special":
			return "特殊"
		_:
			return skill_type if not skill_type.is_empty() else "未知"


func _format_item_effect_line(effect: Dictionary) -> String:
	var effect_type: String = String(effect.get("type", ""))
	match effect_type:
		"heal_hp":
			return "- 回復 HP %d" % int(effect.get("value", 0))
		"heal_mp":
			return "- 回復 MP %d" % int(effect.get("value", 0))
		"revive":
			return "- 復活"
		_:
			var value_text: String = ""
			if effect.has("value"):
				value_text = " %s" % String(effect.get("value", ""))
			return "- %s%s" % [_format_effect_type(effect_type), value_text]


func _format_skill_effect_line(effect: Dictionary, skill_data: Dictionary) -> String:
	var effect_type: String = String(effect.get("type", ""))
	match effect_type:
		"damage":
			return "- 傷害 %d" % int(effect.get("power", skill_data.get("base_power", 0)))
		"status":
			return "- 狀態：%s（%d%% / %d 回合）" % [
				String(effect.get("status", "")),
				int(effect.get("chance", 0)),
				int(effect.get("duration", 0)),
			]
		"heal_hp":
			return "- 回復 HP %d" % int(effect.get("value", 0))
		"heal_mp":
			return "- 回復 MP %d" % int(effect.get("value", 0))
		_:
			return "- %s" % _format_effect_type(effect_type)


func _format_effect_type(effect_type: String) -> String:
	match effect_type:
		"heal_hp":
			return "回復 HP"
		"heal_mp":
			return "回復 MP"
		"damage":
			return "傷害"
		"status":
			return "附加狀態"
		"buff":
			return "增益"
		"debuff":
			return "減益"
		_:
			return effect_type if not effect_type.is_empty() else "效果"


func _append_lines(target: RichTextLabel, lines: Array[String]) -> void:
	target.clear()
	target.append_text("\n".join(lines))


func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_list_container.add_child(label)
