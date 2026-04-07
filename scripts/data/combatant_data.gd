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
	combatant.id = "player"
	combatant.display_name = PlayerManager.player_data.name
	combatant.team = Team.PLAYER
	combatant.element = "none"
	combatant.max_hp = PlayerManager.get_max_hp()
	combatant.current_hp = PlayerManager.player_data.current_hp
	combatant.max_mp = PlayerManager.get_max_mp()
	combatant.current_mp = PlayerManager.player_data.current_mp
	combatant.matk = PlayerManager.get_matk()
	combatant.mdef = PlayerManager.get_mdef()
	combatant.patk = PlayerManager.get_patk()
	combatant.pdef = PlayerManager.get_pdef()
	combatant.speed = PlayerManager.get_speed()
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


static func from_familiar(familiar_id: String, level: int = 1) -> CombatantData:
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
	_append_skill_data(combatant, data.get("default_skills", []), 10)
	combatant.familiar_mode = FamiliarMode.ATTACK
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


static func _new_combatant() -> CombatantData:
	return load(SCRIPT_PATH).new()
