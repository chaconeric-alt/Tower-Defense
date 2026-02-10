extends Node

enum GameState { MENU, DIFFICULTY_SELECT, BUILDING, COMBAT, GAME_OVER }
var current_state: int = GameState.MENU

var currency: int = 10
var base_hp: int = 10
var max_base_hp: int = 10
var difficulty: int = 1
var current_round: int = 0
var max_rounds: int = 6
var current_wave: int = 0
var total_waves: int = 0
var unlocked_towers: Array = []

signal state_changed(new_state: int)
signal currency_changed(amount: int)
signal base_hp_changed(hp: int)
signal tower_unlocked(tower_name: String)
signal game_over(won: bool)
signal round_changed(round_num: int)
signal wave_changed(wave_num: int, total: int)


func start_game(diff: int):
	difficulty = diff
	currency = ConfigManager.get_game_setting("starting_currency", 10)
	max_base_hp = ConfigManager.get_game_setting("base_max_hp", 10)
	base_hp = max_base_hp
	max_rounds = ConfigManager.get_game_setting("max_rounds", 6)
	current_round = 0

	unlocked_towers = []
	for tower_type in ConfigManager.get_tower_types():
		if tower_type.get("unlock_cost", 0) == 0:
			unlocked_towers.append(tower_type.name)

	emit_signal("currency_changed", currency)
	emit_signal("base_hp_changed", base_hp)
	change_state(GameState.BUILDING)

func change_state(new_state: int):
	current_state = new_state
	emit_signal("state_changed", new_state)

func is_building_phase() -> bool:
	return current_state == GameState.BUILDING

func unlock_tower(tower_name: String, unlock_cost: int) -> bool:
	if tower_name in unlocked_towers:
		return false
	if currency >= unlock_cost:
		currency -= unlock_cost
		unlocked_towers.append(tower_name)
		emit_signal("currency_changed", currency)
		emit_signal("tower_unlocked", tower_name)
		return true
	return false

func is_tower_unlocked(tower_name: String) -> bool:
	return tower_name in unlocked_towers

func spend_currency(amount: int) -> bool:
	if currency >= amount:
		currency -= amount
		emit_signal("currency_changed", currency)
		return true
	return false

func add_currency(amount: int):
	currency += amount
	emit_signal("currency_changed", currency)

func damage_base(amount: int):
	base_hp -= amount
	if base_hp <= 0:
		base_hp = 0
		emit_signal("base_hp_changed", base_hp)
		change_state(GameState.GAME_OVER)
		emit_signal("game_over", false)
	else:
		emit_signal("base_hp_changed", base_hp)

func start_round():
	current_round += 1
	emit_signal("round_changed", current_round)
	change_state(GameState.COMBAT)

func get_waves_for_round() -> Array:
	return ConfigManager.get_waves_for_round(current_round)

func round_complete():
	if current_round >= max_rounds:
		change_state(GameState.GAME_OVER)
		emit_signal("game_over", true)
	else:
		change_state(GameState.BUILDING)

func set_wave_info(wave_num: int, total: int):
	current_wave = wave_num
	total_waves = total
	emit_signal("wave_changed", wave_num, total)
