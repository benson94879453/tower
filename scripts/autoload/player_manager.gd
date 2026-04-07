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
	_clamp_resources()
	_emit_resource_signals()
	player_gold_changed.emit(player_data.gold)


func to_save_dict() -> Dictionary:
	if player_data == null:
		init_new_game()
	if inventory == null:
		inventory = InventoryClass.new()

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
	var old_id := player_data.weapon_id
	_last_unequipped_enhance = player_data.weapon_enhance
	player_data.weapon_id = item_id
	player_data.weapon_enhance = enhance_level
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func equip_armor(item_id: String, enhance_level: int = 0) -> String:
	_ensure_player_data()
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
