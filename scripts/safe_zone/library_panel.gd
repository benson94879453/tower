class_name LibraryPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal panel_closed

enum Tab { FAMILIARS, ITEMS, SKILLS, ENEMIES, RESEARCH }

const STAT_ORDER := ["hp", "mp", "matk", "mdef", "patk", "pdef", "speed"]

var _current_tab: int = Tab.FAMILIARS
var _selected_id: String = ""
var _status_message: String = ""

var _meta_label: Label
var _familiar_tab_button: Button
var _item_tab_button: Button
var _skill_tab_button: Button
var _enemy_tab_button: Button
var _research_tab_button: Button
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


func setup() -> void:
	_current_tab = Tab.FAMILIARS
	_selected_id = ""
	_status_message = ""

	theme_type_variation = "CombatantPanel"

	for child in get_children():
		child.queue_free()

	# Connect to DataManager to ensure data is loaded before refreshing
	if not DataManager.data_loaded.is_connected(_on_data_loaded):
		DataManager.data_loaded.connect(_on_data_loaded)

	_build_ui()
	# Don't refresh immediately - wait for data to load
	if DataManager.get_all_skills().size() > 0:  # Check if data is already loaded
		_refresh_list()


func _on_data_loaded() -> void:
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

	_research_tab_button = _create_tab_button("研究", Tab.RESEARCH)
	tabs.add_child(_research_tab_button)

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
	_detail_desc.custom_minimum_size.y = 88.0
	detail_root.add_child(_detail_desc)

	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.custom_minimum_size.y = 190.0
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
		_update_meta_label(entries)
		_add_empty_label(_get_empty_text())
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
		Tab.RESEARCH:
			_show_research_detail(DataManager.get_skill(_selected_id))


