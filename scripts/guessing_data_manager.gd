extends Node
## Central manager for all guessing data operations.
## Handles loading/saving topics, lists, and packs from res:// and user://.

signal topics_loaded(topics: Array[Dictionary])
signal lists_loaded(lists: Array[Dictionary])
signal packs_loaded(packs: Array[Dictionary])
signal data_initialized()

const DEFAULT_TOPICS_PATH: String = "res://data/topics.json"
const DEFAULT_LISTS_DIR: String = "res://data/lists"
const DEFAULT_PACKS_DIR: String = "res://data/packs"
const USER_DATA_DIR: String = "user://guessing"
const USER_TOPICS_PATH: String = "user://guessing/topics.json"
const USER_LISTS_DIR: String = "user://guessing/lists"
const USER_PACKS_DIR: String = "user://guessing/packs"

var _all_topics: Array[Dictionary] = []
var _all_lists: Array[Dictionary] = []
var _all_packs: Array[Dictionary] = []

var _enabled_topic_ids: Array[String] = []
var _enabled_list_ids: Array[String] = []
var _enabled_pack_ids: Array[String] = []

var _guessing_lists: Dictionary = {}
var _word_bank: Array[String] = []


func _ready() -> void:
	add_to_group("guessing_data_manager")
	_ensure_user_directories()


func _ensure_user_directories() -> void:
	DirAccess.make_dir_recursive_absolute(USER_DATA_DIR)
	DirAccess.make_dir_recursive_absolute(USER_LISTS_DIR)
	DirAccess.make_dir_recursive_absolute(USER_PACKS_DIR)


func load_all_topics() -> Array[Dictionary]:
	_all_topics.clear()
	var default_topics: Array[Dictionary] = _load_topics_from_path(DEFAULT_TOPICS_PATH)
	_all_topics.append_array(default_topics)
	var user_topics: Array[Dictionary] = _load_topics_from_path(USER_TOPICS_PATH)
	_all_topics.append_array(user_topics)
	topics_loaded.emit(_all_topics)
	return _all_topics


func load_all_lists() -> Array[Dictionary]:
	_all_lists.clear()
	var default_lists: Array[Dictionary] = _load_lists_from_dir(DEFAULT_LISTS_DIR)
	_all_lists.append_array(default_lists)
	var user_lists: Array[Dictionary] = _load_lists_from_dir(USER_LISTS_DIR)
	_all_lists.append_array(user_lists)
	lists_loaded.emit(_all_lists)
	return _all_lists


func load_all_packs() -> Array[Dictionary]:
	_all_packs.clear()
	var default_packs: Array[Dictionary] = _load_packs_from_dir(DEFAULT_PACKS_DIR)
	_all_packs.append_array(default_packs)
	var user_packs: Array[Dictionary] = _load_packs_from_dir(USER_PACKS_DIR)
	_all_packs.append_array(user_packs)
	packs_loaded.emit(_all_packs)
	return _all_packs


func initialize_game_data(topic_ids: Array[String], list_ids: Array[String], pack_ids: Array[String]) -> void:
	_enabled_topic_ids = topic_ids
	_enabled_list_ids = list_ids
	_enabled_pack_ids = pack_ids

	_guessing_lists.clear()
	_word_bank.clear()

	for topic_id: String in _enabled_topic_ids:
		var combined: Array[String] = _build_combined_list_for_topic(topic_id)
		_guessing_lists[topic_id] = combined

	_build_word_bank()
	data_initialized.emit()


func _build_combined_list_for_topic(topic_id: String) -> Array[String]:
	var list_entries: Array[String] = []
	for list: Dictionary in _all_lists:
		if list.metadata.topic_id == topic_id and list.metadata.id in _enabled_list_ids:
			list_entries.append_array(list.entries)

	var pack_entries: Array[String] = []
	for pack: Dictionary in _all_packs:
		if pack.metadata.topic_id == topic_id and pack.metadata.id in _enabled_pack_ids:
			pack_entries.append_array(pack.entries)

	for entry: String in pack_entries:
		if entry not in list_entries:
			list_entries.append(entry)

	return deduplicate_entries(list_entries)


func _build_word_bank() -> void:
	for pack: Dictionary in _all_packs:
		if pack.metadata.id in _enabled_pack_ids:
			_word_bank.append_array(pack.entries)
	_word_bank = deduplicate_entries(_word_bank)


func get_word_bank() -> Array[String]:
	return _word_bank


func get_guessing_list_for_topic(topic_id: String) -> Array[String]:
	return _guessing_lists.get(topic_id, [])


func get_enabled_topics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for topic: Dictionary in _all_topics:
		if topic.id in _enabled_topic_ids:
			result.append(topic)
	return result


