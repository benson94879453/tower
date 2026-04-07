class_name BattleAI
extends RefCounted

const SkillExecutorClass = preload("res://scripts/battle/skill_executor.gd")


static func decide_enemy_action(actor, hostile_targets: Array, friendly_targets: Array) -> Dictionary:
	if hostile_targets.is_empty():
		return {}

	var usable_skills: Array = _get_usable_skills_with_data(actor)
	match String(actor.ai_type):
		"cautious":
			return _decide_cautious(actor, usable_skills, hostile_targets, friendly_targets)
		"status":
			return _decide_status(actor, usable_skills, hostile_targets, friendly_targets)
		"boss":
			return _decide_boss(actor, usable_skills, hostile_targets, friendly_targets)
		_:
			return _decide_aggressive(actor, usable_skills, hostile_targets, friendly_targets)


static func decide_familiar_action(actor, hostile_targets: Array, friendly_targets: Array) -> Dictionary:
	match int(actor.familiar_mode):
		0:
			return _decide_familiar_attack(actor, hostile_targets)
		2:
			return _decide_familiar_support(actor, hostile_targets, friendly_targets)
		_:
			return {}


static func _get_usable_skills_with_data(actor) -> Array:
	var result: Array = []
	for skill_id in actor.skill_ids:
		var check: Dictionary = SkillExecutorClass.can_use_skill(actor, skill_id)
		if not bool(check.get("usable", false)):
			continue

		var skill_data: Dictionary = DataManager.get_skill(skill_id)
		if skill_data.is_empty():
			continue

		result.append({
			"id": skill_id,
			"data": skill_data,
			"type": String(skill_data.get("type", "")),
			"power": int(skill_data.get("base_power", 0)),
			"effects": Array(skill_data.get("effects", [])),
		})

	return result


static func _categorize_skills(skills: Array) -> Dictionary:
	var attack_skills: Array = []
	var support_skills: Array = []
	var status_skills: Array = []

	for raw_skill in skills:
		var skill: Dictionary = raw_skill
		var skill_type: String = String(skill.get("type", ""))
		var has_status_effect := false
		for raw_effect in Array(skill.get("effects", [])):
			var effect: Dictionary = raw_effect
			if String(effect.get("type", "")) == "status":
				has_status_effect = true
				break

		if skill_type.contains("heal") or skill_type.contains("buff") or skill_type == "buff_self":
			support_skills.append(skill)
		elif has_status_effect:
			status_skills.append(skill)
			attack_skills.append(skill)
		elif skill_type.contains("attack"):
			attack_skills.append(skill)
		else:
			attack_skills.append(skill)

	return {
		"attack": attack_skills,
		"support": support_skills,
		"status": status_skills,
	}


static func _get_lowest_hp_target(targets: Array):
	var best = null
	var lowest_hp: int = 999999
	for target in targets:
		if target != null and target.is_alive and int(target.current_hp) < lowest_hp:
			lowest_hp = int(target.current_hp)
			best = target
	return best


static func _get_highest_threat_target(targets: Array):
	var best = null
	var highest_atk: int = -1
	for target in targets:
		if target != null and target.is_alive and int(target.matk) > highest_atk:
			highest_atk = int(target.matk)
			best = target
	return best


