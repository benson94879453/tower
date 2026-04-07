class_name Inventory
extends RefCounted

var consumables: Dictionary = {}
var materials: Dictionary = {}
var key_items: Dictionary = {}
var magic_books: Dictionary = {}
var equipment: Array[String] = []


func add(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	var category: String = _get_category(item_id)
	match category:
		"equipment":
			for _index in range(amount):
				equipment.append(item_id)
			return true
		_:
			var bag: Dictionary = _get_bag(category)
			var current: int = int(bag.get(item_id, 0))
			var max_stack: int = _get_max_stack(item_id)
			var new_count: int = min(current + amount, max_stack)
			if new_count <= current:
				return false
			bag[item_id] = new_count
			_set_bag(category, bag)
			return true


func remove(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	var category: String = _get_category(item_id)
	match category:
		"equipment":
			var removed: int = 0
			for _index in range(amount):
				var found_index: int = equipment.find(item_id)
				if found_index < 0:
					break
				equipment.remove_at(found_index)
				removed += 1
			return removed == amount
		_:
			var bag: Dictionary = _get_bag(category)
			var current: int = int(bag.get(item_id, 0))
			if current < amount:
				return false
			var new_count: int = current - amount
			if new_count <= 0:
				bag.erase(item_id)
			else:
				bag[item_id] = new_count
			_set_bag(category, bag)
			return true


func count(item_id: String) -> int:
	var category: String = _get_category(item_id)
	match category:
		"equipment":
			return equipment.count(item_id)
		_:
			var bag: Dictionary = _get_bag(category)
			return int(bag.get(item_id, 0))


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func get_all_items() -> Array:
	var result: Array = []
	for bag in [consumables, materials, key_items, magic_books]:
		for raw_id in bag.keys():
			var item_id: String = String(raw_id)
			result.append({"id": item_id, "count": int(bag.get(raw_id, 0))})
	for equipment_id in equipment:
		result.append({"id": equipment_id, "count": 1})
	return result


func clear() -> void:
	consumables.clear()
	materials.clear()
	key_items.clear()
	magic_books.clear()
	equipment.clear()


func to_save_dict() -> Dictionary:
	return {
		"consumables": _bag_to_array(consumables),
		"materials": _bag_to_array(materials),
		"key_items": _bag_to_array(key_items),
		"magic_books": _bag_to_array(magic_books),
		"equipment": equipment.duplicate(),
	}


func load_from_dict(data: Dictionary) -> void:
	clear()
	consumables = _array_to_bag(Array(data.get("consumables", [])))
	materials = _array_to_bag(Array(data.get("materials", [])))
	key_items = _array_to_bag(Array(data.get("key_items", [])))
	magic_books = _array_to_bag(Array(data.get("magic_books", [])))

	var saved_equipment: Array = Array(data.get("equipment", []))
	for raw_item_id in saved_equipment:
		equipment.append(String(raw_item_id))


func _get_category(item_id: String) -> String:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_type: String = String(item_data.get("type", ""))
	match item_type:
		"consumable":
			return "consumable"
		"material":
			return "material"
		"key_item":
			return "key_item"
		"magic_book":
			return "magic_book"
		"weapon", "armor", "accessory":
			return "equipment"
		_:
			if bool(item_data.get("stackable", false)):
				return "consumable"
			return "equipment"


func _get_bag(category: String) -> Dictionary:
	match category:
		"consumable":
			return consumables
		"material":
			return materials
		"key_item":
			return key_items
		"magic_book":
			return magic_books
		_:
			return consumables


func _set_bag(category: String, bag: Dictionary) -> void:
	match category:
		"consumable":
			consumables = bag
		"material":
			materials = bag
		"key_item":
			key_items = bag
		"magic_book":
			magic_books = bag
		_:
			consumables = bag


func _get_max_stack(item_id: String) -> int:
	var item_data: Dictionary = DataManager.get_item(item_id)
	return int(item_data.get("max_stack", 99))


static func _bag_to_array(bag: Dictionary) -> Array:
	var result: Array = []
	for raw_id in bag.keys():
		result.append({
			"id": String(raw_id),
			"count": int(bag.get(raw_id, 0)),
		})
	return result


static func _array_to_bag(entries: Array) -> Dictionary:
	var bag: Dictionary = {}
	for raw_entry in entries:
		if raw_entry is not Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id: String = String(entry.get("id", ""))
		if item_id.is_empty():
			continue
		bag[item_id] = int(entry.get("count", 1))
	return bag
