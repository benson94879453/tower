class_name FamiliarHousePanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")

signal panel_closed
signal familiar_action_performed(action: String, detail: String)

enum Tab { ROSTER, TRAIN, PARTY }

const STAT_ORDER := ["hp", "mp", "matk", "mdef", "patk", "pdef", "speed"]

var _current_tab: int = Tab.ROSTER
var _selected_index: int = -1

var _title_label: Label
var _gold_label: Label
var _roster_tab_button: Button
var _train_tab_button: Button
var _party_tab_button: Button
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
	_current_tab = Tab.ROSTER
	_selected_index = -1

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

	_title_label = Label.new()
	_title_label.text = "使魔小屋"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	_gold_label.add_theme_color_override("font_color", ThemeConstantsClass.EXP_COLOR)
	header.add_child(_gold_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)

	_roster_tab_button = _create_tab_button("全覽", Tab.ROSTER)
	tabs.add_child(_roster_tab_button)

	_train_tab_button = _create_tab_button("訓練", Tab.TRAIN)
	tabs.add_child(_train_tab_button)

	_party_tab_button = _create_tab_button("隊伍", Tab.PARTY)
	tabs.add_child(_party_tab_button)

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

	_update_gold_display()
	_update_tab_style()

	var roster: Array = _get_owned_familiars()
	if roster.is_empty():
		_selected_index = -1
		_add_empty_label("（尚未擁有任何使魔）")
		_clear_detail()
		return

	if _selected_index < 0 or _selected_index >= roster.size():
		_selected_index = 0

	for index in range(roster.size()):
		var entry: Dictionary = Dictionary(roster[index])
		var familiar_data: Dictionary = DataManager.get_familiar(String(entry.get("id", "")))
		if familiar_data.is_empty():
			continue

		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 36.0
		row.text = _build_list_text(index, entry, familiar_data)
		row.add_theme_color_override(
			"font_color",
			ThemeConstantsClass.get_element_color(String(familiar_data.get("element", "none")))
		)
		if index == _selected_index:
			row.disabled = true
		row.pressed.connect(_on_familiar_selected.bind(index))
		_list_container.add_child(row)

	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_index < 0:
		_clear_detail()
		return

	var entry: Dictionary = PlayerManager.get_familiar_instance(_selected_index)
	var familiar_data: Dictionary = DataManager.get_familiar(String(entry.get("id", "")))
	if entry.is_empty() or familiar_data.is_empty():
		_clear_detail()
		return

	match _current_tab:
		Tab.ROSTER:
			_show_roster_detail(entry, familiar_data)
		Tab.TRAIN:
			_show_train_detail(entry, familiar_data)
		Tab.PARTY:
			_show_party_detail(entry, familiar_data)


func _show_roster_detail(entry: Dictionary, familiar_data: Dictionary) -> void:
	_prepare_detail(entry, familiar_data)
	var evolve_status: Dictionary = PlayerManager.can_evolve_familiar(_selected_index)

	var description_lines: Array[String] = [
		"屬性: %s" % _format_element_name(String(familiar_data.get("element", "none"))),
		"定位: %s" % _format_role_name(String(familiar_data.get("type", ""))),
		"獲得日期: %s" % String(entry.get("obtained_at", "-")),
		"來源: %s" % String(familiar_data.get("obtain_source", "未知")),
	]
	_append_lines(_detail_desc, description_lines)

	var skill_ids: Array = Array(entry.get("skill_ids", []))
	var skill_slots: int = int(familiar_data.get("skill_slots", 0))
	var stats_lines: Array[String] = _build_growth_lines(familiar_data, int(entry.get("level", 1)))
	stats_lines.append("")
	stats_lines.append("已裝備技能: %d/%d" % [skill_ids.size(), skill_slots])
	stats_lines.append_array(_build_skill_name_lines(skill_ids))
	stats_lines.append("")
	stats_lines.append_array(_build_evolution_lines(entry, familiar_data, evolve_status))
	stats_lines.append("")
	stats_lines.append_array(_build_hatch_lines())
	_append_lines(_detail_stats, stats_lines)

	_footer_label.text = "最高等級: Lv.%d / 使魔欄位: %d/%d" % [
		int(familiar_data.get("max_level", 1)),
		_get_owned_familiars().size(),
		PlayerManager.FAMILIAR_ROSTER_LIMIT,
	]
	_populate_roster_actions(evolve_status)