static func _get_highest_power_skill(skills: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_power: int = -1
	for raw_skill in skills:
		var skill: Dictionary = raw_skill
		var power: int = int(skill.get("power", 0))
		if power > best_power:
			best_power = power
			best = skill
	return best


static func _make_action(skill_id: String, target) -> Dictionary:
	return {"type": "skill", "skill_id": skill_id, "target": target}


static func _make_basic_attack(target) -> Dictionary:
	return {"type": "skill", "skill_id": "", "target": target}


static func _decide_aggressive(actor, usable_skills: Array, hostile_targets: Array, _friendly_targets: Array) -> Dictionary:
	var target = _get_lowest_hp_target(hostile_targets)
	if target == null and not hostile_targets.is_empty():
		target = hostile_targets[randi() % hostile_targets.size()]
	if target == null:
		return {}

	if usable_skills.is_empty():
		return _make_basic_attack(target)

	var categories: Dictionary = _categorize_skills(usable_skills)
	var attacks: Array = Array(categories.get("attack", []))
	if attacks.is_empty():
		var fallback_skill: Dictionary = usable_skills[randi() % usable_skills.size()]
		if String(fallback_skill.get("type", "")).contains("self"):
			return _make_action(String(fallback_skill.get("id", "")), actor)
		return _make_action(String(fallback_skill.get("id", "")), target)

	var chosen: Dictionary = {}
	if randf() < 0.8:
		chosen = _get_highest_power_skill(attacks)
	else:
		chosen = attacks[randi() % attacks.size()]

	if String(chosen.get("type", "")).contains("self"):
		return _make_action(String(chosen.get("id", "")), actor)
	return _make_action(String(chosen.get("id", "")), target)


static func _decide_cautious(actor, usable_skills: Array, hostile_targets: Array, friendly_targets: Array) -> Dictionary:
	var categories: Dictionary = _categorize_skills(usable_skills)
	var hp_ratio: float = float(actor.current_hp) / float(max(actor.max_hp, 1))
	var support_skills: Array = Array(categories.get("support", []))

	if hp_ratio < 0.4 and not support_skills.is_empty():
		var support: Dictionary = support_skills[0]
		return _make_action(String(support.get("id", "")), _get_support_target(support, actor, friendly_targets))

	var target = _get_highest_threat_target(hostile_targets)
	if target == null and not hostile_targets.is_empty():
		target = hostile_targets[randi() % hostile_targets.size()]
	if target == null:
		return {}

	if usable_skills.is_empty():
		return _make_basic_attack(target)

	var attacks: Array = Array(categories.get("attack", []))
	if attacks.is_empty():
		var skill: Dictionary = usable_skills[randi() % usable_skills.size()]
		if String(skill.get("type", "")).contains("self"):
			return _make_action(String(skill.get("id", "")), actor)
		return _make_action(String(skill.get("id", "")), target)

	var chosen: Dictionary = attacks[randi() % attacks.size()]
	if String(chosen.get("type", "")).contains("self"):
		return _make_action(String(chosen.get("id", "")), actor)
	return _make_action(String(chosen.get("id", "")), target)


static func _decide_status(actor, usable_skills: Array, hostile_targets: Array, _friendly_targets: Array) -> Dictionary:
	if hostile_targets.is_empty():
		return {}

	var target = hostile_targets[randi() % hostile_targets.size()]
	if usable_skills.is_empty():
		return _make_basic_attack(target)

	var categories: Dictionary = _categorize_skills(usable_skills)
	var status_skills: Array = Array(categories.get("status", []))
	if randf() < 0.7 and not status_skills.is_empty():
		var status_skill: Dictionary = status_skills[randi() % status_skills.size()]
		var status_id: String = _get_primary_status_from_skill(status_skill)
		var best_target = null
		for possible_target in hostile_targets:
			if possible_target != null and possible_target.is_alive and (status_id.is_empty() or not possible_target.has_status(status_id)):
				best_target = possible_target
				break

		if best_target == null:
			best_target = target
		if String(status_skill.get("type", "")).contains("self"):
			return _make_action(String(status_skill.get("id", "")), actor)
		return _make_action(String(status_skill.get("id", "")), best_target)

	var attacks: Array = Array(categories.get("attack", []))
	if attacks.is_empty():
		return _make_basic_attack(target)

	var chosen: Dictionary = attacks[randi() % attacks.size()]
	if String(chosen.get("type", "")).contains("self"):
		return _make_action(String(chosen.get("id", "")), actor)
	return _make_action(String(chosen.get("id", "")), target)


static func _get_primary_status_from_skill(skill: Dictionary) -> String:
	for raw_effect in Array(skill.get("effects", [])):
		var effect: Dictionary = raw_effect
		if String(effect.get("type", "")) == "status":
			return String(effect.get("status", ""))
	return ""


static func _decide_boss(actor, usable_skills: Array, hostile_targets: Array, friendly_targets: Array) -> Dictionary:
	var hp_ratio: float = float(actor.current_hp) / float(max(actor.max_hp, 1))
	var categories: Dictionary = _categorize_skills(usable_skills)
	var support_skills: Array = Array(categories.get("support", []))
	var status_skills: Array = Array(categories.get("status", []))
	var attack_skills: Array = Array(categories.get("attack", []))

	if hp_ratio > 0.6:
		return _decide_aggressive(actor, usable_skills, hostile_targets, friendly_targets)

	if hp_ratio > 0.4:
		if randf() < 0.4 and not support_skills.is_empty():
			var support: Dictionary = support_skills[0]
			return _make_action(String(support.get("id", "")), _get_support_target(support, actor, friendly_targets))
		if randf() < 0.5 and not status_skills.is_empty():
			return _decide_status(actor, usable_skills, hostile_targets, friendly_targets)
		return _decide_aggressive(actor, usable_skills, hostile_targets, friendly_targets)

	var aoe_skills: Array = []
	for raw_skill in attack_skills:
		var skill: Dictionary = raw_skill
		if String(skill.get("type", "")).contains("all"):
			aoe_skills.append(skill)

	if not aoe_skills.is_empty() and randf() < 0.6 and not hostile_targets.is_empty():
		var chosen: Dictionary = aoe_skills[randi() % aoe_skills.size()]
		var target = hostile_targets[randi() % hostile_targets.size()]
		return _make_action(String(chosen.get("id", "")), target)

	return _decide_aggressive(actor, usable_skills, hostile_targets, friendly_targets)


static func _decide_familiar_attack(actor, hostile_targets: Array) -> Dictionary:
	var target = _get_lowest_hp_target(hostile_targets)
	if target == null and not hostile_targets.is_empty():
		target = hostile_targets[randi() % hostile_targets.size()]
	if target == null:
		return {}

	var usable: Array = _get_usable_skills_with_data(actor)
	if usable.is_empty():
		return _make_basic_attack(target)

	var categories: Dictionary = _categorize_skills(usable)
	var attacks: Array = Array(categories.get("attack", []))
	var best: Dictionary = _get_highest_power_skill(attacks if not attacks.is_empty() else usable)
	if best.is_empty():
		return _make_basic_attack(target)

	if String(best.get("type", "")).contains("self"):
		return _make_action(String(best.get("id", "")), actor)
	return _make_action(String(best.get("id", "")), target)


static func _decide_familiar_support(actor, hostile_targets: Array, friendly_targets: Array) -> Dictionary:
	var usable: Array = _get_usable_skills_with_data(actor)
	if usable.is_empty():
		if hostile_targets.is_empty():
			return {}
		var basic_target = _get_lowest_hp_target(hostile_targets)
		if basic_target == null:
			basic_target = hostile_targets[randi() % hostile_targets.size()]
		return _make_basic_attack(basic_target)

	var categories: Dictionary = _categorize_skills(usable)
	var support_skills: Array = Array(categories.get("support", []))
	var heal_skills: Array = []
	for raw_skill in support_skills:
		var skill: Dictionary = raw_skill
		if String(skill.get("type", "")).contains("heal"):
			heal_skills.append(skill)

	if not heal_skills.is_empty():
		var heal_target = _get_lowest_hp_target(friendly_targets)
		if heal_target != null:
			var hp_ratio: float = float(heal_target.current_hp) / float(max(heal_target.max_hp, 1))
			if hp_ratio < 0.7:
				var chosen_heal: Dictionary = heal_skills[0]
				if String(chosen_heal.get("type", "")).contains("self"):
					return _make_action(String(chosen_heal.get("id", "")), actor)
				return _make_action(String(chosen_heal.get("id", "")), heal_target)

	var buff_skills: Array = []
	for raw_skill in support_skills:
		var skill: Dictionary = raw_skill
		if String(skill.get("type", "")).contains("buff"):
			buff_skills.append(skill)

	if not buff_skills.is_empty():
		var chosen_buff: Dictionary = buff_skills[0]
		return _make_action(String(chosen_buff.get("id", "")), actor)

	if hostile_targets.is_empty():
		return {}

	var target = _get_lowest_hp_target(hostile_targets)
	if target == null:
		target = hostile_targets[randi() % hostile_targets.size()]

	var attacks: Array = Array(categories.get("attack", []))
	if attacks.is_empty():
		return _make_basic_attack(target)

	var best: Dictionary = _get_highest_power_skill(attacks)
	if best.is_empty():
		return _make_basic_attack(target)
	return _make_action(String(best.get("id", "")), target)


static func _get_support_target(skill: Dictionary, actor, friendly_targets: Array):
	var skill_type: String = String(skill.get("type", ""))
	if skill_type.contains("self") or skill_type.contains("buff"):
		return actor

	var target = _get_lowest_hp_target(friendly_targets)
	if target == null:
		return actor
	return target
