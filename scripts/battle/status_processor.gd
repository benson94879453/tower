class_name StatusProcessor
extends RefCounted

const DOT_STATUSES := ["burn", "poison", "heavy_poison"]
const CONTROL_STATUSES := ["freeze", "paralyze", "sleep", "confuse", "charm"]
const DEBUFF_STATUSES := ["atk_down", "def_down", "speed_down", "hit_down", "seal", "curse"]
const BUFF_STATUSES := ["atk_up", "def_up", "speed_up", "regen", "mp_regen", "reflect", "stealth"]

const DOT_RATES := {
	"burn": 0.08,
	"poison": 0.06,
	"heavy_poison": 0.12,
}

const STAT_MOD_MAP := {
	"atk_down": {"stats": ["matk", "patk"], "multiplier": -0.25},
	"def_down": {"stats": ["mdef", "pdef"], "multiplier": -0.25},
	"speed_down": {"stats": ["speed"], "multiplier": -0.25},
	"hit_down": {"stats": ["hit"], "multiplier": -0.25},
	"atk_up": {"stats": ["matk", "patk"], "multiplier": 0.25},
	"def_up": {"stats": ["mdef", "pdef"], "multiplier": 0.25},
	"speed_up": {"stats": ["speed"], "multiplier": 0.25},
}


static func check_before_action(actor, all_allies: Array, _all_enemies: Array) -> Dictionary:
	var logs: Array = []
	var result: Dictionary = {
		"can_act": true,
		"reason": "",
		"redirect_target": null,
		"logs": logs,
	}

	if actor.has_status("freeze"):
		result["can_act"] = false
		result["reason"] = "freeze"
		logs.append({
			"text": "%s 被凍結，無法行動！" % actor.display_name,
			"color": Color("#00FFFF"),
		})
		return result

	if actor.has_status("sleep"):
		result["can_act"] = false
		result["reason"] = "sleep"
		logs.append({
			"text": "%s 在沉睡中..." % actor.display_name,
			"color": Color("#9370DB"),
		})
		return result

	if actor.has_status("paralyze"):
		if randf() < 0.5:
			result["can_act"] = false
			result["reason"] = "paralyze"
			logs.append({
				"text": "%s 因麻痺無法動彈！" % actor.display_name,
				"color": Color("#FFD700"),
			})
			return result
		logs.append({
			"text": "%s 克服了麻痺！" % actor.display_name,
			"color": Color("#FFD700"),
		})

	if actor.has_status("confuse"):
		if randf() < 0.5:
			result["redirect_target"] = actor
			logs.append({
				"text": "%s 在混亂中攻擊了自己！" % actor.display_name,
				"color": Color("#FFA500"),
			})
		else:
			logs.append({
				"text": "%s 在混亂中恢復了意識！" % actor.display_name,
				"color": Color("#FFA500"),
			})

	if actor.has_status("charm") and result.get("redirect_target", null) == null:
		if randf() < 0.5:
			var allies: Array = []
			for ally in all_allies:
				if ally != actor and ally.is_alive:
					allies.append(ally)

			if not allies.is_empty():
				result["redirect_target"] = allies[randi() % allies.size()]
				logs.append({
					"text": "%s 被魅惑，攻擊了隊友！" % actor.display_name,
					"color": Color("#FF69B4"),
				})

	return result


static func process_end_of_turn(combatant) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not combatant.is_alive:
		return results

	for status_id in DOT_STATUSES:
		if not combatant.has_status(status_id):
			continue

		var rate: float = float(DOT_RATES.get(status_id, 0.0))
		var damage: int = max(1, int(float(combatant.max_hp) * rate))
		combatant.current_hp = clampi(combatant.current_hp - damage, 0, combatant.max_hp)
		var killed: bool = combatant.current_hp <= 0
		if killed:
			combatant.is_alive = false

		results.append({
			"type": "dot_damage",
			"combatant": combatant,
			"status_id": status_id,
			"value": damage,
			"killed": killed,
		})

		if killed:
			_tick_status_turns(combatant, results)
			return results

	if combatant.has_status("regen"):
		var heal: int = max(1, int(float(combatant.max_hp) * 0.05))
		var old_hp: int = combatant.current_hp
		combatant.current_hp = clampi(combatant.current_hp + heal, 0, combatant.max_hp)
		heal = combatant.current_hp - old_hp
		results.append({
			"type": "regen",
			"combatant": combatant,
			"status_id": "regen",
			"value": heal,
			"killed": false,
		})

	if combatant.has_status("mp_regen"):
		var mp_heal: int = max(1, int(float(combatant.max_mp) * 0.03))
		var old_mp: int = combatant.current_mp
		combatant.current_mp = clampi(combatant.current_mp + mp_heal, 0, combatant.max_mp)
		mp_heal = combatant.current_mp - old_mp
		results.append({
			"type": "mp_regen",
			"combatant": combatant,
			"status_id": "mp_regen",
			"value": mp_heal,
			"killed": false,
		})

	_tick_status_turns(combatant, results)
	return results


