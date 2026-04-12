class_name LoadoutPanel
extends PanelContainer

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal panel_closed
signal loadout_changed

const MAX_ACTIVE_SKILLS := 8
const MAX_ACCESSORIES := 6

var _skill_slots: Array[Button] = []
var _accessory_slots: Array[Button] = []
var _selected_skill_slot: int = -1
var _selected_accessory_slot: int = -1
var _skill_picker_container: VBoxContainer
var _accessory_picker_container: VBoxContainer
var _skill_picker_scroll: ScrollContainer
var _accessory_picker_scroll: ScrollContainer
var _tab_buttons: Dictionary = {}
var _current_tab: String = "skills"
var _detail_label: RichTextLabel
var _slot_title_label: Label
var _skill_slots_box: VBoxContainer
var _accessory_slots_box: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(780, 560)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup() -> void:
	theme_type_variation = "CombatantPanel"
	_selected_skill_slot = -1
	_selected_accessory_slot = -1
	_current_tab = "skills"

	for child in get_children():
		child.queue_free()

	_build_ui()
	_refresh()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 12.0
	root.offset_top = 12.0
	root.offset_right = -12.0
	root.offset_bottom = -12.0
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_label := Label.new()
	title_label.text = "編組配置"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_LARGE)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func(): panel_closed.emit())
	header.add_child(close_button)

	# Tab row
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	root.add_child(tab_row)

	var skill_tab := Button.new()
	skill_tab.text = "主動技能 (%d/%d)" % [_count_active_skills(), MAX_ACTIVE_SKILLS]
	skill_tab.custom_minimum_size = Vector2(160, 36)
	skill_tab.pressed.connect(_on_tab_pressed.bind("skills"))
	tab_row.add_child(skill_tab)
	_tab_buttons["skills"] = skill_tab

	var acc_tab := Button.new()
	acc_tab.text = "飾品 (%d/%d)" % [_count_active_accessories(), MAX_ACCESSORIES]
	acc_tab.custom_minimum_size = Vector2(160, 36)
	acc_tab.pressed.connect(_on_tab_pressed.bind("accessories"))
	tab_row.add_child(acc_tab)
	_tab_buttons["accessories"] = acc_tab

	root.add_child(HSeparator.new())

	# Main content: slots on left, picker on right
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# Left: slot grid
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.5
	left_panel.add_theme_constant_override("separation", 6)
	content.add_child(left_panel)

	_slot_title_label = Label.new()
	_slot_title_label.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	_slot_title_label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	_slot_title_label.name = "SlotTitle"
	left_panel.add_child(_slot_title_label)

	# Skill slots container
	_skill_slots_box = VBoxContainer.new()
	_skill_slots_box.name = "SkillSlotsBox"
	_skill_slots_box.add_theme_constant_override("separation", 4)
	left_panel.add_child(_skill_slots_box)

	_skill_slots.clear()
	for i in range(MAX_ACTIVE_SKILLS):
		var slot_btn := Button.new()
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.custom_minimum_size = Vector2(0, 36)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.pressed.connect(_on_skill_slot_pressed.bind(i))
		slot_btn.name = "SkillSlot%d" % i
		_skill_slots_box.add_child(slot_btn)
		_skill_slots.append(slot_btn)

	# Accessory slots container
	_accessory_slots_box = VBoxContainer.new()
	_accessory_slots_box.name = "AccSlotsBox"
	_accessory_slots_box.add_theme_constant_override("separation", 4)
	_accessory_slots_box.visible = false
	left_panel.add_child(_accessory_slots_box)

	_accessory_slots.clear()
	for i in range(MAX_ACCESSORIES):
		var slot_btn := Button.new()
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.custom_minimum_size = Vector2(0, 36)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.pressed.connect(_on_accessory_slot_pressed.bind(i))
		slot_btn.name = "AccSlot%d" % i
		_accessory_slots_box.add_child(slot_btn)
		_accessory_slots.append(slot_btn)

	# Detail label at bottom of left panel
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.scroll_active = false
	_detail_label.custom_minimum_size.y = 60.0
	_detail_label.name = "DetailLabel"
	left_panel.add_child(_detail_label)

	# Right: picker
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.5
	right_panel.add_theme_constant_override("separation", 6)
	content.add_child(right_panel)

	var picker_title := Label.new()
	picker_title.text = "可配置項目"
	picker_title.add_theme_font_size_override("font_size", ThemeConstantsClass.FONT_SIZE_NORMAL)
	picker_title.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
	right_panel.add_child(picker_title)

	# Skill picker
	_skill_picker_scroll = ScrollContainer.new()
	_skill_picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skill_picker_scroll.name = "SkillPickerScroll"
	right_panel.add_child(_skill_picker_scroll)

	_skill_picker_container = VBoxContainer.new()
	_skill_picker_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_picker_container.add_theme_constant_override("separation", 2)
	_skill_picker_container.name = "SkillPickerList"
	_skill_picker_scroll.add_child(_skill_picker_container)

	# Accessory picker (hidden by default)
	_accessory_picker_scroll = ScrollContainer.new()
	_accessory_picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_accessory_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_accessory_picker_scroll.visible = false
	_accessory_picker_scroll.name = "AccPickerScroll"
	right_panel.add_child(_accessory_picker_scroll)

	_accessory_picker_container = VBoxContainer.new()
	_accessory_picker_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accessory_picker_container.add_theme_constant_override("separation", 2)
	_accessory_picker_container.name = "AccPickerList"
	_accessory_picker_scroll.add_child(_accessory_picker_container)


