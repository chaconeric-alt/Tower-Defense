extends Node

const CONFIG_DIR = "res://config"
const GAME_CONFIG_FILE = "res://config/game_config.csv"
const TOWER_CONFIG_FILE = "res://config/tower_types.csv"
const ENEMY_CONFIG_FILE = "res://config/enemy_types.csv"
const WAVE_CONFIG_FILE = "res://config/wave_config.csv"

var game_config: Dictionary = {}
var tower_types: Array = []
var enemy_types: Array = []
var wave_config: Dictionary = {}  # round_num -> Array of wave dicts

func _ready():
	load_all_configs()

func load_all_configs():
	load_game_config()
	load_tower_config()
	load_enemy_config()
	load_wave_config()

func load_game_config():
	if not FileAccess.file_exists(GAME_CONFIG_FILE):
		push_warning("game_config.csv not found, using defaults")
		game_config = {
			"grid_size": 9,
			"starting_currency": 10,
			"base_max_hp": 10,
			"max_rounds": 6,
			"cell_size": 80
		}
		return
	var file = FileAccess.open(GAME_CONFIG_FILE, FileAccess.READ)
	var _header_line = file.get_line()  # skip header
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var parts = line.split(",")
		if parts.size() >= 2:
			var key = parts[0].strip_edges()
			var val = parts[1].strip_edges()
			if val.is_valid_int():
				game_config[key] = int(val)
			elif val.is_valid_float():
				game_config[key] = float(val)
			else:
				game_config[key] = val
	file.close()

func load_tower_config():
	if not FileAccess.file_exists(TOWER_CONFIG_FILE):
		push_warning("tower_types.csv not found, using defaults")
		tower_types = [
			{"name": "Basic Tower", "cost": 1, "damage": 1.0, "fire_rate": 1.0, "range": 120.0,
			 "color_r": 0.27, "color_g": 0.51, "color_b": 0.71, "shape": "square", "size": 30,
			 "unlock_cost": 0, "description": "Cheap and reliable"}
		]
		return
	var file = FileAccess.open(TOWER_CONFIG_FILE, FileAccess.READ)
	var header = file.get_line().strip_edges().split(",")
	tower_types = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var parts = line.split(",")
		if parts.size() < header.size():
			continue
		var entry = {}
		for i in range(header.size()):
			var key = header[i].strip_edges()
			var val = parts[i].strip_edges()
			match key:
				"name", "shape", "description":
					entry[key] = val
				"cost", "unlock_cost", "size":
					entry[key] = int(val) if val.is_valid_int() else 0
				_:
					entry[key] = float(val) if val.is_valid_float() else 0.0
		tower_types.append(entry)
	file.close()

func load_enemy_config():
	if not FileAccess.file_exists(ENEMY_CONFIG_FILE):
		push_warning("enemy_types.csv not found, using defaults")
		enemy_types = [
			{"name": "Scout", "hp_multiplier": 1.0, "speed": 3.0, "damage": 1,
			 "currency_multiplier": 1.0, "color_r": 1.0, "color_g": 0.0, "color_b": 0.0,
			 "shape": "circle", "size": 20}
		]
		return
	var file = FileAccess.open(ENEMY_CONFIG_FILE, FileAccess.READ)
	var header = file.get_line().strip_edges().split(",")
	enemy_types = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var parts = line.split(",")
		if parts.size() < header.size():
			continue
		var entry = {}
		for i in range(header.size()):
			var key = header[i].strip_edges()
			var val = parts[i].strip_edges()
			match key:
				"name", "shape":
					entry[key] = val
				"damage", "size":
					entry[key] = int(val) if val.is_valid_int() else 0
				_:
					entry[key] = float(val) if val.is_valid_float() else 0.0
		enemy_types.append(entry)
	file.close()

func load_wave_config():
	if not FileAccess.file_exists(WAVE_CONFIG_FILE):
		push_warning("wave_config.csv not found, creating defaults")
		create_default_wave_config()

	var file = FileAccess.open(WAVE_CONFIG_FILE, FileAccess.READ)
	if file == null:
		push_warning("Failed to open wave_config.csv, using hardcoded defaults")
		_set_default_wave_config()
		return

	var header = file.get_line().strip_edges().split(",")
	wave_config = {}

	# Parse header to find entry columns (format: entry1_Scout, entry2_Runner, etc.)
	var entry_columns: Array = []
	for i in range(header.size()):
		var col = header[i].strip_edges()
		if col.begins_with("entry"):
			var underscore_pos = col.find("_")
			if underscore_pos > 0:
				var entry_num = int(col.substr(5, underscore_pos - 5)) - 1  # 0-indexed
				var type_name = col.substr(underscore_pos + 1)
				entry_columns.append({"col": i, "entry": entry_num, "type": type_name})

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var parts = line.split(",")
		if parts.size() < 4:
			continue

		var round_num = int(parts[0].strip_edges())
		var _wave_num = int(parts[1].strip_edges())
		var speed = float(parts[2].strip_edges())
		var hp_mult = float(parts[3].strip_edges())

		var entries: Array = [{}, {}, {}, {}]
		for ec in entry_columns:
			if ec.col < parts.size():
				var count = int(parts[ec.col].strip_edges())
				if count > 0:
					entries[ec.entry][ec.type] = count

		var wave_data = {
			"speed": speed,
			"hp_multiplier": hp_mult,
			"entries": entries
		}

		if round_num not in wave_config:
			wave_config[round_num] = []
		wave_config[round_num].append(wave_data)

	file.close()

