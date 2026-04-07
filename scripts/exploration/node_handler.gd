class_name NodeHandler
extends RefCounted


static func generate_battle_enemies(floor_number: int, is_elite: bool) -> Array:
	var floor_enemies: Array = DataManager.get_enemies_by_floor(floor_number)
	if floor_enemies.is_empty():
		return ["enemy_fire_sprite"]

	var enemy_ids: Array = []
	var count: int = 1 if is_elite else randi_range(1, 3)
	for _index in range(count):
		var enemy_data: Dictionary = floor_enemies[randi() % floor_enemies.size()]
		var enemy_id: String = _sanitize_enemy_id(String(enemy_data.get("id", "")))
		if not enemy_id.is_empty():
			enemy_ids.append(enemy_id)

	if enemy_ids.is_empty():
		enemy_ids.append("enemy_fire_sprite")

	return enemy_ids


static func build_battle_config(floor_number: int, zone_element: String, is_boss: bool, is_elite: bool = false) -> Dictionary:
	var active_familiar: Dictionary = PlayerManager.get_active_familiar()
	var familiar_id: String = String(active_familiar.get("id", ""))
	var familiar_level: int = int(active_familiar.get("level", 1))
	var familiar_skill_ids: Array = []
	if not active_familiar.is_empty():
		familiar_skill_ids = Array(active_familiar.get("skill_ids", [])).duplicate(true)

	return {
		"floor": floor_number,
		"is_boss": is_boss,
		"is_elite": is_elite,
		"environment_element": zone_element,
		"familiar_id": familiar_id,
		"familiar_level": familiar_level,
		"familiar_skill_ids": familiar_skill_ids,
	}


static func pick_event(floor_number: int) -> Dictionary:
	var all_events: Dictionary = {}
	var event_types: Array = ["discovery", "encounter", "trap", "puzzle", "environment", "story"]
	for raw_event_type in event_types:
		var event_type: String = String(raw_event_type)
		var events: Array = DataManager.get_events_by_type(event_type)
		for raw_event in events:
			var event: Dictionary = raw_event
			var floor_range: Array = Array(event.get("floor_range", [1, 100]))
			if floor_range.size() < 2:
				continue
			var min_floor: int = int(floor_range[0])
			var max_floor: int = int(floor_range[1])
			if floor_number >= min_floor and floor_number <= max_floor:
				all_events[String(event.get("id", ""))] = event

	if all_events.is_empty():
		return _fallback_event()

	var total_weight: int = 0
	var entries: Array = []
	for raw_event_id in all_events.keys():
		var event: Dictionary = all_events[raw_event_id]
		var weight: int = int(event.get("weight", 10))
		entries.append({"event": event, "weight": weight})
		total_weight += weight

	if total_weight <= 0:
		return _fallback_event()

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		cumulative += int(entry.get("weight", 0))
		if roll < cumulative:
			return Dictionary(entry.get("event", {}))

	return _fallback_event()


static func evaluate_option_condition(option: Dictionary) -> bool:
	var condition = option.get("condition", null)
	if condition == null:
		return true
	if condition is not Dictionary:
		return true
	var condition_dict: Dictionary = condition
	if condition_dict.is_empty():
		return true

	var required_skill: String = String(condition_dict.get("has_skill", ""))
	if not required_skill.is_empty():
		if PlayerManager.player_data == null:
			return false
		if not PlayerManager.player_data.learned_skill_ids.has(required_skill):
			return false

	var min_mp: int = int(condition_dict.get("min_mp", 0))
	if min_mp > 0:
		if PlayerManager.player_data == null:
			return false
		if PlayerManager.player_data.current_mp < min_mp:
			return false

	return true


