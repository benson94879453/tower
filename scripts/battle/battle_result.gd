class_name BattleResult
extends RefCounted



static func calculate_victory_rewards(
	enemies: Array,
	floor_number: int,
	received_skill_ids: Array[String],
	is_boss_battle: bool = false,
	is_elite_battle: bool = false
) -> Dictionary:
	var total_exp: int = 0
	var total_gold: int = 0
	var dropped_items: Array = []
	var learned_skills: Array[String] = []
	var drop_entries: Array[Dictionary] = []

	var enemy_count: int = enemies.size()
	var count_mod: float = 1.0 + float(max(enemy_count - 1, 0)) * 0.1
	var floor_mod: float = 1.0 + float(max(floor_number, 0)) * 0.01

	var raw_exp: int = 0
	for enemy in enemies:
		raw_exp += int(enemy.base_exp)
	total_exp = max(1, int(float(raw_exp) * count_mod * floor_mod))
	var title_bonuses: Dictionary = PlayerManager.get_title_bonuses()
	var exp_bonus_percent: int = int(title_bonuses.get("exp_bonus_percent", 0))
	if exp_bonus_percent != 0:
		total_exp = max(1, int(round(float(total_exp) * (1.0 + float(exp_bonus_percent) / 100.0))))

	for enemy in enemies:
		var base_gold: int = int(enemy.base_gold)
		total_gold += max(1, int(float(base_gold) * randf_range(0.8, 1.2)))

	for enemy in enemies:
		for raw_drop in enemy.drops:
			if raw_drop is not Dictionary:
				continue
			var drop: Dictionary = raw_drop
			var drop_id: String = String(drop.get("id", ""))
			var rate: float = float(drop.get("rate", 0.0))
			if drop_id.begins_with("core_"):
				rate = _get_familiar_core_drop_rate(rate, floor_number, is_boss_battle, is_elite_battle)
			var item_data: Dictionary = DataManager.get_item(drop_id)
			drop_entries.append({
				"id": drop_id,
				"source": enemy.display_name,
				"rate": rate,
				"rarity": String(item_data.get("rarity", "")),
			})

	var already_learned: Array[String] = []
	if PlayerManager.player_data != null:
		already_learned.assign(PlayerManager.player_data.learned_skill_ids.duplicate())

	for skill_id in received_skill_ids:
		if skill_id.is_empty():
			continue
		if already_learned.has(skill_id):
			continue
		if randf() < 0.05:
			learned_skills.append(skill_id)
			already_learned.append(skill_id)

	var familiar_exp: int = max(1, int(float(total_exp) * 0.5))
	var rewards: Dictionary = {
		"exp": total_exp,
		"gold": total_gold,
		"dropped_items": dropped_items,
		"learned_skills": learned_skills,
		"familiar_exp": familiar_exp,
		"level_before": int(PlayerManager.player_data.level) if PlayerManager.player_data != null else 1,
		"drop_entries": drop_entries,
		"drop_rate_bonus": int(title_bonuses.get("drop_rate_bonus", 0)),
	}

	PassiveProcessor.on_battle_reward(rewards)
	AccessoryProcessor.on_battle_reward(rewards)

	var drop_rate_bonus: int = max(int(rewards.get("drop_rate_bonus", 0)), 0)
	for raw_drop in Array(rewards.get("drop_entries", [])):
		if raw_drop is not Dictionary:
			continue
		var drop_entry: Dictionary = raw_drop
		var drop_id: String = String(drop_entry.get("id", ""))
		var rate: float = float(drop_entry.get("rate", 0.0))
		var rarity: String = String(drop_entry.get("rarity", "")).to_upper()
		if drop_rate_bonus > 0 and (rarity != "" and rarity != "N" or drop_id.begins_with("core_")):
			rate = clampf(rate + float(drop_rate_bonus) / 100.0, 0.0, 1.0)
		if randf() < rate:
			dropped_items.append({
				"id": drop_id,
				"source": String(drop_entry.get("source", "")),
			})

	return rewards


static func _get_familiar_core_drop_rate(
	default_rate: float,
	floor_number: int,
	is_boss_battle: bool,
	is_elite_battle: bool
) -> float:
	if is_boss_battle:
		return 1.0 if _is_first_boss_clear(floor_number) else 0.15
	if is_elite_battle:
		return 0.05
	if default_rate > 0.0:
		return default_rate
	return 0.01


static func _is_first_boss_clear(floor_number: int) -> bool:
	if PlayerManager.player_data == null:
		return true
	return not PlayerManager.player_data.defeated_bosses.has(floor_number)


static func apply_victory_rewards(rewards: Dictionary) -> Dictionary:
	var level_before: int = int(rewards.get("level_before", 1))

	PlayerManager.add_exp(int(rewards.get("exp", 0)))
	PlayerManager.add_gold(int(rewards.get("gold", 0)))
	for raw_drop in Array(rewards.get("dropped_items", [])):
		if raw_drop is Dictionary:
			var drop_id: String = String(raw_drop.get("id", ""))
			if not drop_id.is_empty():
				PlayerManager.add_item(drop_id)

	for raw_skill_id in Array(rewards.get("learned_skills", [])):
		PlayerManager.learn_skill(String(raw_skill_id))

	var level_after: int = int(PlayerManager.player_data.level) if PlayerManager.player_data != null else 1
	var leveled_up: bool = level_after > level_before

	return {
		"leveled_up": leveled_up,
		"old_level": level_before,
		"new_level": level_after,
	}


static func calculate_defeat_penalty() -> Dictionary:
	var current_gold: int = int(PlayerManager.player_data.gold) if PlayerManager.player_data != null else 0
	var gold_lost: int = int(float(current_gold) * 0.2)
	return {
		"gold_lost": gold_lost,
	}


static func apply_defeat_penalty(penalty: Dictionary) -> void:
	var gold_lost: int = int(penalty.get("gold_lost", 0))
	if gold_lost > 0:
		PlayerManager.spend_gold(gold_lost)

	if PlayerManager.player_data != null:
		PlayerManager.player_data.current_hp = PlayerManager.get_max_hp()
		PlayerManager.player_data.current_mp = PlayerManager.get_max_mp()
		PlayerManager.player_hp_changed.emit(PlayerManager.player_data.current_hp, PlayerManager.get_max_hp())
		PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())
