class_name TurnManager
extends RefCounted

const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")
const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal turn_order_determined(order: Array)
signal combatant_turn_started(combatant)
signal combatant_turn_ended(combatant)
signal all_actions_resolved
signal victory_detected
signal defeat_detected

var _battle_manager

var _turn_order: Array = []
var _current_actor_index: int = -1
var _pending_actions: Array[Dictionary] = []

var player_action: Dictionary = {}


func determine_turn_order() -> Array:
	var alive: Array = []
	for combatant in _battle_manager.all_combatants:
		if combatant.is_alive:
			alive.append(combatant)

	alive.sort_custom(func(a, b): return _compare_speed(a, b))
	_turn_order = alive
	_battle_manager.turn_order = _turn_order.duplicate()
	turn_order_determined.emit(_turn_order)
	return _turn_order


func execute_turn() -> void:
	determine_turn_order()
	_battle_manager.battle_ui.update_turn_order(_turn_order)

	for index in range(_turn_order.size()):
		_current_actor_index = index
		var actor = _turn_order[index]
		if not actor.is_alive:
			continue

		combatant_turn_started.emit(actor)

		match actor.team:
			CombatantDataClass.Team.PLAYER:
				await _execute_player_turn(actor)
			CombatantDataClass.Team.FAMILIAR:
				_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
				_execute_familiar_turn(actor)
			CombatantDataClass.Team.ENEMY:
				_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
				_execute_enemy_turn(actor)

		combatant_turn_ended.emit(actor)

		if _battle_manager.battle_state == _battle_manager.BattleState.FLEEING:
			return

		if _check_battle_end():
			return

		await _battle_manager.get_tree().process_frame

	_end_of_turn_phase()
	all_actions_resolved.emit()


func _execute_player_turn(actor) -> void:
	_battle_manager._change_state(_battle_manager.BattleState.PLAYER_TURN)
	_battle_manager.battle_ui.set_player_input_enabled(true)
	_battle_manager.battle_ui.show_waiting_indicator(actor.display_name)

	player_action.clear()
	while player_action.is_empty():
		await _battle_manager.get_tree().process_frame

	var action: Dictionary = player_action.duplicate()
	player_action.clear()

	_battle_manager.battle_ui.set_player_input_enabled(false)
	_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
	_resolve_action(actor, action)


func _execute_familiar_turn(actor) -> void:
	if not actor.is_alive:
		return

	_battle_manager.battle_ui.add_log("輪到 %s 行動" % actor.display_name)
	var action: Dictionary = _get_familiar_action(actor)
	_resolve_action(actor, action)


func _execute_enemy_turn(actor) -> void:
	if not actor.is_alive:
		return

	_battle_manager.battle_ui.add_log(
		"輪到 %s 行動" % actor.display_name,
		ThemeConstantsClass.get_element_color(actor.element)
	)
	var action: Dictionary = _get_enemy_action(actor)
	_resolve_action(actor, action)


func _resolve_action(actor, action: Dictionary) -> void:
	var action_type: String = String(action.get("type", ""))
	_pending_actions.append(action.duplicate())

	match action_type:
		"skill":
			_resolve_skill_action(actor, action)
		"item":
			_resolve_item_action(actor, action)
		"flee":
			_resolve_flee_action(actor)
		"defend":
			_resolve_defend_action(actor)
		_:
			_battle_manager.battle_ui.add_log("%s 什麼都沒做" % actor.display_name)

	_battle_manager.action_executed.emit({
		"actor": actor,
		"type": action_type,
		"target": action.get("target", null),
		"result": "resolved",
	})


