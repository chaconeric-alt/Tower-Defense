extends Node2D

var actual_grid_size: int = 9
var actual_cell_size: int = 80
var towers: Array = []
var path_generator: Node = null
var grid_container: Node2D = null
var tower_container: Node2D = null
var enemy_container: Node2D = null
var arrow_container: Node2D = null

var placing_tower: bool = false
var placing_tower_type: Dictionary = {}
var ghost_tower: Node2D = null

var spawning: bool = false
var active_enemies: int = 0

const BOARD_MARGIN_LEFT: int = 10
const TOP_BAR_HEIGHT: int = 40
const BOTTOM_BAR_HEIGHT: int = 38
const RIGHT_PANEL_WIDTH: int = 250
const PANEL_GAP: int = 20
const MAX_GRID_SIZE: int = 20

func _ready():
	actual_grid_size = mini(ConfigManager.get_game_setting("grid_size", 9), MAX_GRID_SIZE)
	actual_cell_size = ConfigManager.get_game_setting("cell_size", 80)

	# Calculate viewport size from grid
	var grid_px = actual_grid_size * actual_cell_size
	var viewport_w = BOARD_MARGIN_LEFT + grid_px + PANEL_GAP + RIGHT_PANEL_WIDTH
	var viewport_h = TOP_BAR_HEIGHT + 2 + grid_px + BOTTOM_BAR_HEIGHT

	# Resize viewport and window
	get_tree().root.content_scale_size = Vector2i(viewport_w, viewport_h)
	DisplayServer.window_set_size(Vector2i(viewport_w, viewport_h))

	# Center window on screen
	var screen_size = DisplayServer.screen_get_size()
	var win_pos = (screen_size - Vector2i(viewport_w, viewport_h)) / 2
	DisplayServer.window_set_position(win_pos)

	# Reposition camera to center of new viewport
	var camera = get_node_or_null("../Camera2D")
	if camera:
		camera.position = Vector2(viewport_w / 2.0, viewport_h / 2.0)

	# Position board below top bar
	position = Vector2(BOARD_MARGIN_LEFT, TOP_BAR_HEIGHT + 2)

	grid_container = Node2D.new()
	grid_container.name = "GridContainer"
	add_child(grid_container)

	arrow_container = Node2D.new()
	arrow_container.name = "ArrowContainer"
	add_child(arrow_container)

	tower_container = Node2D.new()
	tower_container.name = "TowerContainer"
	add_child(tower_container)

	enemy_container = Node2D.new()
	enemy_container.name = "EnemyContainer"
	add_child(enemy_container)

	path_generator = Node.new()
	path_generator.set_script(load("res://scripts/path_generator.gd"))
	path_generator.name = "PathGenerator"
	add_child(path_generator)

	create_grid()

	GameManager.state_changed.connect(_on_state_changed)

func create_grid():
	# Clear previous
	for child in grid_container.get_children():
		child.queue_free()

	var center: int = actual_grid_size / 2

	for y in range(actual_grid_size):
		for x in range(actual_grid_size):
			var cell = ColorRect.new()
			cell.size = Vector2(actual_cell_size - 2, actual_cell_size - 2)
			cell.position = Vector2(x * actual_cell_size + 1, y * actual_cell_size + 1)

			if x == center and y == center:
				cell.color = Color(0.2, 0.4, 0.8, 1.0)  # Blue base
			else:
				cell.color = Color(0.15, 0.15, 0.15, 1.0)  # Dark gray

			cell.name = "Cell_%d_%d" % [x, y]
			grid_container.add_child(cell)

	# Grid border
	var border = Line2D.new()
	border.default_color = Color(0.3, 0.3, 0.3, 1.0)
	border.width = 2.0
	var total = actual_grid_size * actual_cell_size
	border.points = PackedVector2Array([
		Vector2(0, 0), Vector2(total, 0),
		Vector2(total, total), Vector2(0, total), Vector2(0, 0)
	])
	grid_container.add_child(border)

func generate_paths(difficulty: int):
	path_generator.generate_paths(difficulty)
	update_path_visuals()
	draw_path_arrows()

func update_path_visuals():
	# Color path cells
	for path in path_generator.paths:
		for cell_pos in path:
			var cell_name = "Cell_%d_%d" % [cell_pos.x, cell_pos.y]
			var cell = grid_container.get_node_or_null(cell_name)
			if cell and not path_generator.is_base_cell(cell_pos):
				cell.color = Color(0.6, 0.53, 0.4, 1.0)  # tan/brown

func draw_path_arrows():
	for child in arrow_container.get_children():
		child.queue_free()

	for path in path_generator.paths:
		for i in range(path.size() - 1):
			var current = path[i]
			var next_cell = path[i + 1]
			var direction = next_cell - current

			var arrow = Polygon2D.new()
			arrow.color = Color(0.3, 0.2, 0.1, 0.7)
			arrow.polygon = create_arrow_points(direction, actual_cell_size * 0.3)
			arrow.position = Vector2(
				current.x * actual_cell_size + actual_cell_size / 2.0,
				current.y * actual_cell_size + actual_cell_size / 2.0
			)
			arrow_container.add_child(arrow)