func _show_train_detail(entry: Dictionary, familiar_data: Dictionary) -> void:
	_prepare_detail(entry, familiar_data)

	var level: int = int(entry.get("level", 1))
	var current_exp: int = int(entry.get("exp", 0))
	var max_level: int = max(int(familiar_data.get("max_level", 1)), 1)
	var at_max_level: bool = level >= max_level
	var train_cost: int = _get_training_cost(level)
	var train_exp: int = _get_training_exp(level)

	var description_lines: Array[String] = [
		"目前等級: Lv.%d / %d" % [level, max_level],
	]
	if at_max_level:
		description_lines.append("已達最高等級")
	else:
		description_lines.append(
			"目前 EXP: %d / %d" % [current_exp, DataManager.get_familiar_exp_required(level)]
		)
	_append_lines(_detail_desc, description_lines)

	var stats_lines: Array[String] = _build_growth_lines(familiar_data, level)
	stats_lines.append("")
	stats_lines.append("訓練獲得 EXP: %d" % train_exp)
	stats_lines.append("訓練費用: %d G" % train_cost)
	_append_lines(_detail_stats, stats_lines)

	if at_max_level:
		_footer_label.text = "已達最高等級"
	else:
		_footer_label.text = "持有金幣: %d G" % _get_current_gold()

	var train_button := Button.new()
	train_button.text = "訓練"
	train_button.custom_minimum_size = Vector2(100, 40)
	train_button.disabled = at_max_level or _get_current_gold() < train_cost
	train_button.pressed.connect(_on_train_pressed.bind(_selected_index))
	_action_container.add_child(train_button)

	if train_button.disabled:
		var hint := Label.new()
		hint.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		hint.text = "已達最高等級" if at_max_level else "金幣不足"
		_action_container.add_child(hint)


func _show_party_detail(entry: Dictionary, familiar_data: Dictionary) -> void:
	_prepare_detail(entry, familiar_data)

	var level: int = int(entry.get("level", 1))
	var preview = CombatantDataClass.from_familiar(
		String(entry.get("id", "")),
		level,
		Array(entry.get("skill_ids", []))
	)
	var is_active: bool = (
		PlayerManager.player_data != null
		and PlayerManager.player_data.active_familiar_index == _selected_index
	)

	var description_lines: Array[String] = [
		"屬性: %s" % _format_element_name(String(familiar_data.get("element", "none"))),
		"定位: %s" % _format_role_name(String(familiar_data.get("type", ""))),
		"出戰狀態: %s" % ("已出戰" if is_active else "待命中"),
	]
	_append_lines(_detail_desc, description_lines)

	var stats_lines: Array[String] = []
	if preview != null:
		stats_lines = [
			"HP: %d" % preview.max_hp,
			"MP: %d" % preview.max_mp,
			"MATK: %d" % preview.matk,
			"MDEF: %d" % preview.mdef,
			"PATK: %d" % preview.patk,
			"PDEF: %d" % preview.pdef,
			"SPEED: %d" % preview.speed,
		]
	else:
		stats_lines.append("（無法建立戰鬥預覽）")

	stats_lines.append("")
	stats_lines.append("已裝備技能")
	stats_lines.append_array(_build_skill_name_lines(Array(entry.get("skill_ids", []))))
	_append_lines(_detail_stats, stats_lines)

	_footer_label.text = "目前僅可出戰 1 隻使魔"

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(120, 40)
	action_button.text = "取消出戰" if is_active else "設為出戰"
	action_button.pressed.connect(_on_party_button_pressed.bind(_selected_index, is_active))
	_action_container.add_child(action_button)


func _prepare_detail(entry: Dictionary, familiar_data: Dictionary) -> void:
	_detail_name.text = _get_display_name(entry, familiar_data)
	_detail_name.add_theme_color_override(
		"font_color",
		ThemeConstantsClass.get_element_color(String(familiar_data.get("element", "none")))
	)
	_detail_desc.clear()
	_detail_stats.clear()
	_footer_label.text = ""
	for child in _action_container.get_children():
		child.queue_free()


func _clear_detail() -> void:
	for child in _action_container.get_children():
		child.queue_free()

	_detail_name.text = "選擇使魔"
	_detail_name.remove_theme_color_override("font_color")
	_detail_desc.clear()
	match _current_tab:
		Tab.ROSTER:
			_detail_desc.append_text("選擇左側使魔以查看詳細資訊。")
			_append_lines(_detail_stats, _build_hatch_lines())
			_footer_label.text = "使魔欄位: %d/%d" % [_get_owned_familiars().size(), PlayerManager.FAMILIAR_ROSTER_LIMIT]
			_populate_hatch_actions()
		Tab.TRAIN:
			_detail_desc.append_text("選擇左側使魔以進行訓練。")
			_detail_stats.clear()
			_footer_label.text = ""
		Tab.PARTY:
			_detail_desc.append_text("選擇左側使魔以設定出戰。")
			_detail_stats.clear()
			_footer_label.text = ""