func _resolve_skill_action(actor, action: Dictionary) -> void:
	var skill_id: String = String(action.get("skill_id", ""))
	var target = action.get("target", null)
	var skill_data: Dictionary = {}
	if not skill_id.is_empty():
		skill_data = DataManager.get_skill(skill_id)

	if target == null:
		target = actor

	var skill_name := "普通攻擊"
	var mp_cost := 0
	var remaining_pp := 0
	var power := 40
	var element := "none"
	var skill_type := "attack_single"
	var effects: Array = []

	if not skill_id.is_empty() and not skill_data.is_empty():
		skill_name = String(skill_data.get("name", "???"))
		mp_cost = int(skill_data.get("mp_cost", 0))
		remaining_pp = int(actor.skill_pp.get(skill_id, 0))
		power = int(skill_data.get("base_power", skill_data.get("power", 50)))
		element = String(skill_data.get("element", "none"))
		skill_type = String(skill_data.get("type", "attack_single"))
		effects = Array(skill_data.get("effects", []))

		if actor.current_mp < mp_cost:
			_battle_manager.battle_ui.add_log("%s MP 不足！" % actor.display_name)
			return
		if remaining_pp <= 0:
			_battle_manager.battle_ui.add_log("%s 已無法使用 %s！" % [actor.display_name, skill_name])
			return

		actor.current_mp -= mp_cost
		actor.skill_pp[skill_id] = remaining_pp - 1

	var handled_effect := false
	for effect in effects:
		if effect is not Dictionary:
			continue
		if String(effect.get("type", "")) != "buff":
			continue

		var buff_target = actor if String(effect.get("target", "self")) == "self" else target
		if buff_target == null:
			continue

		var buff_value := int(effect.get("value", 0))
		var buff_turns := int(effect.get("duration", 1))
		buff_target.battle_buffs.append({
			"stat": String(effect.get("stat", "")),
			"value": buff_value,
			"turns": buff_turns,
			"source": skill_id,
		})
		_battle_manager.battle_ui.add_element_log(
			"%s 使用了 %s，%s 獲得增益效果！" % [actor.display_name, skill_name, buff_target.display_name],
			element
		)
		handled_effect = true
		_update_display_for(buff_target)

	if power > 0 and (target != null or not skill_type.contains("self")):
		var damage := _calc_simple_damage(actor, target, power)
		if _has_defend_buff(target):
			damage = max(1, int(ceil(float(damage) / 2.0)))

		target.current_hp = clampi(target.current_hp - damage, 0, target.max_hp)
		_battle_manager.battle_ui.add_element_log(
			"%s 使用了 %s，對 %s 造成 %d 點傷害！" % [actor.display_name, skill_name, target.display_name, damage],
			element
		)
		_battle_manager.damage_dealt.emit(target, damage, element, false)
		_battle_manager.combatant_hp_changed.emit(target)
		_update_display_for(actor)
		_update_display_for(target)

		if target.current_hp <= 0:
			target.is_alive = false
			_battle_manager.combatant_defeated.emit(target)
			_battle_manager.battle_ui.add_log("%s 被擊倒了！" % target.display_name)
			_update_display_for(target)
		return

	if handled_effect:
		_update_display_for(actor)
		return

	_battle_manager.battle_ui.add_log("%s 使用了 %s，但沒有產生效果" % [actor.display_name, skill_name])
	_update_display_for(actor)


static func _calc_simple_damage(attacker, defender, power: int) -> int:
	var raw := int(float(attacker.matk) * float(power) / 100.0) - int(float(defender.mdef) / 2.0)
	var damage: int = max(1, raw)
	damage = int(float(damage) * randf_range(0.85, 1.15))
	return max(1, damage)


func _resolve_item_action(actor, action: Dictionary) -> void:
	_battle_manager.battle_ui.add_log("%s 使用了道具（尚未實作）" % actor.display_name)


func _resolve_flee_action(actor) -> void:
	if _battle_manager.is_boss_battle:
		_battle_manager.battle_ui.add_log("無法從 Boss 戰逃跑！")
		return

	var flee_chance := 0.4
	var fastest_enemy_speed := 0
	for enemy in _battle_manager.enemies:
		if enemy.is_alive:
			fastest_enemy_speed = max(fastest_enemy_speed, int(enemy.speed))

	if actor.speed > fastest_enemy_speed:
		flee_chance += 0.2
	elif actor.speed < fastest_enemy_speed:
		flee_chance -= 0.1

	if randf() < flee_chance:
		_battle_manager.battle_ui.add_log("成功逃跑！")
		_battle_manager.end_battle("flee")
	else:
		_battle_manager.battle_ui.add_log("逃跑失敗！")


func _resolve_defend_action(actor) -> void:
	actor.battle_buffs.append({
		"stat": "defending",
		"value": 1,
		"turns": 1,
		"source": "defend_action",
	})
	_battle_manager.battle_ui.add_log("%s 選擇防禦" % actor.display_name)