func create_arrow_points(direction: Vector2i, arrow_size: float) -> PackedVector2Array:
	var half = arrow_size / 2.0
	# Arrow pointing right by default, then rotate
	var base_points = PackedVector2Array([
		Vector2(half, 0),
		Vector2(-half, -half * 0.6),
		Vector2(-half * 0.3, 0),
		Vector2(-half, half * 0.6)
	])

	var angle = Vector2(direction.x, direction.y).angle()
	var rotated = PackedVector2Array()
	for p in base_points:
		rotated.append(p.rotated(angle))
	return rotated

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * actual_cell_size + actual_cell_size / 2.0,
		grid_pos.y * actual_cell_size + actual_cell_size / 2.0
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx = int(world_pos.x / actual_cell_size)
	var gy = int(world_pos.y / actual_cell_size)
	gx = clampi(gx, 0, actual_grid_size - 1)
	gy = clampi(gy, 0, actual_grid_size - 1)
	return Vector2i(gx, gy)

func start_placing_tower(tower_type: Dictionary):
	placing_tower = true
	placing_tower_type = tower_type

	if ghost_tower:
		ghost_tower.queue_free()

	ghost_tower = Node2D.new()
	var poly = Polygon2D.new()
	poly.color = Color(tower_type.get("color_r", 1.0), tower_type.get("color_g", 1.0), tower_type.get("color_b", 1.0), 0.5)
	var s = tower_type.get("size", 30)
	poly.polygon = _get_shape_points_local(tower_type.get("shape", "square"), s)
	ghost_tower.add_child(poly)

	# Range circle
	var range_line = Line2D.new()
	range_line.default_color = Color(1, 1, 1, 0.3)
	range_line.width = 1.0
	var r = tower_type.get("range", 120.0)
	var pts = PackedVector2Array()
	for i in range(33):
		var angle = (i / 32.0) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	range_line.points = pts
	ghost_tower.add_child(range_line)

	add_child(ghost_tower)

func cancel_placing():
	placing_tower = false
	placing_tower_type = {}
	if ghost_tower:
		ghost_tower.queue_free()
		ghost_tower = null

func get_mouse_local_pos() -> Vector2:
	# Convert global mouse position to this node's local coordinate space
	return to_local(get_global_mouse_position())

var _was_left_pressed: bool = false
var _was_right_pressed: bool = false

func _is_ui_popup_open() -> bool:
	var ui = get_node_or_null("../UI")
	if ui:
		var demolish = ui.get("demolish_popup")
		if demolish and demolish is Control and demolish.visible:
			return true
		var catalog = ui.get("catalog_panel")
		if catalog and catalog is Control and catalog.visible:
			return true
		var game_over = ui.get("game_over_panel")
		if game_over and game_over is Control and game_over.visible:
			return true
	return false

func _process(_delta: float):
	# Always track mouse button state
	var left_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var left_just_pressed = left_pressed and not _was_left_pressed
	var right_just_pressed = right_pressed and not _was_right_pressed
	_was_left_pressed = left_pressed
	_was_right_pressed = right_pressed
	
	var local_pos = get_mouse_local_pos()
	var in_grid = local_pos.x >= 0 and local_pos.y >= 0 and local_pos.x < actual_grid_size * actual_cell_size and local_pos.y < actual_grid_size * actual_cell_size
	
	if placing_tower and ghost_tower != null:
		var grid_pos = world_to_grid(local_pos)
		ghost_tower.position = grid_to_world(grid_pos)
		
		var valid = is_valid_placement(grid_pos)
		var poly = ghost_tower.get_child(0) as Polygon2D
		if poly:
			if valid:
				poly.color = Color(0.5, 1.0, 0.5, 0.7)
			else:
				poly.color = Color(1.0, 0.5, 0.5, 0.7)
		
		if left_just_pressed and in_grid and valid:
			try_place_tower(grid_pos)
		
		if right_just_pressed:
			cancel_placing()
	
	elif left_just_pressed and in_grid and not _is_ui_popup_open():
		# Check for tower click (demolish)
		if GameManager.is_building_phase():
			var clicked_tower = get_tower_at_pos(local_pos)
			if clicked_tower:
				_on_tower_clicked(clicked_tower)

