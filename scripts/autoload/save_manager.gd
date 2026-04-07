extends Node

const SAVE_DIR := "user://saves"
const MAX_SLOTS := 3

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(error: String)


func save_game(slot: int) -> void:
	if not _is_valid_slot(slot):
		save_failed.emit("Invalid save slot: %d" % slot)
		return

	if not _ensure_save_dir():
		save_failed.emit("Failed to create save directory.")
		return

	var player_snapshot := PlayerManager.to_save_dict()
	var save_data := {
		"save_version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(false, true).replace(" ", "T"),
		"play_time_seconds": 0,
		"player": player_snapshot,
		"familiars": {
			"party": int(player_snapshot.get("active_familiar_index", -1)),
			"roster": Array(player_snapshot.get("owned_familiars", [])).duplicate(true),
		},
		"familiar_instances": {},
		"inventory": PlayerManager.inventory.to_save_dict() if PlayerManager.inventory != null else {
			"consumables": [],
			"materials": [],
			"key_items": [],
			"magic_books": [],
			"equipment": [],
		},
		"equipment": {
			"weapon": {},
			"armor": {},
			"accessories": player_snapshot.get("accessory_ids", []).duplicate(),
		},
		"progress": {
			"highest_floor": player_snapshot.get("highest_floor", 1),
			"cleared_floors": [],
			"unlocked_teleports": player_snapshot.get("unlocked_teleports", []).duplicate(),
			"defeated_bosses": player_snapshot.get("defeated_bosses", []).duplicate(),
			"main_quest_chapter": 0,
			"completed_quests": [],
			"active_quests": [],
			"achievements": {},
		},
		"settings": {
			"bgm_volume": AudioManager.bgm_volume,
			"sfx_volume": AudioManager.sfx_volume,
			"text_speed": "normal",
		},
	}

	var file := FileAccess.open(_get_save_path(slot), FileAccess.WRITE)
	if file == null:
		save_failed.emit("Failed to open save file for slot %d." % slot)
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	save_completed.emit(slot)


func load_game(slot: int) -> void:
	if not has_save(slot):
		save_failed.emit("Save slot %d does not exist." % slot)
		return

	var file := FileAccess.open(_get_save_path(slot), FileAccess.READ)
	if file == null:
		save_failed.emit("Failed to open save file for slot %d." % slot)
		return

	var raw_text := file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if parsed is not Dictionary:
		save_failed.emit("Failed to parse save file for slot %d." % slot)
		return

	PlayerManager.load_from_save(parsed)
	var familiar_data = parsed.get("familiars", {})
	if familiar_data is Dictionary:
		PlayerManager.load_familiars_from_save(familiar_data)

	var inventory_data = parsed.get("inventory", {})
	if inventory_data is Dictionary and PlayerManager.inventory != null:
		PlayerManager.inventory.load_from_dict(inventory_data)
		if PlayerManager.player_data != null:
			PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	var settings = parsed.get("settings", {})
	if settings is Dictionary:
		if settings.has("bgm_volume"):
			AudioManager.set_bgm_volume(float(settings["bgm_volume"]))
		if settings.has("sfx_volume"):
			AudioManager.set_sfx_volume(float(settings["sfx_volume"]))

	load_completed.emit(slot)


func auto_save() -> void:
	save_game(0)


func delete_save(slot: int) -> void:
	if not has_save(slot):
		return

	var directory := DirAccess.open(SAVE_DIR)
	if directory == null:
		save_failed.emit("Failed to open save directory.")
		return

	var file_name := "save_%d.json" % slot
	var error := directory.remove(file_name)
	if error != OK:
		save_failed.emit("Failed to delete save slot %d." % slot)


func has_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false

	return FileAccess.file_exists(_get_save_path(slot))


func get_save_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}

	var file := FileAccess.open(_get_save_path(slot), FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return {}

	var player = parsed.get("player", {})
	var progress = parsed.get("progress", {})

	return {
		"slot": slot,
		"timestamp": parsed.get("timestamp", ""),
		"level": player.get("level", 1) if player is Dictionary else 1,
		"highest_floor": progress.get("highest_floor", 1) if progress is Dictionary else 1,
	}


func _get_save_path(slot: int) -> String:
	return SAVE_DIR.path_join("save_%d.json" % slot)


func _ensure_save_dir() -> bool:
	var root_directory := DirAccess.open("user://")
	if root_directory == null:
		return false

	if root_directory.dir_exists("saves"):
		return true

	return root_directory.make_dir_recursive("saves") == OK


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot <= MAX_SLOTS