func _get_enemy_action(actor) -> Dictionary:
	var targets: Array = _battle_manager.get_alive_allies()
	if targets.is_empty():
		return {}

	var usable_skills: Array[String] = []
	for skill_id in actor.skill_ids:
		var pp := int(actor.skill_pp.get(skill_id, 0))
		var skill_data := DataManager.get_skill(skill_id)
		var mp_cost := int(skill_data.get("mp_cost", 0))
		if pp > 0 and actor.current_mp >= mp_cost:
			usable_skills.append(skill_id)

	if usable_skills.is_empty():
		var target_index := randi() % targets.size()
		return {"type": "skill", "skill_id": "", "target": targets[target_index]}

	var chosen_skill: String = usable_skills[randi() % usable_skills.size()]
	var chosen_skill_data := DataManager.get_skill(chosen_skill)
	var chosen_type := String(chosen_skill_data.get("type", "attack_single"))
	if chosen_type.contains("self"):
		return {"type": "skill", "skill_id": chosen_skill, "target": actor}

	var target = targets[randi() % targets.size()]
	return {"type": "skill", "skill_id": chosen_skill, "target": target}


func _get_familiar_action(actor) -> Dictionary:
	var targets: Array = []

	match actor.familiar_mode:
		CombatantDataClass.FamiliarMode.ATTACK:
			targets = _battle_manager.get_alive_enemies()
		CombatantDataClass.FamiliarMode.SUPPORT:
			targets = _battle_manager.get_alive_allies()
		CombatantDataClass.FamiliarMode.DEFEND:
			return {"type": "defend"}
		CombatantDataClass.FamiliarMode.STANDBY:
			_battle_manager.battle_ui.add_log("%s 待命中" % actor.display_name)
			return {}

	if targets.is_empty():
		return {}

	var usable_skills: Array[String] = []
	for skill_id in actor.skill_ids:
		var pp := int(actor.skill_pp.get(skill_id, 0))
		var skill_data := DataManager.get_skill(skill_id)
		var mp_cost := int(skill_data.get("mp_cost", 0))
		if pp > 0 and actor.current_mp >= mp_cost:
			usable_skills.append(skill_id)

	if usable_skills.is_empty():
		return {}

	var chosen_skill: String = usable_skills[randi() % usable_skills.size()]
	var chosen_skill_data := DataManager.get_skill(chosen_skill)
	var chosen_type := String(chosen_skill_data.get("type", "attack_single"))
	if chosen_type.contains("self"):
		return {"type": "skill", "skill_id": chosen_skill, "target": actor}

	var target = targets[randi() % targets.size()]
	return {"type": "skill", "skill_id": chosen_skill, "target": target}


func _check_battle_end() -> bool:
	if _battle_manager.battle_state == _battle_manager.BattleState.FLEEING:
		return true

	var alive_enemies: Array = _battle_manager.get_alive_enemies()
	if alive_enemies.is_empty():
		victory_detected.emit()
		_battle_manager.battle_ui.add_log("戰鬥勝利！", Color.GOLD)
		_battle_manager.end_battle("victory")
		return true

	if _battle_manager.player != null and not _battle_manager.player.is_alive:
		defeat_detected.emit()
		_battle_manager.battle_ui.add_log("戰鬥失敗...", Color.RED)
		_battle_manager.end_battle("defeat")
		return true

	return false


func _end_of_turn_phase() -> void:
	for combatant in _battle_manager.all_combatants:
		if not combatant.is_alive:
			continue

		var expired: Array[int] = []
		for index in range(combatant.battle_buffs.size()):
			combatant.battle_buffs[index]["turns"] = int(combatant.battle_buffs[index].get("turns", 0)) - 1
			if int(combatant.battle_buffs[index].get("turns", 0)) <= 0:
				expired.append(index)

		expired.reverse()
		for index in expired:
			combatant.battle_buffs.remove_at(index)

	_pending_actions.clear()


func _update_display_for(combatant) -> void:
	if combatant.team == CombatantDataClass.Team.PLAYER:
		_battle_manager.battle_ui._update_player_display()
	elif combatant.team == CombatantDataClass.Team.FAMILIAR:
		_battle_manager.battle_ui._update_familiar_display()
	else:
		_battle_manager.battle_ui.update_enemy_display(combatant)


func _has_defend_buff(combatant) -> bool:
	for buff in combatant.battle_buffs:
		if String(buff.get("stat", "")) == "defending":
			return true

	return false


static func _compare_speed(a, b) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	return randf() > 0.5
