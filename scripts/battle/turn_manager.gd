class_name TurnManager
extends RefCounted


signal turn_order_determined(order: Array)
signal combatant_turn_started(combatant)
signal combatant_turn_ended(combatant)
signal all_actions_resolved
signal victory_detected
signal defeat_detected

var _battle_manager: BattleManager

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
	if _battle_manager != null:
		_battle_manager.set_turn_order_snapshot(_turn_order)
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
		if actor.team == CombatantData.Team.PLAYER:
			_add_log_entries(PassiveProcessor.on_turn_start(actor))
			_add_log_entries(AccessoryProcessor.on_turn_start(actor, _battle_manager.familiar))
			_update_display_for(actor)
			if _battle_manager.familiar != null:
				_update_display_for(_battle_manager.familiar)

		var all_allies: Array = _get_friendly_targets_for(actor)
		var all_enemies: Array = _get_hostile_targets_for(actor)
		var status_check: Dictionary = StatusProcessor.check_before_action(actor, all_allies, all_enemies)
		_add_log_entries(Array(status_check.get("logs", [])))

		if not bool(status_check.get("can_act", true)):
			combatant_turn_ended.emit(actor)
			await _battle_manager.delay(0.3)
			continue

		var redirect_target = status_check.get("redirect_target", null)

		match actor.team:
			CombatantData.Team.PLAYER:
				if redirect_target != null:
					_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
					await _resolve_action(actor, {"type": "skill", "skill_id": "", "target": redirect_target})
				else:
					await _execute_player_turn(actor)
			CombatantData.Team.FAMILIAR:
				_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
				if redirect_target != null:
					await _resolve_action(actor, {"type": "skill", "skill_id": "", "target": redirect_target})
				else:
					await _execute_familiar_turn(actor)
			CombatantData.Team.ENEMY:
				_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
				if redirect_target != null:
					await _resolve_action(actor, {"type": "skill", "skill_id": "", "target": redirect_target})
				else:
					await _execute_enemy_turn(actor)

		combatant_turn_ended.emit(actor)

		if _battle_manager.battle_state == _battle_manager.BattleState.FLEEING:
			return

		if await _check_battle_end():
			return

		if _has_remaining_actors_after(index):
			await _battle_manager.delay(0.6)

	await _end_of_turn_phase()
	if await _check_battle_end():
		return
	all_actions_resolved.emit()


func _execute_player_turn(actor) -> void:
	_battle_manager._change_state(_battle_manager.BattleState.PLAYER_TURN)
	_battle_manager.battle_ui.show_waiting_indicator(actor.display_name)
	await _battle_manager.delay(0.3)
	_battle_manager.battle_ui.set_player_input_enabled(true)

	player_action.clear()
	while player_action.is_empty():
		await _battle_manager.get_tree().process_frame

	var action: Dictionary = player_action.duplicate()
	player_action.clear()

	_battle_manager.battle_ui.set_player_input_enabled(false)
	_battle_manager._change_state(_battle_manager.BattleState.EXECUTING)
	await _resolve_action(actor, action)


func _execute_familiar_turn(actor) -> void:
	if not actor.is_alive:
		return

	_battle_manager.battle_ui.add_log("輪到 %s 行動。" % actor.display_name, Color.CYAN)
	await _battle_manager.delay(0.3)
	var action: Dictionary = _get_familiar_action(actor)
	await _resolve_action(actor, action)


func _execute_enemy_turn(actor) -> void:
	if not actor.is_alive:
		return

	_battle_manager.battle_ui.add_log(
		"輪到 %s 行動。" % actor.display_name,
		ThemeConstants.get_element_color(actor.element)
	)
	await _battle_manager.delay(0.3)
	var action: Dictionary = _get_enemy_action(actor)
	await _resolve_action(actor, action)


func _resolve_action(actor, action: Dictionary) -> void:
	var action_type: String = String(action.get("type", ""))
	_pending_actions.append(action.duplicate())

	if action_type.is_empty():
		_battle_manager.action_executed.emit({
			"actor": actor,
			"type": action_type,
			"target": action.get("target", null),
			"result": "skipped",
		})
		return

	match action_type:
		"skill":
			await _resolve_skill_action(actor, action)
		"item":
			await _resolve_item_action(actor, action)
		"flee":
			await _resolve_flee_action(actor)
		"defend":
			await _resolve_defend_action(actor)
		_:
			_battle_manager.battle_ui.add_log("%s 的行動沒有被處理。" % actor.display_name)

	_battle_manager.action_executed.emit({
		"actor": actor,
		"type": action_type,
		"target": action.get("target", null),
		"result": "resolved",
	})


