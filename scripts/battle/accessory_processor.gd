class_name AccessoryProcessor
extends RefCounted

const TURN_ORDER_SPEED_BONUS := 9999

static var _battle_state: Dictionary = {}


static func reset_battle_state() -> void:
	_battle_state = {}


static func _get_accessory_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if PlayerManager.player_data == null:
		return result

	for raw_id in Array(PlayerManager.player_data.accessory_ids):
		var accessory_id: String = String(raw_id).strip_edges()
		if accessory_id.is_empty():
			continue

		var item_data: Dictionary = DataManager.get_item(accessory_id)
		if item_data.is_empty():
			continue
		if String(item_data.get("type", "")) != "accessory":
			continue

		var item_name: String = String(item_data.get("name", accessory_id))
		for raw_effect in Array(item_data.get("passive_effects", [])):
			if raw_effect is not Dictionary:
				continue
			var effect: Dictionary = Dictionary(raw_effect).duplicate(true)
			effect["item_id"] = accessory_id
			effect["item_name"] = item_name
			result.append(effect)

	return result


static func on_battle_start(player, familiar) -> Array[Dictionary]:
	var logs: Array[Dictionary] = []
	var first_turn_source: String = ""

	for effect in _get_accessory_effects():
		if not _effect_matches(effect, "on_battle_start", {}):
			continue

		match String(effect.get("effect", "")):
			"guaranteed_first_turn":
				if player == null or bool(_battle_state.get("time_watch_pending", false)):
					continue
				player.speed += TURN_ORDER_SPEED_BONUS
				_battle_state["time_watch_pending"] = true
				_battle_state["time_watch_bonus"] = TURN_ORDER_SPEED_BONUS
				first_turn_source = String(effect.get("item_name", "Accessory"))
			"familiar_stat_bonus":
				if familiar == null:
					continue
				var stat: String = String(effect.get("stat", "")).strip_edges()
				var bonus_percent: int = max(int(effect.get("value_percent", effect.get("value", 0))), 0)
				if stat.is_empty() or bonus_percent <= 0:
					continue
				var base_value: float = float(familiar.get(stat, 0))
				var bonus_value: int = max(0, int(base_value * float(bonus_percent) / 100.0))
				if bonus_value <= 0:
					continue
				familiar.battle_buffs.append({
					"stat": stat,
					"value": bonus_value,
					"turns": 9999,
					"source": String(effect.get("item_id", "accessory")),
				})
				_add_log(logs, "%s boosted familiar %s by %d%%." % [String(effect.get("item_name", "Accessory")), _get_stat_display_name(stat), bonus_percent], Color("#7CFFB2"))

	if not first_turn_source.is_empty():
		_add_log(logs, "%s activated. Guaranteed first action." % first_turn_source, Color("#FFD966"))

	return logs


