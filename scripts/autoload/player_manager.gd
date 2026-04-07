extends Node

signal player_level_up(new_level: int)
signal player_hp_changed(new_hp: int, max_hp: int)
signal player_mp_changed(new_mp: int, max_mp: int)
signal player_gold_changed(new_gold: int)
signal player_died
signal equipment_changed
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal item_used(item_id: String)
signal familiar_added(index: int)
signal familiar_removed(index: int)
signal familiar_trained(index: int, new_level: int)
signal active_familiar_changed(index: int)

const PlayerDataResource = preload("res://scripts/data/player_data.gd")
const InventoryClass = preload("res://scripts/data/inventory.gd")
const GROWTH_PER_LEVEL := {
	"base_hp": 12,
	"base_mp": 8,
	"base_matk": 3,
	"base_mdef": 2,
	"base_patk": 1,
	"base_pdef": 1,
	"base_speed": 1,
}
const FAMILIAR_ROSTER_LIMIT := 10
const SAVE_FIELDS := [
	"name",
	"level",
	"exp",
	"gold",
	"base_hp",
	"base_mp",
	"base_matk",
	"base_mdef",
	"base_patk",
	"base_pdef",
	"base_speed",
	"base_hit",
	"base_dodge",
	"base_crit",
	"current_hp",
	"current_mp",
	"weapon_id",
	"weapon_enhance",
	"armor_id",
	"armor_enhance",
	"accessory_ids",
	"accessory_enhances",
	"active_skill_ids",
	"passive_skill_ids",
	"learned_skill_ids",
	"skill_proficiency",
	"highest_floor",
	"unlocked_teleports",
	"defeated_bosses",
	"title",
	"titles_unlocked",
	"owned_familiars",
	"active_familiar_index",
	"discovered_familiar_ids",
	"discovered_item_ids",
	"discovered_enemy_ids",
]

var player_data: PlayerDataResource
var inventory = null
var _active_buffs: Array[Dictionary] = []
var _last_unequipped_enhance: int = 0


func _ready() -> void:
	if player_data == null:
		init_new_game()


func init_new_game() -> void:
	player_data = PlayerDataResource.new()
	inventory = InventoryClass.new()
	player_data.inventory_data = inventory.to_save_dict()
	_active_buffs.clear()
	_last_unequipped_enhance = 0
	_normalize_collection_progress()
	_normalize_owned_familiars()
	_clamp_resources()
	_emit_resource_signals()


func load_from_save(save_dict: Dictionary) -> void:
	var source := save_dict
	if save_dict.has("player") and save_dict["player"] is Dictionary:
		source = save_dict["player"]

	if player_data == null:
		player_data = PlayerDataResource.new()
	if inventory == null:
		inventory = InventoryClass.new()

	for field_name in SAVE_FIELDS:
		if not source.has(field_name):
			continue

		var value = source[field_name]
		if value is Array or value is Dictionary:
			player_data.set(field_name, value.duplicate(true))
		else:
			player_data.set(field_name, value)

	var inventory_source = save_dict.get("inventory", source.get("inventory", {}))
	if inventory_source is Dictionary:
		inventory.load_from_dict(inventory_source)
	else:
		inventory.clear()
	while player_data.accessory_enhances.size() < player_data.accessory_ids.size():
		player_data.accessory_enhances.append(0)
	player_data.inventory_data = inventory.to_save_dict()

	_active_buffs.clear()
	_normalize_collection_progress()
	_backfill_item_discovery_from_inventory()
	_normalize_owned_familiars()
	_clamp_resources()
	_emit_resource_signals()
	player_gold_changed.emit(player_data.gold)


func to_save_dict() -> Dictionary:
	if player_data == null:
		init_new_game()
	if inventory == null:
		inventory = InventoryClass.new()

	_normalize_collection_progress()
	_backfill_item_discovery_from_inventory()
	_normalize_owned_familiars()

	var save_dict: Dictionary = {}
	for field_name in SAVE_FIELDS:
		var value = player_data.get(field_name)
		if value is Array or value is Dictionary:
			save_dict[field_name] = value.duplicate(true)
		else:
			save_dict[field_name] = value

	player_data.inventory_data = inventory.to_save_dict()
	save_dict["inventory"] = player_data.inventory_data.duplicate(true)
	return save_dict


func get_max_hp() -> int:
	_ensure_player_data()
	return max(player_data.base_hp + _get_equipment_bonus("hp") + _get_buff_bonus("hp"), 1)


func get_max_mp() -> int:
	_ensure_player_data()
	return max(player_data.base_mp + _get_equipment_bonus("mp") + _get_buff_bonus("mp"), 0)