func _resolve_skill_action(actor, action: Dictionary) -> void:
	var skill_id: String = String(action.get("skill_id", ""))
	var target = action.get("target", null)
	if target == null:
		target = actor

	var target_groups: Dictionary = _get_target_groups_for(actor)
	var all_enemies: Array = Array(target_groups.get("enemies", []))
	var all_allies: Array = Array(target_groups.get("allies", []))
	var exec_result: Dictionary = SkillExecutor.execute_skill(
		actor,
		skill_id,
		target,
		all_enemies,
		all_allies,
		_battle_manager.environment_element
	)
	var skill_name: String = String(exec_result.get("skill_name", "普通攻擊"))
	var skill_element: String = String(exec_result.get("skill_element", "none"))

	if not bool(exec_result.get("success", false)):
		match String(exec_result.get("fail_reason", "")):
			"no_mp":
				_battle_manager.battle_ui.add_log("%s 的 MP 不足。" % actor.display_name)
			"no_pp":
				_battle_manager.battle_ui.add_log("%s 的 %s 次數不足。" % [actor.display_name, skill_name])
			"on_cooldown":
				_battle_manager.battle_ui.add_log("%s 的 %s 還在冷卻中。" % [actor.display_name, skill_name])
			"sealed":
				_battle_manager.battle_ui.add_log("%s 因封印無法使用 %s。" % [actor.display_name, skill_name])
			_:
				_battle_manager.battle_ui.add_log("%s 無法使用 %s。" % [actor.display_name, skill_name])
		_update_display_for(actor)
		await _battle_manager.delay(0.3)
		return

	_battle_manager.battle_ui.add_element_log("%s 使用了 %s！" % [actor.display_name, skill_name], skill_element)
	await _battle_manager.delay(0.4)

	var results: Array = Array(exec_result.get("results", []))
	for result in results:
		if result is not Dictionary:
			continue

		var result_dict: Dictionary = result
		match String(result_dict.get("effect_type", "")):
			"damage":
				await _handle_damage_result(actor, result_dict, skill_name, skill_element, skill_id)
			"heal":
				await _handle_heal_result(actor, result_dict, skill_name, skill_element)
			"status":
				await _handle_status_result(actor, result_dict, skill_name, skill_element)
			"buff":
				await _handle_buff_result(actor, result_dict, skill_name, skill_element)
			"shield":
				await _handle_shield_result(actor, result_dict, skill_name, skill_element)

	if actor.team == CombatantData.Team.PLAYER and not skill_id.is_empty():
		var killed_any := false
		for result in results:
			if result is Dictionary and bool(Dictionary(result).get("killed", false)):
				killed_any = true
				break
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var gain: int = rng.randi_range(1, 3) + (1 if killed_any else 0)
		PlayerManager.add_skill_proficiency(skill_id, gain)
		PlayerManager.record_skill_element_usage(skill_element)

	_update_display_for(actor)


func _resolve_item_action(actor, _action: Dictionary) -> void:
	_battle_manager.battle_ui.add_log("%s 想使用道具，但功能尚未完成。" % actor.display_name)
	await _battle_manager.delay(0.3)


func _resolve_flee_action(actor) -> void:
	if _battle_manager.is_boss_battle:
		_battle_manager.battle_ui.add_log("Boss 戰中無法逃跑！")
		await _battle_manager.delay(0.5)
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
		_battle_manager.battle_ui.add_log("成功逃離戰鬥！")
		await _battle_manager.delay(0.5)
		await _battle_manager.end_battle("flee")
	else:
		_battle_manager.battle_ui.add_log("逃跑失敗！")
		await _battle_manager.delay(0.5)


func _resolve_defend_action(actor) -> void:
	actor.battle_buffs.append({
		"stat": "defending",
		"value": 1,
		"turns": 1,
		"source": "defend_action",
	})
	_battle_manager.battle_ui.add_log("%s 採取防禦姿態。" % actor.display_name)
	await _battle_manager.delay(0.3)