static func on_turn_start(actor, familiar) -> Array[Dictionary]:
	var logs: Array[Dictionary] = []
	if actor == null or int(actor.team) != CombatantData.Team.PLAYER:
		return logs

	if bool(_battle_state.get("time_watch_pending", false)):
		var speed_bonus: int = int(_battle_state.get("time_watch_bonus", TURN_ORDER_SPEED_BONUS))
		actor.speed = max(actor.speed - speed_bonus, 0)
		_battle_state["time_watch_pending"] = false
		_battle_state.erase("time_watch_bonus")

	for effect in _get_accessory_effects():
		if not _effect_matches(effect, "on_turn_start", {}):
			continue

		match String(effect.get("effect", "")):
			"mp_regen_percent":
				var mp_percent: int = max(int(effect.get("value", 0)), 0)
				if mp_percent <= 0:
					continue
				var old_mp: int = int(actor.current_mp)
				var mp_gain: int = max(1, int(float(actor.max_mp) * float(mp_percent) / 100.0))
				actor.current_mp = clampi(actor.current_mp + mp_gain, 0, actor.max_mp)
				mp_gain = actor.current_mp - old_mp
				if mp_gain > 0:
					_add_log(logs, "%s restored %d MP." % [String(effect.get("item_name", "Accessory")), mp_gain], Color("#66B3FF"))
			"heal_hp_percent":
				var hp_percent: int = max(int(effect.get("value", 0)), 0)
				if hp_percent <= 0:
					continue
				var old_hp: int = int(actor.current_hp)
				var hp_gain: int = max(1, int(float(actor.max_hp) * float(hp_percent) / 100.0))
				actor.current_hp = clampi(actor.current_hp + hp_gain, 0, actor.max_hp)
				hp_gain = actor.current_hp - old_hp
				if hp_gain > 0:
					_add_log(logs, "%s restored %d HP." % [String(effect.get("item_name", "Accessory")), hp_gain], Color("#44CC44"))
			"heal_hp":
				var flat_heal: int = max(int(effect.get("value", 0)), 0)
				if flat_heal <= 0:
					continue
				var old_flat_hp: int = int(actor.current_hp)
				actor.current_hp = clampi(actor.current_hp + flat_heal, 0, actor.max_hp)
				flat_heal = actor.current_hp - old_flat_hp
				if flat_heal > 0:
					_add_log(logs, "%s restored %d HP." % [String(effect.get("item_name", "Accessory")), flat_heal], Color("#44CC44"))
			"familiar_heal_percent":
				if familiar == null or not familiar.is_alive:
					continue
				var familiar_percent: int = max(int(effect.get("value", 0)), 0)
				if familiar_percent <= 0:
					continue
				var old_familiar_hp: int = int(familiar.current_hp)
				var familiar_gain: int = max(1, int(float(familiar.max_hp) * float(familiar_percent) / 100.0))
				familiar.current_hp = clampi(familiar.current_hp + familiar_gain, 0, familiar.max_hp)
				familiar_gain = familiar.current_hp - old_familiar_hp
				if familiar_gain > 0:
					_add_log(logs, "%s restored %d familiar HP." % [String(effect.get("item_name", "Accessory")), familiar_gain], Color("#7CFFB2"))

	return logs


static func on_deal_damage(actor, target, damage: int, skill_element: String, element_multiplier: float, damage_type: String = "") -> Dictionary:
	var logs: Array[Dictionary] = []
	var apply_status: Array[Dictionary] = []
	var result: Dictionary = {
		"bonus_damage": 0,
		"heal_actor": 0,
		"apply_status": apply_status,
		"logs": logs,
	}

	if actor == null or target == null:
		return result
	if int(actor.team) != CombatantData.Team.PLAYER:
		return result
	if int(target.team) == CombatantData.Team.PLAYER:
		return result

	var bonus_damage: int = 0
	var lifesteal_percent: int = 0

	for effect in _get_accessory_effects():
		if not _effect_matches(effect, "on_deal_damage", {
			"skill_element": skill_element,
			"element_multiplier": element_multiplier,
			"damage_type": damage_type,
			"damage": damage + bonus_damage,
		}):
			continue

		match String(effect.get("effect", "")):
			"apply_status":
				var status_id: String = String(effect.get("status", "")).strip_edges()
				var duration: int = max(int(effect.get("duration", 0)), 0)
				var chance: int = clampi(int(effect.get("chance", 100)), 0, 100)
				if status_id.is_empty() or duration <= 0:
					continue
				if randf() * 100.0 >= float(chance):
					continue
				apply_status.append({
					"target": target,
					"status_id": status_id,
					"duration": duration,
				})
				_add_log(logs, "%s applied %s." % [String(effect.get("item_name", "Accessory")), status_id], Color("#FF8A65"))
			"lifesteal_percent":
				var life_value: int = max(int(effect.get("value", 0)), 0)
				if life_value <= 0:
					continue
				lifesteal_percent += life_value
				_add_log(logs, "%s activated. Lifesteal %d%%." % [String(effect.get("item_name", "Accessory")), life_value], Color("#FF7A7A"))
			"echo_attack":
				if bool(_battle_state.get("echo_active", false)):
					continue
				var echo_chance: int = clampi(int(effect.get("chance", 0)), 0, 100)
				if echo_chance <= 0 or randf() * 100.0 >= float(echo_chance):
					continue
				var damage_percent: int = max(int(effect.get("damage_percent", 0)), 0)
				var echo_bonus: int = max(0, int(float(max(damage + bonus_damage, 0)) * float(damage_percent) / 100.0))
				if echo_bonus <= 0:
					continue
				_battle_state["echo_active"] = true
				bonus_damage += echo_bonus
				_battle_state["echo_active"] = false
				_add_log(logs, "%s echoed the spell for %d bonus damage." % [String(effect.get("item_name", "Accessory")), echo_bonus], Color("#A78BFA"))

	var total_damage: int = max(damage + bonus_damage, 0)
	var heal_actor: int = max(0, int(float(total_damage) * float(lifesteal_percent) / 100.0))

	result["bonus_damage"] = bonus_damage
	result["heal_actor"] = min(heal_actor, total_damage)
	return result