func get_matk() -> int:
	_ensure_player_data()
	return max(player_data.base_matk + _get_equipment_bonus("matk") + _get_buff_bonus("matk"), 0)


func get_mdef() -> int:
	_ensure_player_data()
	return max(player_data.base_mdef + _get_equipment_bonus("mdef") + _get_buff_bonus("mdef"), 0)


func get_patk() -> int:
	_ensure_player_data()
	return max(player_data.base_patk + _get_equipment_bonus("patk") + _get_buff_bonus("patk"), 0)


func get_pdef() -> int:
	_ensure_player_data()
	return max(player_data.base_pdef + _get_equipment_bonus("pdef") + _get_buff_bonus("pdef"), 0)


func get_speed() -> int:
	_ensure_player_data()
	return max(player_data.base_speed + _get_equipment_bonus("speed") + _get_buff_bonus("speed"), 1)


func get_hit() -> int:
	_ensure_player_data()
	return max(player_data.base_hit + _get_equipment_bonus("hit") + _get_buff_bonus("hit"), 0)


func get_dodge() -> float:
	_ensure_player_data()
	return player_data.base_dodge + float(_get_equipment_bonus("dodge")) + float(_get_buff_bonus("dodge"))


func get_crit() -> float:
	_ensure_player_data()
	return player_data.base_crit + float(_get_equipment_bonus("crit")) + float(_get_buff_bonus("crit"))


func take_damage(amount: int) -> void:
	_ensure_player_data()

	player_data.current_hp = clampi(player_data.current_hp - max(amount, 0), 0, get_max_hp())
	player_hp_changed.emit(player_data.current_hp, get_max_hp())

	if player_data.current_hp <= 0:
		player_died.emit()


func heal_hp(amount: int) -> void:
	_ensure_player_data()

	player_data.current_hp = clampi(player_data.current_hp + max(amount, 0), 0, get_max_hp())
	player_hp_changed.emit(player_data.current_hp, get_max_hp())


func consume_mp(amount: int) -> void:
	_ensure_player_data()

	player_data.current_mp = clampi(player_data.current_mp - max(amount, 0), 0, get_max_mp())
	player_mp_changed.emit(player_data.current_mp, get_max_mp())


func restore_mp(amount: int) -> void:
	_ensure_player_data()

	player_data.current_mp = clampi(player_data.current_mp + max(amount, 0), 0, get_max_mp())
	player_mp_changed.emit(player_data.current_mp, get_max_mp())


func add_exp(amount: int) -> void:
	_ensure_player_data()
	if amount <= 0:
		return

	player_data.exp += amount
	_check_level_up()


func add_gold(amount: int) -> void:
	_ensure_player_data()
	if amount <= 0:
		return

	player_data.gold += amount
	player_gold_changed.emit(player_data.gold)


func spend_gold(amount: int) -> bool:
	_ensure_player_data()
	if amount < 0:
		return false

	if player_data.gold < amount:
		return false

	player_data.gold -= amount
	player_gold_changed.emit(player_data.gold)
	return true


func add_item(item_id: String, amount: int = 1) -> bool:
	_ensure_player_data()
	var result: bool = inventory.add(item_id, amount)
	if result:
		player_data.inventory_data = inventory.to_save_dict()
		discover_item(item_id)
		item_added.emit(item_id, amount)
	return result


func remove_item(item_id: String, amount: int = 1) -> bool:
	_ensure_player_data()
	var result: bool = inventory.remove(item_id, amount)
	if result:
		player_data.inventory_data = inventory.to_save_dict()
		item_removed.emit(item_id, amount)
	return result


func has_item(item_id: String, amount: int = 1) -> bool:
	if inventory == null:
		return false
	return inventory.has(item_id, amount)


func get_item_count(item_id: String) -> int:
	if inventory == null:
		return 0
	return inventory.count(item_id)


func add_familiar(familiar_id: String) -> int:
	_ensure_player_data()
	if player_data.owned_familiars.size() >= FAMILIAR_ROSTER_LIMIT:
		return -1
	var familiar_entry: Dictionary = _build_new_familiar_entry(familiar_id)
	if familiar_entry.is_empty():
		return -1

	player_data.owned_familiars.append(familiar_entry)
	discover_familiar(familiar_id)
	var new_index: int = player_data.owned_familiars.size() - 1
	familiar_added.emit(new_index)
	return new_index


