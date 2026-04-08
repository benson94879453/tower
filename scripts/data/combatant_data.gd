class_name CombatantData
extends RefCounted

const SCRIPT_PATH := "res://scripts/data/combatant_data.gd"

enum Team { PLAYER, FAMILIAR, ENEMY }
enum FamiliarMode { ATTACK, DEFEND, SUPPORT, STANDBY }

var id: String = ""
var display_name: String = ""
var team: int = Team.ENEMY
var element: String = "none"

var max_hp: int = 1
var current_hp: int = 1
var max_mp: int = 0
var current_mp: int = 0
var matk: int = 0
var mdef: int = 0
var patk: int = 0
var pdef: int = 0
var speed: int = 0
var hit: int = 100
var dodge: float = 0.0
var crit: float = 5.0

var skill_ids: Array[String] = []
var skill_pp: Dictionary = {}
var cooldowns: Dictionary = {}
var cooldown_reduction: int = 0
var sealed_skill_id: String = ""

var familiar_mode: int = FamiliarMode.ATTACK

var status_effects: Array[Dictionary] = []
var battle_buffs: Array[Dictionary] = []
var shield_hp: int = 0
var shield_max: int = 0

var is_alive: bool = true

var visual: Dictionary = {}

var ai_type: String = ""

var drops: Array[Dictionary] = []
var base_exp: int = 0
var base_gold: int = 0


func has_status(status_id: String) -> bool:
	for effect in status_effects:
		if String(effect.get("id", "")) == status_id:
			return true
	return false


func remove_status(status_id: String) -> bool:
	for index in range(status_effects.size()):
		if String(status_effects[index].get("id", "")) == status_id:
			status_effects.remove_at(index)
			if status_id == "seal":
				sealed_skill_id = ""
			return true
	return false


func get_status(status_id: String) -> Dictionary:
	for effect in status_effects:
		if String(effect.get("id", "")) == status_id:
			return effect
	return {}


static func from_player() -> CombatantData:
	if PlayerManager.player_data == null:
		PlayerManager.init_new_game()

	var combatant = _new_combatant()
	var title_bonuses: Dictionary = PlayerManager.get_title_bonuses()
	var all_stats_percent: int = int(title_bonuses.get("all_stats_percent", 0))
	var atk_bonus_percent: int = int(title_bonuses.get("atk_bonus_percent", 0))
	var base_max_hp: int = PlayerManager.get_max_hp()
	var base_max_mp: int = PlayerManager.get_max_mp()
	var base_current_hp: int = clampi(PlayerManager.player_data.current_hp, 0, base_max_hp)
	var base_current_mp: int = clampi(PlayerManager.player_data.current_mp, 0, base_max_mp)
	combatant.id = "player"
	combatant.display_name = PlayerManager.player_data.name
	combatant.team = Team.PLAYER
	combatant.element = "none"
	combatant.max_hp = _apply_percent_bonus(base_max_hp, all_stats_percent)
	combatant.current_hp = _scale_current_resource(base_current_hp, base_max_hp, combatant.max_hp)
	combatant.max_mp = _apply_percent_bonus(base_max_mp, all_stats_percent)
	combatant.current_mp = _scale_current_resource(base_current_mp, base_max_mp, combatant.max_mp)
	combatant.matk = _apply_percent_bonus(PlayerManager.get_matk(), all_stats_percent)
	combatant.mdef = _apply_percent_bonus(PlayerManager.get_mdef(), all_stats_percent)
	combatant.patk = _apply_percent_bonus(PlayerManager.get_patk(), all_stats_percent)
	combatant.pdef = _apply_percent_bonus(PlayerManager.get_pdef(), all_stats_percent)
	combatant.speed = _apply_percent_bonus(PlayerManager.get_speed(), all_stats_percent)
	combatant.matk = _apply_percent_bonus(combatant.matk, atk_bonus_percent)
	combatant.patk = _apply_percent_bonus(combatant.patk, atk_bonus_percent)
	combatant.hit = PlayerManager.get_hit()
	combatant.dodge = PlayerManager.get_dodge()
	combatant.crit = PlayerManager.get_crit()
	_append_skill_data(combatant, PlayerManager.player_data.active_skill_ids, 10)
	combatant.visual = {"shape": "pentagon", "color": "#EAEAEA", "size": "medium"}
	combatant.is_alive = combatant.current_hp > 0
	return combatant