static func execute_event_results(option: Dictionary) -> Array:
	var outcomes: Array = []

	var cost = option.get("cost", null)
	if cost is Dictionary and PlayerManager.player_data != null:
		var cost_dict: Dictionary = cost
		var mp_cost: int = int(cost_dict.get("mp", 0))
		if mp_cost > 0:
			PlayerManager.player_data.current_mp = max(0, PlayerManager.player_data.current_mp - mp_cost)
			PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())
			outcomes.append({"type": "cost", "text": "消耗 %d MP" % mp_cost})

	var results: Array = Array(option.get("results", []))
	for raw_result in results:
		if raw_result is not Dictionary:
			continue
		var result: Dictionary = raw_result
		var result_type: String = String(result.get("type", ""))
		var chance: float = float(result.get("chance", 1.0))
		if randf() > chance:
			continue

		match result_type:
			"gold_reward":
				var min_gold: int = int(result.get("min", 10))
				var max_gold: int = int(result.get("max", 50))
				var amount: int = randi_range(min_gold, max_gold)
				PlayerManager.add_gold(amount)
				outcomes.append({"type": "gold", "text": "獲得 %d 金幣" % amount})
			"item_reward":
				var item_id: String = String(result.get("item_id", ""))
				if not item_id.is_empty():
					PlayerManager.add_item(item_id)
				var item_data: Dictionary = DataManager.get_item(item_id)
				var item_name: String = String(item_data.get("name", item_id if not item_id.is_empty() else "未知道具"))
				outcomes.append({"type": "item", "text": "獲得 %s" % item_name, "item_id": item_id})
			"battle":
				var enemy_id: String = _sanitize_enemy_id(String(result.get("enemy_id", "")))
				outcomes.append({"type": "battle", "text": "遭遇敵人！", "enemy_id": enemy_id})
			"familiar_reward":
				var familiar_id: String = String(result.get("familiar_id", ""))
				var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
				var familiar_name: String = String(familiar_data.get("name", familiar_id if not familiar_id.is_empty() else "未知使魔"))
				if PlayerManager.player_data != null and PlayerManager.player_data.owned_familiars.size() >= PlayerManager.FAMILIAR_ROSTER_LIMIT:
					outcomes.append({"type": "familiar", "text": "使魔小屋已滿，無法帶回 %s" % familiar_name, "familiar_id": familiar_id})
				else:
					var familiar_index: int = PlayerManager.add_familiar(familiar_id)
					if familiar_index >= 0:
						outcomes.append({"type": "familiar", "text": "%s 願意加入隊伍！" % familiar_name, "familiar_id": familiar_id})
					else:
						outcomes.append({"type": "familiar", "text": "未能帶回 %s" % familiar_name, "familiar_id": familiar_id})
			"research_points":
				var value: int = int(result.get("value", 0))
				outcomes.append({"type": "research", "text": "獲得 %d 研究點數" % value})
			_:
				outcomes.append({"type": "unknown", "text": "（%s - 尚未實作）" % result_type})

	if outcomes.is_empty():
		outcomes.append({"type": "nothing", "text": "什麼也沒有發生。"})

	return outcomes


static func generate_chest_reward(floor_number: int) -> Dictionary:
	var rarity: String = _get_chest_rarity(floor_number)
	var gold_base: int = 20 + floor_number * 5
	var gold_min: int = int(float(gold_base) * 0.8)
	var gold_max: int = int(float(gold_base) * 1.2)
	var gold: int = randi_range(gold_min, gold_max)
	var items: Array = []

	PlayerManager.add_gold(gold)

	var chest_candidates: Array = ["item_hp_potion_s", "item_mp_potion_s"]
	if floor_number >= 10:
		chest_candidates.append("item_hp_potion_m")

	if randf() < 0.6:
		var picked_id: String = String(chest_candidates[randi() % chest_candidates.size()])
		var amount: int = randi_range(1, 2)
		var before_count: int = PlayerManager.get_item_count(picked_id)
		if PlayerManager.add_item(picked_id, amount):
			var after_count: int = PlayerManager.get_item_count(picked_id)
			var actual_added: int = after_count - before_count
			if actual_added > 0:
				var item_data: Dictionary = DataManager.get_item(picked_id)
				items.append({
					"id": picked_id,
					"name": String(item_data.get("name", picked_id)),
					"count": actual_added,
				})

	return {
		"rarity": rarity,
		"gold": gold,
		"items": items,
	}


static func generate_merchant_stock(floor_number: int) -> Array:
	var stock: Array = []
	var candidate_ids: Array = [
		"item_hp_potion_s",
		"item_hp_potion_m",
		"item_mp_potion_s",
		"weapon_apprentice_staff",
		"armor_apprentice_robe",
	]
	var candidates: Array = []

	for raw_item_id in candidate_ids:
		var item_id: String = String(raw_item_id)
		var item_data: Dictionary = DataManager.get_item(item_id)
		if item_data.is_empty():
			continue
		var available_from_floor: int = int(item_data.get("available_from_floor", 1))
		if floor_number < available_from_floor:
			continue
		var price: int = int(item_data.get("buy_price", 0))
		if price <= 0:
			continue
		candidates.append({
			"id": item_id,
			"name": String(item_data.get("name", item_id)),
			"price": price,
		})

	if candidates.is_empty():
		return stock

	candidates.shuffle()
	var desired_count: int = randi_range(3, 5)
	var final_count: int = min(desired_count, candidates.size())
	for index in range(final_count):
		stock.append(Dictionary(candidates[index]))

	return stock


