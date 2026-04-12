class_name BattleUI
extends Control

const DrawShapeClass = preload("res://scripts/ui/draw_shape.gd")


class _ElementIcon extends Control:
	var _element: String = "none"
	var _icon_size: float = 14.0

	func _init(element: String, icon_size: float = 14.0) -> void:
		_element = element
		_icon_size = icon_size
		custom_minimum_size = Vector2(icon_size + 8.0, icon_size + 4.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		DrawShapeClass.draw_element_icon(self, _element, size / 2.0, _icon_size, ThemeConstants.get_element_color(_element))


class _SkillTypeIcon extends Control:
	var _skill_type: String = ""
	var _icon_size: float = 10.0
	var _color: Color = Color.WHITE

	func _init(skill_type: String, icon_size: float = 10.0, color: Color = Color.WHITE) -> void:
		_skill_type = skill_type
		_icon_size = icon_size
		_color = color
		custom_minimum_size = Vector2(icon_size + 4.0, icon_size + 4.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		DrawShapeClass.draw_skill_type_icon(self, _skill_type, size / 2.0, _icon_size, _color)



@onready var enemy_container: HBoxContainer = $EnemyArea/EnemyContainer
@onready var player_panel: PanelContainer = $AllyArea/PlayerPanel
@onready var familiar_panel_display: PanelContainer = $AllyArea/FamiliarPanel
@onready var action_menu: HBoxContainer = $ActionMenu
@onready var skill_panel: PanelContainer = $SkillPanel
@onready var item_panel: PanelContainer = $ItemPanel
@onready var familiar_cmd_panel: PanelContainer = $FamiliarCmdPanel
@onready var target_selector: Control = $TargetSelector
@onready var turn_order_display: VBoxContainer = $TurnOrderPanel/Padding/TurnOrderContent/TurnOrderDisplay
@onready var battle_log: RichTextLabel = $BattleLogPanel/Padding/BattleLogContent/BattleLog
@onready var skill_preview_title: Label = $SkillPanel/Padding/Content/SkillPreviewPanel/Padding/PreviewContent/PreviewTitle
@onready var skill_preview_desc: RichTextLabel = $SkillPanel/Padding/Content/SkillPreviewPanel/Padding/PreviewContent/PreviewDesc
@onready var skill_preview_hint: Label = $SkillPanel/Padding/Content/SkillPreviewPanel/Padding/PreviewContent/PreviewHint

@onready var player_name_label: Label = $AllyArea/PlayerPanel/Padding/Content/HeaderRow/PlayerName
@onready var player_level_label: Label = $AllyArea/PlayerPanel/Padding/Content/HeaderRow/PlayerLevel
@onready var player_hp_bar: ProgressBar = $AllyArea/PlayerPanel/Padding/Content/PlayerHPBar
@onready var player_hp_label: Label = $AllyArea/PlayerPanel/Padding/Content/PlayerHPLabel
@onready var player_mp_bar: ProgressBar = $AllyArea/PlayerPanel/Padding/Content/PlayerMPBar
@onready var player_mp_label: Label = $AllyArea/PlayerPanel/Padding/Content/PlayerMPLabel

@onready var familiar_name_label: Label = $AllyArea/FamiliarPanel/Padding/Content/HeaderRow/FamiliarName
@onready var familiar_hp_bar: ProgressBar = $AllyArea/FamiliarPanel/Padding/Content/FamiliarHPBar
@onready var familiar_hp_label: Label = $AllyArea/FamiliarPanel/Padding/Content/FamiliarHPLabel
@onready var familiar_mode_label: Label = $AllyArea/FamiliarPanel/Padding/Content/HeaderRow/FamiliarMode

var _battle_manager
var _player
var _familiar
var _enemies: Array = []
var _pending_skill_id: String = ""
var _player_status_container: HFlowContainer
var _familiar_status_container: HFlowContainer


func _ready() -> void:
	# Hide until setup_battle() fills real data — prevents default panel flash
	visible = false
	_battle_manager = get_parent()
	_ensure_status_labels()
	_hide_all_subpanels()
	_style_progress_bars()
	_style_panels()

	$ActionMenu/SkillButton.pressed.connect(_on_skill_button)
	$ActionMenu/ItemButton.pressed.connect(_on_item_button)
	$ActionMenu/FamiliarButton.pressed.connect(_on_familiar_button)
	$ActionMenu/FleeButton.pressed.connect(_on_flee_button)

	$FamiliarCmdPanel/Padding/Content/AttackModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.ATTACK))
	$FamiliarCmdPanel/Padding/Content/DefendModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.DEFEND))
	$FamiliarCmdPanel/Padding/Content/SupportModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.SUPPORT))
	$FamiliarCmdPanel/Padding/Content/StandbyModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.STANDBY))

	$SkillPanel/Padding/Content/SkillListContainer/BackButton.pressed.connect(_show_action_menu)
	$ItemPanel/Padding/Content/BackButton.pressed.connect(_show_action_menu)
	$FamiliarCmdPanel/Padding/Content/BackButton.pressed.connect(_show_action_menu)


