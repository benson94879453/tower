class_name SkillExecutor
extends RefCounted



static func execute_skill(
	actor,
	skill_id: String,
	primary_target,
	all_enemies: Array,
	all_allies: Array,
	environment_element: String = "none"
) -> Dictionary:
	var output: Dictionary = {
		"success": false,
		"fail_reason": "",
		"results": [],
		"skill_name": "普通攻擊",
		"skill_element": "none",
	}

	if actor == null:
		output["fail_reason"] = "invalid_actor"
		return output

	var skill_data: Dictionary = {}
	var using_basic_attack: bool = skill_id.is_empty()
	if not skill_id.is_empty():
		skill_data = DataManager.get_skill(skill_id)
	if using_basic_attack or skill_data.is_empty():
		skill_data = DamageCalculator.get_basic_attack_data()
		using_basic_attack = true

	var resolved_skill_data: Dictionary = skill_data.duplicate(true)
	var scaled_power: int = -1
	if not using_basic_attack and actor != null and int(actor.team) == CombatantData.Team.PLAYER:
		var skill_level: int = PlayerManager.get_skill_level(skill_id)
		if skill_level >= 2:
			var scaling: Dictionary = Dictionary(skill_data.get("level_scaling", {}))
			var overlay_key: String = str(skill_level)
			var overlay: Dictionary = {}
			if scaling.has(overlay_key) and scaling[overlay_key] is Dictionary:
				overlay = Dictionary(scaling[overlay_key])
			elif scaling.has("max") and scaling["max"] is Dictionary:
				overlay = Dictionary(scaling["max"])

			if not overlay.is_empty():
				if overlay.has("power"):
					scaled_power = int(overlay.get("power", resolved_skill_data.get("base_power", 0)))
					resolved_skill_data["base_power"] = scaled_power
				if overlay.has("mp_cost"):
					resolved_skill_data["mp_cost"] = int(overlay.get("mp_cost", resolved_skill_data.get("mp_cost", 0)))
				var override_effects: Array = Array(overlay.get("effects_override", []))
				if not override_effects.is_empty():
					resolved_skill_data["effects"] = override_effects.duplicate(true)
				elif scaled_power >= 0:
					var scaled_effects: Array = []
					for raw_effect in Array(resolved_skill_data.get("effects", [])):
						if raw_effect is not Dictionary:
							scaled_effects.append(raw_effect)
							continue

						var effect_copy: Dictionary = Dictionary(raw_effect).duplicate(true)
						if String(effect_copy.get("type", "")) == "damage":
							effect_copy["power"] = scaled_power
						scaled_effects.append(effect_copy)

					resolved_skill_data["effects"] = scaled_effects

	var skill_name: String = String(resolved_skill_data.get("name", "普通攻擊"))
	var skill_element: String = String(resolved_skill_data.get("element", "none"))
	output["skill_name"] = skill_name
	output["skill_element"] = skill_element

	if not using_basic_attack:
		if actor.sealed_skill_id == skill_id:
			output["fail_reason"] = "sealed"
			return output
		var cd_remaining: int = int(actor.cooldowns.get(skill_id, 0))
		if cd_remaining > 0:
			output["fail_reason"] = "on_cooldown"
			return output

	var mp_cost: int = int(resolved_skill_data.get("mp_cost", 0))
	if actor.current_mp < mp_cost:
		output["fail_reason"] = "no_mp"
		return output

	if not using_basic_attack:
		var remaining_pp: int = int(actor.skill_pp.get(skill_id, 0))
		if remaining_pp <= 0:
			output["fail_reason"] = "no_pp"
			return output
		actor.skill_pp[skill_id] = remaining_pp - 1

	actor.current_mp -= mp_cost

	var cooldown: int = int(resolved_skill_data.get("cooldown", 0))
	if cooldown > 0 and not using_basic_attack:
		var reduced_cooldown: int = max(cooldown - max(int(actor.cooldown_reduction), 0), 0)
		if reduced_cooldown > 0:
			actor.cooldowns[skill_id] = reduced_cooldown

	var effects: Array = Array(resolved_skill_data.get("effects", []))
	if effects.is_empty():
		var power: int = int(resolved_skill_data.get("base_power", 0))
		if power > 0 and primary_target != null:
			effects = [{"type": "damage", "target": "single_enemy", "power": power}]

	for effect in effects:
		if effect is not Dictionary:
			continue

		var effect_dict: Dictionary = effect
		var effect_type: String = String(effect_dict.get("type", ""))
		var targets: Array = _resolve_targets(effect_dict, actor, primary_target, all_enemies, all_allies)

		match effect_type:
			"damage":
				for target in targets:
					if target == null or not target.is_alive:
						continue
					output["results"].append(_apply_damage(
						actor,
						target,
						resolved_skill_data,
						effect_dict,
						environment_element
					))
			"heal":
				for target in targets:
					if target == null or not target.is_alive:
						continue
					output["results"].append(_apply_heal(actor, target, effect_dict))
			"status":
				for target in targets:
					if target == null or not target.is_alive:
						continue
					output["results"].append(_apply_status(target, effect_dict))
			"buff":
				for target in targets:
					if target == null or not target.is_alive:
						continue
					output["results"].append(_apply_buff(actor, target, effect_dict, skill_id))
			"shield":
				for target in targets:
					if target == null or not target.is_alive:
						continue
					output["results"].append(_apply_shield(target, effect_dict))

	output["success"] = true
	return output


