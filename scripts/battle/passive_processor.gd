class_name PassiveProcessor
extends RefCounted

const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")


static func _get_passive_ids() -> Array[String]:
	var result: Array[String] = []
	if PlayerManager.player_data == null:
		return result

	for raw_id in Array(PlayerManager.player_data.passive_skill_ids):
		var passive_id: String = String(raw_id).strip_edges()
		if passive_id.is_empty():
			continue
		var skill_data: Dictionary = DataManager.get_skill(passive_id)
		if skill_data.is_empty():
			continue
		if String(skill_data.get("type", "")) != "passive":
			continue
		result.append(passive_id)

	return result


static func _get_passive_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for passive_id in _get_passive_ids():
		var skill_data: Dictionary = DataManager.get_skill(passive_id)
		if skill_data.is_empty():
			continue

		var passive_name: String = String(skill_data.get("name", passive_id))
		for raw_effect in Array(skill_data.get("passive_effects", [])):
			if raw_effect is not Dictionary:
				continue
			var effect: Dictionary = Dictionary(raw_effect).duplicate(true)
			effect["skill_id"] = passive_id
			effect["skill_name"] = passive_name
			result.append(effect)

	return result


static func on_battle_start(player, familiar) -> Array[Dictionary]:
	var logs: Array[Dictionary] = []
	var cooldown_reduction: int = 0
	var stat_bonus_by_name: Dictionary = {}

	for effect in _get_passive_effects():
		if not _effect_matches(effect, "on_battle_start", {}):
			continue

		match String(effect.get("effect", "")):
			"cooldown_reduction":
				var value: int = max(int(effect.get("value", 0)), 0)
				if value <= 0:
					continue
				cooldown_reduction += value
				_add_log(logs, "%s activated. Cooldown -%d." % [String(effect.get("skill_name", "Passive")), value], Color("#FFD966"))
			"familiar_stat_bonus":
				if familiar == null:
					continue
				var stat: String = String(effect.get("stat", "")).strip_edges()
				var percent: int = max(int(effect.get("value_percent", effect.get("value", 0))), 0)
				if stat.is_empty() or percent <= 0:
					continue
				stat_bonus_by_name[stat] = int(stat_bonus_by_name.get(stat, 0)) + percent
			_:
				continue

	if cooldown_reduction > 0:
		if player != null:
			player.cooldown_reduction = max(int(player.cooldown_reduction), 0) + cooldown_reduction
		if familiar != null:
			familiar.cooldown_reduction = max(int(familiar.cooldown_reduction), 0) + cooldown_reduction

	for stat in stat_bonus_by_name.keys():
		var bonus_percent: int = max(int(stat_bonus_by_name.get(stat, 0)), 0)
		if bonus_percent <= 0 or familiar == null:
			continue
		var base_value: float = float(familiar.get(stat, 0))
		var bonus_value: int = max(0, int(base_value * float(bonus_percent) / 100.0))
		if bonus_value <= 0:
			continue
		familiar.battle_buffs.append({
			"stat": stat,
			"value": bonus_value,
			"turns": 9999,
			"source": "passive_familiar_resonance",
		})
		_add_log(logs, "%s activated. Familiar %s +%d%%." % [String(DataManager.get_skill("passive_familiar_resonance").get("name", "Familiar Resonance")), _get_stat_display_name(stat), bonus_percent], Color("#7CFFB2"))

	return logs


static func on_turn_start(actor) -> Array[Dictionary]:
	var logs: Array[Dictionary] = []
	if actor == null or int(actor.team) != CombatantDataClass.Team.PLAYER:
		return logs

	var total_percent: int = 0
	for effect in _get_passive_effects():
		if not _effect_matches(effect, "on_turn_start", {}):
			continue
		if String(effect.get("effect", "")) != "mp_regen_percent":
			continue

		total_percent += max(int(effect.get("value", 0)), 0)

	if total_percent <= 0:
		return logs

	var mp_regen: int = max(1, int(float(actor.max_mp) * float(total_percent) / 100.0))
	var old_mp: int = int(actor.current_mp)
	actor.current_mp = clampi(actor.current_mp + mp_regen, 0, actor.max_mp)
	mp_regen = actor.current_mp - old_mp
	if mp_regen > 0:
		_add_log(logs, "Mana Spring restored %d MP." % mp_regen, Color("#66B3FF"))

	return logs