static func buy_item(item: Dictionary) -> Dictionary:
	var price: int = int(item.get("price", 0))
	if PlayerManager.player_data == null:
		return {"success": false, "reason": "no_player"}
	if PlayerManager.player_data.gold < price:
		return {"success": false, "reason": "no_gold"}

	PlayerManager.spend_gold(price)
	PlayerManager.add_item(String(item.get("id", "")))
	return {
		"success": true,
		"item_id": String(item.get("id", "")),
		"item_name": String(item.get("name", "")),
		"price": price,
	}


static func apply_rest() -> Dictionary:
	if PlayerManager.player_data == null:
		return {}

	var max_hp: int = PlayerManager.get_max_hp()
	var max_mp: int = PlayerManager.get_max_mp()
	var hp_restore_request: int = int(float(max_hp) * 0.3)
	var mp_restore_request: int = int(float(max_mp) * 0.3)
	var hp_before: int = PlayerManager.player_data.current_hp
	var mp_before: int = PlayerManager.player_data.current_mp

	PlayerManager.heal_hp(hp_restore_request)
	PlayerManager.restore_mp(mp_restore_request)

	return {
		"hp_restored": PlayerManager.player_data.current_hp - hp_before,
		"mp_restored": PlayerManager.player_data.current_mp - mp_before,
		"current_hp": PlayerManager.player_data.current_hp,
		"current_mp": PlayerManager.player_data.current_mp,
		"max_hp": max_hp,
		"max_mp": max_mp,
	}


static func get_altar_options() -> Array:
	return [
		{
			"id": "blood_altar",
			"name": "血之祭壇",
			"description": "獻祭 30% 當前 HP",
			"cost_type": "hp",
			"cost_percent": 0.3,
			"reward": "隨機稀有技能卷軸",
		},
		{
			"id": "mana_altar",
			"name": "魔力祭壇",
			"description": "獻祭 50% 當前 MP",
			"cost_type": "mp",
			"cost_percent": 0.5,
			"reward": "永久 MP 上限 +5",
		},
		{
			"id": "wealth_altar",
			"name": "財富祭壇",
			"description": "獻祭 500G",
			"cost_type": "gold",
			"cost_value": 500,
			"reward": "隨機稀有飾品",
		},
		{
			"id": "leave",
			"name": "離開",
			"description": "不進行獻祭",
			"cost_type": "none",
		},
	]


static func execute_altar(altar_id: String) -> Dictionary:
	if PlayerManager.player_data == null:
		return {"success": false, "reason": "no_player"}

	match altar_id:
		"blood_altar":
			var hp_cost: int = int(float(PlayerManager.player_data.current_hp) * 0.3)
			if hp_cost <= 0:
				return {"success": false, "reason": "insufficient"}
			PlayerManager.player_data.current_hp = max(1, PlayerManager.player_data.current_hp - hp_cost)
			PlayerManager.player_hp_changed.emit(PlayerManager.player_data.current_hp, PlayerManager.get_max_hp())
			return {"success": true, "text": "獻祭了 %d HP，獲得技能卷軸（待實作）" % hp_cost}
		"mana_altar":
			var mp_cost: int = int(float(PlayerManager.player_data.current_mp) * 0.5)
			if mp_cost <= 0:
				return {"success": false, "reason": "insufficient"}
			PlayerManager.player_data.current_mp = max(0, PlayerManager.player_data.current_mp - mp_cost)
			PlayerManager.player_data.base_mp += 5
			PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())
			return {"success": true, "text": "獻祭了 %d MP，MP 上限永久 +5！" % mp_cost}
		"wealth_altar":
			if PlayerManager.player_data.gold < 500:
				return {"success": false, "reason": "no_gold"}
			PlayerManager.spend_gold(500)
			return {"success": true, "text": "獻祭了 500G，獲得稀有飾品（待實作）"}
		"leave":
			return {"success": true, "text": "你離開了祭壇。"}
		_:
			return {"success": false, "reason": "unknown"}


static func _fallback_event() -> Dictionary:
	return {
		"id": "event_fallback",
		"name": "寧靜的走廊",
		"type": "fallback",
		"description": "這裡什麼也沒有，只有安靜的空氣。",
		"options": [
			{
				"text": "繼續前進",
				"condition": null,
				"results": [],
			}
		],
		"conditional_options": [],
	}


static func _get_chest_rarity(floor_number: int) -> String:
	if floor_number >= 81:
		return ["SR", "SSR"][randi() % 2]
	if floor_number >= 51:
		return ["R", "SR"][randi() % 2]
	if floor_number >= 21:
		return ["R", "R"][randi() % 2]
	return ["N", "R"][randi() % 2]


static func _sanitize_enemy_id(enemy_id: String) -> String:
	if enemy_id.is_empty():
		return "enemy_fire_sprite"
	if DataManager.get_enemy(enemy_id).is_empty():
		return "enemy_fire_sprite"
	return enemy_id