func _on_familiar_selected(index: int) -> void:
	_selected_index = index
	_refresh_list()


func _on_train_pressed(index: int) -> void:
	var entry: Dictionary = PlayerManager.get_familiar_instance(index)
	if entry.is_empty():
		return

	var level: int = int(entry.get("level", 1))
	var cost: int = _get_training_cost(level)
	var exp_gain: int = _get_training_exp(level)
	if not PlayerManager.spend_gold(cost):
		_refresh_detail()
		return

	var result: Dictionary = PlayerManager.train_familiar(index, exp_gain)
	if not bool(result.get("success", false)):
		PlayerManager.add_gold(cost)
		_refresh_detail()
		return

	var updated_entry: Dictionary = PlayerManager.get_familiar_instance(index)
	var familiar_name: String = _get_display_name(
		updated_entry,
		DataManager.get_familiar(String(updated_entry.get("id", "")))
	)
	var detail: String = "%s 獲得 %d EXP" % [familiar_name, exp_gain]
	if bool(result.get("leveled_up", false)):
		detail = "%s 升到 Lv.%d" % [familiar_name, int(result.get("new_level", level))]

	familiar_action_performed.emit("train", detail)
	_refresh_list()


func _on_party_button_pressed(index: int, is_active: bool) -> void:
	PlayerManager.set_active_familiar(-1 if is_active else index)

	var entry: Dictionary = PlayerManager.get_familiar_instance(index)
	var familiar_data: Dictionary = DataManager.get_familiar(String(entry.get("id", "")))
	var familiar_name: String = _get_display_name(entry, familiar_data)
	var detail: String = ""
	if is_active:
		detail = "%s 取消出戰" % familiar_name
	else:
		detail = "%s 設為出戰" % familiar_name
	familiar_action_performed.emit("party", detail)
	_refresh_list()


func _on_evolve_pressed(index: int) -> void:
	var before_entry: Dictionary = PlayerManager.get_familiar_instance(index)
	var before_data: Dictionary = DataManager.get_familiar(String(before_entry.get("id", "")))
	if before_entry.is_empty() or before_data.is_empty():
		return

	var old_name: String = _get_display_name(before_entry, before_data)
	var result: Dictionary = PlayerManager.evolve_familiar(index)
	if not bool(result.get("success", false)):
		_refresh_detail()
		_footer_label.text = _format_evolution_failure_reason(result)
		return

	_refresh_list()
	var new_entry: Dictionary = PlayerManager.get_familiar_instance(index)
	var new_data: Dictionary = DataManager.get_familiar(String(new_entry.get("id", "")))
	var new_name: String = _get_display_name(new_entry, new_data)
	var detail: String = "%s 進化為 %s" % [old_name, new_name]
	familiar_action_performed.emit("evolve", detail)
	_footer_label.text = detail


func _on_hatch_pressed(core_item_id: String) -> void:
	var result: Dictionary = PlayerManager.hatch_familiar(core_item_id)
	if bool(result.get("success", false)):
		_selected_index = _get_owned_familiars().size() - 1
		var familiar_name: String = String(result.get("familiar_name", result.get("familiar_id", "使魔")))
		familiar_action_performed.emit("hatch", "%s 孵化成功" % familiar_name)
		_refresh_list()
		_footer_label.text = "%s 孵化成功" % familiar_name
		return

	_footer_label.text = _format_hatch_failure_reason(String(result.get("reason", "")))
	if String(result.get("reason", "")) == "no_core":
		_refresh_list()