func _style_progress_bars() -> void:
	_apply_bar_style(player_hp_bar, ThemeConstants.HP_COLOR, ThemeConstants.HP_BG_COLOR)
	_apply_bar_style(player_mp_bar, ThemeConstants.MP_COLOR, ThemeConstants.MP_BG_COLOR)
	_apply_bar_style(familiar_hp_bar, ThemeConstants.HP_COLOR, ThemeConstants.HP_BG_COLOR)


func _style_panels() -> void:
	var dark_style := StyleBoxFlat.new()
	dark_style.bg_color = ThemeConstants.BG_MID.darkened(0.2)
	dark_style.border_width_left = 2
	dark_style.border_width_top = 2
	dark_style.border_width_right = 2
	dark_style.border_width_bottom = 2
	dark_style.border_color = ThemeConstants.ACCENT.darkened(0.2)
	dark_style.corner_radius_top_left = 8
	dark_style.corner_radius_top_right = 8
	dark_style.corner_radius_bottom_right = 8
	dark_style.corner_radius_bottom_left = 8
	dark_style.shadow_color = Color(0, 0, 0, 0.4)
	dark_style.shadow_size = 4
	dark_style.content_margin_left = 12
	dark_style.content_margin_right = 12
	dark_style.content_margin_top = 12
	dark_style.content_margin_bottom = 12

	var light_style := dark_style.duplicate()
	light_style.bg_color = ThemeConstants.PANEL_BG.darkened(0.1)
	light_style.border_color = ThemeConstants.ACCENT
	light_style.shadow_size = 6

	for panel in [skill_panel, item_panel, familiar_cmd_panel]:
		panel.add_theme_stylebox_override("panel", dark_style)

	var log_panel: PanelContainer = $BattleLogPanel
	if log_panel:
		log_panel.add_theme_stylebox_override("panel", dark_style)
		var scroll: ScrollContainer = log_panel.get_node_or_null("Padding/BattleLogContent/BattleLogScroll")
		if scroll:
			var scroll_style := StyleBoxFlat.new()
			scroll_style.bg_color = ThemeConstants.BG_DARK.darkened(0.3)
			scroll_style.corner_radius_top_left = 4
			scroll_style.corner_radius_top_right = 4
			scroll_style.corner_radius_bottom_right = 4
			scroll_style.corner_radius_bottom_left = 4
			scroll.add_theme_stylebox_override("panel", scroll_style)

	var turn_order_panel: PanelContainer = $TurnOrderPanel
	if turn_order_panel:
		turn_order_panel.add_theme_stylebox_override("panel", light_style)