static func on_deal_damage(actor, target, damage: int, skill_element: String, element_multiplier: float) -> Dictionary:
	var logs: Array[Dictionary] = []
	var result: Dictionary = {
		"bonus_damage": 0,
		"heal_actor": 0,
		"logs": logs,
	}

	if actor == null or target == null:
		return result
	if int(actor.team) != CombatantDataClass.Team.PLAYER:
		return result
	if int(target.team) == CombatantDataClass.Team.PLAYER:
		return result

	var bonus_percent: int = 0
	var lifesteal_percent: int = 0

	for effect in _get_passive_effects():
		if not _effect_matches(effect, "on_deal_damage", {
			"skill_element": skill_element,
			"element_multiplier": element_multiplier,
			"damage": damage,
		}):
			continue

		match String(effect.get("effect", "")):
			"damage_bonus_percent":
				var value: int = max(int(effect.get("value", 0)), 0)
				if value <= 0:
					continue
				bonus_percent += value
				_add_log(logs, "%s activated. Damage +%d%%." % [String(effect.get("skill_name", "Passive")), value], Color("#FFB347"))
			"lifesteal_percent":
				var life_value: int = max(int(effect.get("value", 0)), 0)
				if life_value <= 0:
					continue
				lifesteal_percent += life_value
				_add_log(logs, "%s activated. Lifesteal %d%%." % [String(effect.get("skill_name", "Passive")), life_value], Color("#FF7A7A"))

	var bonus_damage: int = max(0, int(float(damage) * float(bonus_percent) / 100.0))
	var total_damage: int = max(damage + bonus_damage, 0)
	var heal_actor: int = max(0, int(float(total_damage) * float(lifesteal_percent) / 100.0))

	result["bonus_damage"] = bonus_damage
	result["heal_actor"] = min(heal_actor, total_damage)
	return result


static func on_receive_damage(attacker, target, damage: int, skill_element: String, damage_type: String) -> Dictionary:
	var logs: Array[Dictionary] = []
	var counter_status: Array[Dictionary] = []
	var result: Dictionary = {
		"counter_status": counter_status,
		"logs": logs,
	}

	if attacker == null or target == null:
		return result
	if not attacker.is_alive:
		return result
	if int(target.team) != CombatantDataClass.Team.PLAYER:
		return result
	if int(attacker.team) == CombatantDataClass.Team.PLAYER:
		return result

	var total_chance: int = 0
	var max_duration: int = 0

	for effect in _get_passive_effects():
		if not _effect_matches(effect, "on_receive_damage", {
			"skill_element": skill_element,
			"damage_type": damage_type,
			"damage": damage,
		}):
			continue
		if String(effect.get("effect", "")) != "counter_status":
			continue

		var status_id: String = String(effect.get("status", "")).strip_edges()
		var chance: int = max(int(effect.get("chance", 0)), 0)
		var duration: int = max(int(effect.get("duration", 0)), 0)
		if status_id.is_empty() or chance <= 0 or duration <= 0:
			continue

		total_chance += chance
		max_duration = max(max_duration, duration)

	if total_chance <= 0 or max_duration <= 0:
		return result

	if randf() * 100.0 >= float(total_chance):
		return result

	counter_status.append({
		"status_id": "freeze",
		"duration": max_duration,
	})
	_add_log(logs, "%s activated. Attacker frozen." % String(DataManager.get_skill("passive_frost_body").get("name", "Frost Body")), Color("#7CEEFF"))

	return result