func remove_familiar(index: int) -> bool:
	_ensure_player_data()
	if not _is_valid_familiar_index(index):
		return false

	var removed_active: bool = player_data.active_familiar_index == index
	player_data.owned_familiars.remove_at(index)

	if removed_active:
		player_data.active_familiar_index = -1
		active_familiar_changed.emit(-1)
	elif player_data.active_familiar_index > index:
		player_data.active_familiar_index -= 1
		active_familiar_changed.emit(player_data.active_familiar_index)

	familiar_removed.emit(index)
	return true


func hatch_familiar(core_item_id: String) -> Dictionary:
	_ensure_player_data()
	if player_data.owned_familiars.size() >= FAMILIAR_ROSTER_LIMIT:
		return {"success": false, "reason": "roster_full", "familiar_id": "", "familiar_name": ""}

	var core_data: Dictionary = DataManager.get_item(core_item_id)
	if core_data.is_empty() or String(core_data.get("type", "")) != "familiar_core":
		return {"success": false, "reason": "invalid_data", "familiar_id": "", "familiar_name": ""}

	var familiar_id: String = String(core_data.get("hatches_into", ""))
	var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
	if familiar_id.is_empty() or familiar_data.is_empty():
		return {"success": false, "reason": "invalid_data", "familiar_id": "", "familiar_name": ""}

	if not has_item(core_item_id):
		return {"success": false, "reason": "no_core", "familiar_id": familiar_id, "familiar_name": String(familiar_data.get("name", familiar_id))}

	var hatch_cost: Dictionary = Dictionary(core_data.get("hatch_cost", {}))
	var gold_cost: int = max(int(hatch_cost.get("gold", 0)), 0)
	if gold_cost > 0 and player_data.gold < gold_cost:
		return {"success": false, "reason": "no_gold", "familiar_id": familiar_id, "familiar_name": String(familiar_data.get("name", familiar_id))}

	if gold_cost > 0 and not spend_gold(gold_cost):
		return {"success": false, "reason": "no_gold", "familiar_id": familiar_id, "familiar_name": String(familiar_data.get("name", familiar_id))}
	if not remove_item(core_item_id, 1):
		if gold_cost > 0:
			add_gold(gold_cost)
		return {"success": false, "reason": "no_core", "familiar_id": familiar_id, "familiar_name": String(familiar_data.get("name", familiar_id))}

	var new_index: int = add_familiar(familiar_id)
	if new_index < 0:
		add_item(core_item_id, 1)
		if gold_cost > 0:
			add_gold(gold_cost)
		var fail_reason: String = "roster_full" if player_data.owned_familiars.size() >= FAMILIAR_ROSTER_LIMIT else "invalid_data"
		return {"success": false, "reason": fail_reason, "familiar_id": familiar_id, "familiar_name": String(familiar_data.get("name", familiar_id))}

	return {
		"success": true,
		"reason": "",
		"familiar_id": familiar_id,
		"familiar_name": String(familiar_data.get("name", familiar_id)),
	}


func can_evolve_familiar(index: int) -> Dictionary:
	_ensure_player_data()
	var state: Dictionary = _get_familiar_evolution_state(index)
	return _build_familiar_evolution_result(state)


func evolve_familiar(index: int) -> Dictionary:
	_ensure_player_data()
	var state: Dictionary = _get_familiar_evolution_state(index)
	var result: Dictionary = _build_familiar_evolution_result(state)
	if not bool(result.get("success", false)):
		return result

	var evolution: Dictionary = Dictionary(state.get("evolution", {}))
	var consumed_items: Array[Dictionary] = []
	for raw_item in Array(evolution.get("required_items", [])):
		if raw_item is not Dictionary:
			continue
		var required_item: Dictionary = raw_item
		var item_id: String = String(required_item.get("id", ""))
		var amount: int = max(int(required_item.get("count", 0)), 0)
		if item_id.is_empty() or amount <= 0:
			continue
		if remove_item(item_id, amount):
			consumed_items.append({"id": item_id, "count": amount})
			continue

		for consumed in consumed_items:
			add_item(String(consumed.get("id", "")), int(consumed.get("count", 0)))
		result["success"] = false
		result["reason"] = "missing_items"
		result["missing"] = _collect_missing_familiar_evolution_items(evolution)
		return result

	var familiar_entry: Dictionary = Dictionary(player_data.owned_familiars[index]).duplicate(true)
	var target_id: String = String(state.get("new_id", ""))
	var target_data: Dictionary = Dictionary(state.get("target_data", {}))
	var target_max_level: int = max(int(target_data.get("max_level", 1)), 1)
	var target_skill_slots: int = max(int(target_data.get("skill_slots", 0)), 0)
	var merged_skills: Array[String] = _merge_familiar_skill_ids(
		Array(familiar_entry.get("skill_ids", [])),
		Array(target_data.get("default_skills", [])),
		target_skill_slots
	)

	familiar_entry["id"] = target_id
	familiar_entry["level"] = clampi(int(familiar_entry.get("level", 1)), 1, target_max_level)
	familiar_entry["exp"] = 0
	familiar_entry["skill_ids"] = merged_skills
	player_data.owned_familiars[index] = familiar_entry

	discover_familiar(target_id)
	familiar_trained.emit(index, int(familiar_entry.get("level", 1)))

	result["new_name"] = String(target_data.get("name", target_id))
	return result