func get_lists_for_topic(topic_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for list: Dictionary in _all_lists:
		if list.metadata.topic_id == topic_id:
			result.append(list)
	return result


func get_packs_for_topic(topic_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pack: Dictionary in _all_packs:
		if pack.metadata.topic_id == topic_id:
			result.append(pack)
	return result


func set_enabled_topics(topic_ids: Array[String]) -> void:
	_enabled_topic_ids = topic_ids


func set_enabled_lists(list_ids: Array[String]) -> void:
	_enabled_list_ids = list_ids


func set_enabled_packs(pack_ids: Array[String]) -> void:
	_enabled_pack_ids = pack_ids


func deduplicate_entries(entries: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for entry: String in entries:
		var lower: String = entry.to_lower()
		if not seen.has(lower):
			seen[lower] = true
			result.append(entry)
	return result


func create_custom_topic(topic_name: String) -> Dictionary:
	var id: String = topic_name.to_lower().replace(" ", "_")
	id = id.validate_node_name()
	var topic: Dictionary = {
		"id": id,
		"name": topic_name,
		"is_default": false,
		"created_by": ""
	}
	_all_topics.append(topic)
	_save_user_topics()
	return topic


func create_custom_list(list_name: String, topic_id: String, entries: Array[String]) -> Dictionary:
	var id: String = list_name.to_lower().replace(" ", "_")
	id = id.validate_node_name()
	var list: Dictionary = {
		"version": 1,
		"metadata": {
			"id": id,
			"name": list_name,
			"topic_id": topic_id,
			"is_default": false,
			"created_by": ""
		},
		"entries": entries
	}
	_all_lists.append(list)
	_save_list_to_user(list)
	return list


func create_custom_pack(pack_name: String, topic_id: String, entries: Array[String]) -> Dictionary:
	var id: String = pack_name.to_lower().replace(" ", "_")
	id = id.validate_node_name()
	var pack: Dictionary = {
		"version": 1,
		"metadata": {
			"id": id,
			"name": pack_name,
			"topic_id": topic_id,
			"is_default": false,
			"created_by": ""
		},
		"entries": entries
	}
	_all_packs.append(pack)
	_save_pack_to_user(pack)
	return pack


func copy_pack(source_id: String, new_name: String) -> Dictionary:
	var source: Dictionary = _find_pack(source_id)
	if source.is_empty():
		return {}
	return create_custom_pack(new_name, source.metadata.topic_id, source.entries.duplicate())


func copy_list(source_id: String, new_name: String) -> Dictionary:
	var source: Dictionary = _find_list(source_id)
	if source.is_empty():
		return {}
	return create_custom_list(new_name, source.metadata.topic_id, source.entries.duplicate())


func _find_pack(pack_id: String) -> Dictionary:
	for pack: Dictionary in _all_packs:
		if pack.metadata.id == pack_id:
			return pack
	return {}


func _find_list(list_id: String) -> Dictionary:
	for list: Dictionary in _all_lists:
		if list.metadata.id == list_id:
			return list
	return {}


func delete_custom_pack(pack_id: String) -> bool:
	var pack: Dictionary = _find_pack(pack_id)
	if pack.is_empty() or pack.metadata.is_default:
		return false
	_all_packs = _all_packs.filter(func(p: Dictionary) -> bool: return p.metadata.id != pack_id)
	var file_path: String = USER_PACKS_DIR.path_join(pack_id + ".json")
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	return true


func delete_custom_list(list_id: String) -> bool:
	var list: Dictionary = _find_list(list_id)
	if list.is_empty() or list.metadata.is_default:
		return false
	_all_lists = _all_lists.filter(func(l: Dictionary) -> bool: return l.metadata.id != list_id)
	var file_path: String = USER_LISTS_DIR.path_join(list_id + ".json")
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	return true


func _load_topics_from_path(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_warning("GuessingDataManager: Failed to parse topics from %s" % path)
		return []
	var data: Variant = json.data
	if not data is Dictionary:
		return []
	var raw_topics: Array = data.get("topics", [])
	var typed_topics: Array[Dictionary] = []
	for topic: Variant in raw_topics:
		if topic is Dictionary:
			typed_topics.append(topic)
	return typed_topics


func _load_lists_from_dir(dir_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path: String = dir_path.path_join(file_name)
			var list_data: Dictionary = _load_list_from_path(full_path)
			if not list_data.is_empty():
				result.append(list_data)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _load_packs_from_dir(dir_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path: String = dir_path.path_join(file_name)
			var pack_data: Dictionary = _load_pack_from_path(full_path)
			if not pack_data.is_empty():
				result.append(pack_data)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _load_list_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_warning("GuessingDataManager: Failed to parse list from %s" % path)
		return {}
	return json.data


func _load_pack_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_warning("GuessingDataManager: Failed to parse pack from %s" % path)
		return {}
	return json.data


func _save_user_topics() -> void:
	var data: Dictionary = {
		"version": 1,
		"topics": _all_topics.filter(func(t: Dictionary) -> bool: return not t.is_default)
	}
	_write_json_file(USER_TOPICS_PATH, data)


func _save_list_to_user(list: Dictionary) -> void:
	var file_path: String = USER_LISTS_DIR.path_join(list.metadata.id + ".json")
	_write_json_file(file_path, list)


func _save_pack_to_user(pack: Dictionary) -> void:
	var file_path: String = USER_PACKS_DIR.path_join(pack.metadata.id + ".json")
	_write_json_file(file_path, pack)


func _write_json_file(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("GuessingDataManager: Failed to write to %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