func _create_tab_button(text: String, tab: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(_on_tab_pressed.bind(tab))
	return button


func _on_tab_pressed(tab: int) -> void:
	_current_tab = tab
	_refresh_list()


func _update_gold_display() -> void:
	_gold_label.text = "金幣: %d" % _get_current_gold()


func _update_tab_style() -> void:
	_roster_tab_button.disabled = _current_tab == Tab.ROSTER
	_train_tab_button.disabled = _current_tab == Tab.TRAIN
	_party_tab_button.disabled = _current_tab == Tab.PARTY


func _get_owned_familiars() -> Array:
	if PlayerManager.player_data == null:
		return []
	return PlayerManager.player_data.owned_familiars


func _build_list_text(index: int, entry: Dictionary, familiar_data: Dictionary) -> String:
	var prefix: String = ""
	if (
		_current_tab == Tab.PARTY
		and PlayerManager.player_data != null
		and PlayerManager.player_data.active_familiar_index == index
	):
		prefix = "★ "

	return "%s[%s] %s Lv.%d" % [
		prefix,
		_format_element_name(String(familiar_data.get("element", "none"))),
		_get_display_name(entry, familiar_data),
		int(entry.get("level", 1)),
	]


func _build_growth_lines(familiar_data: Dictionary, level: int) -> Array[String]:
	var base_stats: Dictionary = Dictionary(familiar_data.get("base_stats", {}))
	var growth: Dictionary = Dictionary(familiar_data.get("growth_per_level", {}))
	var level_bonus: int = max(level - 1, 0)
	var lines: Array[String] = []
	for stat_key in STAT_ORDER:
		var base_value: int = int(base_stats.get(stat_key, 0))
		var growth_value: int = int(growth.get(stat_key, 0))
		var current_value: int = base_value + growth_value * level_bonus
		lines.append("%s: %d（基礎 %d / 成長 +%d）" % [
			stat_key.to_upper(),
			current_value,
			base_value,
			growth_value,
		])
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
		lines.append("- （尚未裝備技能）")
	return lines


func _build_evolution_lines(entry: Dictionary, familiar_data: Dictionary, evolve_status: Dictionary) -> Array[String]:
	var lines: Array[String] = ["進化條件"]
	var evolution: Dictionary = Dictionary(familiar_data.get("evolution", {}))
	if evolution.is_empty():
		lines.append("- 無進化")
		return lines

	var target_id: String = String(evolution.get("target_id", ""))
	var target_data: Dictionary = DataManager.get_familiar(target_id)
	lines.append("- 目標: %s" % String(target_data.get("name", target_id)))
	lines.append("- 等級: Lv.%d / %d" % [int(entry.get("level", 1)), int(evolution.get("required_level", 1))])

	var items: Array = Array(evolution.get("required_items", []))
	if items.is_empty():
		lines.append("- 需求道具: 無")
	else:
		lines.append("- 需求道具")
		for raw_item in items:
			if raw_item is not Dictionary:
				continue
			var item: Dictionary = raw_item
			var item_id: String = String(item.get("id", ""))
			var item_data: Dictionary = DataManager.get_item(item_id)
			var need: int = int(item.get("count", 0))
			var have: int = PlayerManager.get_item_count(item_id)
			lines.append("- %s：%d/%d" % [String(item_data.get("name", item_id)), have, need])
	lines.append("- 狀態: %s" % _format_evolution_status(evolve_status))
	return lines


func _build_hatch_lines() -> Array[String]:
	var lines: Array[String] = ["可孵化核心"]
	var core_entries: Array[Dictionary] = _get_hatchable_core_entries()
	if core_entries.is_empty():
		lines.append("- （目前沒有可孵化核心）")
		return lines

	for core_entry in core_entries:
		var item_data: Dictionary = Dictionary(core_entry.get("item_data", {}))
		var core_count: int = int(core_entry.get("count", 0))
		var familiar_id: String = String(item_data.get("hatches_into", ""))
		var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
		var familiar_name: String = String(familiar_data.get("name", familiar_id if not familiar_id.is_empty() else "未知使魔"))
		var gold_cost: int = int(Dictionary(item_data.get("hatch_cost", {})).get("gold", 0))
		lines.append("- %s x%d -> %s（%dG）" % [String(item_data.get("name", "")), core_count, familiar_name, gold_cost])
	return lines


func _get_hatchable_core_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if PlayerManager.inventory == null:
		return result

	for raw_entry in PlayerManager.inventory.get_all_items():
		if raw_entry is not Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id: String = String(entry.get("id", ""))
		var count: int = int(entry.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue

		var item_data: Dictionary = DataManager.get_item(item_id)
		if String(item_data.get("type", "")) != "familiar_core":
			continue

		result.append({
			"id": item_id,
			"count": count,
			"item_data": item_data,
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary):
		return String(Dictionary(a.get("item_data", {})).get("name", a.get("id", ""))) \
			< String(Dictionary(b.get("item_data", {})).get("name", b.get("id", "")))
	)
	return result


func _populate_roster_actions(evolve_status: Dictionary) -> void:
	if _current_tab != Tab.ROSTER:
		return

	if _selected_index != -1:
		var evolve_button := Button.new()
		evolve_button.text = "進化"
		evolve_button.custom_minimum_size = Vector2(100, 40)
		evolve_button.disabled = not bool(evolve_status.get("success", false))
		evolve_button.pressed.connect(_on_evolve_pressed.bind(_selected_index))
		_action_container.add_child(evolve_button)

		if evolve_button.disabled:
			var evolve_label := Label.new()
			evolve_label.text = _format_evolution_failure_reason(evolve_status)
			evolve_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
			_action_container.add_child(evolve_label)

	_populate_hatch_actions()


func _populate_hatch_actions() -> void:
	if _current_tab != Tab.ROSTER:
		return

	var core_entries: Array[Dictionary] = _get_hatchable_core_entries()
	if core_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "目前沒有可孵化核心"
		empty_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_action_container.add_child(empty_label)
		return

	var is_roster_full: bool = _get_owned_familiars().size() >= PlayerManager.FAMILIAR_ROSTER_LIMIT
	var needs_gold_hint := false
	for core_entry in core_entries:
		var item_id: String = String(core_entry.get("id", ""))
		var item_data: Dictionary = Dictionary(core_entry.get("item_data", {}))
		var familiar_id: String = String(item_data.get("hatches_into", ""))
		var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
		var familiar_name: String = String(familiar_data.get("name", familiar_id if not familiar_id.is_empty() else "使魔"))
		var gold_cost: int = int(Dictionary(item_data.get("hatch_cost", {})).get("gold", 0))

		var button := Button.new()
		button.text = "孵化 %s（%dG）" % [familiar_name, gold_cost]
		button.custom_minimum_size = Vector2(140, 40)
		button.disabled = is_roster_full or _get_current_gold() < gold_cost
		if not is_roster_full and _get_current_gold() < gold_cost:
			needs_gold_hint = true
		button.pressed.connect(_on_hatch_pressed.bind(item_id))
		_action_container.add_child(button)
	if is_roster_full:
		var full_label := Label.new()
		full_label.text = "使魔小屋已滿"
		full_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_action_container.add_child(full_label)
	elif needs_gold_hint:
		var gold_label := Label.new()
		gold_label.text = "金幣不足"
		gold_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_action_container.add_child(gold_label)


func _format_evolution_status(evolve_status: Dictionary) -> String:
	if bool(evolve_status.get("success", false)):
		return "可進化"
	return _format_evolution_failure_reason(evolve_status)


func _format_evolution_failure_reason(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"invalid_index":
			return "使魔資料無效"
		"no_evolution":
			return "已達最終型態"
		"level_too_low":
			return "等級不足（需要 Lv.%d）" % int(result.get("required_level", 1))
		"missing_items":
			return _format_missing_item_hint(Array(result.get("missing", [])))
		"target_not_found":
			return "進化資料缺失"
		_:
			return "目前無法進化"


func _format_missing_item_hint(missing_items: Array) -> String:
	var parts: Array[String] = []
	for raw_missing in missing_items:
		if raw_missing is not Dictionary:
			continue
		var missing: Dictionary = raw_missing
		var item_id: String = String(missing.get("id", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_name: String = String(item_data.get("name", item_id))
		var need: int = int(missing.get("need", 0))
		var have: int = int(missing.get("have", 0))
		parts.append("%s %d/%d" % [item_name, have, need])
	if parts.is_empty():
		return "缺少素材"
	return "缺少素材：%s" % "、".join(parts)


func _get_display_name(entry: Dictionary, familiar_data: Dictionary) -> String:
	var nickname: String = String(entry.get("nickname", "")).strip_edges()
	var base_name: String = String(familiar_data.get("name", entry.get("id", "???")))
	if nickname.is_empty():
		return base_name
	return "%s（%s）" % [nickname, base_name]


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


func _format_hatch_failure_reason(reason: String) -> String:
	match reason:
		"no_core":
			return "缺少使魔核心"
		"no_gold":
			return "金幣不足"
		"roster_full":
			return "使魔小屋已滿"
		"invalid_data":
			return "核心資料異常"
		_:
			return "孵化失敗"


func _append_lines(target: RichTextLabel, lines: Array[String]) -> void:
	target.clear()
	target.append_text("\n".join(lines))


func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_list_container.add_child(label)


func _get_training_cost(level: int) -> int:
	return 50 * max(level, 1)


func _get_training_exp(level: int) -> int:
	return 20 + max(level, 1) * 5


func _get_current_gold() -> int:
	if PlayerManager.player_data == null:
		return 0
	return PlayerManager.player_data.gold