func _apply_bar_style(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_right = 3
	fill.corner_radius_bottom_left = 3
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_right = 3
	bg.corner_radius_bottom_left = 3
	bar.add_theme_stylebox_override("background", bg)


func setup_battle(player_data, familiar_data, enemy_list: Array) -> void:
	_player = player_data
	_familiar = familiar_data
	_enemies = enemy_list

	battle_log.clear()
	update_turn_order([])
	_update_player_display()
	_update_familiar_display()
	_generate_enemy_panels()
	set_player_input_enabled(false)
	add_log("戰鬥開始！")
	# Now that real data is loaded, make UI visible
	visible = true


func _update_player_display() -> void:
	if _player == null:
		return

	player_name_label.text = _player.display_name
	player_level_label.text = "Lv.%d" % PlayerManager.player_data.level
	player_hp_bar.max_value = _player.max_hp
	player_hp_bar.value = _player.current_hp
	player_hp_label.text = "HP: %d/%d" % [_player.current_hp, _player.max_hp]
	player_mp_bar.max_value = _player.max_mp
	player_mp_bar.value = _player.current_mp
	player_mp_label.text = "MP: %d/%d" % [_player.current_mp, _player.max_mp]
	_set_status_container(_player_status_container, _player)


func _update_familiar_display() -> void:
	if _familiar == null:
		familiar_panel_display.visible = false
		return

	familiar_panel_display.visible = true
	familiar_name_label.text = _familiar.display_name
	familiar_hp_bar.max_value = _familiar.max_hp
	familiar_hp_bar.value = _familiar.current_hp
	familiar_hp_label.text = "HP: %d/%d" % [_familiar.current_hp, _familiar.max_hp]
	var mode_names := ["攻擊模式", "防禦模式", "輔助模式", "待命"]
	familiar_mode_label.text = mode_names[_familiar.familiar_mode]
	_set_status_container(_familiar_status_container, _familiar)


func _generate_enemy_panels() -> void:
	for child in enemy_container.get_children():
		child.queue_free()

	for enemy in _enemies:
		enemy_container.add_child(_create_enemy_panel(enemy))


func _create_enemy_panel(enemy) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var element_color: Color = ThemeConstants.get_element_color(enemy.element)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(ThemeConstants.PANEL_BG.darkened(0.2)).lerp(
		Color(ThemeConstants.ELEMENT_BG_TINT.get(enemy.element, ThemeConstants.ELEMENT_BG_TINT["none"])),
		0.4
	)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = element_color.darkened(0.3)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	vbox.add_child(header_row)

	var elem_icon := _ElementIcon.new(String(enemy.element), 16.0)
	header_row.add_child(elem_icon)

	var name_label := Label.new()
	name_label.text = enemy.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", element_color)
	header_row.add_child(name_label)

	var enemy_data := DataManager.get_enemy(enemy.id)
	var level_label := Label.new()
	level_label.text = "Lv.%d" % int(enemy_data.get("level", 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	level_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(level_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.current_hp
	hp_bar.custom_minimum_size.y = 14
	hp_bar.show_percentage = false
	_apply_bar_style(hp_bar, element_color.darkened(0.15), ThemeConstants.HP_BG_COLOR)
	vbox.add_child(hp_bar)

	var hp_label := Label.new()
	hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	vbox.add_child(hp_label)

	var status_container := HFlowContainer.new()
	status_container.alignment = FlowContainer.ALIGNMENT_CENTER
	status_container.add_theme_constant_override("h_separation", 4)
	status_container.add_theme_constant_override("v_separation", 4)
	vbox.add_child(status_container)

	panel.set_meta("combatant", enemy)
	panel.set_meta("hp_bar", hp_bar)
	panel.set_meta("hp_label", hp_label)
	panel.set_meta("status_container", status_container)
	panel.set_meta("target_connected", false)

	return panel


func update_enemy_display(enemy) -> void:
	for child in enemy_container.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue

		if panel.get_meta("combatant", null) == enemy:
			var hp_bar := panel.get_meta("hp_bar", null) as ProgressBar
			var hp_label := panel.get_meta("hp_label", null) as Label
			var status_container := panel.get_meta("status_container", null) as HFlowContainer
			if hp_bar != null:
				hp_bar.value = enemy.current_hp
			if hp_label != null:
				hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
			if status_container != null:
				_set_status_container(status_container, enemy)
			panel.modulate.a = 0.4 if not enemy.is_alive else 1.0
			break


func refresh_all_displays() -> void:
	_update_player_display()
	_update_familiar_display()
	for enemy in _enemies:
		update_enemy_display(enemy)


func _hide_all_subpanels() -> void:
	skill_panel.visible = false
	item_panel.visible = false
	familiar_cmd_panel.visible = false
	target_selector.visible = false
	_set_enemy_panels_targetable(false)


func _show_action_menu() -> void:
	_hide_all_subpanels()
	action_menu.visible = true
	_pending_skill_id = ""


func _on_skill_button() -> void:
	action_menu.visible = false
	_hide_all_subpanels()
	_populate_skill_list()
	_clear_skill_preview()
	skill_panel.visible = true


func _on_item_button() -> void:
	action_menu.visible = false
	_hide_all_subpanels()
	_populate_item_list()
	item_panel.visible = true


func _on_familiar_button() -> void:
	if _familiar == null:
		add_log("沒有攜帶使魔！")
		return

	action_menu.visible = false
	_hide_all_subpanels()
	familiar_cmd_panel.visible = true


func _on_flee_button() -> void:
	_battle_manager.on_player_flee()


func _on_familiar_mode(mode: int) -> void:
	_battle_manager.on_player_familiar_mode_changed(mode)
	_update_familiar_display()
	_show_action_menu()


func _populate_skill_list() -> void:
	var skill_list: VBoxContainer = $SkillPanel/Padding/Content/SkillListContainer/SkillScroll/SkillList
	for child in skill_list.get_children():
		child.queue_free()

	for skill_id in _player.skill_ids:
		if skill_id.is_empty():
			continue

		var skill_data := DataManager.get_skill(skill_id)
		if skill_data.is_empty():
			continue

		var check: Dictionary = SkillExecutor.can_use_skill(_player, skill_id)
		var remaining_pp := int(_player.skill_pp.get(skill_id, 0))
		var mp_cost := int(skill_data.get("mp_cost", 0))
		var cd: int = int(_player.cooldowns.get(skill_id, 0))
		var skill_element: String = String(skill_data.get("element", "none"))
		var is_usable: bool = bool(check.get("usable", false))
		var base_power: int = int(skill_data.get("base_power", skill_data.get("power", 0)))
		var rarity: String = String(skill_data.get("rarity", "N"))

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		var rarity_bg: Color = ThemeConstants.get_rarity_bg(rarity)
		card_style.bg_color = Color(ThemeConstants.BG_MID).lerp(rarity_bg, 0.3) if is_usable else ThemeConstants.BG_DARK
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.border_width_left = 3
		card_style.border_width_bottom = 1
		card_style.border_width_right = 1
		card_style.border_width_top = 1
		card_style.border_color = ThemeConstants.get_element_color(skill_element).darkened(0.3) if is_usable else Color(0.3, 0.3, 0.3, 0.5)
		card_style.content_margin_left = 8.0
		card_style.content_margin_top = 4.0
		card_style.content_margin_right = 8.0
		card_style.content_margin_bottom = 4.0
		card.add_theme_stylebox_override("panel", card_style)

		var card_hbox := HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 4)
		card.add_child(card_hbox)

		var elem_icon := _ElementIcon.new(skill_element, 14.0)
		card_hbox.add_child(elem_icon)

		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 2)
		card_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_hbox.add_child(card_content)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 6)
		card_content.add_child(top_row)

		var skill_name_label := Label.new()
		skill_name_label.text = String(skill_data.get("name", "???"))
		skill_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_name_label.add_theme_font_size_override("font_size", 15)
		if is_usable:
			skill_name_label.add_theme_color_override("font_color", ThemeConstants.get_element_color(skill_element))
		else:
			skill_name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		top_row.add_child(skill_name_label)

		var skill_type: String = String(skill_data.get("type", ""))
		var type_icon := _SkillTypeIcon.new(skill_type, 10.0, ThemeConstants.TEXT_SECONDARY)
		top_row.add_child(type_icon)

		var type_text: String = _get_skill_type_label(skill_type)
		var type_label := Label.new()
		type_label.text = type_text
		type_label.add_theme_font_size_override("font_size", 12)
		type_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		top_row.add_child(type_label)

		var info_row := HBoxContainer.new()
		info_row.add_theme_constant_override("separation", 12)
		card_content.add_child(info_row)

		var mp_label := Label.new()
		mp_label.text = "MP:%d" % mp_cost
		mp_label.add_theme_font_size_override("font_size", 12)
		mp_label.add_theme_color_override("font_color", ThemeConstants.MP_COLOR if is_usable else ThemeConstants.TEXT_SECONDARY)
		info_row.add_child(mp_label)

		var pp_label := Label.new()
		pp_label.text = "PP:%d" % remaining_pp
		pp_label.add_theme_font_size_override("font_size", 12)
		pp_label.add_theme_color_override("font_color", ThemeConstants.EXP_COLOR if remaining_pp > 0 else Color.RED)
		info_row.add_child(pp_label)

		if cd > 0:
			var cd_label := Label.new()
			cd_label.text = "CD:%d" % cd
			cd_label.add_theme_font_size_override("font_size", 12)
			cd_label.add_theme_color_override("font_color", Color.RED)
			info_row.add_child(cd_label)

		if base_power > 0:
			var power_label := Label.new()
			power_label.text = "POW:%d" % base_power
			power_label.add_theme_font_size_override("font_size", 12)
			power_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
			info_row.add_child(power_label)

		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var captured_id: String = skill_id
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if is_usable:
						_on_skill_chosen(captured_id)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_show_skill_preview(captured_id)
		)
		card.mouse_entered.connect(func(): _show_skill_preview(captured_id))

		skill_list.add_child(card)