func get_familiar_instance(index: int) -> Dictionary:
	_ensure_player_data()
	if not _is_valid_familiar_index(index):
		return {}
	return Dictionary(player_data.owned_familiars[index]).duplicate(true)


func get_active_familiar() -> Dictionary:
	_ensure_player_data()
	return get_familiar_instance(player_data.active_familiar_index)


func set_active_familiar(index: int) -> void:
	_ensure_player_data()
	if index != -1 and not _is_valid_familiar_index(index):
		return
	if player_data.active_familiar_index == index:
		return

	player_data.active_familiar_index = index
	active_familiar_changed.emit(index)


func train_familiar(index: int, exp_amount: int) -> Dictionary:
	_ensure_player_data()
	if not _is_valid_familiar_index(index) or exp_amount <= 0:
		return {"success": false, "leveled_up": false, "new_level": -1}

	var familiar := player_data.owned_familiars[index]
	var familiar_id: String = String(familiar.get("id", ""))
	var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
	if familiar_data.is_empty():
		return {"success": false, "leveled_up": false, "new_level": int(familiar.get("level", 1))}

	var max_level: int = max(int(familiar_data.get("max_level", 1)), 1)
	var current_level: int = clampi(int(familiar.get("level", 1)), 1, max_level)
	if current_level >= max_level:
		familiar["level"] = max_level
		familiar["exp"] = 0
		player_data.owned_familiars[index] = familiar
		return {"success": false, "leveled_up": false, "new_level": max_level}

	var leveled_up := false
	familiar["level"] = current_level
	familiar["exp"] = int(familiar.get("exp", 0)) + exp_amount
	while int(familiar.get("level", 1)) < max_level:
		var required_exp: int = DataManager.get_familiar_exp_required(int(familiar.get("level", 1)))
		if int(familiar.get("exp", 0)) < required_exp:
			break
		familiar["exp"] = int(familiar.get("exp", 0)) - required_exp
		familiar["level"] = int(familiar.get("level", 1)) + 1
		leveled_up = true

	if int(familiar.get("level", 1)) >= max_level:
		familiar["level"] = max_level
		familiar["exp"] = 0

	player_data.owned_familiars[index] = familiar
	if leveled_up:
		familiar_trained.emit(index, int(familiar.get("level", 1)))

	return {
		"success": true,
		"leveled_up": leveled_up,
		"new_level": int(familiar.get("level", 1)),
	}


func set_familiar_nickname(index: int, nickname: String) -> void:
	_ensure_player_data()
	if not _is_valid_familiar_index(index):
		return
	player_data.owned_familiars[index]["nickname"] = nickname.strip_edges()


func equip_familiar_skill(index: int, skill_id: String, slot: int) -> bool:
	_ensure_player_data()
	if not _is_valid_familiar_index(index) or slot < 0:
		return false

	var familiar := player_data.owned_familiars[index]
	var familiar_data: Dictionary = DataManager.get_familiar(String(familiar.get("id", "")))
	if familiar_data.is_empty():
		return false

	var skill_slots: int = max(int(familiar_data.get("skill_slots", 0)), 0)
	if slot >= skill_slots:
		return false

	var skills: Array[String] = _sanitize_familiar_skill_ids(Array(familiar.get("skill_ids", [])), skill_slots)
	while skills.size() < skill_slots:
		skills.append("")

	if skill_id.is_empty():
		skills[slot] = ""
		familiar["skill_ids"] = _trim_trailing_empty_skills(skills)
		player_data.owned_familiars[index] = familiar
		return true

	if DataManager.get_skill(skill_id).is_empty():
		return false

	for skill_index in range(skills.size()):
		if skills[skill_index] == skill_id and skill_index != slot:
			skills[skill_index] = ""

	skills[slot] = skill_id
	familiar["skill_ids"] = _trim_trailing_empty_skills(skills)
	player_data.owned_familiars[index] = familiar
	return true


func discover_familiar(familiar_id: String) -> void:
	_ensure_player_data()
	if DataManager.get_familiar(familiar_id).is_empty():
		return
	_append_unique_string(player_data.discovered_familiar_ids, familiar_id)