static func on_battle_reward(rewards: Dictionary) -> void:
	if rewards.is_empty():
		return

	var total_bonus: int = 0
	for effect in _get_passive_effects():
		if not _effect_matches(effect, "on_battle_reward", {"rewards": rewards}):
			continue
		if String(effect.get("effect", "")) != "drop_rate_bonus":
			continue
		total_bonus += max(int(effect.get("value", 0)), 0)

	if total_bonus <= 0:
		return

	rewards["drop_rate_bonus"] = int(rewards.get("drop_rate_bonus", 0)) + total_bonus


static func _effect_matches(effect: Dictionary, trigger: String, context: Dictionary) -> bool:
	if String(effect.get("trigger", "")) != trigger:
		return false
	return _condition_matches(effect.get("condition", ""), context)


static func _condition_matches(condition, context: Dictionary) -> bool:
	if condition == null:
		return true

	var condition_text: String = String(condition).strip_edges()
	if condition_text.is_empty():
		return true

	for raw_part in condition_text.split("&&"):
		var part: String = String(raw_part).strip_edges()
		if part.is_empty():
			continue
		if not _atomic_condition_matches(part, context):
			return false

	return true


static func _atomic_condition_matches(condition_text: String, context: Dictionary) -> bool:
	var operators: Array[String] = [">=", "<=", "==", "!=", ">", "<"]
	for op in operators:
		var idx: int = condition_text.find(op)
		if idx < 0:
			continue

		var left_key: String = condition_text.substr(0, idx).strip_edges()
		var right_text: String = condition_text.substr(idx + op.length(), condition_text.length() - idx - op.length()).strip_edges()
		if left_key.is_empty() or not context.has(left_key):
			return false

		var left_value = context.get(left_key)
		var right_value = _coerce_condition_value(right_text, left_value)
		if op == "==":
			return _values_equal(left_value, right_value)
		if op == "!=":
			return not _values_equal(left_value, right_value)

		var left_number: float = float(left_value)
		var right_number: float = float(right_value)
		match op:
			">":
				return left_number > right_number
			">=":
				return left_number >= right_number
			"<":
				return left_number < right_number
			"<=":
				return left_number <= right_number

	return false


static func _coerce_condition_value(raw_text: String, reference) -> Variant:
	var cleaned: String = raw_text.strip_edges()
	if cleaned.begins_with("\"") and cleaned.ends_with("\"") and cleaned.length() >= 2:
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	elif cleaned.begins_with("'") and cleaned.ends_with("'") and cleaned.length() >= 2:
		cleaned = cleaned.substr(1, cleaned.length() - 2)

	match typeof(reference):
		TYPE_BOOL:
			var bool_lower: String = cleaned.to_lower()
			return bool_lower == "true" or bool_lower == "1" or bool_lower == "yes"
		TYPE_INT:
			return int(cleaned)
		TYPE_FLOAT:
			return float(cleaned)
		_:
			if cleaned.is_valid_int():
				return int(cleaned)
			if cleaned.is_valid_float():
				return float(cleaned)
			var text_lower: String = cleaned.to_lower()
			if text_lower == "true":
				return true
			if text_lower == "false":
				return false
			return cleaned


static func _values_equal(left_value, right_value) -> bool:
	if typeof(left_value) == TYPE_BOOL or typeof(right_value) == TYPE_BOOL:
		return bool(left_value) == bool(right_value)
	if typeof(left_value) == TYPE_INT or typeof(left_value) == TYPE_FLOAT or typeof(right_value) == TYPE_INT or typeof(right_value) == TYPE_FLOAT:
		return is_equal_approx(float(left_value), float(right_value))
	return String(left_value) == String(right_value)


static func _add_log(logs: Array[Dictionary], text: String, color: Color) -> void:
	logs.append({
		"text": text,
		"color": color,
	})


static func _get_stat_display_name(stat: String) -> String:
	match stat:
		"matk":
			return "MAG"
		"patk":
			return "PHY"
		"mdef":
			return "MDEF"
		"pdef":
			return "PDEF"
		"speed":
			return "SPD"
		_:
			return stat