func _refresh() -> void:
	if PlayerManager.player_data == null:
		return

	# Update tab labels
	var skill_tab_btn: Button = _tab_buttons.get("skills")
	var acc_tab_btn: Button = _tab_buttons.get("accessories")
	if skill_tab_btn:
		skill_tab_btn.text = "主動技能 (%d/%d)" % [_count_active_skills(), MAX_ACTIVE_SKILLS]
	if acc_tab_btn:
		acc_tab_btn.text = "飾品 (%d/%d)" % [_count_active_accessories(), MAX_ACCESSORIES]

	# Update tab disabled states
	for key in _tab_buttons:
		var btn: Button = _tab_buttons[key]
		if btn:
			btn.disabled = (key == _current_tab)

	# Toggle visibility
	if _slot_title_label:
		_slot_title_label.text = "主動技能欄位" if _current_tab == "skills" else "飾品欄位"

	if _current_tab == "skills":
		if _skill_slots_box:
			_skill_slots_box.visible = true
		if _accessory_slots_box:
			_accessory_slots_box.visible = false
		_skill_picker_scroll.visible = true
		_accessory_picker_scroll.visible = false
		_refresh_skill_slots()
		_refresh_skill_picker()
	else:
		if _skill_slots_box:
			_skill_slots_box.visible = false
		if _accessory_slots_box:
			_accessory_slots_box.visible = true
		_skill_picker_scroll.visible = false
		_accessory_picker_scroll.visible = true
		_refresh_accessory_slots()
		_refresh_accessory_picker()

	_refresh_detail()


func _refresh_skill_slots() -> void:
	var pd = PlayerManager.player_data
	if pd == null:
		return

	for i in range(MAX_ACTIVE_SKILLS):
		var btn: Button = _skill_slots[i]
		var skill_id: String = _get_active_skill_at(i)
		if skill_id.is_empty():
			btn.text = "  技能 %d: (空)" % (i + 1)
			btn.remove_theme_color_override("font_color")
		else:
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = String(skill_data.get("name", skill_id))
			var element: String = String(skill_data.get("element", "none"))
			btn.text = "  技能 %d: %s" % [i + 1, skill_name]
			btn.add_theme_color_override("font_color", ThemeConstantsClass.get_element_color(element))

		var style := StyleBoxFlat.new()
		style.bg_color = ThemeConstantsClass.ACCENT.darkened(0.6) if i == _selected_skill_slot else ThemeConstantsClass.BG_MID
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		style.content_margin_left = 8.0
		style.content_margin_top = 4.0
		style.content_margin_right = 8.0
		style.content_margin_bottom = 4.0
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = ThemeConstantsClass.ACCENT if i == _selected_skill_slot else ThemeConstantsClass.BG_DARK
		btn.add_theme_stylebox_override("normal", style)


