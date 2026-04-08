extends SceneTree

const TurnManager = preload("res://scripts/battle/turn_manager.gd")
const SkillExecutor = preload("res://scripts/battle/skill_executor.gd")
const CombatantData = preload("res://scripts/data/combatant_data.gd")

class DummyBattleUi:
	func add_log(msg, color=Color.WHITE): pass
	func add_element_log(msg, el): pass

class DummyBattleManager:
	var battle_ui = DummyBattleUi.new()
	var player = null
	var enemies = []
	var all_combatants = []
	var environment_element = "none"
	var familiar = null
	
	func record_enemy_skill_hit(s): pass
	func get_alive_enemies(): return enemies

	signal action_executed(data)
	signal damage_dealt(t, d, e, c)
	signal combatant_hp_changed(t)
	signal combatant_defeated(t)

	func _change_state(s): pass

func _init():
	print("Starting simulation...")
	
	var bm = DummyBattleManager.new()
	var tm = TurnManager.new()
	tm._battle_manager = bm
	
	var player = CombatantData.new()
	player.id = "player"
	player.team = CombatantData.Team.PLAYER
	player.display_name = "Player"
	player.current_hp = 100
	player.max_hp = 100
	player.patk = 15
	player.matk = 15
	player.hit = 100
	player.speed = 10
	player.is_alive = true
	
	var enemy = CombatantData.new()
	enemy.id = "enemy"
	enemy.team = CombatantData.Team.ENEMY
	enemy.display_name = "Enemy"
	enemy.current_hp = 100
	enemy.max_hp = 100
	enemy.pdef = 5
	enemy.mdef = 5
	enemy.speed = 5
	enemy.is_alive = true
	enemy.dodge = 0
	
	bm.player = player
	bm.enemies = [enemy]
	bm.all_combatants = [player, enemy]
	
	print("Resolving skill action...")
	var action = {
		"type": "skill",
		"skill_id": "", # basic attack
		"target": enemy
	}
	
	tm._pending_actions = []
	tm._resolve_skill_action(player, action)
	print("Action resolved!")
	
	quit()