func get_tower_at_pos(local_pos: Vector2) -> Node2D:
	var closest_tower: Node2D = null
	var closest_dist: float = 30.0  # Click radius threshold
	for tower in towers:
		if is_instance_valid(tower):
			var dist = tower.position.distance_to(local_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_tower = tower
	return closest_tower

func is_valid_placement(grid_pos: Vector2i) -> bool:
	if not GameManager.is_building_phase():
		return false
	if grid_pos.x < 0 or grid_pos.x >= actual_grid_size:
		return false
	if grid_pos.y < 0 or grid_pos.y >= actual_grid_size:
		return false
	if path_generator.is_path_cell(grid_pos):
		return false
	if path_generator.is_base_cell(grid_pos):
		return false
	if GameManager.currency < placing_tower_type.get("cost", 999):
		return false
	# Check for existing towers
	for tower in towers:
		if is_instance_valid(tower):
			var tower_grid = world_to_grid(tower.position)
			if tower_grid == grid_pos:
				return false
	return true

func try_place_tower(grid_pos: Vector2i):
	var tower_cost = placing_tower_type.get("cost", 1)
	if not GameManager.spend_currency(tower_cost):
		return

	var tower = Node2D.new()
	tower.set_script(load("res://scripts/tower.gd"))
	tower.position = grid_to_world(grid_pos)
	tower.initialize(placing_tower_type)
	tower.tower_clicked.connect(_on_tower_clicked)
	tower_container.add_child(tower)
	towers.append(tower)

	# Don't cancel placement - allow placing multiple
	# cancel_placing()

func _on_tower_clicked(tower: Node2D):
	var ui = get_node_or_null("../UI")
	if ui and ui.has_method("on_tower_clicked"):
		ui.on_tower_clicked(tower)

func remove_tower(tower: Node2D):
	if tower in towers:
		towers.erase(tower)

func _on_state_changed(new_state: int):
	match new_state:
		GameManager.GameState.COMBAT:
			cancel_placing()
			for tower in towers:
				if is_instance_valid(tower):
					tower.active = true
			start_combat()
		GameManager.GameState.BUILDING:
			for tower in towers:
				if is_instance_valid(tower):
					tower.active = false

func start_combat():
	var waves = GameManager.get_waves_for_round()
	GameManager.set_wave_info(1, waves.size())
	spawning = true
	spawn_all_waves(waves)

func spawn_all_waves(waves: Array):
	for wave_idx in range(waves.size()):
		GameManager.set_wave_info(wave_idx + 1, waves.size())
		var wave_data = waves[wave_idx]
		var enemy_speed = wave_data.get("speed", 3.0)
		var hp_multiplier = wave_data.get("hp_multiplier", 1.0)
		var entries = wave_data.get("entries", [])

		var num_paths = path_generator.paths.size()
		if num_paths == 0:
			continue

		# Build per-entry spawn queues with {type_data, path_idx}
		var entry_queues: Array = []
		for entry_idx in range(mini(entries.size(), num_paths)):
			var queue: Array = []
			for type_name in entries[entry_idx]:
				var count = entries[entry_idx][type_name]
				var type_data = ConfigManager.get_enemy_type_by_name(type_name)
				if type_data.size() > 0:
					for _j in range(count):
						queue.append({"type": type_data, "path_idx": entry_idx})
			entry_queues.append(queue)

		# Interleave spawning across entry points
		var max_queue_size = 0
		for q in entry_queues:
			max_queue_size = maxi(max_queue_size, q.size())

		for i in range(max_queue_size):
			for entry_idx in range(entry_queues.size()):
				if i < entry_queues[entry_idx].size():
					var spawn_info = entry_queues[entry_idx][i]
					var path = path_generator.paths[spawn_info.path_idx]
					var world_path = path_generator.get_world_path(path, actual_cell_size)

					var enemy = CharacterBody2D.new()
					enemy.set_script(load("res://scripts/enemy.gd"))
					enemy.initialize(spawn_info.type, GameManager.difficulty, hp_multiplier, enemy_speed)
					enemy_container.add_child(enemy)
					enemy.set_path(world_path)
					active_enemies += 1
					enemy.tree_exiting.connect(_on_enemy_removed)

					await get_tree().create_timer(0.5).timeout

		# Brief pause between waves
		if wave_idx < waves.size() - 1:
			await get_tree().create_timer(1.0).timeout

	spawning = false
	# All waves spawned - check if enemies already all dead
	call_deferred("check_round_complete")

func _on_enemy_removed():
	active_enemies -= 1
	if active_enemies < 0:
		active_enemies = 0
	# Use call_deferred to avoid checking during tree modification
	call_deferred("check_round_complete")

func check_round_complete():
	if not spawning and active_enemies <= 0 and GameManager.current_state == GameManager.GameState.COMBAT:
		# Double-check by counting actual enemies in the container
		var real_count = 0
		for child in enemy_container.get_children():
			if is_instance_valid(child):
				real_count += 1
		if real_count == 0:
			GameManager.round_complete()

func _get_shape_points_local(p_shape: String, p_size: float) -> PackedVector2Array:
	var half = p_size / 2.0
	match p_shape:
		"square":
			return PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half)
			])
		"circle":
			var points = PackedVector2Array()
			for i in range(16):
				var angle = (i / 16.0) * TAU
				points.append(Vector2(cos(angle), sin(angle)) * half)
			return points
		"triangle":
			return PackedVector2Array([
				Vector2(0, -half), Vector2(half, half), Vector2(-half, half)
			])
		"hexagon":
			var points = PackedVector2Array()
			for i in range(6):
				var angle = (i / 6.0) * TAU
				points.append(Vector2(cos(angle), sin(angle)) * half)
			return points
		_:
			return PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half)
			])