func _get_enemy_action(actor) -> Dictionary:
	var hostile: Array = _get_hostile_targets_for(actor)
	var friendly: Array = _get_friendly_targets_for(actor)
	if hostile.is_empty():
		return {}
	return BattleAI.decide_enemy_action(actor, hostile, friendly)


func _get_familiar_action(actor) -> Dictionary:
	match actor.familiar_mode:
		CombatantData.FamiliarMode.DEFEND:
			return {"type": "defend"}
		CombatantData.FamiliarMode.STANDBY:
			_battle_manager.battle_ui.add_log("%s 正在待命。" % actor.display_name)
			return {}
		_:
			var hostile: Array = _get_hostile_targets_for(actor)
			var friendly: Array = _get_friendly_targets_for(actor)
			if hostile.is_empty() and actor.familiar_mode == CombatantData.FamiliarMode.ATTACK:
				return {}
			return BattleAI.decide_familiar_action(actor, hostile, friendly)


func _check_battle_end() -> bool:
	if _battle_manager.battle_state == _battle_manager.BattleState.FLEEING:
		return true

	var alive_enemies: Array = _battle_manager.get_alive_enemies()
	if alive_enemies.is_empty():
		victory_detected.emit()
		_battle_manager.battle_ui.add_log("戰鬥勝利！", Color.GOLD)
		await _battle_manager.end_battle("victory")
		return true

	if _battle_manager.player != null and not _battle_manager.player.is_alive:
		defeat_detected.emit()
		_battle_manager.battle_ui.add_log("戰鬥失敗...", Color.RED)
		await _battle_manager.end_battle("defeat")
		return true

	return false


func _end_of_turn_phase() -> void:
	for combatant in _battle_manager.all_combatants:
		if not combatant.is_alive:
			continue

		var status_results: Array = StatusProcessor.process_end_of_turn(combatant)
		for raw_result in status_results:
			await _handle_status_tick_result(raw_result)

		if not combatant.is_alive:
			continue

		SkillExecutor.tick_cooldowns(combatant)

		var expired: Array[int] = []
		for index in range(combatant.battle_buffs.size()):
			combatant.battle_buffs[index]["turns"] = int(combatant.battle_buffs[index].get("turns", 0)) - 1
			if int(combatant.battle_buffs[index].get("turns", 0)) <= 0:
				expired.append(index)

		expired.reverse()
		for index in expired:
			combatant.battle_buffs.remove_at(index)

	_pending_actions.clear()