static func from_enemy(enemy_id: String) -> CombatantData:
	var data := DataManager.get_enemy(enemy_id)
	if data.is_empty():
		push_error("Enemy not found: " + enemy_id)
		return null

	var combatant = _new_combatant()
	combatant.id = enemy_id
	combatant.display_name = String(data.get("name", "???"))
	combatant.team = Team.ENEMY
	combatant.element = String(data.get("element", "none"))

	var stats: Dictionary = data.get("stats", {})
	combatant.max_hp = int(stats.get("hp", 100))
	combatant.current_hp = combatant.max_hp
	combatant.max_mp = int(stats.get("mp", 0))
	combatant.current_mp = combatant.max_mp
	combatant.matk = int(stats.get("matk", 10))
	combatant.mdef = int(stats.get("mdef", 10))
	combatant.patk = int(stats.get("patk", 10))
	combatant.pdef = int(stats.get("pdef", 10))
	combatant.speed = int(stats.get("speed", 10))
	combatant.hit = int(stats.get("hit", 100))
	combatant.dodge = float(stats.get("dodge", 0.0))
	combatant.crit = float(stats.get("crit", 5.0))
	_append_skill_data(combatant, data.get("skills", []), 99)
	combatant.ai_type = String(data.get("ai_type", "aggressive"))
	for drop in data.get("drops", []):
		if drop is Dictionary:
			combatant.drops.append(drop.duplicate(true))
	combatant.base_exp = int(data.get("exp", 0))
	combatant.base_gold = int(data.get("gold", 0))
	combatant.visual = data.get("visual", {}).duplicate(true) if data.get("visual", {}) is Dictionary else {}
	combatant.is_alive = combatant.current_hp > 0
	return combatant


static func from_familiar(
	familiar_id: String,
	level: int = 1,
	p_skill_ids: Array = [],
	mode: String = "attack"
) -> CombatantData:
	var data := DataManager.get_familiar(familiar_id)
	if data.is_empty():
		push_error("Familiar not found: " + familiar_id)
		return null

	var combatant = _new_combatant()
	combatant.id = familiar_id
	combatant.display_name = String(data.get("name", "???"))
	combatant.team = Team.FAMILIAR
	combatant.element = String(data.get("element", "none"))

	var base_stats: Dictionary = data.get("base_stats", {})
	var growth: Dictionary = data.get("growth_per_level", {})
	var level_bonus: int = max(level - 1, 0)
	combatant.max_hp = int(base_stats.get("hp", 80)) + int(growth.get("hp", 0)) * level_bonus
	combatant.current_hp = combatant.max_hp
	combatant.max_mp = int(base_stats.get("mp", 30)) + int(growth.get("mp", 0)) * level_bonus
	combatant.current_mp = combatant.max_mp
	combatant.matk = int(base_stats.get("matk", 10)) + int(growth.get("matk", 0)) * level_bonus
	combatant.mdef = int(base_stats.get("mdef", 10)) + int(growth.get("mdef", 0)) * level_bonus
	combatant.patk = int(base_stats.get("patk", 10)) + int(growth.get("patk", 0)) * level_bonus
	combatant.pdef = int(base_stats.get("pdef", 10)) + int(growth.get("pdef", 0)) * level_bonus
	combatant.speed = int(base_stats.get("speed", 10)) + int(growth.get("speed", 0)) * level_bonus
	combatant.hit = int(base_stats.get("hit", 100))
	combatant.dodge = float(base_stats.get("dodge", 0.0))
	combatant.crit = float(base_stats.get("crit", 5.0))
	var active_skill_ids: Array = Array(p_skill_ids)
	if active_skill_ids.is_empty():
		active_skill_ids = Array(data.get("default_skills", []))
	_append_skill_data(combatant, active_skill_ids, 10)
	combatant.familiar_mode = _familiar_mode_from_string(mode)
	combatant.visual = data.get("visual", {}).duplicate(true) if data.get("visual", {}) is Dictionary else {}
	combatant.is_alive = combatant.current_hp > 0
	return combatant


static func _append_skill_data(combatant: CombatantData, raw_skills, default_pp: int) -> void:
	for raw_skill in raw_skills:
		var skill_id := String(raw_skill)
		if skill_id.is_empty():
			continue

		combatant.skill_ids.append(skill_id)
		var skill_data := DataManager.get_skill(skill_id)
		combatant.skill_pp[skill_id] = int(skill_data.get("pp_max", default_pp))


static func _familiar_mode_from_string(mode: String) -> int:
	match mode.to_lower().strip_edges():
		"defend":
			return FamiliarMode.DEFEND
		"support":
			return FamiliarMode.SUPPORT
		"standby":
			return FamiliarMode.STANDBY
		_:
			return FamiliarMode.ATTACK


static func _apply_percent_bonus(base_value: int, bonus_percent: int) -> int:
	if bonus_percent == 0:
		return base_value
	return max(0, int(round(float(base_value) * (1.0 + float(bonus_percent) / 100.0))))


static func _scale_current_resource(current_value: int, base_max: int, scaled_max: int) -> int:
	if scaled_max <= 0:
		return 0
	if base_max <= 0:
		return clampi(current_value, 0, scaled_max)
	var ratio: float = float(clampi(current_value, 0, base_max)) / float(base_max)
	return clampi(int(round(float(scaled_max) * ratio)), 0, scaled_max)


static func _new_combatant() -> CombatantData:
	return load(SCRIPT_PATH).new()