static func on_receive_damage(attacker, target, damage: int, skill_element: String, damage_type: String) -> Dictionary:
	var logs: Array[Dictionary] = []
	var counter_status: Array[Dictionary] = []
	var result: Dictionary = {
		"revive_hp": 0,
		"counter_status": counter_status,
		"logs": logs,
	}

	if attacker == null or target == null:
		return result
	if int(target.team) != CombatantData.Team.PLAYER:
		return result
	if int(attacker.team) == CombatantData.Team.PLAYER:
		return result

	for effect in _get_accessory_effects():
		if not _effect_matches(effect, "on_receive_damage", {
			"skill_element": skill_element,
			"damage_type": damage_type,
			"damage": damage,
		}):
			continue

		match String(effect.get("effect", "")):
			"revive_once":
				if target.current_hp > 0 or bool(_battle_state.get("guardian_angel_used", false)):
					continue
				var hp_percent: int = max(int(effect.get("hp_percent", 0)), 0)
				if hp_percent <= 0:
					continue
				var revive_hp: int = max(1, int(float(target.max_hp) * float(hp_percent) / 100.0))
				target.current_hp = clampi(revive_hp, 1, target.max_hp)
				target.is_alive = true
				_battle_state["guardian_angel_used"] = true
				result["revive_hp"] = target.current_hp
				_add_log(logs, "%s activated. Revived to %d HP." % [String(effect.get("item_name", "Accessory")), target.current_hp], Color("#FFD700"))
			"counter_status":
				if not attacker.is_alive:
					continue
				var status_id: String = String(effect.get("status", "")).strip_edges()
				var chance: int = clampi(int(effect.get("chance", 0)), 0, 100)
				var duration: int = max(int(effect.get("duration", 0)), 0)
				if status_id.is_empty() or chance <= 0 or duration <= 0:
					continue
				if randf() * 100.0 >= float(chance):
					continue
				counter_status.append({
					"status_id": status_id,
					"duration": duration,
				})
				_add_log(logs, "%s afflicted the attacker with %s." % [String(effect.get("item_name", "Accessory")), status_id], Color("#7CEEFF"))

	return result


static func on_battle_reward(rewards: Dictionary) -> void:
	if rewards.is_empty():
		return

	var total_bonus: int = 0
	for effect in _get_accessory_effects():
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


static func _coerce_condition_value(raw_text: String, ref_val) -> Variant:
	var cleaned: String = raw_text.strip_edges()
	if cleaned.begins_with("\"") and cleaned.ends_with("\"") and cleaned.length() >= 2:
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	elif cleaned.begins_with("'") and cleaned.ends_with("'") and cleaned.length() >= 2:
		cleaned = cleaned.substr(1, cleaned.length() - 2)

	match typeof(ref_val):
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