func _get_skill_type_label(skill_type: String) -> String:
	var display := DrawShapeClass.get_skill_type_display(skill_type)
	if not display.is_empty():
		return "[%s]" % display
	if skill_type.contains("all"):
		return "[全體]"
	elif skill_type.contains("self"):
		return "[自身]"
	elif skill_type.contains("single"):
		return "[單體]"
	return "[單體]"


func _show_skill_preview(skill_id: String) -> void:
	var skill_data := DataManager.get_skill(skill_id)
	if skill_data.is_empty():
		return

	var skill_name: String = String(skill_data.get("name", "???"))
	var skill_element: String = String(skill_data.get("element", "none"))
	var description: String = String(skill_data.get("description", "無描述"))
	var base_power: int = int(skill_data.get("base_power", skill_data.get("power", 0)))
	var hit_rate: int = int(skill_data.get("hit_rate", 95))
	var skill_type: String = String(skill_data.get("type", ""))

	skill_preview_title.text = skill_name
	skill_preview_title.add_theme_color_override("font_color", ThemeConstants.get_element_color(skill_element))
	skill_preview_hint.visible = false

	skill_preview_desc.clear()
	skill_preview_desc.push_color(ThemeConstants.TEXT_PRIMARY)
	skill_preview_desc.append_text(description)
	skill_preview_desc.pop()
	skill_preview_desc.append_text("\n\n")

	skill_preview_desc.push_color(ThemeConstants.TEXT_SECONDARY)
	var element_names: Dictionary = {
		"fire": "火", "water": "水", "thunder": "雷", "wind": "風",
		"earth": "地", "light": "光", "dark": "暗", "none": "無",
	}
	skill_preview_desc.append_text("屬性: %s\n" % String(element_names.get(skill_element, "無")))
	if base_power > 0:
		skill_preview_desc.append_text("威力: %d\n" % base_power)
	skill_preview_desc.append_text("命中: %d%%\n" % hit_rate)
	skill_preview_desc.pop()

	if base_power > 0 and _player != null and not _enemies.is_empty():
		skill_preview_desc.append_text("\n")
		skill_preview_desc.push_color(ThemeConstants.EXP_COLOR)
		skill_preview_desc.append_text("— 預計傷害 —\n")
		skill_preview_desc.pop()

		var damage_type: String = String(skill_data.get("damage_type", "magic"))
		if damage_type.is_empty() or damage_type == "magic":
			damage_type = "physical" if skill_type.contains("physical") else "magic"

		var atk_stat: float
		if damage_type == "physical":
			atk_stat = DamageCalculator.get_effective_stat(_player, "patk")
		else:
			atk_stat = DamageCalculator.get_effective_stat(_player, "matk")

		for enemy in _enemies:
			if not enemy.is_alive:
				continue
			var def_stat: float
			if damage_type == "physical":
				def_stat = DamageCalculator.get_effective_stat(enemy, "pdef")
			else:
				def_stat = DamageCalculator.get_effective_stat(enemy, "mdef")
			def_stat = max(def_stat, 1.0)

			var est_damage: float = float(base_power) * atk_stat / def_stat
			var elem_multi: float = 1.0
			if damage_type != "physical":
				elem_multi = DamageCalculator.get_element_multiplier(skill_element, String(enemy.element))
				est_damage *= elem_multi
			var low: int = max(1, int(est_damage * 0.85))
			var high: int = max(1, int(est_damage * 1.15))

			var enemy_element_color: Color = ThemeConstants.get_element_color(enemy.element)
			skill_preview_desc.push_color(enemy_element_color)
			skill_preview_desc.append_text("%s: " % enemy.display_name)
			skill_preview_desc.pop()
			skill_preview_desc.push_color(ThemeConstants.TEXT_PRIMARY)
			skill_preview_desc.append_text("%d~%d" % [low, high])
			skill_preview_desc.pop()

			if elem_multi >= 2.0:
				skill_preview_desc.push_color(Color.GREEN)
				skill_preview_desc.append_text(" 效果絕佳！")
				skill_preview_desc.pop()
			elif elem_multi <= 0.5:
				skill_preview_desc.push_color(Color.RED)
				skill_preview_desc.append_text(" 效果不佳...")
				skill_preview_desc.pop()

			skill_preview_desc.append_text("\n")