static func _resolve_targets(
	effect: Dictionary,
	actor,
	primary_target,
	all_enemies: Array,
	all_allies: Array
) -> Array:
	var target_type: String = String(effect.get("target", "single_enemy"))
	var resolved: Array = []

	match target_type:
		"single_enemy":
			if primary_target != null:
				resolved.append(primary_target)
		"all_enemies":
			for enemy in all_enemies:
				if enemy != null and enemy.is_alive:
					resolved.append(enemy)
		"self":
			resolved.append(actor)
		"single_ally":
			if primary_target != null:
				resolved.append(primary_target)
			else:
				resolved.append(actor)
		"all_allies":
			for ally in all_allies:
				if ally != null and ally.is_alive:
					resolved.append(ally)
		_:
			if primary_target != null:
				resolved.append(primary_target)

	return resolved


static func _apply_damage(
	actor,
	target,
	skill_data: Dictionary,
	effect: Dictionary,
	environment_element: String
) -> Dictionary:
	var effect_power: int = int(effect.get("power", 0))
	var modified_skill: Dictionary = skill_data.duplicate(true)
	if effect_power > 0:
		modified_skill["base_power"] = effect_power

	var skill_element: String = String(skill_data.get("element", "none"))
	var damage_type: String = String(skill_data.get("damage_type", "magic"))
	if damage_type.is_empty() or damage_type == "magic":
		var skill_type: String = String(skill_data.get("type", "attack_single"))
		damage_type = "physical" if skill_type.contains("physical") else "magic"

	var result: Dictionary = {
		"effect_type": "damage",
		"target": target,
		"is_hit": false,
		"damage": 0,
		"is_crit": false,
		"effectiveness_text": "",
		"killed": false,
		"extra_logs": [],
		"reflected": false,
	}
	var extra_logs: Array = result["extra_logs"]

	var stealth_check: Dictionary = StatusProcessor.check_stealth_dodge(target)
	if bool(stealth_check.get("dodged", false)):
		extra_logs.append_array(Array(stealth_check.get("logs", [])))
		return result

	var reflect_check: Dictionary = StatusProcessor.check_reflect(target, skill_element, damage_type)
	if bool(reflect_check.get("reflected", false)):
		extra_logs.append_array(Array(reflect_check.get("logs", [])))
		result["reflected"] = true
		target = actor
		result["target"] = actor

	var calc_result: Dictionary = DamageCalculator.calculate_damage(
		actor,
		target,
		modified_skill,
		environment_element
	)
	result["is_hit"] = bool(calc_result.get("is_hit", false))
	result["is_crit"] = bool(calc_result.get("is_crit", false))
	result["effectiveness_text"] = String(calc_result.get("effectiveness_text", ""))
	result["element_multiplier"] = float(calc_result.get("element_multiplier", 1.0))
	result["damage_type"] = damage_type
	if not bool(result.get("is_hit", false)):
		return result

	var damage: int = int(calc_result.get("damage", 0))
	if target.shield_hp > 0:
		var absorbed: int = min(target.shield_hp, damage)
		target.shield_hp -= absorbed
		damage -= absorbed
		result["shield_absorbed"] = absorbed
		if target.shield_hp <= 0:
			target.shield_hp = 0
			target.shield_max = 0

	target.current_hp = clampi(target.current_hp - damage, 0, target.max_hp)
	result["damage"] = damage + int(result.get("shield_absorbed", 0))
	if target.current_hp <= 0:
		target.is_alive = false
		result["killed"] = true
	elif bool(result.get("is_hit", false)):
		extra_logs.append_array(StatusProcessor.on_damage_received(target, skill_element))

	return result


