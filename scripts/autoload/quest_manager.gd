extends Node

signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress_updated(quest_id: String, objective_index: int, current: int, target: int)

const MAX_ACTIVE_QUESTS := 3
const BOUNTY_BOARD_SIZE := 3

var _bounty_board: Array[String] = []
var _suspend_item_updates: int = 0


func refresh_bounty_board(target_floor: int) -> void:
	_ensure_player_data()

	var eligible_ids: Array[String] = []
	for quest_data in DataManager.get_all_quests():
		if String(quest_data.get("type", "")) != "bounty":
			continue
		if not _is_quest_available_for_floor(quest_data, target_floor):
			continue
		var quest_id: String = String(quest_data.get("id", ""))
		if quest_id.is_empty() or _is_quest_active(quest_id):
			continue
		if _is_non_repeatable_completed(quest_id, quest_data):
			continue
		eligible_ids.append(quest_id)

	eligible_ids.shuffle()
	_bounty_board.clear()
	for index in range(min(BOUNTY_BOARD_SIZE, eligible_ids.size())):
		_bounty_board.append(eligible_ids[index])


func get_bounty_board() -> Array[Dictionary]:
	_ensure_player_data()
	var result: Array[Dictionary] = []
	for quest_id in _bounty_board:
		var quest_data: Dictionary = DataManager.get_quest(quest_id)
		if quest_data.is_empty():
			continue
		if _is_quest_active(quest_id):
			continue
		if _is_non_repeatable_completed(quest_id, quest_data):
			continue
		result.append(Dictionary(quest_data).duplicate(true))
	return result


func get_available_side_quests(current_floor: int) -> Array[Dictionary]:
	_ensure_player_data()
	var result: Array[Dictionary] = []
	for quest_data in DataManager.get_all_quests():
		if String(quest_data.get("type", "")) != "side":
			continue
		var quest_id: String = String(quest_data.get("id", ""))
		if quest_id.is_empty():
			continue
		if _is_quest_active(quest_id):
			continue
		if _is_non_repeatable_completed(quest_id, quest_data):
			continue
		if not _is_side_quest_available(quest_data, current_floor):
			continue
		result.append(Dictionary(quest_data).duplicate(true))
	return result


func get_available_main_quests(current_floor: int) -> Array[Dictionary]:
	_ensure_player_data()
	var result: Array[Dictionary] = []
	for quest_data in DataManager.get_all_quests():
		if String(quest_data.get("type", "")) != "main":
			continue
		var quest_id: String = String(quest_data.get("id", ""))
		if quest_id.is_empty():
			continue
		if _is_quest_active(quest_id):
			continue
		if _is_non_repeatable_completed(quest_id, quest_data):
			continue
		if not _is_main_quest_available(quest_data, current_floor):
			continue
		result.append(Dictionary(quest_data).duplicate(true))
	return result


func check_auto_main_quests(current_floor: int) -> void:
	_ensure_player_data()
	for quest_data in get_available_main_quests(current_floor):
		var quest_id: String = String(quest_data.get("id", ""))
		if quest_id.is_empty():
			continue
		if _is_quest_active(quest_id):
			continue
		if PlayerManager.player_data.active_quests.size() >= MAX_ACTIVE_QUESTS:
			continue
		var trigger: String = String(quest_data.get("trigger", "auto"))
		if trigger != "auto":
			continue
		var available_from: int = int(quest_data.get("available_from_floor", 1))
		var progress_floor: int = current_floor
		if PlayerManager.player_data != null:
			progress_floor = maxi(progress_floor, PlayerManager.player_data.highest_floor)
		if progress_floor >= available_from:
			accept_quest(quest_id)


func accept_quest(quest_id: String) -> Dictionary:
	_ensure_player_data()

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_id.is_empty() or quest_data.is_empty():
		return {"success": false, "reason": "not_found"}
	if _is_quest_active(quest_id):
		return {"success": false, "reason": "already_active"}
	if PlayerManager.player_data.active_quests.size() >= MAX_ACTIVE_QUESTS:
		return {"success": false, "reason": "max_quests"}
	if _is_non_repeatable_completed(quest_id, quest_data):
		return {"success": false, "reason": "already_completed"}

	var progress: Array[int] = []
	for objective in Array(quest_data.get("objectives", [])):
		progress.append(_get_initial_objective_progress(Dictionary(objective)))

	PlayerManager.player_data.active_quests.append({
		"id": quest_id,
		"progress": progress,
	})
	quest_accepted.emit(quest_id)

	for objective_index in range(progress.size()):
		quest_progress_updated.emit(
			quest_id,
			objective_index,
			int(progress[objective_index]),
			_get_objective_target(Dictionary(Array(quest_data.get("objectives", []))[objective_index]))
		)

	return {"success": true, "reason": ""}