func _show_familiar_detail(familiar_data: Dictionary) -> void:
	if familiar_data.is_empty():
		_clear_detail()
		return
	if not _is_familiar_discovered(String(familiar_data.get("id", ""))):
		_show_hidden_detail("尚未發現這隻使魔。")
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
	lines.append("預設技能")
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
		_show_hidden_detail("尚未取得這個道具。")
		return

	_prepare_detail(
		String(item_data.get("name", "???")),
		ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N")))
	)
	_append_lines(_detail_desc, [
		"類型: %s" % _format_item_type(String(item_data.get("type", ""))),
		"稀有度: %s" % String(item_data.get("rarity", "N")),
		"說明: %s" % String(item_data.get("description", "")),
	])

	var lines: Array[String] = []
	var stats: Dictionary = Dictionary(item_data.get("stats", {}))
	if not stats.is_empty():
		lines.append("能力加成")
		var stat_keys: Array = stats.keys()
		stat_keys.sort()
		for raw_key in stat_keys:
			lines.append("- %s +%d" % [_format_stat_name(String(raw_key)), int(stats.get(raw_key, 0))])

	var effects: Array = Array(item_data.get("effects", []))
	if not effects.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append("效果")
		for raw_effect in effects:
			if raw_effect is not Dictionary:
				continue
			lines.append(_format_item_effect_line(Dictionary(raw_effect)))

	if lines.is_empty():
		lines.append("沒有額外效果。")
	_append_lines(_detail_stats, lines)
	_footer_label.text = "買價: %dG / 售價: %dG" % [
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
		"說明: %s" % String(skill_data.get("description", "")),
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
			lines.append(_format_skill_effect_line(Dictionary(raw_effect), skill_data))

	_append_lines(_detail_stats, lines)
	_footer_label.text = "已習得" if learned else "尚未習得"


func _show_enemy_detail(enemy_data: Dictionary) -> void:
	if enemy_data.is_empty():
		_clear_detail()
		return
	if not _is_enemy_discovered(String(enemy_data.get("id", ""))):
		_show_hidden_detail("尚未遭遇這種怪物。")
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
		lines.append("- %s: %d" % [_format_stat_name(stat_key), int(stats.get(stat_key, 0))])

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
			var item_name: String = String(DataManager.get_item(item_id).get("name", item_id))
			lines.append("- %s (%.0f%%)" % [item_name, float(drop.get("rate", 0.0)) * 100.0])

	_append_lines(_detail_stats, lines)

	var floor_range: Array = Array(enemy_data.get("floor_range", []))
	if floor_range.size() >= 2:
		_footer_label.text = "出現樓層: %dF - %dF" % [int(floor_range[0]), int(floor_range[1])]
	else:
		_footer_label.text = ""


func _show_research_detail(skill_data: Dictionary) -> void:
	if skill_data.is_empty():
		_clear_detail()
		return

	var state: Dictionary = _build_research_state(skill_data)
	_prepare_detail(
		String(skill_data.get("name", "???")),
		ThemeConstantsClass.get_element_color(String(skill_data.get("element", "none")))
	)
	_append_lines(_detail_desc, [
		"屬性: %s" % _format_element_name(String(skill_data.get("element", "none"))),
		"類型: %s" % _format_skill_type(String(skill_data.get("type", ""))),
		"說明: %s" % String(skill_data.get("description", "")),
	])

	var lines: Array[String] = [
		"研究消耗",
		"- 金幣: %d / %d" % [int(state.get("gold_have", 0)), int(state.get("gold_cost", 0))],
	]

	var item_requirements: Array = Array(state.get("item_requirements", []))
	if item_requirements.is_empty():
		lines.append("- 素材: 無")
	else:
		lines.append("- 素材:")
		for raw_requirement in item_requirements:
			if raw_requirement is not Dictionary:
				continue
			var requirement: Dictionary = raw_requirement
			lines.append(
				"  %s %d / %d" % [
					String(requirement.get("name", requirement.get("id", ""))),
					int(requirement.get("have", 0)),
					int(requirement.get("need", 0)),
				]
			)

	var prereq_states: Array = Array(state.get("prereq_states", []))
	if prereq_states.is_empty():
		lines.append("- 前置技能: 無")
	else:
		lines.append("- 前置技能:")
		for raw_prereq in prereq_states:
			if raw_prereq is not Dictionary:
				continue
			var prereq: Dictionary = raw_prereq
			lines.append(
				"  %s - %s" % [
					String(prereq.get("name", prereq.get("id", ""))),
					"已習得" if bool(prereq.get("learned", false)) else "未習得",
				]
			)

	_append_lines(_detail_stats, lines)
	_footer_label.text = _format_research_reason(state)

	var research_button := Button.new()
	research_button.text = "研究" if bool(state.get("can_research", false)) else "研究 - %s" % _format_research_reason(state)
	research_button.disabled = not bool(state.get("can_research", false))
	research_button.custom_minimum_size = Vector2(120, 40)
	research_button.pressed.connect(_on_research_pressed.bind(String(skill_data.get("id", ""))))
	_action_container.add_child(research_button)


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
	_detail_desc.append_text("選擇左側條目以查看詳細資訊。")
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
		Tab.RESEARCH:
			var result: Array[Dictionary] = []
			for skill_data in DataManager.get_all_skills():
				var skill_id: String = String(skill_data.get("id", ""))
				var research_cost: Dictionary = Dictionary(skill_data.get("research_cost", {}))
				if research_cost.is_empty():
					continue
				if _is_skill_learned(skill_id):
					continue
				result.append(skill_data)
			return result
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
			return "%s[%s] %s" % [
				"★" if _is_skill_learned(entry_id) else "",
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
		Tab.RESEARCH:
			var research_cost: Dictionary = Dictionary(entry.get("research_cost", {}))
			return "[%s] %s - %dG" % [
				_format_element_name(String(entry.get("element", "none"))),
				String(entry.get("name", entry_id)),
				int(research_cost.get("gold", 0)),
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
		Tab.RESEARCH:
			var state: Dictionary = _build_research_state(entry)
			if bool(state.get("can_research", false)):
				return ThemeConstantsClass.get_element_color(String(entry.get("element", "none")))
			if not Array(state.get("missing_prereqs", [])).is_empty():
				return Color("#FF6666")
			return ThemeConstantsClass.TEXT_SECONDARY
		_:
			return ThemeConstantsClass.TEXT_PRIMARY


func _update_meta_label(entries: Array[Dictionary]) -> void:
	var text: String = ""
	match _current_tab:
		Tab.FAMILIARS:
			text = "已發現: %d / %d" % [_count_discovered(entries, "familiar"), entries.size()]
		Tab.ITEMS:
			text = "已發現: %d / %d" % [_count_discovered(entries, "item"), entries.size()]
		Tab.SKILLS:
			text = "已習得: %d / %d" % [_count_learned_skills(entries), entries.size()]
		Tab.ENEMIES:
			text = "已遭遇: %d / %d" % [_count_discovered(entries, "enemy"), entries.size()]
		Tab.RESEARCH:
			text = "可研究: %d" % entries.size()

	if not _status_message.is_empty():
		text += "  %s" % _status_message
	_meta_label.text = text


func _count_discovered(entries: Array[Dictionary], entry_type: String) -> int:
	var count: int = 0
	for entry in entries:
		var entry_id: String = String(entry.get("id", ""))
		match entry_type:
			"familiar":
				if _is_familiar_discovered(entry_id):
					count += 1
			"item":
				if _is_item_discovered(entry_id):
					count += 1
			"enemy":
				if _is_enemy_discovered(entry_id):
					count += 1
	return count


func _count_learned_skills(entries: Array[Dictionary]) -> int:
	var count: int = 0
	for entry in entries:
		if _is_skill_learned(String(entry.get("id", ""))):
			count += 1
	return count


func _create_tab_button(text: String, tab: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 36)
	button.pressed.connect(_on_tab_pressed.bind(tab))
	return button


func _on_tab_pressed(tab: int) -> void:
	_current_tab = tab
	_status_message = ""
	_refresh_list()


func _on_entry_selected(entry_id: String) -> void:
	_selected_id = entry_id
	_status_message = ""
	_refresh_list()


func _on_research_pressed(skill_id: String) -> void:
	var result: Dictionary = PlayerManager.research_skill(skill_id)
	if bool(result.get("success", false)):
		_status_message = "成功習得 %s！" % String(result.get("skill_name", skill_id))
	else:
		_status_message = _format_research_result_message(result)
	_refresh_list()


func _update_tab_style() -> void:
	_familiar_tab_button.disabled = _current_tab == Tab.FAMILIARS
	_item_tab_button.disabled = _current_tab == Tab.ITEMS
	_skill_tab_button.disabled = _current_tab == Tab.SKILLS
	_enemy_tab_button.disabled = _current_tab == Tab.ENEMIES
	_research_tab_button.disabled = _current_tab == Tab.RESEARCH


func _is_familiar_discovered(familiar_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.discovered_familiar_ids.has(familiar_id)


func _is_item_discovered(item_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.discovered_item_ids.has(item_id)


func _is_enemy_discovered(enemy_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.discovered_enemy_ids.has(enemy_id)


func _is_skill_learned(skill_id: String) -> bool:
	return PlayerManager.player_data != null and PlayerManager.player_data.learned_skill_ids.has(skill_id)


func _build_research_state(skill_data: Dictionary) -> Dictionary:
	var player_gold: int = int(PlayerManager.player_data.gold) if PlayerManager.player_data != null else 0
	var research_cost: Dictionary = Dictionary(skill_data.get("research_cost", {}))
	var required_prereqs: Array[String] = []
	var prereq_states: Array[Dictionary] = []
	var missing_prereqs: Array[String] = []
	var item_requirements: Array[Dictionary] = []
	var has_all_items: bool = true

	for raw_prereq in Array(research_cost.get("prerequisite_skills", [])):
		var prereq_id: String = String(raw_prereq).strip_edges()
		if prereq_id.is_empty():
			continue
		required_prereqs.append(prereq_id)
		var learned: bool = _is_skill_learned(prereq_id)
		if not learned:
			missing_prereqs.append(prereq_id)
		prereq_states.append({
			"id": prereq_id,
			"name": String(DataManager.get_skill(prereq_id).get("name", prereq_id)),
			"learned": learned,
		})

	for raw_item in Array(research_cost.get("items", [])):
		if raw_item is not Dictionary:
			continue
		var required_item: Dictionary = raw_item
		var item_id: String = String(required_item.get("id", "")).strip_edges()
		var need: int = max(int(required_item.get("count", 0)), 0)
		if item_id.is_empty() or need <= 0:
			continue
		var have: int = PlayerManager.get_item_count(item_id)
		var enough: bool = have >= need
		if not enough:
			has_all_items = false
		item_requirements.append({
			"id": item_id,
			"name": String(DataManager.get_item(item_id).get("name", item_id)),
			"need": need,
			"have": have,
			"enough": enough,
		})

	var gold_cost: int = max(int(research_cost.get("gold", 0)), 0)
	var has_gold: bool = player_gold >= gold_cost
	var reason: String = ""
	if research_cost.is_empty():
		reason = "no_research_data"
	elif _is_skill_learned(String(skill_data.get("id", ""))):
		reason = "already_learned"
	elif not missing_prereqs.is_empty():
		reason = "prerequisite_missing"
	elif not has_gold:
		reason = "not_enough_gold"
	elif not has_all_items:
		reason = "missing_items"

	return {
		"can_research": reason.is_empty(),
		"reason": reason,
		"gold_cost": gold_cost,
		"gold_have": player_gold,
		"has_gold": has_gold,
		"required_prereqs": required_prereqs,
		"missing_prereqs": missing_prereqs,
		"prereq_states": prereq_states,
		"item_requirements": item_requirements,
	}


func _format_research_reason(state: Dictionary) -> String:
	match String(state.get("reason", "")):
		"prerequisite_missing":
			return "缺少前置技能"
		"not_enough_gold":
			return "金幣不足"
		"missing_items":
			return "素材不足"
		"already_learned":
			return "已習得"
		"no_research_data":
			return "無研究資料"
		_:
			return "可研究" if bool(state.get("can_research", false)) else ""


func _format_research_result_message(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"already_learned":
			return "這個技能已經學會了。"
		"no_research_data":
			return "這個技能目前不能研究。"
		"prerequisite_missing":
			return "缺少前置技能。"
		"not_enough_gold":
			return "金幣不足。"
		"missing_items":
			return "素材不足。"
		_:
			return "研究失敗。"


func _build_base_growth_lines(familiar_data: Dictionary) -> Array[String]:
	var lines: Array[String] = ["基礎能力"]
	var base_stats: Dictionary = Dictionary(familiar_data.get("base_stats", {}))
	var growth: Dictionary = Dictionary(familiar_data.get("growth_per_level", {}))
	for stat_key in STAT_ORDER:
		lines.append(
			"- %s: %d（每級 +%d）" % [
				_format_stat_name(stat_key),
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
		lines.append("- 無")
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
	lines.append("- 等級需求: Lv.%d" % int(evolution.get("required_level", 1)))

	var items: Array = Array(evolution.get("required_items", []))
	if items.is_empty():
		lines.append("- 素材需求: 無")
	else:
		for raw_item in items:
			if raw_item is not Dictionary:
				continue
			var item: Dictionary = raw_item
			var item_id: String = String(item.get("id", ""))
			var item_name: String = String(DataManager.get_item(item_id).get("name", item_id))
			lines.append("- %s x%d" % [item_name, int(item.get("count", 0))])
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
			return "地"
		"light":
			return "光"
		"dark":
			return "暗"
		"none":
			return "無"
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
			return "魔法書"
		_:
			return item_type if not item_type.is_empty() else "未知"


func _format_skill_type(skill_type: String) -> String:
	match skill_type:
		"attack_single":
			return "單體攻擊"
		"attack_all":
			return "全體攻擊"
		"heal_single":
			return "單體治療"
		"heal_all":
			return "全體治療"
		"buff_self":
			return "自身強化"
		"passive":
			return "被動"
		_:
			return skill_type if not skill_type.is_empty() else "未知"


func _format_stat_name(stat_name: String) -> String:
	match stat_name:
		"hp":
			return "HP"
		"mp":
			return "MP"
		"matk":
			return "魔攻"
		"mdef":
			return "魔防"
		"patk":
			return "物攻"
		"pdef":
			return "物防"
		"speed":
			return "速度"
		"hit":
			return "命中"
		"crit":
			return "爆擊"
		_:
			return stat_name.to_upper()


func _format_item_effect_line(effect: Dictionary) -> String:
	match String(effect.get("type", "")):
		"heal_hp":
			return "- 回復 HP %d" % int(effect.get("value", 0))
		"heal_mp":
			return "- 回復 MP %d" % int(effect.get("value", 0))
		"revive":
			return "- 復活"
		_:
			return "- %s" % String(effect.get("type", "未知效果"))


func _format_skill_effect_line(effect: Dictionary, skill_data: Dictionary) -> String:
	match String(effect.get("type", "")):
		"damage":
			return "- 傷害: %d" % int(effect.get("power", skill_data.get("base_power", 0)))
		"status":
			return "- 狀態: %s %d%% / %d 回合" % [
				_format_status_name(String(effect.get("status", ""))),
				int(effect.get("chance", 0)),
				int(effect.get("duration", 0)),
			]
		"heal":
			return "- 治療: %d" % int(effect.get("value", 0))
		"buff":
			return "- 強化: %s %+d / %d 回合" % [
				_format_stat_name(String(effect.get("stat", ""))),
				int(effect.get("value", 0)),
				int(effect.get("duration", 0)),
			]
		"shield":
			return "- 護盾: %d" % int(effect.get("value", 0))
		_:
			return "- %s" % String(effect.get("type", "未知效果"))


func _format_status_name(status_id: String) -> String:
	match status_id:
		"burn":
			return "燃燒"
		"freeze":
			return "凍結"
		"paralyze":
			return "麻痺"
		"confuse":
			return "混亂"
		"poison":
			return "中毒"
		_:
			return status_id if not status_id.is_empty() else "異常"


func _append_lines(target: RichTextLabel, lines: Array[String]) -> void:
	target.clear()
	target.append_text("\n".join(lines))


func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_list_container.add_child(label)


func _get_empty_text() -> String:
	match _current_tab:
		Tab.RESEARCH:
			return "目前沒有可研究的技能"
		_:
			return "目前沒有資料"
