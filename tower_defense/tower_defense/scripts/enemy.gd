extends CharacterBody2D

var enemy_name: String = "Scout"
var max_hp: float = 5.0
var hp: float = 5.0
var speed: float = 3.0
var base_damage: int = 1
var currency_reward: int = 1
var color: Color = Color.RED
var shape_name: String = "circle"
var size: float = 20.0

var world_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var shape_polygon: Polygon2D = null
var health_bar_bg: ColorRect = null
var health_bar_fg: ColorRect = null
var dead: bool = false

func initialize(type_data: Dictionary, difficulty: int, hp_multiplier: float, move_speed: float):
	enemy_name = type_data.get("name", "Scout")
	var base_hp_mult = type_data.get("hp_multiplier", 1.0)
	max_hp = difficulty * base_hp_mult * hp_multiplier
	hp = max_hp
	speed = move_speed
	base_damage = type_data.get("damage", 1)
	var curr_mult = type_data.get("currency_multiplier", 1.0)
	currency_reward = int(ceil(difficulty * curr_mult))
	color = Color(type_data.get("color_r", 1.0), type_data.get("color_g", 0.0), type_data.get("color_b", 0.0))
	shape_name = type_data.get("shape", "circle")
	size = type_data.get("size", 20.0)

	add_to_group("enemies")
	setup_visuals()
	setup_collision()

func setup_collision():
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = size * 0.5
	collision.shape = shape
	add_child(collision)

func setup_visuals():
	shape_polygon = Polygon2D.new()
	shape_polygon.color = color
	shape_polygon.polygon = get_shape_points(shape_name, size)
	add_child(shape_polygon)

	# Health bar background
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar_bg.size = Vector2(30, 4)
	health_bar_bg.position = Vector2(-15, -size - 8)
	add_child(health_bar_bg)

	# Health bar foreground
	health_bar_fg = ColorRect.new()
	health_bar_fg.color = Color.GREEN
	health_bar_fg.size = Vector2(30, 4)
	health_bar_fg.position = Vector2(-15, -size - 8)
	add_child(health_bar_fg)

func set_path(path: PackedVector2Array):
	world_path = path
	path_index = 0
	if world_path.size() > 0:
		position = world_path[0]
		path_index = 1

func _physics_process(delta: float):
	if dead:
		return
	if path_index >= world_path.size():
		reach_base()
		return

	var target_pos = world_path[path_index]
	var actual_speed = 40.0 * (speed / 3.0)
	var step = actual_speed * delta

	if position.distance_to(target_pos) <= step:
		position = target_pos
		path_index += 1
	else:
		var direction = (target_pos - position).normalized()
		position += direction * step

func take_damage(amount: float):
	if dead:
		return
	hp -= amount
	update_health_bar()
	if hp <= 0:
		die()

func update_health_bar():
	if health_bar_fg == null:
		return
	var ratio = clampf(hp / max_hp, 0.0, 1.0)
	health_bar_fg.size.x = 30.0 * ratio
	if ratio > 0.6:
		health_bar_fg.color = Color.GREEN
	elif ratio > 0.3:
		health_bar_fg.color = Color.YELLOW
	else:
		health_bar_fg.color = Color.RED

func die():
	dead = true
	GameManager.add_currency(currency_reward)
	queue_free()

func reach_base():
	dead = true
	GameManager.damage_base(base_damage)
	queue_free()

func get_shape_points(p_shape: String, p_size: float) -> PackedVector2Array:
	var half = p_size / 2.0
	match p_shape:
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
		"square":
			return PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half)
			])
		"hexagon":
			var points = PackedVector2Array()
			for i in range(6):
				var angle = (i / 6.0) * TAU
				points.append(Vector2(cos(angle), sin(angle)) * half)
			return points
		_:
			var points = PackedVector2Array()
			for i in range(16):
				var angle = (i / 16.0) * TAU
				points.append(Vector2(cos(angle), sin(angle)) * half)
			return points
