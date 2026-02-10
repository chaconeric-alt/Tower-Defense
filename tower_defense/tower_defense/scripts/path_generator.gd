extends Node

enum CellType { EMPTY, PATH, BASE }

var actual_grid_size: int = 9
var actual_center: int = 4
var grid: Array = []
var paths: Array = []
var entry_points: Array = []

func initialize_grid():
	actual_grid_size = ConfigManager.get_game_setting("grid_size", 9)
	actual_center = actual_grid_size / 2
	grid = []
	for y in range(actual_grid_size):
		var row = []
		for x in range(actual_grid_size):
			row.append(CellType.EMPTY)
		grid.append(row)
	grid[actual_center][actual_center] = CellType.BASE

func get_edge_positions() -> Array:
	var edges = []
	for i in range(actual_grid_size):
		edges.append(Vector2i(i, 0))             # top
		edges.append(Vector2i(i, actual_grid_size - 1))  # bottom
		edges.append(Vector2i(0, i))              # left
		edges.append(Vector2i(actual_grid_size - 1, i))  # right
	# Remove duplicates (corners)
	var unique = {}
	for e in edges:
		unique[e] = true
	var result = []
	for key in unique.keys():
		result.append(key)
	result.shuffle()
	return result

func generate_paths(difficulty: int) -> Array:
	initialize_grid()
	var possible_entries = get_edge_positions()

	paths = []
	entry_points = []
	var attempts = 0

	for i in range(difficulty):
		var found = false
		while not found and attempts < 100:
			attempts += 1
			if possible_entries.size() == 0:
				break
			var entry = possible_entries.pop_front()
			var path = generate_path_from_entry(entry)
			if path.size() > 0 and path_reaches_center(path):
				paths.append(path)
				entry_points.append(entry)
				mark_path_on_grid(path)
				found = true
			else:
				# put it back at end to try others first
				possible_entries.append(entry)

	return paths

func path_reaches_center(path: Array) -> bool:
	if path.size() == 0:
		return false
	var last = path[path.size() - 1]
	return last.x == actual_center and last.y == actual_center

func generate_path_from_entry(entry: Vector2i) -> Array:
	var path: Array = []
	var current = entry
	var target = Vector2i(actual_center, actual_center)
	var visited: Dictionary = {}

	path.append(current)
	visited[current] = true

	var max_steps = actual_grid_size * actual_grid_size * 2
	var steps = 0

	while current != target and steps < max_steps:
		steps += 1
		var next_pos = get_next_position(current, target, visited)
		if next_pos == current:
			break
		current = next_pos
		path.append(current)
		visited[current] = true

	return path

func get_next_position(current: Vector2i, target: Vector2i, visited: Dictionary) -> Vector2i:
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]

	var possible_moves = []
	for dir in directions:
		var new_pos = current + dir

		if new_pos.x < 0 or new_pos.x >= actual_grid_size:
			continue
		if new_pos.y < 0 or new_pos.y >= actual_grid_size:
			continue
		if new_pos in visited:
			continue
		
		var cell = grid[new_pos.y][new_pos.x]
		if new_pos == target:
			# Always allow moving to center
			var target_dist = abs(target.x - new_pos.x) + abs(target.y - new_pos.y)
			possible_moves.append({"pos": new_pos, "dist": target_dist})
			continue
		if cell == CellType.PATH:
			continue
		if cell != CellType.EMPTY and cell != CellType.BASE:
			continue

		var dist = abs(target.x - new_pos.x) + abs(target.y - new_pos.y)
		# Add small randomness to make paths interesting
		var rand_offset = randf() * 2.0
		possible_moves.append({"pos": new_pos, "dist": dist + rand_offset})

	possible_moves.sort_custom(func(a, b): return a.dist < b.dist)

	if possible_moves.size() > 0:
		return possible_moves[0].pos
	return current

func mark_path_on_grid(path: Array):
	for cell in path:
		if cell != Vector2i(actual_center, actual_center):
			grid[cell.y][cell.x] = CellType.PATH

func get_path_for_entry(entry_index: int) -> Array:
	if entry_index < paths.size():
		return paths[entry_index]
	return paths[0] if paths.size() > 0 else []

func get_world_path(path: Array, cell_size: int) -> PackedVector2Array:
	var world_path = PackedVector2Array()
	var half = cell_size / 2.0
	for cell in path:
		world_path.append(Vector2(cell.x * cell_size + half, cell.y * cell_size + half))
	return world_path

func is_path_cell(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= actual_grid_size or pos.y < 0 or pos.y >= actual_grid_size:
		return true
	return grid[pos.y][pos.x] == CellType.PATH

func is_base_cell(pos: Vector2i) -> bool:
	return pos.x == actual_center and pos.y == actual_center