func _handle_damage_result(actor, result: Dictionary, skill_name: String, element: String, skill_id: String = "") -> void:
	var target = result.get("target", null)
	if target == null:
		return

	var extra_logs: Array = Array(result.get("extra_logs", []))
	_add_log_entries(extra_logs)

	if not bool(result.get("is_hit", false)) and not extra_logs.is_empty():
		await _battle_manager.delay(0.35)
		return

	if not bool(result.get("is_hit", false)):
		_battle_manager.battle_ui.add_log("%s 使用 %s 但沒有命中 %s！" % [
			actor.display_name,
			skill_name,
			target.display_name,
		])
		await _battle_manager.delay(0.35)
		return

	var dealt_damage: int = int(result.get("damage", 0))
	var shield_absorbed: int = int(result.get("shield_absorbed", 0))
	if shield_absorbed > 0:
		dealt_damage = max(dealt_damage - shield_absorbed, 0)

	var element_multiplier: float = float(result.get("element_multiplier", 1.0))
	var damage_type: String = String(result.get("damage_type", "magic"))
	var attacker_status_changed := false

	if actor.team == CombatantData.Team.PLAYER and target.team != CombatantData.Team.PLAYER:
		var passive_result: Dictionary = PassiveProcessor.on_deal_damage(
			actor,
			target,
			dealt_damage,
			element,
			element_multiplier
		)
		_add_log_entries(Array(passive_result.get("logs", [])))

		var bonus_damage: int = max(int(passive_result.get("bonus_damage", 0)), 0)
		if bonus_damage > 0:
			dealt_damage += bonus_damage
			target.current_hp = clampi(target.current_hp - bonus_damage, 0, target.max_hp)
			if target.current_hp <= 0:
				target.is_alive = false

		var heal_actor: int = max(int(passive_result.get("heal_actor", 0)), 0)
		if heal_actor > 0:
			actor.current_hp = clampi(actor.current_hp + heal_actor, 0, actor.max_hp)

		var accessory_result: Dictionary = AccessoryProcessor.on_deal_damage(
			actor,
			target,
			dealt_damage,
			element,
			element_multiplier,
			damage_type
		)
		_add_log_entries(Array(accessory_result.get("logs", [])))

		var accessory_bonus_damage: int = max(int(accessory_result.get("bonus_damage", 0)), 0)
		if accessory_bonus_damage > 0:
			dealt_damage += accessory_bonus_damage
			target.current_hp = clampi(target.current_hp - accessory_bonus_damage, 0, target.max_hp)
			if target.current_hp <= 0:
				target.is_alive = false

		var accessory_heal_actor: int = max(int(accessory_result.get("heal_actor", 0)), 0)
		if accessory_heal_actor > 0:
			actor.current_hp = clampi(actor.current_hp + accessory_heal_actor, 0, actor.max_hp)

		for raw_status in Array(accessory_result.get("apply_status", [])):
			if raw_status is not Dictionary:
				continue
			var status_entry: Dictionary = Dictionary(raw_status)
			var status_target = status_entry.get("target", target)
			if _apply_status_to_combatant(status_target, status_entry) and status_target != null:
				_update_display_for(status_target)

	if target.team == CombatantData.Team.PLAYER and actor.team != CombatantData.Team.PLAYER:
		var receive_result: Dictionary = PassiveProcessor.on_receive_damage(
			actor,
			target,
			dealt_damage,
			element,
			damage_type
		)
		for raw_status in Array(receive_result.get("counter_status", [])):
			if raw_status is not Dictionary:
				continue
			if _apply_status_to_combatant(actor, Dictionary(raw_status)):
				attacker_status_changed = true
		_add_log_entries(Array(receive_result.get("logs", [])))

		var accessory_receive_result: Dictionary = AccessoryProcessor.on_receive_damage(
			actor,
			target,
			dealt_damage,
			element,
			damage_type
		)
		for raw_status in Array(accessory_receive_result.get("counter_status", [])):
			if raw_status is not Dictionary:
				continue
			if _apply_status_to_combatant(actor, Dictionary(raw_status)):
				attacker_status_changed = true
		_add_log_entries(Array(accessory_receive_result.get("logs", [])))

		if int(accessory_receive_result.get("revive_hp", 0)) > 0:
			result["killed"] = false

	if attacker_status_changed:
		_update_display_for(actor)

	var is_crit: bool = bool(result.get("is_crit", false))
	var log_text: String = "%s 使用 %s 對 %s 造成 %d 點傷害" % [
		actor.display_name,
		skill_name,
		target.display_name,
		dealt_damage,
	]
	if is_crit:
		log_text += "，爆擊！"

	if shield_absorbed > 0:
		log_text += "（護盾吸收 %d）" % shield_absorbed

	var effectiveness: String = String(result.get("effectiveness_text", ""))
	if not effectiveness.is_empty():
		log_text += " " + effectiveness

	result["damage"] = dealt_damage + shield_absorbed
	result["killed"] = target.current_hp <= 0
	target.is_alive = not bool(result.get("killed", false))

	_battle_manager.battle_ui.add_element_log(log_text, element)
	_battle_manager.damage_dealt.emit(target, dealt_damage + shield_absorbed, element, is_crit)
	_battle_manager.combatant_hp_changed.emit(target)
	_update_display_for(target)

	if bool(result.get("is_hit", false)) and not skill_id.is_empty():
		if target.team == CombatantData.Team.PLAYER and actor.team == CombatantData.Team.ENEMY:
			_battle_manager.record_enemy_skill_hit(skill_id)

	await _battle_manager.delay(0.35)

	if bool(result.get("killed", false)):
		_battle_manager.combatant_defeated.emit(target)
		_battle_manager.battle_ui.add_log("%s 被擊敗了！" % target.display_name)
		await _battle_manager.delay(0.5)


func _apply_counter_status(attacker, status_result: Dictionary) -> void:
	_apply_status_to_combatant(attacker, status_result)


