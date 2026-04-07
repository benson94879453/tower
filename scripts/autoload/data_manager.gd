extends Node

signal data_loaded

var _skills: Dictionary = {}
var _enemies: Dictionary = {}
var _items: Dictionary = {}
var _familiars: Dictionary = {}
var _events: Dictionary = {}
var _quests: Dictionary = {}
var _recipes: Dictionary = {}
var _floor_config: Dictionary = {}


func load_all_data() -> void:
	_skills.clear()
	_enemies.clear()
	_items.clear()
	_familiars.clear()
	_events.clear()
	_quests.clear()
	_recipes.clear()
	_floor_config.clear()

	_load_directory("res://data/skills/", _skills)
	_load_directory("res://data/enemies/", _enemies)
	_load_directory("res://data/items/", _items)
	_load_directory("res://data/familiars/", _familiars)
	_load_directory("res://data/events/", _events)
	_load_directory("res://data/quests/", _quests)
	_load_directory("res://data/recipes/", _recipes)
	_load_directory("res://data/floors/", _floor_config)

	if FileAccess.file_exists("res://data/floors/floor_config.json"):
		var floor_config = _load_json_file("res://data/floors/floor_config.json")
		if floor_config is Dictionary:
			_floor_config = floor_config

	data_loaded.emit()


func _load_json_file(file_path: String):
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Cannot open file: " + file_path)
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("JSON parse error in " + file_path + ": " + json.get_error_message())
		return {}

	return json.data


func _load_directory(dir_path: String, cache_dict: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("Cannot open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue

		if not file_name.ends_with(".json"):
			file_name = dir.get_next()
			continue

		var file_path := dir_path + file_name
		var data = _load_json_file(file_path)

		if data is Array:
			for item in data:
				if item is Dictionary and item.has("id"):
					cache_dict[String(item["id"])] = item
		elif data is Dictionary and data.has("id"):
			cache_dict[String(data["id"])] = data

		file_name = dir.get_next()

	dir.list_dir_end()


func get_skill(id: String) -> Dictionary:
	return _skills.get(id, {})


func get_enemy(id: String) -> Dictionary:
	return _enemies.get(id, {})


func get_item(id: String) -> Dictionary:
	return _items.get(id, {})


func get_familiar(id: String) -> Dictionary:
	return _familiars.get(id, {})


func get_event(id: String) -> Dictionary:
	return _events.get(id, {})


func get_quest(id: String) -> Dictionary:
	return _quests.get(id, {})


func get_recipe(id: String) -> Dictionary:
	return _recipes.get(id, {})


func get_floor_config() -> Dictionary:
	return _floor_config


func get_skills_by_element(element: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill in _skills.values():
		if skill.get("element", "") == element:
			result.append(skill)

	return result


func get_enemies_by_floor(floor_num: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in _enemies.values():
		var floor_range = enemy.get("floor_range", [1, 100])
		if floor_range.size() >= 2 and floor_num >= floor_range[0] and floor_num <= floor_range[1]:
			result.append(enemy)

	return result


func get_events_by_type(event_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _events.values():
		if event.get("type", "") == event_type:
			result.append(event)

	return result


func get_items_for_shop(floor_number: int) -> Array:
	var result: Array = []
	for raw_item in _items.values():
		var item: Dictionary = raw_item
		var buy_price: int = int(item.get("buy_price", 0))
		if buy_price <= 0:
			continue
		var available_from: int = int(item.get("available_from_floor", 1))
		if floor_number < available_from:
			continue
		result.append(item)
	return result


func get_recipes_by_type(recipe_type: String, floor_number: int = 999) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_recipe in _recipes.values():
		var recipe: Dictionary = raw_recipe
		if String(recipe.get("type", "")) != recipe_type:
			continue
		var available_from: int = int(recipe.get("available_from_floor", 1))
		if floor_number < available_from:
			continue
		result.append(recipe)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_floor: int = int(a.get("available_from_floor", 1))
		var b_floor: int = int(b.get("available_from_floor", 1))
		if a_floor != b_floor:
			return a_floor < b_floor
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return result
