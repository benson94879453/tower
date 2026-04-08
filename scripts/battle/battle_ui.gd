class_name BattleUI
extends Control


signal skill_selected(skill_id: String)
@warning_ignore("unused_signal")
signal item_selected(item_id: String)
signal familiar_mode_selected(mode: int)
signal flee_pressed
signal target_selected(combatant)
signal back_pressed

@onready var enemy_container: HBoxContainer = $EnemyArea/EnemyContainer
@onready var player_panel: PanelContainer = $AllyArea/PlayerPanel
@onready var familiar_panel_display: PanelContainer = $AllyArea/FamiliarPanel
@onready var action_menu: HBoxContainer = $ActionMenu
@onready var skill_panel: PanelContainer = $SkillPanel
@onready var item_panel: PanelContainer = $ItemPanel
@onready var familiar_cmd_panel: PanelContainer = $FamiliarCmdPanel
@onready var target_selector: Control = $TargetSelector
@onready var turn_order_display: VBoxContainer = $TurnOrderDisplay
@onready var battle_log: RichTextLabel = $BattleLog

@onready var player_name_label: Label = $AllyArea/PlayerPanel/Content/PlayerName
@onready var player_level_label: Label = $AllyArea/PlayerPanel/Content/PlayerLevel
@onready var player_hp_bar: ProgressBar = $AllyArea/PlayerPanel/Content/PlayerHPBar
@onready var player_hp_label: Label = $AllyArea/PlayerPanel/Content/PlayerHPLabel
@onready var player_mp_bar: ProgressBar = $AllyArea/PlayerPanel/Content/PlayerMPBar
@onready var player_mp_label: Label = $AllyArea/PlayerPanel/Content/PlayerMPLabel

@onready var familiar_name_label: Label = $AllyArea/FamiliarPanel/Content/FamiliarName
@onready var familiar_hp_bar: ProgressBar = $AllyArea/FamiliarPanel/Content/FamiliarHPBar
@onready var familiar_hp_label: Label = $AllyArea/FamiliarPanel/Content/FamiliarHPLabel
@onready var familiar_mode_label: Label = $AllyArea/FamiliarPanel/Content/FamiliarMode

const CombatantVisualClass = preload("res://scripts/ui/combatant_visual.gd")

var _battle_manager
var _player
var _familiar
var _enemies: Array = []
var _pending_skill_id: String = ""
var _player_status_label: Label
var _familiar_status_label: Label
var _bar_tweens_enabled := false

var _player_visual: CombatantVisualClass
var _familiar_visual: CombatantVisualClass


func _ready() -> void:
	_battle_manager = get_parent()
	_ensure_status_labels()
	_ensure_visuals()
	_apply_theme_variations()
	_hide_all_subpanels()

	$ActionMenu/SkillButton.pressed.connect(_on_skill_button)
	$ActionMenu/ItemButton.pressed.connect(_on_item_button)
	$ActionMenu/FamiliarButton.pressed.connect(_on_familiar_button)
	$ActionMenu/FleeButton.pressed.connect(_on_flee_button)

	$FamiliarCmdPanel/Content/AttackModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.ATTACK))
	$FamiliarCmdPanel/Content/DefendModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.DEFEND))
	$FamiliarCmdPanel/Content/SupportModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.SUPPORT))
	$FamiliarCmdPanel/Content/StandbyModeBtn.pressed.connect(func(): _on_familiar_mode(CombatantData.FamiliarMode.STANDBY))

	$SkillPanel/Content/BackButton.pressed.connect(_show_action_menu)
	$ItemPanel/Content/BackButton.pressed.connect(_show_action_menu)
	$FamiliarCmdPanel/Content/BackButton.pressed.connect(_show_action_menu)


func _ensure_visuals() -> void:
	var player_content := $AllyArea/PlayerPanel/Content as VBoxContainer
	_player_visual = player_content.get_node_or_null("PlayerVisual") as CombatantVisualClass
	if _player_visual == null:
		_player_visual = CombatantVisualClass.new()
		_player_visual.name = "PlayerVisual"
		_player_visual.custom_minimum_size = Vector2(80, 80)
		_player_visual.is_player = true
		player_content.add_child(_player_visual)
		player_content.move_child(_player_visual, 0)

	var familiar_content := $AllyArea/FamiliarPanel/Content as VBoxContainer
	_familiar_visual = familiar_content.get_node_or_null("FamiliarVisual") as CombatantVisualClass
	if _familiar_visual == null:
		_familiar_visual = CombatantVisualClass.new()
		_familiar_visual.name = "FamiliarVisual"
		_familiar_visual.custom_minimum_size = Vector2(64, 64)
		familiar_content.add_child(_familiar_visual)
		familiar_content.move_child(_familiar_visual, 0)