func _apply_status_to_combatant(combatant, status_result: Dictionary) -> bool:
	if combatant == null or not combatant.is_alive:
		return false

	var status_id: String = String(status_result.get("status_id", status_result.get("status", ""))).strip_edges()
	if status_id.is_empty():
		return false

	var duration: int = max(int(status_result.get("duration", 0)), 0)
	if duration <= 0:
		return false

	for existing in combatant.status_effects:
		if String(existing.get("id", "")) == status_id:
			existing["turns"] = max(int(existing.get("turns", 0)), duration)
			return true

	combatant.status_effects.append({
		"id": status_id,
		"turns": duration,
	})
	return true


func _handle_heal_result(actor, result: Dictionary, skill_name: String, element: String) -> void:
	var target = result.get("target", null)
	if target == null:
		return

	var heal: int = int(result.get("heal_amount", 0))
	if bool(result.get("cursed", false)) or heal < 0:
		var reversed_damage: int = abs(heal)
		_battle_manager.battle_ui.add_element_log(
			"%s 使用 %s，但 %s 因詛咒效果反而受到了 %d 點傷害。" % [
				actor.display_name,
				skill_name,
				target.display_name,
				reversed_damage,
			],
			element
		)
		_battle_manager.combatant_hp_changed.emit(target)
		_update_display_for(target)
		await _battle_manager.delay(0.35)
		if bool(result.get("killed", false)):
			_battle_manager.combatant_defeated.emit(target)
			_battle_manager.battle_ui.add_log("%s 倒下了！" % target.display_name)
			await _battle_manager.delay(0.5)
		return

	_battle_manager.battle_ui.add_element_log(
		"%s 使用 %s，讓 %s 回復 %d HP。" % [actor.display_name, skill_name, target.display_name, heal],
		element
	)
	_battle_manager.combatant_hp_changed.emit(target)
	_update_display_for(target)
	await _battle_manager.delay(0.35)


func _handle_status_result(actor, result: Dictionary, _skill_name: String, element: String) -> void:
	var target = result.get("target", null)
	if target == null:
		return

	var status_id: String = String(result.get("status_id", ""))
	if bool(result.get("applied", false)):
		_battle_manager.battle_ui.add_element_log(
			"%s 對 %s 施加了 %s。" % [actor.display_name, target.display_name, _get_status_display_name(status_id)],
			element
		)
	_update_display_for(target)
	await _battle_manager.delay(0.35)


func _handle_buff_result(actor, result: Dictionary, skill_name: String, element: String) -> void:
	var target = result.get("target", null)
	if target == null:
		return

	var stat: String = String(result.get("stat", ""))
	var value: int = int(result.get("value", 0))
	var verb: String = "提升" if value > 0 else "降低"
	_battle_manager.battle_ui.add_element_log(
		"%s 使用 %s，讓 %s 的%s%s。" % [
			actor.display_name,
			skill_name,
			target.display_name,
			_get_stat_display_name(stat),
			verb,
		],
		element
	)
	_update_display_for(target)
	await _battle_manager.delay(0.35)


func _handle_shield_result(actor, result: Dictionary, skill_name: String, element: String) -> void:
	var target = result.get("target", null)
	if target == null:
		return

	var shield_val: int = int(result.get("shield_value", 0))
	_battle_manager.battle_ui.add_element_log(
		"%s 使用 %s，為 %s 賦予 %d 點護盾。" % [
			actor.display_name,
			skill_name,
			target.display_name,
			shield_val,
		],
		element
	)
	_update_display_for(target)
	await _battle_manager.delay(0.35)


