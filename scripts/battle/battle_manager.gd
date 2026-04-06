class_name BattleManager
extends Node

const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")

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
	battle_ui.set_player_input_enabled(true)

	battle_started.emit()
	turn_number = 1
	_change_state(BattleState.PLAYER_TURN)
	turn_started.emit(turn_number)


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

	battle_ui.set_player_input_enabled(false)
	battle_ended.emit(result)


func cleanup() -> void:
	player = null
	familiar = null
	enemies.clear()
	all_combatants.clear()
	turn_order.clear()
	turn_number = 0
	battle_ui.set_player_input_enabled(false)
	_change_state(BattleState.INACTIVE)


func on_player_skill_selected(skill_id: String, target) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	print("[BattleManager] Player uses skill: %s on %s" % [skill_id, target.display_name])
	battle_ui.set_player_input_enabled(false)
	_change_state(BattleState.EXECUTING)


func on_player_item_selected(item_id: String) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	print("[BattleManager] Player uses item: %s" % item_id)
	battle_ui.set_player_input_enabled(false)
	_change_state(BattleState.EXECUTING)


func on_player_familiar_mode_changed(mode: int) -> void:
	if familiar == null:
		return

	familiar.familiar_mode = mode
	print("[BattleManager] Familiar mode -> %s" % CombatantDataClass.FamiliarMode.keys()[mode])


func on_player_flee() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	if is_boss_battle:
		print("[BattleManager] Cannot flee from boss battle!")
		return

	print("[BattleManager] Player attempts to flee")
	battle_ui.set_player_input_enabled(false)
	_change_state(BattleState.FLEEING)


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