func _clear_skill_preview() -> void:
	skill_preview_title.text = "技能資訊"
	skill_preview_title.remove_theme_color_override("font_color")
	skill_preview_desc.clear()
	skill_preview_hint.visible = true


func _on_skill_chosen(skill_id: String) -> void:
	var skill_data := DataManager.get_skill(skill_id)
	var skill_type: String = String(skill_data.get("type", "attack_single"))
	var effects: Array = Array(skill_data.get("effects", []))
	var has_single_ally_target := false
	for effect in effects:
		if effect is Dictionary and String(effect.get("target", "")) == "single_ally":
			has_single_ally_target = true
			break

	if skill_type.contains("all") or skill_type.contains("self") or has_single_ally_target:
		var default_target = _enemies[0] if not _enemies.is_empty() else _player
		if skill_type.contains("self") or has_single_ally_target:
			default_target = _player
		_battle_manager.on_player_skill_selected(skill_id, default_target)
		_hide_all_subpanels()
		_show_action_menu()
	elif skill_type.contains("single"):
		_pending_skill_id = skill_id
		_show_target_selector()
	else:
		_pending_skill_id = skill_id
		_show_target_selector()


func _populate_item_list() -> void:
	var item_list: VBoxContainer = $ItemPanel/Padding/Content/ItemList
	for child in item_list.get_children():
		child.queue_free()

	var all_items: Array = PlayerManager.inventory.get_all_items()
	var has_any := false

	for raw_entry in all_items:
		if raw_entry is not Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var entry_id: String = String(entry.get("id", ""))
		if entry_id.is_empty():
			continue

		var item_data: Dictionary = DataManager.get_item(entry_id)
		if item_data.is_empty():
			continue

		var item_type: String = String(item_data.get("type", ""))
		if item_type != "consumable":
			continue

		var usable_in_battle: bool = bool(item_data.get("usable_in_battle", true))
		var quantity: int = int(entry.get("count", 0))

		var item_name: String = String(item_data.get("name", entry_id))
		var effects: Array = Array(item_data.get("effects", []))
		var effect_desc: String = ""
		for raw_effect in effects:
			if raw_effect is not Dictionary:
				continue
			var effect: Dictionary = raw_effect
			var etype: String = String(effect.get("type", ""))
			if not effect_desc.is_empty():
				effect_desc += ", "
			match etype:
				"heal_hp":
					effect_desc += "HP+%d" % int(effect.get("value", 0))
				"heal_mp":
					effect_desc += "MP+%d" % int(effect.get("value", 0))
				"revive":
					effect_desc += "復活%d%%HP" % int(effect.get("hp_percent", 50))
				"cure_status":
					effect_desc += "治療異常"
				"cure_all_status":
					effect_desc += "全狀態治療"
				"buff_stat":
					effect_desc += "%s+%d" % [String(effect.get("stat", "")), int(effect.get("value", 0))]
				_:
					effect_desc += etype

		var is_usable: bool = usable_in_battle and quantity > 0
		has_any = true

		var btn := Button.new()
		btn.text = "%s x%d  (%s)" % [item_name, quantity, effect_desc]
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)

		if is_usable:
			btn.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
			btn.add_theme_color_override("font_hover_color", ThemeConstants.TEXT_PRIMARY)
		else:
			btn.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
			btn.add_theme_color_override("font_hover_color", ThemeConstants.TEXT_SECONDARY)
			btn.disabled = true

		var captured_id: String = entry_id
		btn.pressed.connect(func():
			_battle_manager.on_player_item_selected(captured_id)
			_hide_all_subpanels()
			action_menu.visible = false
		)

		item_list.add_child(btn)

	if not has_any:
		var placeholder := Label.new()
		placeholder.text = "沒有可用的道具"
		placeholder.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
		placeholder.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		item_list.add_child(placeholder)