func discover_item(item_id: String) -> void:
	_ensure_player_data()
	if DataManager.get_item(item_id).is_empty():
		return
	_append_unique_string(player_data.discovered_item_ids, item_id)


func discover_enemy(enemy_id: String) -> void:
	_ensure_player_data()
	if DataManager.get_enemy(enemy_id).is_empty():
		return
	_append_unique_string(player_data.discovered_enemy_ids, enemy_id)


func use_item(item_id: String) -> Dictionary:
	_ensure_player_data()
	if inventory == null or not inventory.has(item_id):
		return {"success": false, "reason": "not_owned"}

	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return {"success": false, "reason": "unknown_item"}

	var item_type: String = String(item_data.get("type", ""))
	if item_type != "consumable":
		return {"success": false, "reason": "not_consumable"}

	var effects: Array = Array(item_data.get("effects", []))
	if effects.is_empty():
		return {"success": false, "reason": "no_effects"}

	inventory.remove(item_id)
	player_data.inventory_data = inventory.to_save_dict()
	item_removed.emit(item_id, 1)

	var applied: Array = []
	for raw_effect in effects:
		if raw_effect is not Dictionary:
			continue
		var effect: Dictionary = raw_effect
		var effect_type: String = String(effect.get("type", ""))
		var value: int = int(effect.get("value", 0))
		match effect_type:
			"heal_hp":
				heal_hp(value)
				applied.append("HP +%d" % value)
			"heal_mp":
				restore_mp(value)
				applied.append("MP +%d" % value)
			_:
				applied.append("(%s - 尚未實作)" % effect_type)

	item_used.emit(item_id)
	return {
		"success": true,
		"item_name": String(item_data.get("name", item_id)),
		"effects": applied,
	}


func equip_weapon(item_id: String, enhance_level: int = 0) -> String:
	_ensure_player_data()
	if not item_id.is_empty():
		discover_item(item_id)
	var old_id := player_data.weapon_id
	_last_unequipped_enhance = player_data.weapon_enhance
	player_data.weapon_id = item_id
	player_data.weapon_enhance = enhance_level
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func equip_armor(item_id: String, enhance_level: int = 0) -> String:
	_ensure_player_data()
	if not item_id.is_empty():
		discover_item(item_id)
	var old_id := player_data.armor_id
	_last_unequipped_enhance = player_data.armor_enhance
	player_data.armor_id = item_id
	player_data.armor_enhance = enhance_level
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func equip_accessory(item_id: String, slot: int, enhance_level: int = 0) -> String:
	_ensure_player_data()
	if slot < 0 or slot > 2:
		return ""
	if not item_id.is_empty():
		discover_item(item_id)

	while player_data.accessory_ids.size() <= slot:
		player_data.accessory_ids.append("")
	while player_data.accessory_enhances.size() <= slot:
		player_data.accessory_enhances.append(0)

	var old_id := player_data.accessory_ids[slot]
	_last_unequipped_enhance = int(player_data.accessory_enhances[slot])
	player_data.accessory_ids[slot] = item_id
	player_data.accessory_enhances[slot] = enhance_level
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func unequip_weapon() -> String:
	return equip_weapon("")


func unequip_armor() -> String:
	return equip_armor("")


func unequip_accessory(slot: int) -> String:
	return equip_accessory("", slot)


func get_last_unequip_enhance() -> int:
	return _last_unequipped_enhance


func learn_skill(skill_id: String) -> void:
	_ensure_player_data()
	if skill_id.is_empty():
		return

	if not player_data.learned_skill_ids.has(skill_id):
		player_data.learned_skill_ids.append(skill_id)


func equip_active_skill(skill_id: String, slot: int) -> void:
	_ensure_player_data()
	if slot < 0 or skill_id.is_empty():
		return

	while player_data.active_skill_ids.size() <= slot:
		player_data.active_skill_ids.append("")

	player_data.active_skill_ids[slot] = skill_id


func add_buff(stat: String, value: int, turns: int, source: String = "") -> void:
	_ensure_player_data()
	if stat.is_empty() or turns <= 0:
		return

	_active_buffs.append({
		"stat": stat,
		"value": value,
		"turns": turns,
		"source": source,
	})
	_refresh_player_state()


func tick_buffs() -> void:
	if _active_buffs.is_empty():
		return

	var expired: Array[int] = []
	for index in range(_active_buffs.size()):
		_active_buffs[index]["turns"] = int(_active_buffs[index].get("turns", 0)) - 1
		if int(_active_buffs[index].get("turns", 0)) <= 0:
			expired.append(index)

	expired.reverse()
	for index in expired:
		_active_buffs.remove_at(index)

	_refresh_player_state()