func abandon_quest(quest_id: String) -> void:
	_ensure_player_data()
	var active_index: int = _find_active_quest_index(quest_id)
	if active_index >= 0:
		PlayerManager.player_data.active_quests.remove_at(active_index)


func get_active_quests() -> Array[Dictionary]:
	_ensure_player_data()

	var result: Array[Dictionary] = []
	for raw_entry in PlayerManager.player_data.active_quests:
		if raw_entry is not Dictionary:
			continue
		var _active_entry: Dictionary = Dictionary(raw_entry)
		var quest_id: String = String(_active_entry.get("id", ""))
		var quest_data: Dictionary = DataManager.get_quest(quest_id)
		if quest_data.is_empty():
			continue

		var objective_states: Array[Dictionary] = _build_objective_states(quest_data, _active_entry)
		var merged: Dictionary = Dictionary(quest_data).duplicate(true)
		merged["progress"] = Array(_active_entry.get("progress", [])).duplicate()
		merged["objective_states"] = objective_states
		merged["is_complete"] = _are_objectives_complete(objective_states)
		result.append(merged)
	return result


func check_quest_completion(quest_id: String) -> bool:
	var active_index: int = _find_active_quest_index(quest_id)
	if active_index < 0:
		return false
	var active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[active_index])
	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return false
	return _are_objectives_complete(_build_objective_states(quest_data, active_entry))


func complete_quest(quest_id: String) -> Dictionary:
	_ensure_player_data()

	var active_index: int = _find_active_quest_index(quest_id)
	if active_index < 0:
		return {"success": false, "reason": "not_found", "rewards": {}}

	_refresh_collect_progress(active_index)
	var _active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[active_index])
	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return {"success": false, "reason": "not_found", "rewards": {}}
	if not check_quest_completion(quest_id):
		return {
			"success": false,
			"reason": "not_ready",
			"rewards": Dictionary(quest_data.get("rewards", {})).duplicate(true),
		}

	var missing_collect_items: Array[Dictionary] = _collect_missing_completion_items(quest_data)
	if not missing_collect_items.is_empty():
		return {
			"success": false,
			"reason": "missing_items",
			"rewards": Dictionary(quest_data.get("rewards", {})).duplicate(true),
			"missing_items": missing_collect_items,
		}

	var consumed_items: Array[Dictionary] = []
	_suspend_item_updates += 1
	for objective in Array(quest_data.get("objectives", [])):
		var objective_data: Dictionary = Dictionary(objective)
		if String(objective_data.get("type", "")) != "collect":
			continue
		var item_id: String = String(objective_data.get("item_id", "")).strip_edges()
		var count: int = _get_objective_target(objective_data)
		if item_id.is_empty() or count <= 0:
			continue
		if PlayerManager.remove_item(item_id, count):
			consumed_items.append({"id": item_id, "count": count})
			continue

		for consumed in consumed_items:
			PlayerManager.add_item(String(consumed.get("id", "")), int(consumed.get("count", 0)))
		_suspend_item_updates -= 1
		on_item_changed()
		return {
			"success": false,
			"reason": "missing_items",
			"rewards": Dictionary(quest_data.get("rewards", {})).duplicate(true),
			"missing_items": _collect_missing_completion_items(quest_data),
		}

	var rewards: Dictionary = Dictionary(quest_data.get("rewards", {})).duplicate(true)
	_grant_rewards(rewards)
	_suspend_item_updates -= 1

	PlayerManager.player_data.active_quests.remove_at(active_index)
	_append_completed_quest(quest_id)
	on_item_changed()

	quest_completed.emit(quest_id)

	# Auto-trigger next main quest after completing one with next_quest
	var next_quest_id: String = String(quest_data.get("next_quest", ""))
	if not next_quest_id.is_empty() and not _is_quest_active(next_quest_id):
		var next_quest_data: Dictionary = DataManager.get_quest(next_quest_id)
		if not next_quest_data.is_empty() and String(next_quest_data.get("type", "")) == "main":
			var current_floor: int = PlayerManager.player_data.highest_floor if PlayerManager.player_data != null else 1
			if _is_main_quest_available(next_quest_data, current_floor):
				if PlayerManager.player_data.active_quests.size() < MAX_ACTIVE_QUESTS:
					accept_quest(next_quest_id)

	return {"success": true, "reason": "", "rewards": rewards}


