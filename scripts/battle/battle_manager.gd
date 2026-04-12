class_name BattleManager
extends Node


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
@warning_ignore("unused_signal")
signal combatant_hp_changed(combatant)
@warning_ignore("unused_signal")
signal combatant_defeated(combatant)
@warning_ignore("unused_signal")
signal action_executed(action: Dictionary)
@warning_ignore("unused_signal")
signal damage_dealt(target, amount: int, element: String, is_crit: bool)

var battle_state: int = BattleState.INACTIVE
var turn_number: int = 0

var player: CombatantData
var familiar: CombatantData
var enemies: Array[CombatantData] = []
var all_combatants: Array[CombatantData] = []
var turn_order: Array[CombatantData] = []
var turn_manager: TurnManager
var _received_enemy_skill_ids: Array[String] = []

var is_boss_battle := false
var is_elite_battle := false
var floor_number := 1
var environment_element := "none"

@onready var battle_ui = $BattleUI


func start_battle(enemy_ids: Array, config: Dictionary = {}) -> void:
	if battle_state != BattleState.INACTIVE:
		push_warning("Battle already in progress")
		return

	var normalized_enemy_ids: Array[String] = []
	for raw_enemy_id in enemy_ids:
		var enemy_id: String = String(raw_enemy_id).strip_edges()
		if enemy_id.is_empty():
			continue
		normalized_enemy_ids.append(enemy_id)

	_change_state(BattleState.STARTING)
	turn_number = 0
	turn_order.clear()
	_received_enemy_skill_ids.clear()

	is_boss_battle = bool(config.get("is_boss", false))
	is_elite_battle = bool(config.get("is_elite", false))
	floor_number = int(config.get("floor", 1))
	environment_element = String(config.get("environment_element", "none"))

	player = CombatantData.from_player()

	var familiar_id := String(config.get("familiar_id", ""))
	var familiar_level := int(config.get("familiar_level", 1))
	var familiar_skill_ids: Array = Array(config.get("familiar_skill_ids", []))
	var familiar_mode: String = String(config.get("familiar_mode", "attack"))
	var familiar_current_hp := int(config.get("familiar_current_hp", -1))
	var familiar_current_mp := int(config.get("familiar_current_mp", -1))
	var familiar_is_alive := bool(config.get("familiar_is_alive", true))
	if not familiar_id.is_empty():
		familiar = CombatantData.from_familiar(familiar_id, familiar_level, familiar_skill_ids, familiar_mode, familiar_current_hp, familiar_current_mp, familiar_is_alive)
	else:
		familiar = null

	enemies.clear()
	for enemy_id in normalized_enemy_ids:
		PlayerManager.discover_enemy(enemy_id)
		var enemy = CombatantData.from_enemy(enemy_id)
		if enemy != null:
			enemies.append(enemy)

	if enemies.is_empty():
		push_error("No valid enemies for battle")
		cleanup()
		return

	_rebuild_all_combatants()
	battle_ui.setup_battle(player, familiar, enemies)
	battle_ui.set_player_input_enabled(false)

	turn_manager = TurnManager.new()
	turn_manager._battle_manager = self

	AccessoryProcessor.reset_battle_state()
	var passive_logs: Array[Dictionary] = PassiveProcessor.on_battle_start(player, familiar)
	var accessory_logs: Array[Dictionary] = AccessoryProcessor.on_battle_start(player, familiar)
	battle_ui.refresh_all_displays()
	await delay(0.6)
	for raw_log in passive_logs:
		var log_entry: Dictionary = raw_log
		battle_ui.add_log(
			String(log_entry.get("text", "")),
			log_entry.get("color", Color.WHITE)
		)
		await delay(0.2)
	for raw_log in accessory_logs:
		var log_entry: Dictionary = raw_log
		battle_ui.add_log(
			String(log_entry.get("text", "")),
			log_entry.get("color", Color.WHITE)
		)
		await delay(0.2)

	battle_started.emit()
	turn_number = 1
	turn_started.emit(turn_number)
	await delay(0.5)
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
		match result:
			"victory", "flee":
				PlayerManager.player_data.current_hp = clampi(player.current_hp, 0, PlayerManager.get_max_hp())
				PlayerManager.player_data.current_mp = clampi(player.current_mp, 0, PlayerManager.get_max_mp())
				PlayerManager.player_hp_changed.emit(PlayerManager.player_data.current_hp, PlayerManager.get_max_hp())
				PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())
				if familiar != null:
					var active_idx: int = PlayerManager.player_data.active_familiar_index
					if active_idx >= 0:
						PlayerManager.save_familiar_battle_state(
							active_idx, familiar.current_hp, familiar.current_mp, familiar.is_alive
						)

	battle_ui.set_player_input_enabled(false)
	match result:
		"victory":
			await _process_victory()
		"defeat":
			await _process_defeat()

	battle_ended.emit(result)


func cleanup() -> void:
	turn_manager = null
	player = null
	familiar = null
	enemies.clear()
	all_combatants.clear()
	turn_order.clear()
	_received_enemy_skill_ids.clear()
	is_boss_battle = false
	is_elite_battle = false
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


func get_alive_enemies() -> Array[CombatantData]:
	var alive: Array[CombatantData] = []
	for enemy in enemies:
		if enemy.is_alive:
			alive.append(enemy)

	return alive


func get_alive_allies() -> Array[CombatantData]:
	var alive: Array[CombatantData] = []
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


func set_turn_order_snapshot(order: Array) -> void:
	turn_order.clear()
	for combatant in order:
		if combatant is CombatantData:
			turn_order.append(combatant)


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
		await delay(0.4)
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
	var rewards: Dictionary = BattleResult.calculate_victory_rewards(
		enemies,
		floor_number,
		_received_enemy_skill_ids,
		is_boss_battle,
		is_elite_battle
	)
	var level_result: Dictionary = BattleResult.apply_victory_rewards(rewards)
	if PlayerManager.player_data != null:
		PlayerManager.player_data.battle_victories += 1
	if QuestManager != null:
		for enemy in enemies:
			if enemy == null:
				continue
			QuestManager.on_enemy_defeated(String(enemy.id))
		if is_boss_battle:
			QuestManager.on_boss_defeated(floor_number)
	var familiar_exp: int = int(rewards.get("familiar_exp", 0))
	if familiar_exp > 0:
		var title_bonuses: Dictionary = PlayerManager.get_title_bonuses()
		var familiar_exp_bonus_percent: int = int(title_bonuses.get("familiar_exp_bonus_percent", 0))
		if familiar_exp_bonus_percent != 0:
			familiar_exp = max(1, int(round(float(familiar_exp) * (1.0 + float(familiar_exp_bonus_percent) / 100.0))))
			rewards["familiar_exp"] = familiar_exp
	if familiar != null and familiar_exp > 0 and PlayerManager.player_data != null:
		PlayerManager.train_familiar(PlayerManager.player_data.active_familiar_index, familiar_exp)
	PlayerManager.check_title_unlocks()
	await battle_ui.show_victory_result(rewards, level_result)


func _process_defeat() -> void:
	var penalty: Dictionary = BattleResult.calculate_defeat_penalty()
	BattleResult.apply_defeat_penalty(penalty)
	await battle_ui.show_defeat_result(penalty)
	await delay(0.3)
	cleanup()


func delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