func _show_target_selector() -> void:
	skill_panel.visible = false
	target_selector.visible = true
	_set_enemy_panels_targetable(true)


func _on_enemy_panel_clicked(event: InputEvent, enemy) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_battle_manager.on_player_skill_selected(_pending_skill_id, enemy)
		_pending_skill_id = ""
		_hide_all_subpanels()
		action_menu.visible = false


func update_turn_order(order: Array) -> void:
	for child in turn_order_display.get_children():
		child.queue_free()

	for combatant in order:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)

		var icon := _ElementIcon.new(String(combatant.element), 12.0)
		entry.add_child(icon)

		var label := Label.new()
		label.text = combatant.display_name
		label.add_theme_font_size_override("font_size", 14)
		if combatant.team == CombatantData.Team.PLAYER:
			label.add_theme_color_override("font_color", Color.WHITE)
		elif combatant.team == CombatantData.Team.FAMILIAR:
			label.add_theme_color_override("font_color", Color.CYAN)
		else:
			label.add_theme_color_override("font_color", ThemeConstants.get_element_color(combatant.element))
		entry.add_child(label)

		turn_order_display.add_child(entry)


func add_log(text: String, color: Color = Color.WHITE) -> void:
	battle_log.push_color(color)
	battle_log.append_text(text + "\n")
	battle_log.pop()


func add_element_log(text: String, element: String) -> void:
	add_log(text, ThemeConstants.get_element_color(element))


func show_waiting_indicator(actor_name: String) -> void:
	add_log("等待 %s 行動..." % actor_name, Color.GRAY)