func on_enemy_defeated(enemy_id: String) -> void:
	_ensure_player_data()
	if enemy_id.is_empty():
		return

	for active_index in range(PlayerManager.player_data.active_quests.size()):
		var active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[active_index]).duplicate(true)
		var quest_id: String = String(active_entry.get("id", ""))
		var quest_data: Dictionary = DataManager.get_quest(quest_id)
		if quest_data.is_empty():
			continue

		var progress: Array = Array(active_entry.get("progress", []))
		var objectives: Array = Array(quest_data.get("objectives", []))
		var changed := false
		for objective_index in range(objectives.size()):
			var objective: Dictionary = Dictionary(objectives[objective_index])
			if String(objective.get("type", "")) != "kill":
				continue
			if String(objective.get("target_id", "")) != enemy_id:
				continue

			var target: int = _get_objective_target(objective)
			var current: int = _get_progress_value(progress, objective_index)
			var new_current: int = mini(current + 1, target)
			if new_current == current:
				continue
			_set_progress_value(progress, objective_index, new_current)
			quest_progress_updated.emit(quest_id, objective_index, new_current, target)
			changed = true

		if changed:
			active_entry["progress"] = progress
			PlayerManager.player_data.active_quests[active_index] = active_entry


func on_item_changed() -> void:
	_ensure_player_data()
	if _suspend_item_updates > 0:
		return

	for active_index in range(PlayerManager.player_data.active_quests.size()):
		_refresh_collect_progress(active_index)


func on_floor_reached(target_floor: int) -> void:
	_ensure_player_data()
	if target_floor <= 0:
		return

	for active_index in range(PlayerManager.player_data.active_quests.size()):
		var active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[active_index]).duplicate(true)
		var quest_id: String = String(active_entry.get("id", ""))
		var quest_data: Dictionary = DataManager.get_quest(quest_id)
		if quest_data.is_empty():
			continue

		var progress: Array = Array(active_entry.get("progress", []))
		var objectives: Array = Array(quest_data.get("objectives", []))
		var changed := false
		for objective_index in range(objectives.size()):
			var objective: Dictionary = Dictionary(objectives[objective_index])
			if String(objective.get("type", "")) != "reach_floor":
				continue

			var target_floor_val: int = int(objective.get("floor", 0))
			var target: int = _get_objective_target(objective)
			var current: int = _get_progress_value(progress, objective_index)
			var new_current: int = target if target_floor >= target_floor_val else current
			if new_current == current:
				continue
			_set_progress_value(progress, objective_index, new_current)
			quest_progress_updated.emit(quest_id, objective_index, new_current, target)
			changed = true

		if changed:
			active_entry["progress"] = progress
			PlayerManager.player_data.active_quests[active_index] = active_entry


func on_boss_defeated(target_floor: int) -> void:
	_ensure_player_data()
	if target_floor <= 0:
		return

	for active_index in range(PlayerManager.player_data.active_quests.size()):
		var active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[active_index]).duplicate(true)
		var quest_id: String = String(active_entry.get("id", ""))
		var quest_data: Dictionary = DataManager.get_quest(quest_id)
		if quest_data.is_empty():
			continue

		var progress: Array = Array(active_entry.get("progress", []))
		var objectives: Array = Array(quest_data.get("objectives", []))
		var changed := false
		for objective_index in range(objectives.size()):
			var objective: Dictionary = Dictionary(objectives[objective_index])
			if String(objective.get("type", "")) != "kill_boss":
				continue
			if int(objective.get("floor", 0)) != target_floor:
				continue

			var target: int = _get_objective_target(objective)
			var current: int = _get_progress_value(progress, objective_index)
			if current >= target:
				continue
			_set_progress_value(progress, objective_index, target)
			quest_progress_updated.emit(quest_id, objective_index, target, target)
			changed = true

		if changed:
			active_entry["progress"] = progress
			PlayerManager.player_data.active_quests[active_index] = active_entry