func _refresh_accessory_slots() -> void:
	var pd = PlayerManager.player_data
	if pd == null:
		return

	for i in range(MAX_ACCESSORIES):
		var btn: Button = _accessory_slots[i]
		var acc_id: String = _get_accessory_at(i)
		if acc_id.is_empty():
			btn.text = "  飾品 %d: (空)" % (i + 1)
			btn.remove_theme_color_override("font_color")
		else:
			var item_data: Dictionary = DataManager.get_item(acc_id)
			var item_name: String = String(item_data.get("name", acc_id))
			var rarity: String = String(item_data.get("rarity", "N"))
			var enhance: int = _get_accessory_enhance_at(i)
			var enhance_text: String = " +%d" % enhance if enhance > 0 else ""
			btn.text = "  飾品 %d: %s%s" % [i + 1, item_name, enhance_text]
			btn.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))

		var style := StyleBoxFlat.new()
		style.bg_color = ThemeConstantsClass.ACCENT.darkened(0.6) if i == _selected_accessory_slot else ThemeConstantsClass.BG_MID
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		style.content_margin_left = 8.0
		style.content_margin_top = 4.0
		style.content_margin_right = 8.0
		style.content_margin_bottom = 4.0
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = ThemeConstantsClass.ACCENT if i == _selected_accessory_slot else ThemeConstantsClass.BG_DARK
		btn.add_theme_stylebox_override("normal", style)


func _refresh_skill_picker() -> void:
	for child in _skill_picker_container.get_children():
		child.queue_free()

	var pd = PlayerManager.player_data
	if pd == null:
		return

	var learned_skills: Array = pd.learned_skill_ids
	if learned_skills.is_empty():
		var label := Label.new()
		label.text = "（尚未習得技能）"
		label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_skill_picker_container.add_child(label)
		return

	# "Clear slot" option at top
	if _selected_skill_slot >= 0:
		var clear_btn := Button.new()
		clear_btn.text = "— 卸下此技能 —"
		clear_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		clear_btn.custom_minimum_size.y = 32.0
		clear_btn.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		clear_btn.pressed.connect(_on_clear_skill_slot.bind(_selected_skill_slot))
		_skill_picker_container.add_child(clear_btn)

	for raw_skill_id in learned_skills:
		var skill_id: String = String(raw_skill_id)
		if skill_id.is_empty():
			continue
		var skill_data: Dictionary = DataManager.get_skill(skill_id)
		if skill_data.is_empty():
			continue

		var skill_name: String = String(skill_data.get("name", skill_id))
		var element: String = String(skill_data.get("element", "none"))
		var is_active: bool = _is_skill_in_active_slots(skill_id)

		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 34.0
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.text = "%s%s" % ["[E] " if is_active else "", skill_name]
		row.add_theme_color_override("font_color", ThemeConstantsClass.get_element_color(element))

		var row_style := ThemeConstantsClass.create_list_item_bg(_skill_picker_container.get_child_count())
		if is_active:
			row_style.bg_color = row_style.bg_color.darkened(0.3)
		row.add_theme_stylebox_override("normal", row_style)

		if _selected_skill_slot >= 0:
			var bound_id: String = skill_id
			row.pressed.connect(_on_skill_selected.bind(bound_id, _selected_skill_slot))
		else:
			row.disabled = true

		_skill_picker_container.add_child(row)