static func on_damage_received(target, damage_element: String) -> Array[Dictionary]:
	var logs: Array[Dictionary] = []

	if target.has_status("sleep"):
		target.remove_status("sleep")
		logs.append({
			"text": "%s 被打醒了！" % target.display_name,
			"color": Color("#9370DB"),
		})

	var normalized_element: String = String(load("res://scripts/battle/damage_calculator.gd").normalize_element(damage_element))
	if normalized_element == "fire" and target.has_status("freeze"):
		target.remove_status("freeze")
		logs.append({
			"text": "%s 的凍結被火焰融化了！" % target.display_name,
			"color": Color("#FF4500"),
		})

	return logs


static func check_reflect(target, _skill_element: String, damage_type: String) -> Dictionary:
	var logs: Array = []
	var result: Dictionary = {"reflected": false, "logs": logs}
	if damage_type == "physical":
		return result
	if not target.has_status("reflect"):
		return result

	target.remove_status("reflect")
	logs.append({
		"text": "%s 的反射護壁發動了！" % target.display_name,
		"color": Color("#FFD700"),
	})
	result["reflected"] = true
	return result


static func check_stealth_dodge(target) -> Dictionary:
	var logs: Array = []
	var result: Dictionary = {"dodged": false, "logs": logs}
	if not target.has_status("stealth"):
		return result

	target.remove_status("stealth")
	logs.append({
		"text": "%s 從隱身中閃避了攻擊！" % target.display_name,
		"color": Color("#696969"),
	})
	result["dodged"] = true
	return result


static func get_status_stat_modifier(combatant, stat_name: String) -> float:
	var modifier: float = 0.0
	for status_id in STAT_MOD_MAP.keys():
		if not combatant.has_status(String(status_id)):
			continue

		var mod_info: Dictionary = STAT_MOD_MAP[status_id]
		var affected_stats: Array = Array(mod_info.get("stats", []))
		if affected_stats.has(stat_name):
			var base_value: float = float(combatant.get(stat_name))
			modifier += base_value * float(mod_info.get("multiplier", 0.0))

	return modifier


static func apply_seal(combatant) -> String:
	if combatant.skill_ids.is_empty():
		return ""

	var available: Array[String] = []
	for sid in combatant.skill_ids:
		if not sid.is_empty() and sid != combatant.sealed_skill_id:
			available.append(sid)

	if available.is_empty():
		return ""

	var sealed: String = available[randi() % available.size()]
	combatant.sealed_skill_id = sealed
	return sealed


static func has_curse(combatant) -> bool:
	return combatant.has_status("curse")


static func _tick_status_turns(combatant, results: Array[Dictionary]) -> void:
	var expired: Array[int] = []
	for index in range(combatant.status_effects.size()):
		var effect: Dictionary = combatant.status_effects[index]
		var status_id: String = String(effect.get("id", ""))
		if ["reflect", "stealth"].has(status_id):
			continue

		effect["turns"] = int(effect.get("turns", 0)) - 1
		if int(effect.get("turns", 0)) <= 0:
			expired.append(index)

	expired.reverse()
	for index in expired:
		var expired_effect: Dictionary = combatant.status_effects[index]
		var expired_id: String = String(expired_effect.get("id", ""))
		combatant.status_effects.remove_at(index)
		results.append({
			"type": "status_expired",
			"combatant": combatant,
			"status_id": expired_id,
			"value": 0,
			"killed": false,
		})
		if expired_id == "seal":
			combatant.sealed_skill_id = ""
			results.append({
				"type": "seal_released",
				"combatant": combatant,
				"status_id": "seal",
				"value": 0,
				"killed": false,
			})