func _ensure_player_data() -> void:
	if PlayerManager.player_data == null:
		PlayerManager.init_new_game()


func _is_quest_available_for_floor(quest_data: Dictionary, target_floor: int) -> bool:
	var min_floor: int = int(quest_data.get("min_floor", 1))
	var max_floor: int = int(quest_data.get("max_floor", 999))
	return target_floor >= min_floor and target_floor <= max_floor


func _is_side_quest_available(quest_data: Dictionary, current_floor: int) -> bool:
	var trigger_type: String = String(quest_data.get("trigger", "auto"))
	var progress_floor: int = current_floor
	if PlayerManager.player_data != null:
		progress_floor = maxi(progress_floor, PlayerManager.player_data.highest_floor)

	match trigger_type:
		"reach_floor":
			return progress_floor >= int(quest_data.get("trigger_floor", 1))
		"auto":
			return progress_floor >= int(quest_data.get("available_from_floor", 1))
		_:
			return false


func _is_main_quest_available(quest_data: Dictionary, current_floor: int) -> bool:
	var trigger_type: String = String(quest_data.get("trigger", "auto"))
	var progress_floor: int = current_floor
	if PlayerManager.player_data != null:
		progress_floor = maxi(progress_floor, PlayerManager.player_data.highest_floor)

	match trigger_type:
		"auto":
			return progress_floor >= int(quest_data.get("available_from_floor", 1))
		"quest_complete":
			var trigger_quest: String = String(quest_data.get("trigger_quest", ""))
			if trigger_quest.is_empty():
				return false
			if PlayerManager.player_data == null:
				return false
			if not PlayerManager.player_data.completed_quests.has(trigger_quest):
				return false
			return progress_floor >= int(quest_data.get("available_from_floor", 1))
		_:
			return false


func _is_non_repeatable_completed(quest_id: String, quest_data: Dictionary) -> bool:
	return not bool(quest_data.get("repeatable", false)) and PlayerManager.player_data.completed_quests.has(quest_id)


func _is_quest_active(quest_id: String) -> bool:
	return _find_active_quest_index(quest_id) >= 0


func _find_active_quest_index(quest_id: String) -> int:
	if PlayerManager.player_data == null:
		return -1
	for index in range(PlayerManager.player_data.active_quests.size()):
		var active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[index])
		if String(active_entry.get("id", "")) == quest_id:
			return index
	return -1


func _get_initial_objective_progress(objective: Dictionary) -> int:
	match String(objective.get("type", "")):
		"collect":
			return mini(
				PlayerManager.get_item_count(String(objective.get("item_id", ""))),
				_get_objective_target(objective)
			)
		"reach_floor":
			var current_floor: int = 1
			if PlayerManager.player_data != null:
				current_floor = maxi(current_floor, PlayerManager.player_data.highest_floor)
			return _get_objective_target(objective) if current_floor >= int(objective.get("floor", 0)) else 0
		"kill_boss":
			if PlayerManager.player_data != null and PlayerManager.player_data.defeated_bosses.has(int(objective.get("floor", 0))):
				return _get_objective_target(objective)
			return 0
		_:
			return 0


func _get_objective_target(objective: Dictionary) -> int:
	match String(objective.get("type", "")):
		"kill", "collect":
			return max(int(objective.get("count", 1)), 1)
		"reach_floor", "kill_boss":
			return max(int(objective.get("count", 1)), 1)
		_:
			return max(int(objective.get("count", 1)), 1)


func _get_progress_value(progress: Array, objective_index: int) -> int:
	if objective_index < 0 or objective_index >= progress.size():
		return 0
	return max(int(progress[objective_index]), 0)


func _set_progress_value(progress: Array, objective_index: int, value: int) -> void:
	while progress.size() <= objective_index:
		progress.append(0)
	progress[objective_index] = max(value, 0)


func _refresh_collect_progress(active_index: int) -> void:
	var active_entry: Dictionary = Dictionary(PlayerManager.player_data.active_quests[active_index]).duplicate(true)
	var quest_id: String = String(active_entry.get("id", ""))
	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return

	var progress: Array = Array(active_entry.get("progress", []))
	var objectives: Array = Array(quest_data.get("objectives", []))
	var changed := false
	for objective_index in range(objectives.size()):
		var objective: Dictionary = Dictionary(objectives[objective_index])
		if String(objective.get("type", "")) != "collect":
			continue
		var target: int = _get_objective_target(objective)
		var current_count: int = mini(
			PlayerManager.get_item_count(String(objective.get("item_id", ""))),
			target
		)
		var old_value: int = _get_progress_value(progress, objective_index)
		if old_value == current_count:
			continue
		_set_progress_value(progress, objective_index, current_count)
		quest_progress_updated.emit(quest_id, objective_index, current_count, target)
		changed = true

	if changed:
		active_entry["progress"] = progress
		PlayerManager.player_data.active_quests[active_index] = active_entry