func clear_buffs() -> void:
	if _active_buffs.is_empty():
		return

	_active_buffs.clear()
	_refresh_player_state()


func load_familiars_from_save(familiar_save: Dictionary) -> void:
	_ensure_player_data()
	if familiar_save.is_empty():
		_normalize_owned_familiars()
		return

	var roster = familiar_save.get("roster", familiar_save.get("storage", null))
	if roster is Array:
		player_data.owned_familiars = Array(roster).duplicate(true)

	var party_value = familiar_save.get("party", null)
	if party_value is int:
		player_data.active_familiar_index = int(party_value)
	elif party_value is float:
		player_data.active_familiar_index = int(party_value)
	elif party_value is String:
		player_data.active_familiar_index = _find_first_familiar_index_by_id(String(party_value))

	_normalize_owned_familiars()


func _normalize_collection_progress() -> void:
	player_data.discovered_familiar_ids = _sanitize_string_array(player_data.discovered_familiar_ids)
	player_data.discovered_item_ids = _sanitize_string_array(player_data.discovered_item_ids)
	player_data.discovered_enemy_ids = _sanitize_string_array(player_data.discovered_enemy_ids)


func _backfill_item_discovery_from_inventory() -> void:
	if inventory == null:
		return

	for raw_entry in inventory.get_all_items():
		var item_id: String = String(Dictionary(raw_entry).get("id", ""))
		if not item_id.is_empty():
			discover_item(item_id)

	for equipped_id in player_data.accessory_ids:
		var accessory_id: String = String(equipped_id)
		if not accessory_id.is_empty():
			discover_item(accessory_id)
	if not player_data.weapon_id.is_empty():
		discover_item(player_data.weapon_id)
	if not player_data.armor_id.is_empty():
		discover_item(player_data.armor_id)


func _normalize_owned_familiars() -> void:
	var normalized: Array[Dictionary] = []
	for raw_entry in player_data.owned_familiars:
		if raw_entry is not Dictionary:
			continue
		var familiar_entry: Dictionary = _sanitize_familiar_entry(raw_entry)
		if familiar_entry.is_empty():
			continue
		normalized.append(familiar_entry)
		discover_familiar(String(familiar_entry.get("id", "")))

	player_data.owned_familiars = normalized
	if player_data.active_familiar_index < 0 or player_data.active_familiar_index >= player_data.owned_familiars.size():
		player_data.active_familiar_index = -1


func _sanitize_familiar_entry(raw_entry: Dictionary) -> Dictionary:
	var familiar_id: String = String(raw_entry.get("id", ""))
	var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
	if familiar_id.is_empty() or familiar_data.is_empty():
		return {}

	var max_level: int = max(int(familiar_data.get("max_level", 1)), 1)
	var level: int = clampi(int(raw_entry.get("level", 1)), 1, max_level)
	var exp: int = max(int(raw_entry.get("exp", 0)), 0)
	if level >= max_level:
		exp = 0
	else:
		exp = mini(exp, max(DataManager.get_familiar_exp_required(level) - 1, 0))

	var skill_slots: int = max(int(familiar_data.get("skill_slots", 0)), 0)
	var saved_skills: Array = Array(raw_entry.get("skill_ids", []))
	var skill_ids: Array[String] = _sanitize_familiar_skill_ids(saved_skills, skill_slots)
	if skill_ids.is_empty():
		skill_ids = _sanitize_familiar_skill_ids(Array(familiar_data.get("default_skills", [])), skill_slots)

	return {
		"id": familiar_id,
		"level": level,
		"exp": exp,
		"nickname": String(raw_entry.get("nickname", "")),
		"skill_ids": skill_ids,
		"obtained_at": String(raw_entry.get("obtained_at", Time.get_date_string_from_system())),
	}


func _build_new_familiar_entry(familiar_id: String) -> Dictionary:
	var familiar_data: Dictionary = DataManager.get_familiar(familiar_id)
	if familiar_data.is_empty():
		return {}

	return {
		"id": familiar_id,
		"level": 1,
		"exp": 0,
		"nickname": "",
		"skill_ids": _sanitize_familiar_skill_ids(
			Array(familiar_data.get("default_skills", [])),
			max(int(familiar_data.get("skill_slots", 0)), 0)
		),
		"obtained_at": Time.get_date_string_from_system(),
	}


