extends Node

signal player_level_up(new_level: int)
signal player_hp_changed(new_hp: int, max_hp: int)
signal player_mp_changed(new_mp: int, max_mp: int)
signal player_gold_changed(new_gold: int)
signal player_died
signal equipment_changed

const PlayerDataResource = preload("res://scripts/data/player_data.gd")
const GROWTH_PER_LEVEL := {
	"base_hp": 12,
	"base_mp": 6,
	"base_matk": 2,
	"base_mdef": 1,
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
	"armor_id",
	"accessory_ids",
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
var _active_buffs: Array[Dictionary] = []


func _ready() -> void:
	if player_data == null:
		init_new_game()


func init_new_game() -> void:
	player_data = PlayerDataResource.new()
	_active_buffs.clear()
	_clamp_resources()
	_emit_resource_signals()


func load_from_save(save_dict: Dictionary) -> void:
	var source := save_dict
	if save_dict.has("player") and save_dict["player"] is Dictionary:
		source = save_dict["player"]

	if player_data == null:
		player_data = PlayerDataResource.new()

	for field_name in SAVE_FIELDS:
		if not source.has(field_name):
			continue

		var value = source[field_name]
		if value is Array or value is Dictionary:
			player_data.set(field_name, value.duplicate(true))
		else:
			player_data.set(field_name, value)

	_active_buffs.clear()
	_clamp_resources()
	_emit_resource_signals()
	player_gold_changed.emit(player_data.gold)


func to_save_dict() -> Dictionary:
	if player_data == null:
		init_new_game()

	var save_dict: Dictionary = {}
	for field_name in SAVE_FIELDS:
		var value = player_data.get(field_name)
		if value is Array or value is Dictionary:
			save_dict[field_name] = value.duplicate(true)
		else:
			save_dict[field_name] = value

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


func equip_weapon(item_id: String) -> String:
	_ensure_player_data()
	var old_id := player_data.weapon_id
	player_data.weapon_id = item_id
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func equip_armor(item_id: String) -> String:
	_ensure_player_data()
	var old_id := player_data.armor_id
	player_data.armor_id = item_id
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func equip_accessory(item_id: String, slot: int) -> String:
	_ensure_player_data()
	if slot < 0 or slot > 2:
		return ""

	while player_data.accessory_ids.size() <= slot:
		player_data.accessory_ids.append("")

	var old_id := player_data.accessory_ids[slot]
	player_data.accessory_ids[slot] = item_id
	_refresh_player_state()
	equipment_changed.emit()
	return old_id


func unequip_weapon() -> String:
	return equip_weapon("")


func unequip_armor() -> String:
	return equip_armor("")


func unequip_accessory(slot: int) -> String:
	return equip_accessory("", slot)


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
	return 100 + max(level - 1, 0) * 25


func _ensure_player_data() -> void:
	if player_data == null:
		init_new_game()


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

	if not player_data.armor_id.is_empty():
		bonus += _get_item_stat_bonus(player_data.armor_id, stat_name)

	for accessory_id in player_data.accessory_ids:
		if accessory_id.is_empty():
			continue

		bonus += _get_item_stat_bonus(accessory_id, stat_name)

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


func _refresh_player_state() -> void:
	_clamp_resources()
	_emit_resource_signals()
