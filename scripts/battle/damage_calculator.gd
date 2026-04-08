class_name DamageCalculator
extends RefCounted


const ELEMENTS := ["fire", "water", "thunder", "wind", "earth", "light", "dark", "none"]
const MULTIPLIER_TABLE := {
	"fire": {
		"fire": 0.5, "water": 0.5, "thunder": 1.0, "wind": 2.0,
		"earth": 1.0, "light": 1.0, "dark": 1.0, "none": 1.0,
	},
	"water": {
		"fire": 2.0, "water": 0.5, "thunder": 0.5, "wind": 1.0,
		"earth": 1.0, "light": 1.0, "dark": 1.0, "none": 1.0,
	},
	"thunder": {
		"fire": 1.0, "water": 2.0, "thunder": 0.5, "wind": 0.5,
		"earth": 1.0, "light": 1.0, "dark": 1.0, "none": 1.0,
	},
	"wind": {
		"fire": 0.5, "water": 1.0, "thunder": 2.0, "wind": 0.5,
		"earth": 0.5, "light": 1.0, "dark": 1.0, "none": 1.0,
	},
	"earth": {
		"fire": 1.0, "water": 1.0, "thunder": 2.0, "wind": 2.0,
		"earth": 0.5, "light": 1.0, "dark": 1.0, "none": 1.0,
	},
	"light": {
		"fire": 1.0, "water": 1.0, "thunder": 1.0, "wind": 1.0,
		"earth": 1.0, "light": 0.5, "dark": 2.0, "none": 1.0,
	},
	"dark": {
		"fire": 1.0, "water": 1.0, "thunder": 1.0, "wind": 1.0,
		"earth": 1.0, "light": 2.0, "dark": 0.5, "none": 1.0,
	},
	"none": {
		"fire": 1.0, "water": 1.0, "thunder": 1.0, "wind": 1.0,
		"earth": 1.0, "light": 1.0, "dark": 1.0, "none": 1.0,
	},
}

const HIT_RATE_MIN := 0.10
const HIT_RATE_MAX := 1.00
const CRIT_RATE_MAX := 0.80
const CRIT_MULTIPLIER_BASE := 1.5


static func normalize_element(element: String) -> String:
	var normalized: String = element.to_lower()
	match normalized:
		"ice":
			return "water"
		_:
			return normalized if ELEMENTS.has(normalized) else "none"


static func get_element_multiplier(attack_element: String, defend_element: String) -> float:
	var atk_e: String = normalize_element(attack_element)
	var def_e: String = normalize_element(defend_element)
	var row: Dictionary = MULTIPLIER_TABLE.get(atk_e, MULTIPLIER_TABLE["none"])
	return float(row.get(def_e, 1.0))


static func get_effectiveness_text(multiplier: float) -> String:
	if multiplier >= 2.0:
		return "效果絕佳！"
	if multiplier <= 0.5:
		return "效果不佳..."
	return ""


static func get_environment_modifier(skill_element: String, environment_element: String) -> float:
	var norm_skill: String = normalize_element(skill_element)
	var norm_env: String = normalize_element(environment_element)

	if norm_env == "none" or norm_env.is_empty():
		return 1.0
	if norm_skill == norm_env:
		return 1.2

	var skill_row: Dictionary = MULTIPLIER_TABLE.get(norm_skill, MULTIPLIER_TABLE["none"])
	if float(skill_row.get(norm_env, 1.0)) >= 2.0:
		return 0.9

	return 1.0


static func calc_hit(attacker, defender, skill_data: Dictionary) -> bool:
	if bool(skill_data.get("always_hit", false)):
		return true

	var skill_hit_rate: float = float(skill_data.get("hit_rate", 95)) / 100.0
	var atk_hit: float = max(float(attacker.hit), 0.0)
	var def_dodge: float = max(float(defender.dodge), 0.0)
	var denominator: float = max(atk_hit + def_dodge, 1.0)
	var final_rate: float = skill_hit_rate * (atk_hit / denominator)
	final_rate = clampf(final_rate, HIT_RATE_MIN, HIT_RATE_MAX)
	return randf() < final_rate