static func _apply_heal(actor, target, effect: Dictionary) -> Dictionary:
	var heal_type: String = String(effect.get("heal_type", "flat"))
	var value: int = int(effect.get("value", 0))
	var actual_heal: int = 0

	match heal_type:
		"percent_max":
			actual_heal = int(float(target.max_hp) * float(value) / 100.0)
		"percent_missing":
			var missing: int = target.max_hp - target.current_hp
			actual_heal = int(float(missing) * float(value) / 100.0)
		"matk_scale":
			actual_heal = int(float(DamageCalculator.get_effective_stat(actor, "matk")) * float(value) / 100.0)
		_:
			actual_heal = value

	actual_heal = max(0, actual_heal)
	var old_hp: int = target.current_hp
	if StatusProcessor.has_curse(target):
		target.current_hp = clampi(target.current_hp - actual_heal, 0, target.max_hp)
		var killed: bool = target.current_hp <= 0
		if killed:
			target.is_alive = false
		return {
			"effect_type": "heal",
			"target": target,
			"heal_amount": -actual_heal,
			"cursed": true,
			"killed": killed,
		}

	target.current_hp = clampi(target.current_hp + actual_heal, 0, target.max_hp)
	actual_heal = target.current_hp - old_hp

	return {
		"effect_type": "heal",
		"target": target,
		"heal_amount": actual_heal,
	}


static func _apply_status(target, effect: Dictionary) -> Dictionary:
	var status_id: String = String(effect.get("status", ""))
	var chance: float = float(effect.get("chance", 100))
	var duration: int = int(effect.get("duration", 3))
	var result: Dictionary = {
		"effect_type": "status",
		"target": target,
		"status_id": status_id,
		"applied": false,
	}
	if status_id.is_empty():
		return result
	if randf() * 100.0 >= chance:
		return result

	var found: bool = false
	for existing in target.status_effects:
		if String(existing.get("id", "")) == status_id:
			existing["turns"] = max(int(existing.get("turns", 0)), duration)
			found = true
			break

	if not found:
		target.status_effects.append({
			"id": status_id,
			"turns": duration,
		})

	result["applied"] = true
	if status_id == "seal":
		result["sealed_skill"] = StatusProcessor.apply_seal(target)
	return result


static func _apply_buff(_actor, target, effect: Dictionary, source_skill: String) -> Dictionary:
	var stat: String = String(effect.get("stat", ""))
	var value: int = int(effect.get("value", 0))
	var duration: int = int(effect.get("duration", 3))
	target.battle_buffs.append({
		"stat": stat,
		"value": value,
		"turns": duration,
		"source": source_skill,
	})
	return {
		"effect_type": "buff",
		"target": target,
		"stat": stat,
		"value": value,
		"duration": duration,
	}


static func _apply_shield(target, effect: Dictionary) -> Dictionary:
	var shield_value: int = int(effect.get("value", 0))
	if shield_value > target.shield_hp:
		target.shield_hp = shield_value
		target.shield_max = shield_value

	return {
		"effect_type": "shield",
		"target": target,
		"shield_value": shield_value,
	}


static func tick_cooldowns(combatant) -> void:
	var expired: Array = []
	for raw_skill_id in combatant.cooldowns.keys():
		var skill_id: String = String(raw_skill_id)
		combatant.cooldowns[skill_id] = int(combatant.cooldowns[skill_id]) - 1
		if int(combatant.cooldowns[skill_id]) <= 0:
			expired.append(skill_id)

	for skill_id in expired:
		combatant.cooldowns.erase(skill_id)


static func can_use_skill(actor, skill_id: String) -> Dictionary:
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	if skill_data.is_empty():
		return {"usable": false, "reason": "not_found"}

	if actor.sealed_skill_id == skill_id:
		return {"usable": false, "reason": "sealed"}

	var cd: int = int(actor.cooldowns.get(skill_id, 0))
	if cd > 0:
		return {"usable": false, "reason": "on_cooldown", "cooldown": cd}

	var mp_cost: int = int(skill_data.get("mp_cost", 0))
	if actor.current_mp < mp_cost:
		return {"usable": false, "reason": "no_mp"}

	var pp: int = int(actor.skill_pp.get(skill_id, 0))
	if pp <= 0:
		return {"usable": false, "reason": "no_pp"}

	return {"usable": true, "reason": ""}


static func get_skill_priority(skill_id: String) -> int:
	if skill_id.is_empty():
		return 0
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	if skill_data.is_empty():
		return 0
	return int(skill_data.get("priority", 0))