func _apply_theme_variations() -> void:
	player_panel.theme_type_variation = "CombatantPanel"
	familiar_panel_display.theme_type_variation = "CombatantPanel"
	player_hp_bar.theme_type_variation = "ProgressBarHP"
	player_mp_bar.theme_type_variation = "ProgressBarMP"
	familiar_hp_bar.theme_type_variation = "ProgressBarHP"


func setup_battle(player_data: CombatantData, familiar_data: CombatantData, enemy_list: Array[CombatantData]) -> void:
	_bar_tweens_enabled = false
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
	_bar_tweens_enabled = true


func _tween_bar(bar: ProgressBar, new_value: float, duration: float = 0.4) -> void:
	if bar == null:
		return

	if not _bar_tweens_enabled:
		bar.value = new_value
		return

	var existing_tween = bar.get_meta("_value_tween") if bar.has_meta("_value_tween") else null
	if existing_tween is Tween:
		existing_tween.kill()

	var tween := create_tween()
	bar.set_meta("_value_tween", tween)
	tween.tween_property(bar, "value", new_value, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _show_panel(panel: Control) -> void:
	if panel == null:
		return

	panel.modulate.a = 0.0
	panel.visible = true
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _update_player_display() -> void:
	if _player == null:
		return

	player_name_label.text = _player.display_name
	player_level_label.text = "Lv.%d" % int(PlayerManager.player_data.level if PlayerManager.player_data != null else 1)
	player_hp_bar.max_value = _player.max_hp
	_tween_bar(player_hp_bar, float(_player.current_hp))
	player_hp_label.text = "%d/%d" % [_player.current_hp, _player.max_hp]
	player_mp_bar.max_value = _player.max_mp
	_tween_bar(player_mp_bar, float(_player.current_mp))
	player_mp_label.text = "%d/%d" % [_player.current_mp, _player.max_mp]
	_set_status_label(_player_status_label, _player)
	
	if _player_visual != null:
		_player_visual.element = _player.element


func _update_familiar_display() -> void:
	if _familiar == null:
		familiar_panel_display.visible = false
		return

	familiar_panel_display.visible = true
	familiar_name_label.text = _familiar.display_name
	familiar_hp_bar.max_value = _familiar.max_hp
	_tween_bar(familiar_hp_bar, float(_familiar.current_hp))
	familiar_hp_label.text = "%d/%d" % [_familiar.current_hp, _familiar.max_hp]
	var mode_names := ["攻擊模式", "防禦模式", "支援模式", "待命"]
	familiar_mode_label.text = mode_names[_familiar.familiar_mode]
	_set_status_label(_familiar_status_label, _familiar)
	
	if _familiar_visual != null:
		_familiar_visual.element = _familiar.element
		_familiar_visual.visual = _familiar.visual


func _generate_enemy_panels() -> void:
	for child in enemy_container.get_children():
		child.queue_free()

	for enemy in _enemies:
		enemy_container.add_child(_create_enemy_panel(enemy))


func _create_enemy_panel(enemy: CombatantData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 160)
	panel.theme_type_variation = "EnemyPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var visual := CombatantVisualClass.new()
	visual.name = "Visual"
	visual.custom_minimum_size = Vector2(64, 64)
	visual.element = enemy.element
	visual.visual = enemy.visual
	vbox.add_child(visual)

	var name_label := Label.new()
	name_label.text = enemy.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_NORMAL)
	vbox.add_child(name_label)

	var enemy_data := DataManager.get_enemy(enemy.id)
	var level_label := Label.new()
	level_label.text = "Lv.%d" % int(enemy_data.get("level", 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	level_label.modulate = ThemeConstants.TEXT_SECONDARY
	vbox.add_child(level_label)

	var hp_bar := ProgressBar.new()
	hp_bar.theme_type_variation = "ProgressBarHP"
	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.current_hp
	hp_bar.custom_minimum_size.y = 8
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	var hp_label := Label.new()
	hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	vbox.add_child(hp_label)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = false
	status_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	status_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	vbox.add_child(status_label)

	name_label.add_theme_color_override("font_color", ThemeConstants.get_element_color(enemy.element))

	panel.set_meta("combatant", enemy)
	panel.set_meta("hp_bar", hp_bar)
	panel.set_meta("hp_label", hp_label)
	panel.set_meta("status_label", status_label)
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
			var status_label := panel.get_meta("status_label", null) as Label
			if hp_bar != null:
				_tween_bar(hp_bar, float(enemy.current_hp))
			if hp_label != null:
				hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
			if status_label != null:
				_set_status_label(status_label, enemy)

			var existing_fade_tween = panel.get_meta("_fade_tween") if panel.has_meta("_fade_tween") else null
			if existing_fade_tween is Tween:
				existing_fade_tween.kill()

			if not enemy.is_alive:
				var fade_tween := create_tween()
				panel.set_meta("_fade_tween", fade_tween)
				fade_tween.tween_property(panel, "modulate:a", 0.4, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			else:
				panel.modulate.a = 1.0
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
	_show_panel(action_menu)
	_pending_skill_id = ""
	back_pressed.emit()


func _on_skill_button() -> void:
	action_menu.visible = false
	_hide_all_subpanels()
	_populate_skill_list()
	_show_panel(skill_panel)


func _on_item_button() -> void:
	action_menu.visible = false
	_hide_all_subpanels()
	_populate_item_list()
	_show_panel(item_panel)


func _on_familiar_button() -> void:
	if _familiar == null:
		add_log("目前沒有使魔可以指揮。")
		return

	action_menu.visible = false
	_hide_all_subpanels()
	_show_panel(familiar_cmd_panel)


func _on_flee_button() -> void:
	flee_pressed.emit()
	_battle_manager.on_player_flee()


func _on_familiar_mode(mode: int) -> void:
	familiar_mode_selected.emit(mode)
	_battle_manager.on_player_familiar_mode_changed(mode)
	_update_familiar_display()
	_show_action_menu()


func _populate_skill_list() -> void:
	var skill_list: VBoxContainer = $SkillPanel/Content/SkillList
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

		var button := Button.new()
		var label_text: String = "%s (MP:%d PP:%d)" % [skill_data.get("name", "???"), mp_cost, remaining_pp]
		if cd > 0:
			label_text += " [CD:%d]" % cd
		button.text = label_text
		button.disabled = not bool(check.get("usable", false))
		button.add_theme_color_override("font_color", ThemeConstants.get_element_color(String(skill_data.get("element", "none"))))

		var captured_id: String = skill_id
		button.pressed.connect(func(): _on_skill_chosen(captured_id))
		skill_list.add_child(button)


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
		skill_selected.emit(skill_id)
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
	var item_list: VBoxContainer = $ItemPanel/Content/ItemList
	for child in item_list.get_children():
		child.queue_free()

	var placeholder := Label.new()
	placeholder.text = "道具功能尚未完成。"
	item_list.add_child(placeholder)


func _show_target_selector() -> void:
	skill_panel.visible = false
	target_selector.visible = true
	_set_enemy_panels_targetable(true)


func _on_enemy_panel_clicked(event: InputEvent, enemy) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target_selected.emit(enemy)
		skill_selected.emit(_pending_skill_id)
		_battle_manager.on_player_skill_selected(_pending_skill_id, enemy)
		_pending_skill_id = ""
		_hide_all_subpanels()
		action_menu.visible = false


func update_turn_order(order: Array) -> void:
	for child in turn_order_display.get_children():
		child.queue_free()

	for combatant in order:
		var label := Label.new()
		label.text = combatant.display_name
		if combatant.team == CombatantData.Team.PLAYER:
			label.add_theme_color_override("font_color", Color.WHITE)
		elif combatant.team == CombatantData.Team.FAMILIAR:
			label.add_theme_color_override("font_color", Color.CYAN)
		else:
			label.add_theme_color_override("font_color", ThemeConstants.get_element_color(combatant.element))
		turn_order_display.add_child(label)


func add_log(text: String, color: Color = Color.WHITE) -> void:
	battle_log.push_color(color)
	battle_log.append_text(text + "\n")
	battle_log.pop()


func add_element_log(text: String, element: String) -> void:
	add_log(text, ThemeConstants.get_element_color(element))


func show_waiting_indicator(actor_name: String) -> void:
	add_log("等待 %s 的指令..." % actor_name, Color.GRAY)


func show_victory_result(rewards: Dictionary, level_result: Dictionary) -> void:
	await _battle_manager.delay(0.8)
	add_log("", Color.WHITE)
	add_log("========== 勝利！ ==========", Color.GOLD)
	await _battle_manager.delay(0.6)

	add_log("獲得 EXP: %d" % int(rewards.get("exp", 0)), Color("#44CC44"))
	await _battle_manager.delay(0.3)
	add_log("獲得 Gold: %d" % int(rewards.get("gold", 0)), Color.YELLOW)
	await _battle_manager.delay(0.3)

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
			add_log("  獲得 %s（來源：%s）" % [item_name, String(drop.get("source", ""))], Color("#AAAAFF"))
			await _battle_manager.delay(0.2)

	var skills: Array = Array(rewards.get("learned_skills", []))
	if not skills.is_empty():
		add_log("--- 新技能 ---", Color("#FF88FF"))
		for raw_skill_id in skills:
			var skill_id: String = String(raw_skill_id)
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = String(skill_data.get("name", skill_id))
			add_log("  學會了 %s" % skill_name, Color("#FF88FF"))
			await _battle_manager.delay(0.3)

	if bool(level_result.get("leveled_up", false)):
		add_log("等級提升！Lv.%d -> Lv.%d" % [
			int(level_result.get("old_level", 1)),
			int(level_result.get("new_level", 1)),
		], Color("#FFD700"))
		await _battle_manager.delay(0.6)

	add_log("==========================", Color.GOLD)
	await _battle_manager.delay(1.5)


func show_defeat_result(penalty: Dictionary) -> void:
	await _battle_manager.delay(1.0)
	add_log("", Color.WHITE)
	add_log("========== 戰敗... ==========", Color.RED)
	await _battle_manager.delay(0.6)

	var gold_lost: int = int(penalty.get("gold_lost", 0))
	if gold_lost > 0:
		add_log("損失金幣 %d" % gold_lost, Color("#FF6666"))
		await _battle_manager.delay(0.3)

	add_log("HP / MP 已回復至安全狀態。", Color("#44CC44"))
	await _battle_manager.delay(0.3)
	add_log("============================", Color.RED)
	await _battle_manager.delay(2.0)


func set_player_input_enabled(enabled: bool) -> void:
	if enabled:
		_hide_all_subpanels()
		_show_panel(action_menu)
		return

	action_menu.visible = false
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
	var player_content := $AllyArea/PlayerPanel/Content as VBoxContainer
	_player_status_label = player_content.get_node_or_null("PlayerStatusLabel") as Label
	if _player_status_label == null:
		_player_status_label = Label.new()
		_player_status_label.name = "PlayerStatusLabel"
		_player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_player_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_player_status_label.visible = false
		_player_status_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		player_content.add_child(_player_status_label)

	var familiar_content := $AllyArea/FamiliarPanel/Content as VBoxContainer
	_familiar_status_label = familiar_content.get_node_or_null("FamiliarStatusLabel") as Label
	if _familiar_status_label == null:
		_familiar_status_label = Label.new()
		_familiar_status_label.name = "FamiliarStatusLabel"
		_familiar_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_familiar_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_familiar_status_label.visible = false
		_familiar_status_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		familiar_content.add_child(_familiar_status_label)


func _set_status_label(label: Label, combatant) -> void:
	if label == null or combatant == null:
		return

	var status_text: String = _get_status_text(combatant)
	label.text = status_text
	label.visible = not status_text.is_empty()


func _get_status_text(combatant) -> String:
	if combatant == null or combatant.status_effects.is_empty():
		return ""

	var status_names: Dictionary = {
		"burn": "灼燒",
		"poison": "中毒",
		"heavy_poison": "劇毒",
		"freeze": "冰凍",
		"paralyze": "麻痺",
		"sleep": "睡眠",
		"confuse": "混亂",
		"charm": "魅惑",
		"atk_down": "攻擊下降",
		"def_down": "防禦下降",
		"speed_down": "速度下降",
		"hit_down": "命中下降",
		"seal": "封印",
		"curse": "詛咒",
		"atk_up": "攻擊上升",
		"def_up": "防禦上升",
		"speed_up": "速度上升",
		"regen": "再生",
		"mp_regen": "魔力回復",
		"reflect": "反射",
		"stealth": "隱匿",
	}
	var parts: Array[String] = []
	for effect in combatant.status_effects:
		var status_id: String = String(effect.get("id", ""))
		var turns: int = int(effect.get("turns", 0))
		var status_name: String = String(status_names.get(status_id, status_id))
		if turns > 0:
			parts.append("%s(%d)" % [status_name, turns])
		else:
			parts.append(status_name)

	return " ".join(PackedStringArray(parts))