static func calc_crit(attacker, skill_data: Dictionary) -> Dictionary:
	var base_crit: float = float(attacker.crit) / 100.0
	var skill_crit_bonus: float = float(skill_data.get("crit_bonus", 0)) / 100.0
	var buff_crit: float = 0.0
	for buff in attacker.battle_buffs:
		if String(buff.get("stat", "")) == "crit":
			buff_crit += float(buff.get("value", 0)) / 100.0

	var total_crit: float = clampf(base_crit + skill_crit_bonus + buff_crit, 0.0, CRIT_RATE_MAX)
	var is_crit: bool = randf() < total_crit
	var crit_multi: float = CRIT_MULTIPLIER_BASE
	for buff in attacker.battle_buffs:
		if String(buff.get("stat", "")) == "crit_damage":
			crit_multi += float(buff.get("value", 0)) / 100.0

	return {
		"is_crit": is_crit,
		"multiplier": crit_multi if is_crit else 1.0,
	}


static func get_effective_stat(combatant, stat_name: String) -> float:
	var base_value: float = float(combatant.get(stat_name))
	var buff_bonus: float = 0.0
	for buff in combatant.battle_buffs:
		if String(buff.get("stat", "")) == stat_name:
			buff_bonus += float(buff.get("value", 0))

	var status_mod: float = StatusProcessor.get_status_stat_modifier(combatant, stat_name)
	return max(0.0, base_value + buff_bonus + status_mod)


static func calculate_damage(
	attacker,
	defender,
	skill_data: Dictionary,
	environment_element: String = "none"
) -> Dictionary:
	var result: Dictionary = {
		"damage": 0,
		"is_hit": true,
		"is_crit": false,
		"element_multiplier": 1.0,
		"effectiveness_text": "",
		"environment_mod": 1.0,
	}

	if attacker == null or defender == null:
		result["is_hit"] = false
		return result

	if not calc_hit(attacker, defender, skill_data):
		result["is_hit"] = false
		return result

	var power: float = float(skill_data.get("base_power", skill_data.get("power", 50)))
	var skill_element: String = String(skill_data.get("element", "none"))
	var damage_type: String = String(skill_data.get("damage_type", "magic"))
	var skill_type: String = String(skill_data.get("type", "attack_single"))
	if damage_type.is_empty() or damage_type == "magic":
		damage_type = "physical" if skill_type.contains("physical") else "magic"

	var atk_stat: float
	var def_stat: float
	if damage_type == "physical":
		atk_stat = get_effective_stat(attacker, "patk")
		def_stat = get_effective_stat(defender, "pdef")
	else:
		atk_stat = get_effective_stat(attacker, "matk")
		def_stat = get_effective_stat(defender, "mdef")

	def_stat = max(def_stat, 1.0)
	var base_damage: float = power * atk_stat / def_stat

	var element_multi: float = 1.0
	if damage_type != "physical":
		element_multi = get_element_multiplier(skill_element, String(defender.element))
		result["element_multiplier"] = element_multi
		result["effectiveness_text"] = get_effectiveness_text(element_multi)
		base_damage *= element_multi
		if String(attacker.id) == "player":
			var title_bonuses: Dictionary = PlayerManager.get_title_bonuses()
			var element_bonuses: Dictionary = Dictionary(title_bonuses.get("element_damage_bonus", {}))
			var normalized_element: String = normalize_element(skill_element)
			var title_bonus_percent: int = int(element_bonuses.get(normalized_element, 0))
			title_bonus_percent += int(element_bonuses.get("all", 0))
			if title_bonus_percent != 0:
				base_damage *= 1.0 + float(title_bonus_percent) / 100.0

	var env_mod: float = get_environment_modifier(skill_element, environment_element)
	result["environment_mod"] = env_mod
	base_damage *= env_mod

	var crit_result: Dictionary = calc_crit(attacker, skill_data)
	result["is_crit"] = bool(crit_result.get("is_crit", false))
	base_damage *= float(crit_result.get("multiplier", 1.0))

	base_damage *= randf_range(0.85, 1.15)

	for buff in defender.battle_buffs:
		if String(buff.get("stat", "")) == "defending":
			base_damage *= 0.5
			break

	result["damage"] = max(1, int(base_damage))
	return result


static func get_basic_attack_data() -> Dictionary:
	return {
		"name": "普通攻擊",
		"element": "none",
		"type": "attack_single",
		"damage_type": "magic",
		"base_power": 40,
		"mp_cost": 0,
		"pp_max": 99,
		"hit_rate": 95,
		"always_hit": false,
		"crit_bonus": 0,
		"effects": [],
	}
