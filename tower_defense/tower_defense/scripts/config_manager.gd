extends Node

const CONFIG_DIR = "res://config"
const GAME_CONFIG_FILE = "res://config/game_config.csv"
const TOWER_CONFIG_FILE = "res://config/tower_types.csv"
const ENEMY_CONFIG_FILE = "res://config/enemy_types.csv"

var game_config: Dictionary = {}
var tower_types: Array = []
var enemy_types: Array = []

func _ready():
	load_all_configs()

func load_all_configs():
	load_game_config()
	load_tower_config()
	load_enemy_config()

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

func get_game_setting(key: String, default_value = null):
	return game_config.get(key, default_value)

func get_tower_types() -> Array:
	return tower_types

func get_enemy_types() -> Array:
	return enemy_types