func _handle_status_tick_result(result: Dictionary) -> void:
	var combatant = result.get("combatant", null)
	if combatant == null:
		return

	var status_id: String = String(result.get("status_id", ""))
	var value: int = int(result.get("value", 0))
	var result_type: String = String(result.get("type", ""))
	var did_show_result := false

	match result_type:
		"dot_damage":
			did_show_result = true
			_battle_manager.battle_ui.add_log(
				"%s 因 %s 受到 %d 點傷害。" % [
					combatant.display_name,
					_get_status_display_name(status_id),
					value,
				],
				_get_status_color(status_id)
			)
			_battle_manager.combatant_hp_changed.emit(combatant)
			_update_display_for(combatant)
			if bool(result.get("killed", false)):
				_battle_manager.combatant_defeated.emit(combatant)
				_battle_manager.battle_ui.add_log("%s 因 %s 而倒下。" % [
					combatant.display_name,
					_get_status_display_name(status_id),
				])
		"regen":
			did_show_result = true
			_battle_manager.battle_ui.add_log(
				"%s 的再生效果回復了 %d HP。" % [combatant.display_name, value],
				Color("#44CC44")
			)
			_battle_manager.combatant_hp_changed.emit(combatant)
			_update_display_for(combatant)
		"mp_regen":
			did_show_result = true
			_battle_manager.battle_ui.add_log(
				"%s 的魔力回復了 %d MP。" % [combatant.display_name, value],
				Color("#1E90FF")
			)
			_update_display_for(combatant)
		"status_expired":
			did_show_result = true
			_battle_manager.battle_ui.add_log(
				"%s 的 %s 效果消失了。" % [combatant.display_name, _get_status_display_name(status_id)],
				Color("#D3D3D3")
			)
			_update_display_for(combatant)
		"seal_released":
			did_show_result = true
			_battle_manager.battle_ui.add_log(
				"%s 的封印解除。" % combatant.display_name,
				Color("#D3D3D3")
			)
			_update_display_for(combatant)

	if did_show_result:
		await _battle_manager.delay(0.25)


func _get_target_groups_for(actor) -> Dictionary:
	return {
		"enemies": _get_hostile_targets_for(actor),
		"allies": _get_friendly_targets_for(actor),
	}


func _get_hostile_targets_for(actor) -> Array:
	var targets: Array = []
	for combatant in _battle_manager.all_combatants:
		if combatant == null or not combatant.is_alive:
			continue
		if actor.team == CombatantData.Team.ENEMY:
			if combatant.team != CombatantData.Team.ENEMY:
				targets.append(combatant)
		elif combatant.team == CombatantData.Team.ENEMY:
			targets.append(combatant)

	return targets


func _get_friendly_targets_for(actor) -> Array:
	var targets: Array = []
	for combatant in _battle_manager.all_combatants:
		if combatant == null or not combatant.is_alive:
			continue
		if actor.team == CombatantData.Team.ENEMY:
			if combatant.team == CombatantData.Team.ENEMY:
				targets.append(combatant)
		elif combatant.team != CombatantData.Team.ENEMY:
			targets.append(combatant)

	return targets


func _update_display_for(combatant) -> void:
	if combatant.team == CombatantData.Team.PLAYER:
		_battle_manager.battle_ui._update_player_display()
	elif combatant.team == CombatantData.Team.FAMILIAR:
		_battle_manager.battle_ui._update_familiar_display()
	else:
		_battle_manager.battle_ui.update_enemy_display(combatant)


func _add_log_entries(entries: Array) -> void:
	for raw_log_entry in entries:
		if raw_log_entry is not Dictionary:
			continue
		var log_entry: Dictionary = raw_log_entry
		_battle_manager.battle_ui.add_log(
			String(log_entry.get("text", "")),
			log_entry.get("color", Color.WHITE)
		)


func _has_remaining_actors_after(index: int) -> bool:
	for next_index in range(index + 1, _turn_order.size()):
		var combatant = _turn_order[next_index]
		if combatant != null and combatant.is_alive:
			return true
	return false


static func _get_status_display_name(status_id: String) -> String:
	var names: Dictionary = {
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
	return String(names.get(status_id, status_id))


static func _get_status_color(status_id: String) -> Color:
	var colors: Dictionary = {
		"burn": Color("#FF4500"),
		"poison": Color("#9370DB"),
		"heavy_poison": Color("#9400D3"),
		"freeze": Color("#00FFFF"),
		"paralyze": Color("#FFD700"),
		"sleep": Color("#9370DB"),
		"confuse": Color("#FFA500"),
		"charm": Color("#FF69B4"),
	}
	return colors.get(status_id, Color.WHITE)


static func _get_stat_display_name(stat: String) -> String:
	var names: Dictionary = {
		"matk": "魔法攻擊",
		"mdef": "魔法防禦",
		"patk": "物理攻擊",
		"pdef": "物理防禦",
		"speed": "速度",
		"hit": "命中",
		"crit": "暴擊",
	}
	return String(names.get(stat, stat))


static func _compare_speed(a, b) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	return randf() > 0.5