func _refresh_accessory_picker() -> void:
	for child in _accessory_picker_container.get_children():
		child.queue_free()

	if PlayerManager.inventory == null:
		return

	# "Clear slot" option at top
	if _selected_accessory_slot >= 0:
		var clear_btn := Button.new()
		clear_btn.text = "— 卸下此飾品 —"
		clear_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		clear_btn.custom_minimum_size.y = 32.0
		clear_btn.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		clear_btn.pressed.connect(_on_clear_accessory_slot.bind(_selected_accessory_slot))
		_accessory_picker_container.add_child(clear_btn)

	var equipment_list: Array[Dictionary] = PlayerManager.inventory.get_equipment_list()
	var shown_count: int = 0
	for entry in equipment_list:
		var item_id: String = String(entry.get("id", ""))
		if item_id.is_empty():
			continue
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_type: String = String(item_data.get("type", ""))
		if item_type != "accessory":
			continue

		var item_name: String = String(item_data.get("name", item_id))
		var rarity: String = String(item_data.get("rarity", "N"))
		var enhance: int = int(entry.get("enhance", 0))
		var enhance_text: String = " +%d" % enhance if enhance > 0 else ""
		var is_equipped: bool = _is_accessory_in_active_slots(item_id)

		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 34.0
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.text = "%s[%s] %s%s" % ["[E] " if is_equipped else "", rarity, item_name, enhance_text]
		row.add_theme_color_override("font_color", ThemeConstantsClass.get_rarity_border(rarity))

		var row_style := ThemeConstantsClass.create_list_item_bg(shown_count)
		if is_equipped:
			row_style.bg_color = row_style.bg_color.darkened(0.3)
		row.add_theme_stylebox_override("normal", row_style)

		if _selected_accessory_slot >= 0:
			var equip_idx: int = int(entry.get("index", -1))
			row.pressed.connect(_on_accessory_selected.bind(item_id, equip_idx, enhance, _selected_accessory_slot))
		else:
			row.disabled = true

		_accessory_picker_container.add_child(row)
		shown_count += 1

	if shown_count == 0 and _selected_accessory_slot < 0:
		var label := Label.new()
		label.text = "（沒有可裝備的飾品）"
		label.add_theme_color_override("font_color", ThemeConstantsClass.TEXT_SECONDARY)
		_accessory_picker_container.add_child(label)


func _refresh_detail() -> void:
	if _detail_label == null:
		return
	_detail_label.clear()

	if _current_tab == "skills" and _selected_skill_slot >= 0:
		var skill_id: String = _get_active_skill_at(_selected_skill_slot)
		if not skill_id.is_empty():
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var desc: String = String(skill_data.get("description", ""))
			var mp_cost: int = int(skill_data.get("mp_cost", 0))
			_detail_label.append_text("[color=#%s]%s[/color]  MP: %d\n%s" % [
				ThemeConstantsClass.get_element_color(String(skill_data.get("element", "none"))).to_html(false),
				String(skill_data.get("name", skill_id)),
				mp_cost,
				desc,
			])
		else:
			_detail_label.push_color(ThemeConstantsClass.TEXT_SECONDARY)
			_detail_label.append_text("選擇右側技能以配置到此欄位")
			_detail_label.pop()
	elif _current_tab == "accessories" and _selected_accessory_slot >= 0:
		var acc_id: String = _get_accessory_at(_selected_accessory_slot)
		if not acc_id.is_empty():
			var item_data: Dictionary = DataManager.get_item(acc_id)
			var desc: String = String(item_data.get("description", ""))
			var stats: Dictionary = Dictionary(item_data.get("stats", {}))
			var stat_parts: Array[String] = []
			for key in stats:
				stat_parts.append("%s+%d" % [String(key).to_upper(), int(stats[key])])
			_detail_label.append_text("[color=#%s]%s[/color]  %s\n%s" % [
				ThemeConstantsClass.get_rarity_border(String(item_data.get("rarity", "N"))).to_html(false),
				String(item_data.get("name", acc_id)),
				" ".join(stat_parts),
				desc,
			])
		else:
			_detail_label.push_color(ThemeConstantsClass.TEXT_SECONDARY)
			_detail_label.append_text("選擇右側飾品以裝備到此欄位")
			_detail_label.pop()
	else:
		_detail_label.push_color(ThemeConstantsClass.TEXT_SECONDARY)
		_detail_label.append_text("點擊左側欄位以選擇配置目標")
		_detail_label.pop()


func _on_tab_pressed(tab: String) -> void:
	_current_tab = tab
	_selected_skill_slot = -1
	_selected_accessory_slot = -1
	_refresh()


func _on_skill_slot_pressed(slot: int) -> void:
	if _selected_skill_slot == slot:
		_selected_skill_slot = -1
	else:
		_selected_skill_slot = slot
	_refresh()