func show_victory_result(rewards: Dictionary, level_result: Dictionary) -> void:
	add_log("", Color.WHITE)
	add_log("══════ 戰鬥勝利！ ══════", Color.GOLD)
	add_log("獲得 EXP: %d" % int(rewards.get("exp", 0)), Color("#44CC44"))
	add_log("獲得 Gold: %d" % int(rewards.get("gold", 0)), Color.YELLOW)

	var drops: Array = Array(rewards.get("dropped_items", []))
	if not drops.is_empty():
		add_log("--- 掉落物 ---", Color("#AAAAFF"))
		for raw_drop in drops:
			if raw_drop is not Dictionary:
				continue
			var drop: Dictionary = raw_drop
			var item_id: String = String(drop.get("id", ""))
			var item_data: Dictionary = DataManager.get_item(item_id)
			var item_name: String = String(item_data.get("name", item_id))
			add_log("  ★ %s（來自 %s）" % [item_name, String(drop.get("source", ""))], Color("#AAAAFF"))

	var skills: Array = Array(rewards.get("learned_skills", []))
	if not skills.is_empty():
		add_log("--- 技能領悟！ ---", Color("#FF88FF"))
		for raw_skill_id in skills:
			var skill_id: String = String(raw_skill_id)
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = String(skill_data.get("name", skill_id))
			add_log("  ✦ 領悟了 %s！" % skill_name, Color("#FF88FF"))

	if bool(level_result.get("leveled_up", false)):
		add_log("🎉 升級！Lv.%d → Lv.%d" % [
			int(level_result.get("old_level", 1)),
			int(level_result.get("new_level", 1)),
		], Color("#FFD700"))

	add_log("══════════════════════", Color.GOLD)


func show_defeat_result(penalty: Dictionary) -> void:
	add_log("", Color.WHITE)
	add_log("══════ 戰鬥失敗… ══════", Color.RED)
	var gold_lost: int = int(penalty.get("gold_lost", 0))
	if gold_lost > 0:
		add_log("失去 %d 金幣" % gold_lost, Color("#FF6666"))
	add_log("HP/MP 已完全回復", Color("#44CC44"))
	add_log("══════════════════════", Color.RED)

	# Show a centered defeat overlay panel and wait for input or timeout
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.85)
	overlay_style.border_width_left = 3
	overlay_style.border_width_top = 3
	overlay_style.border_width_right = 3
	overlay_style.border_width_bottom = 3
	overlay_style.border_color = Color(0.8, 0.15, 0.15)
	overlay_style.corner_radius_top_left = 12
	overlay_style.corner_radius_top_right = 12
	overlay_style.corner_radius_bottom_right = 12
	overlay_style.corner_radius_bottom_left = 12
	overlay.add_theme_stylebox_override("panel", overlay_style)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	var center_pad := MarginContainer.new()
	center_pad.add_theme_constant_override("margin_left", 40)
	center_pad.add_theme_constant_override("margin_right", 40)
	center_pad.add_theme_constant_override("margin_top", 20)
	center_pad.add_theme_constant_override("margin_bottom", 20)
	center_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_pad)
	center_pad.add_child(center)

	var defeat_label := Label.new()
	defeat_label.text = "戰鬥失敗"
	defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_label.add_theme_font_size_override("font_size", 42)
	defeat_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	center.add_child(defeat_label)

	var sep := HSeparator.new()
	center.add_child(sep)

	if gold_lost > 0:
		var gold_label := Label.new()
		gold_label.text = "失去 %d 金幣" % gold_lost
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_label.add_theme_font_size_override("font_size", 20)
		gold_label.add_theme_color_override("font_color", Color("#FF6666"))
		center.add_child(gold_label)

	var heal_label := Label.new()
	heal_label.text = "HP / MP 已完全回復"
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_label.add_theme_font_size_override("font_size", 20)
	heal_label.add_theme_color_override("font_color", Color("#44CC44"))
	center.add_child(heal_label)

	var return_label := Label.new()
	return_label.text = "即將返回安全區..."
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_label.add_theme_font_size_override("font_size", 18)
	return_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	center.add_child(return_label)

	add_child(overlay)

	# Move overlay to front so it covers everything
	move_child(overlay, get_child_count() - 1)

	# Wait for a click/key press or a 3-second timeout
	var state := { "clicked": false }
	var _on_input := func(_event: InputEvent):
		if (_event is InputEventMouseButton and _event.pressed) or \
		   (_event is InputEventKey and _event.pressed):
			state["clicked"] = true
	overlay.gui_input.connect(_on_input)
	var _elapsed := 0.0
	while _elapsed < 3.0 and not state["clicked"]:
		await get_tree().create_timer(0.05).timeout
		_elapsed += 0.05
	if overlay.gui_input.is_connected(_on_input):
		overlay.gui_input.disconnect(_on_input)

	if is_instance_valid(overlay):
		overlay.queue_free()


func set_player_input_enabled(enabled: bool) -> void:
	action_menu.visible = enabled
	if not enabled:
		_hide_all_subpanels()