func _collect_missing_completion_items(quest_data: Dictionary) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	for objective in Array(quest_data.get("objectives", [])):
		var objective_data: Dictionary = Dictionary(objective)
		if String(objective_data.get("type", "")) != "collect":
			continue
		var item_id: String = String(objective_data.get("item_id", "")).strip_edges()
		var need: int = _get_objective_target(objective_data)
		if item_id.is_empty() or need <= 0:
			continue
		var have: int = PlayerManager.get_item_count(item_id)
		if have >= need:
			continue
		missing.append({
			"id": item_id,
			"name": String(DataManager.get_item(item_id).get("name", item_id)),
			"need": need,
			"have": have,
		})
	return missing


func _build_objective_states(quest_data: Dictionary, active_entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var objectives: Array = Array(quest_data.get("objectives", []))
	var progress: Array = Array(active_entry.get("progress", []))
	for objective_index in range(objectives.size()):
		var objective: Dictionary = Dictionary(objectives[objective_index])
		var target: int = _get_objective_target(objective)
		var current: int = mini(_get_progress_value(progress, objective_index), target)
		result.append({
			"objective_index": objective_index,
			"type": String(objective.get("type", "")),
			"current": current,
			"target": target,
			"completed": current >= target,
			"target_id": String(objective.get("target_id", "")),
			"item_id": String(objective.get("item_id", "")),
			"floor": int(objective.get("floor", 0)),
			"label": _build_objective_label(objective, current, target),
		})
	return result


func _build_objective_label(objective: Dictionary, current: int, target: int) -> String:
	match String(objective.get("type", "")):
		"kill":
			var enemy_id: String = String(objective.get("target_id", ""))
			var enemy_name: String = String(DataManager.get_enemy(enemy_id).get("name", enemy_id))
			return "討伐 %s：%d/%d" % [enemy_name, current, target]
		"collect":
			var item_id: String = String(objective.get("item_id", ""))
			var item_name: String = String(DataManager.get_item(item_id).get("name", item_id))
			return "收集 %s：%d/%d" % [item_name, current, target]
		"reach_floor":
			return "抵達 %dF：%d/%d" % [int(objective.get("floor", 0)), current, target]
		"kill_boss":
			return "擊敗 %dF Boss：%d/%d" % [int(objective.get("floor", 0)), current, target]
		_:
			return "目標進度：%d/%d" % [current, target]


func _are_objectives_complete(objective_states: Array[Dictionary]) -> bool:
	if objective_states.is_empty():
		return false
	for objective_state in objective_states:
		if not bool(objective_state.get("completed", false)):
			return false
	return true


func _grant_rewards(rewards: Dictionary) -> void:
	var gold: int = max(int(rewards.get("gold", 0)), 0)
	if gold > 0:
		PlayerManager.add_gold(gold)

	var exp_amount: int = max(int(rewards.get("exp", 0)), 0)
	if exp_amount > 0:
		PlayerManager.add_exp(exp_amount)

	for raw_item in Array(rewards.get("items", [])):
		if raw_item is not Dictionary:
			continue
		var item_reward: Dictionary = Dictionary(raw_item)
		var item_id: String = String(item_reward.get("id", "")).strip_edges()
		var count: int = max(int(item_reward.get("count", 0)), 0)
		if item_id.is_empty() or count <= 0:
			continue
		PlayerManager.add_item(item_id, count)

	for raw_skill_id in Array(rewards.get("skills", [])):
		var skill_id: String = String(raw_skill_id).strip_edges()
		if skill_id.is_empty():
			continue
		if DataManager.get_skill(skill_id).is_empty():
			continue
		PlayerManager.learn_skill(skill_id)


func _append_completed_quest(quest_id: String) -> void:
	if quest_id.is_empty():
		return
	if not PlayerManager.player_data.completed_quests.has(quest_id):
		PlayerManager.player_data.completed_quests.append(quest_id)