func _get_familiar_evolution_state(index: int) -> Dictionary:
	if not _is_valid_familiar_index(index):
		return {"success": false, "reason": "invalid_index", "missing": []}

	var familiar_entry: Dictionary = Dictionary(player_data.owned_familiars[index]).duplicate(true)
	var old_id: String = String(familiar_entry.get("id", ""))
	var familiar_data: Dictionary = DataManager.get_familiar(old_id)
	if familiar_data.is_empty():
		return {
			"success": false,
			"reason": "no_evolution",
			"old_id": old_id,
			"new_id": "",
			"new_name": "",
			"missing": [],
		}

	var evolution: Dictionary = Dictionary(familiar_data.get("evolution", {}))
	if evolution.is_empty():
		return {
			"success": false,
			"reason": "no_evolution",
			"old_id": old_id,
			"new_id": "",
			"new_name": "",
			"missing": [],
		}

	var target_id: String = String(evolution.get("target_id", ""))
	var current_level: int = max(int(familiar_entry.get("level", 1)), 1)
	var required_level: int = max(int(evolution.get("required_level", 1)), 1)
	if current_level < required_level:
		return {
			"success": false,
			"reason": "level_too_low",
			"old_id": old_id,
			"new_id": target_id,
			"new_name": "",
			"current_level": current_level,
			"required_level": required_level,
			"missing": [],
		}

	var missing_items: Array[Dictionary] = _collect_missing_familiar_evolution_items(evolution)
	if not missing_items.is_empty():
		return {
			"success": false,
			"reason": "missing_items",
			"old_id": old_id,
			"new_id": target_id,
			"new_name": "",
			"current_level": current_level,
			"required_level": required_level,
			"missing": missing_items,
		}

	var target_data: Dictionary = DataManager.get_familiar(target_id)
	if target_id.is_empty() or target_data.is_empty():
		return {
			"success": false,
			"reason": "target_not_found",
			"old_id": old_id,
			"new_id": target_id,
			"new_name": target_id,
			"current_level": current_level,
			"required_level": required_level,
			"missing": [],
		}

	return {
		"success": true,
		"reason": "",
		"old_id": old_id,
		"new_id": target_id,
		"new_name": String(target_data.get("name", target_id)),
		"current_level": current_level,
		"required_level": required_level,
		"missing": [],
		"evolution": evolution,
		"target_data": target_data,
	}


func _sanitize_familiar_skill_ids(raw_skills: Array, max_slots: int) -> Array[String]:
	var result: Array[String] = []
	if max_slots <= 0:
		return result

	for raw_skill in raw_skills:
		var skill_id: String = String(raw_skill)
		if skill_id.is_empty():
			continue
		if not DataManager.get_skill(skill_id).is_empty() and not result.has(skill_id):
			result.append(skill_id)
		if result.size() >= max_slots:
			break
	return result


func _merge_familiar_skill_ids(current_skills: Array, default_skills: Array, max_slots: int) -> Array[String]:
	var merged: Array[String] = _sanitize_familiar_skill_ids(current_skills, max_slots)
	if merged.size() >= max_slots:
		return merged

	for skill_id in _sanitize_familiar_skill_ids(default_skills, max_slots):
		if merged.has(skill_id):
			continue
		merged.append(skill_id)
		if merged.size() >= max_slots:
			break
	return merged


func _collect_missing_familiar_evolution_items(evolution: Dictionary) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	for raw_item in Array(evolution.get("required_items", [])):
		if raw_item is not Dictionary:
			continue
		var required_item: Dictionary = raw_item
		var item_id: String = String(required_item.get("id", ""))
		var need: int = max(int(required_item.get("count", 0)), 0)
		if item_id.is_empty() or need <= 0:
			continue
		var have: int = get_item_count(item_id)
		if have >= need:
			continue
		missing.append({
			"id": item_id,
			"need": need,
			"have": have,
		})
	return missing


func _build_familiar_evolution_result(state: Dictionary) -> Dictionary:
	var missing_result: Array[Dictionary] = []
	for raw_missing in Array(state.get("missing", [])):
		if raw_missing is Dictionary:
			missing_result.append(Dictionary(raw_missing).duplicate(true))

	return {
		"success": bool(state.get("success", false)),
		"reason": String(state.get("reason", "")),
		"old_id": String(state.get("old_id", "")),
		"new_id": String(state.get("new_id", "")),
		"new_name": String(state.get("new_name", "")),
		"missing": missing_result,
		"current_level": int(state.get("current_level", 1)),
		"required_level": int(state.get("required_level", 1)),
	}


func _trim_trailing_empty_skills(skills: Array[String]) -> Array[String]:
	var result: Array[String] = []
	result.assign(skills)
	while not result.is_empty() and result[result.size() - 1].is_empty():
		result.remove_at(result.size() - 1)
	return result


