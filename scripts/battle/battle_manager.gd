class_name BattleManager
extends Node

const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")
const BattleResultClass = preload("res://scripts/battle/battle_result.gd")
const TurnManagerClass = preload("res://scripts/battle/turn_manager.gd")

enum BattleState {
	INACTIVE,
	STARTING,
	PLAYER_TURN,
	EXECUTING,
	TURN_END,
	VICTORY,
	DEFEAT,
	FLEEING,
}

signal battle_started
signal battle_ended(result: String)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal state_changed(new_state: int)
signal combatant_hp_changed(combatant)
signal combatant_defeated(combatant)
signal action_executed(action: Dictionary)
signal damage_dealt(target, amount: int, element: String, is_crit: bool)

var battle_state: int = BattleState.INACTIVE
var turn_number: int = 0

var player
var familiar
var enemies: Array = []
var all_combatants: Array = []
var turn_order: Array = []
var turn_manager
var _received_enemy_skill_ids: Array[String] = []

var is_boss_battle := false
var floor_number := 1
var environment_element := "none"

@onready var battle_ui = $BattleUI


func start_battle(enemy_ids: Array[String], config: Dictionary = {}) -> void:
	if battle_state != BattleState.INACTIVE:
		push_warning("Battle already in progress")
		return

	_change_state(BattleState.STARTING)
	turn_number = 0
	turn_order.clear()
	_received_enemy_skill_ids.clear()

	is_boss_battle = bool(config.get("is_boss", false))
	floor_number = int(config.get("floor", 1))
	environment_element = String(config.get("environment_element", "none"))

	player = CombatantDataClass.from_player()

	var familiar_id := String(config.get("familiar_id", ""))
	var familiar_level := int(config.get("familiar_level", 1))
	if not familiar_id.is_empty():
		familiar = CombatantDataClass.from_familiar(familiar_id, familiar_level)
	else:
		familiar = null

	enemies.clear()
	for enemy_id in enemy_ids:
		var enemy = CombatantDataClass.from_enemy(enemy_id)
		if enemy != null:
			enemies.append(enemy)

	if enemies.is_empty():
		push_error("No valid enemies for battle")
		cleanup()
		return

	_rebuild_all_combatants()
	battle_ui.setup_battle(player, familiar, enemies)
	battle_ui.set_player_input_enabled(false)

	turn_manager = TurnManagerClass.new()
	turn_manager._battle_manager = self

	battle_started.emit()
	turn_number = 1
	turn_started.emit(turn_number)
	_run_battle_loop()


func end_battle(result: String) -> void:
	match result:
		"victory":
			_change_state(BattleState.VICTORY)
		"defeat":
			_change_state(BattleState.DEFEAT)
		_:
			_change_state(BattleState.FLEEING)

	if player != null and PlayerManager.player_data != null:
		PlayerManager.player_data.current_hp = clampi(player.current_hp, 0, PlayerManager.get_max_hp())
		PlayerManager.player_data.current_mp = clampi(player.current_mp, 0, PlayerManager.get_max_mp())
		PlayerManager.player_hp_changed.emit(PlayerManager.player_data.current_hp, PlayerManager.get_max_hp())
		PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())

	match result:
		"victory":
			_process_victory()
		"defeat":
			_process_defeat()

	battle_ui.set_player_input_enabled(false)
	battle_ended.emit(result)


func cleanup() -> void:
	turn_manager = null
	player = null
	familiar = null
	enemies.clear()
	all_combatants.clear()
	turn_order.clear()
	_received_enemy_skill_ids.clear()
	turn_number = 0
	battle_ui.set_player_input_enabled(false)
	_change_state(BattleState.INACTIVE)


func on_player_skill_selected(skill_id: String, target) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	if turn_manager != null:
		turn_manager.player_action = {
			"type": "skill",
			"skill_id": skill_id,
			"target": target,
		}


func on_player_item_selected(item_id: String) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	if turn_manager != null:
		turn_manager.player_action = {
			"type": "item",
			"item_id": item_id,
		}


func on_player_familiar_mode_changed(mode: int) -> void:
	if familiar == null:
		return

	familiar.familiar_mode = mode
	battle_ui._update_familiar_display()


func on_player_flee() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	if is_boss_battle:
		battle_ui.add_log("無法從 Boss 戰逃跑！")
		return

	if turn_manager != null:
		turn_manager.player_action = {
			"type": "flee",
		}


func get_alive_enemies() -> Array:
	var alive: Array = []
	for enemy in enemies:
		if enemy.is_alive:
			alive.append(enemy)

	return alive


func get_alive_allies() -> Array:
	var alive: Array = []
	if player != null and player.is_alive:
		alive.append(player)
	if familiar != null and familiar.is_alive:
		alive.append(familiar)

	return alive


func is_battle_active() -> bool:
	return battle_state != BattleState.INACTIVE


func record_enemy_skill_hit(skill_id: String) -> void:
	if skill_id.is_empty():
		return
	if not _received_enemy_skill_ids.has(skill_id):
		_received_enemy_skill_ids.append(skill_id)


func _change_state(new_state: int) -> void:
	battle_state = new_state
	state_changed.emit(new_state)


func _rebuild_all_combatants() -> void:
	all_combatants.clear()
	if player != null:
		all_combatants.append(player)
	if familiar != null:
		all_combatants.append(familiar)
	all_combatants.append_array(enemies)


func _run_battle_loop() -> void:
	while battle_state != BattleState.VICTORY \
		and battle_state != BattleState.DEFEAT \
		and battle_state != BattleState.FLEEING \
		and battle_state != BattleState.INACTIVE:
		battle_ui.add_log("--- 第 %d 回合 ---" % turn_number, Color.YELLOW)
		await turn_manager.execute_turn()

		if battle_state == BattleState.VICTORY \
			or battle_state == BattleState.DEFEAT \
			or battle_state == BattleState.FLEEING:
			break

		_change_state(BattleState.TURN_END)
		turn_ended.emit(turn_number)
		turn_number += 1
		turn_started.emit(turn_number)


func _process_victory() -> void:
	var rewards: Dictionary = BattleResultClass.calculate_victory_rewards(
		enemies,
		floor_number,
		_received_enemy_skill_ids
	)
	var level_result: Dictionary = BattleResultClass.apply_victory_rewards(rewards)
	battle_ui.show_victory_result(rewards, level_result)


func _process_defeat() -> void:
	var penalty: Dictionary = BattleResultClass.calculate_defeat_penalty()
	BattleResultClass.apply_defeat_penalty(penalty)
	battle_ui.show_defeat_result(penalty)