func _on_accessory_slot_pressed(slot: int) -> void:
	if _selected_accessory_slot == slot:
		_selected_accessory_slot = -1
	else:
		_selected_accessory_slot = slot
	_refresh()


func _on_skill_selected(skill_id: String, slot: int) -> void:
	# Remove skill from any other active slot first
	var pd = PlayerManager.player_data
	if pd == null:
		return
	for i in range(pd.active_skill_ids.size()):
		if String(pd.active_skill_ids[i]) == skill_id and i != slot:
			pd.active_skill_ids[i] = ""

	PlayerManager.equip_active_skill(skill_id, slot)
	_selected_skill_slot = -1
	loadout_changed.emit()
	_refresh()


func _on_clear_skill_slot(slot: int) -> void:
	var pd = PlayerManager.player_data
	if pd == null:
		return
	if slot < pd.active_skill_ids.size():
		pd.active_skill_ids[slot] = ""
	_selected_skill_slot = -1
	loadout_changed.emit()
	_refresh()


func _on_accessory_selected(item_id: String, equipment_index: int, enhance: int, target_slot: int) -> void:
	# If already equipped in another slot, swap them
	var pd = PlayerManager.player_data
	if pd == null:
		return

	var old_id: String = PlayerManager.equip_accessory(item_id, target_slot, enhance)

	# Remove from inventory
	if equipment_index >= 0 and PlayerManager.inventory != null:
		PlayerManager.inventory.remove_equipment_at(equipment_index)
		PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	# Put old item back into inventory
	if not old_id.is_empty():
		var old_enhance: int = PlayerManager.get_last_unequip_enhance()
		PlayerManager.inventory.add_equipment(old_id, old_enhance)
		PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	_selected_accessory_slot = -1
	loadout_changed.emit()
	_refresh()


func _on_clear_accessory_slot(slot: int) -> void:
	var pd = PlayerManager.player_data
	if pd == null:
		return
	if slot < pd.accessory_ids.size():
		var old_id: String = String(pd.accessory_ids[slot])
		if not old_id.is_empty():
			var old_enhance: int = 0
			if slot < pd.accessory_enhances.size():
				old_enhance = int(pd.accessory_enhances[slot])
			PlayerManager.equip_accessory("", slot)
			if PlayerManager.inventory != null:
				PlayerManager.inventory.add_equipment(old_id, old_enhance)
				PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	_selected_accessory_slot = -1
	loadout_changed.emit()
	_refresh()


func _get_active_skill_at(slot: int) -> String:
	var pd = PlayerManager.player_data
	if pd == null or slot >= pd.active_skill_ids.size():
		return ""
	return String(pd.active_skill_ids[slot])


func _get_accessory_at(slot: int) -> String:
	var pd = PlayerManager.player_data
	if pd == null or slot >= pd.accessory_ids.size():
		return ""
	return String(pd.accessory_ids[slot])


func _get_accessory_enhance_at(slot: int) -> int:
	var pd = PlayerManager.player_data
	if pd == null or slot >= pd.accessory_enhances.size():
		return 0
	return int(pd.accessory_enhances[slot])


func _is_skill_in_active_slots(skill_id: String) -> bool:
	var pd = PlayerManager.player_data
	if pd == null:
		return false
	for raw_id in pd.active_skill_ids:
		if String(raw_id) == skill_id:
			return true
	return false


func _is_accessory_in_active_slots(item_id: String) -> bool:
	var pd = PlayerManager.player_data
	if pd == null:
		return false
	for raw_id in pd.accessory_ids:
		if String(raw_id) == item_id:
			return true
	return false


func _count_active_skills() -> int:
	var pd = PlayerManager.player_data
	if pd == null:
		return 0
	var count := 0
	for raw_id in pd.active_skill_ids:
		if not String(raw_id).is_empty():
			count += 1
	return count


func _count_active_accessories() -> int:
	var pd = PlayerManager.player_data
	if pd == null:
		return 0
	var count := 0
	for raw_id in pd.accessory_ids:
		if not String(raw_id).is_empty():
			count += 1
	return count