func _set_enemy_panels_targetable(enabled: bool) -> void:
	for child in enemy_container.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue

		if enabled:
			var enemy = panel.get_meta("combatant", null)
			if enemy == null or not enemy.is_alive:
				panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				continue

			if not bool(panel.get_meta("target_connected", false)):
				panel.gui_input.connect(_on_enemy_panel_clicked.bind(enemy))
				panel.set_meta("target_connected", true)
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_status_labels() -> void:
	var player_content := $AllyArea/PlayerPanel/Padding/Content as VBoxContainer
	_player_status_container = player_content.get_node_or_null("PlayerStatusContainer") as HFlowContainer
	if _player_status_container == null:
		_player_status_container = HFlowContainer.new()
		_player_status_container.name = "PlayerStatusContainer"
		_player_status_container.alignment = FlowContainer.ALIGNMENT_CENTER
		_player_status_container.add_theme_constant_override("h_separation", 4)
		_player_status_container.add_theme_constant_override("v_separation", 4)
		player_content.add_child(_player_status_container)

	var familiar_content := $AllyArea/FamiliarPanel/Padding/Content as VBoxContainer
	_familiar_status_container = familiar_content.get_node_or_null("FamiliarStatusContainer") as HFlowContainer
	if _familiar_status_container == null:
		_familiar_status_container = HFlowContainer.new()
		_familiar_status_container.name = "FamiliarStatusContainer"
		_familiar_status_container.alignment = FlowContainer.ALIGNMENT_CENTER
		_familiar_status_container.add_theme_constant_override("h_separation", 4)
		_familiar_status_container.add_theme_constant_override("v_separation", 4)
		familiar_content.add_child(_familiar_status_container)

func _set_status_container(container: HFlowContainer, combatant) -> void:
	if container == null or combatant == null:
		return
		
	for child in container.get_children():
		child.queue_free()

	if combatant.status_effects.is_empty():
		container.visible = false
		return
		
	container.visible = true
	for effect in combatant.status_effects:
		var status_id: String = String(effect.get("id", ""))
		var turns: int = int(effect.get("turns", 0))
		var icon := _StatusIcon.new(status_id, turns)
		container.add_child(icon)

class _StatusIcon extends PanelContainer:
	func _init(status_id: String, turns: int):
		var bg := StyleBoxFlat.new()
		bg.bg_color = _get_status_color(status_id)
		bg.corner_radius_top_left = 4
		bg.corner_radius_top_right = 4
		bg.corner_radius_bottom_right = 4
		bg.corner_radius_bottom_left = 4
		bg.content_margin_left = 4
		bg.content_margin_right = 4
		bg.content_margin_top = 2
		bg.content_margin_bottom = 2
		add_theme_stylebox_override("panel", bg)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 2)
		add_child(hbox)
		
		var name_label := Label.new()
		name_label.text = _get_status_short_name(status_id)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(name_label)
		
		if turns > 0:
			var turn_label := Label.new()
			turn_label.text = str(turns)
			turn_label.add_theme_font_size_override("font_size", 11)
			turn_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
			hbox.add_child(turn_label)

	func _get_status_color(id: String) -> Color:
		match id:
			"burn": return Color("#e74c3c")
			"poison", "heavy_poison": return Color("#9b59b6")
			"freeze": return Color("#3498db")
			"paralyze": return Color("#f1c40f")
			"sleep": return Color("#34495e")
			"confuse": return Color("#e67e22")
			"charm": return Color("#ff69b4")
			"atk_down", "def_down", "speed_down", "hit_down": return Color("#c0392b")
			"seal", "curse": return Color("#2c3e50")
			"atk_up", "def_up", "speed_up": return Color("#27ae60")
			"regen", "mp_regen": return Color("#2ecc71")
			"reflect", "stealth": return Color("#95a5a6")
			_: return Color("#7f8c8d")

	func _get_status_short_name(id: String) -> String:
		match id:
			"burn": return "🔥燃燒"
			"poison": return "☠中毒"
			"heavy_poison": return "☠猛毒"
			"freeze": return "❄凍結"
			"paralyze": return "⚡麻痺"
			"sleep": return "💤睡眠"
			"confuse": return "💫混亂"
			"charm": return "💕魅惑"
			"atk_down": return "⬇攻"
			"def_down": return "⬇防"
			"speed_down": return "⬇速"
			"hit_down": return "⬇命"
			"seal": return "🔒封印"
			"curse": return "💀詛咒"
			"atk_up": return "⬆攻"
			"def_up": return "⬆防"
			"speed_up": return "⬆速"
			"regen": return "💚再生"
			"mp_regen": return "💙回魔"
			"reflect": return "🪞反射"
			"stealth": return "👻隱身"
			_: return id