func create_default_wave_config():
	var file = FileAccess.open(WAVE_CONFIG_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot create wave_config.csv")
		return
	file.store_line("round,wave,speed,hp_multiplier,entry1_Scout,entry1_Runner,entry1_Sprinter,entry1_Tank,entry2_Scout,entry2_Runner,entry2_Sprinter,entry2_Tank,entry3_Scout,entry3_Runner,entry3_Sprinter,entry3_Tank,entry4_Scout,entry4_Runner,entry4_Sprinter,entry4_Tank")
	file.store_line("1,1,3.0,1.0,3,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0")
	file.store_line("2,1,3.0,1.0,3,1,0,0,3,1,0,0,0,0,0,0,0,0,0,0")
	file.store_line("3,1,3.0,1.0,2,1,0,0,2,1,0,0,0,0,0,0,0,0,0,0")
	file.store_line("3,2,4.0,1.0,1,2,0,0,1,2,0,0,0,0,0,0,0,0,0,0")
	file.store_line("4,1,3.0,1.0,2,2,0,0,2,2,0,0,0,0,0,0,0,0,0,0")
	file.store_line("4,2,4.0,1.0,0,1,2,1,0,1,2,1,0,0,0,0,0,0,0,0")
	file.store_line("5,1,4.0,1.0,2,2,1,0,2,2,1,0,0,0,0,0,0,0,0,0")
	file.store_line("5,2,5.0,1.0,0,1,2,1,0,2,2,2,0,0,0,0,0,0,0,0")
	file.store_line("6,1,4.0,1.2,2,2,1,0,2,2,1,0,0,0,0,0,0,0,0,0")
	file.store_line("6,2,5.0,1.2,1,2,2,1,1,2,2,1,0,0,0,0,0,0,0,0")
	file.store_line("6,3,5.0,1.5,0,1,2,2,1,2,2,2,0,0,0,0,0,0,0,0")
	file.close()

func _set_default_wave_config():
	wave_config = {
		1: [{"speed": 3.0, "hp_multiplier": 1.0, "entries": [{"Scout": 3}, {"Scout": 2}, {}, {}]}],
		2: [{"speed": 3.0, "hp_multiplier": 1.0, "entries": [{"Scout": 3, "Runner": 1}, {"Scout": 3, "Runner": 1}, {}, {}]}],
		3: [
			{"speed": 3.0, "hp_multiplier": 1.0, "entries": [{"Scout": 2, "Runner": 1}, {"Scout": 2, "Runner": 1}, {}, {}]},
			{"speed": 4.0, "hp_multiplier": 1.0, "entries": [{"Scout": 1, "Runner": 2}, {"Scout": 1, "Runner": 2}, {}, {}]}
		],
		4: [
			{"speed": 3.0, "hp_multiplier": 1.0, "entries": [{"Scout": 2, "Runner": 2}, {"Scout": 2, "Runner": 2}, {}, {}]},
			{"speed": 4.0, "hp_multiplier": 1.0, "entries": [{"Runner": 1, "Sprinter": 2, "Tank": 1}, {"Runner": 1, "Sprinter": 2, "Tank": 1}, {}, {}]}
		],
		5: [
			{"speed": 4.0, "hp_multiplier": 1.0, "entries": [{"Scout": 2, "Runner": 2, "Sprinter": 1}, {"Scout": 2, "Runner": 2, "Sprinter": 1}, {}, {}]},
			{"speed": 5.0, "hp_multiplier": 1.0, "entries": [{"Runner": 1, "Sprinter": 2, "Tank": 1}, {"Runner": 2, "Sprinter": 2, "Tank": 2}, {}, {}]}
		],
		6: [
			{"speed": 4.0, "hp_multiplier": 1.2, "entries": [{"Scout": 2, "Runner": 2, "Sprinter": 1}, {"Scout": 2, "Runner": 2, "Sprinter": 1}, {}, {}]},
			{"speed": 5.0, "hp_multiplier": 1.2, "entries": [{"Scout": 1, "Runner": 2, "Sprinter": 2, "Tank": 1}, {"Scout": 1, "Runner": 2, "Sprinter": 2, "Tank": 1}, {}, {}]},
			{"speed": 5.0, "hp_multiplier": 1.5, "entries": [{"Runner": 1, "Sprinter": 2, "Tank": 2}, {"Scout": 1, "Runner": 2, "Sprinter": 2, "Tank": 2}, {}, {}]}
		]
	}

func get_waves_for_round(round_num: int) -> Array:
	return wave_config.get(round_num, [])

func get_enemy_type_by_name(type_name: String) -> Dictionary:
	for type_data in enemy_types:
		if type_data.get("name", "") == type_name:
			return type_data
	return {}

func get_game_setting(key: String, default_value = null):
	return game_config.get(key, default_value)

func get_tower_types() -> Array:
	return tower_types

func get_enemy_types() -> Array:
	return enemy_types