func _sanitize_string_array(raw_values: Array[String]) -> Array[String]:
	var sanitized: Array[String] = []
	for raw_value in raw_values:
		var value: String = String(raw_value).strip_edges()
		if value.is_empty() or sanitized.has(value):
			continue
		sanitized.append(value)
	return sanitized


func _append_unique_string(target: Array[String], value: String) -> void:
	var cleaned: String = value.strip_edges()
	if cleaned.is_empty() or target.has(cleaned):
		return
	target.append(cleaned)


func _is_valid_familiar_index(index: int) -> bool:
	return index >= 0 and index < player_data.owned_familiars.size()


func _find_first_familiar_index_by_id(familiar_id: String) -> int:
	for index in range(player_data.owned_familiars.size()):
		if String(Dictionary(player_data.owned_familiars[index]).get("id", "")) == familiar_id:
			return index
	return -1


func _check_level_up() -> void:
	_ensure_player_data()

	while player_data.exp >= _get_exp_required(player_data.level):
		var required_exp := _get_exp_required(player_data.level)
		player_data.exp -= required_exp
		player_data.level += 1
		for stat_name in GROWTH_PER_LEVEL:
			var current_value = int(player_data.get(stat_name))
			player_data.set(stat_name, current_value + int(GROWTH_PER_LEVEL[stat_name]))

		player_data.current_hp = get_max_hp()
		player_data.current_mp = get_max_mp()
		player_level_up.emit(player_data.level)

	_emit_resource_signals()


func _get_exp_required(level: int) -> int:
	return 50 + level * level * 5


func _ensure_player_data() -> void:
	if player_data == null:
		init_new_game()
	elif inventory == null:
		inventory = InventoryClass.new()
		player_data.inventory_data = inventory.to_save_dict()


func _clamp_resources() -> void:
	player_data.current_hp = clampi(player_data.current_hp, 0, get_max_hp())
	player_data.current_mp = clampi(player_data.current_mp, 0, get_max_mp())


func _emit_resource_signals() -> void:
	player_hp_changed.emit(player_data.current_hp, get_max_hp())
	player_mp_changed.emit(player_data.current_mp, get_max_mp())


func _get_equipment_bonus(stat_name: String) -> int:
	_ensure_player_data()

	var bonus := 0
	if not player_data.weapon_id.is_empty():
		bonus += _get_item_stat_bonus(player_data.weapon_id, stat_name)
		bonus += _get_enhance_bonus(player_data.weapon_id, player_data.weapon_enhance, stat_name)

	if not player_data.armor_id.is_empty():
		bonus += _get_item_stat_bonus(player_data.armor_id, stat_name)
		bonus += _get_enhance_bonus(player_data.armor_id, player_data.armor_enhance, stat_name)

	for acc_index in range(player_data.accessory_ids.size()):
		var accessory_id: String = player_data.accessory_ids[acc_index]
		if accessory_id.is_empty():
			continue

		bonus += _get_item_stat_bonus(accessory_id, stat_name)
		var acc_enhance: int = 0
		if acc_index < player_data.accessory_enhances.size():
			acc_enhance = int(player_data.accessory_enhances[acc_index])
		bonus += _get_enhance_bonus(accessory_id, acc_enhance, stat_name)

	return bonus


func _get_buff_bonus(stat_name: String) -> int:
	var bonus := 0
	for buff in _active_buffs:
		if buff.get("stat", "") == stat_name:
			bonus += int(buff.get("value", 0))

	return bonus


func _get_item_stat_bonus(item_id: String, stat_name: String) -> int:
	var item := DataManager.get_item(item_id)
	var stats = item.get("stats", {})
	if stats is Dictionary:
		return int(stats.get(stat_name, 0))

	return 0


func _get_enhance_bonus(item_id: String, enhance_level: int, stat_name: String) -> int:
	if enhance_level <= 0:
		return 0
	var item_data: Dictionary = DataManager.get_item(item_id)
	var per_level: Dictionary = Dictionary(item_data.get("enhance_bonus_per_level", {}))
	if per_level.is_empty():
		per_level = _get_default_enhance_bonus(String(item_data.get("type", "")))
	return int(per_level.get(stat_name, 0)) * enhance_level


static func _get_default_enhance_bonus(item_type: String) -> Dictionary:
	match item_type:
		"weapon":
			return {"matk": 1}
		"armor":
			return {"pdef": 1, "mdef": 1}
		"accessory":
			return {"hp": 3}
		_:
			return {}


func _refresh_player_state() -> void:
	_clamp_resources()
	_emit_resource_signals()
