extends Node2D

signal tower_clicked(tower: Node2D)

var tower_name: String = ""
var cost: int = 0
var damage: float = 1.0
var fire_rate: float = 1.0
var attack_range: float = 120.0
var tower_color: Color = Color.WHITE
var shape_name: String = "square"
var size: float = 30.0

var shape_polygon: Polygon2D = null
var turret_polygon: Polygon2D = null
var range_circle: Line2D = null
var detection_area: Area2D = null
var click_area: Area2D = null

var fire_timer: float = 0.0
var target_enemy: Node2D = null
var enemies_in_range: Array = []
var active: bool = false

func initialize(type_data: Dictionary):
	tower_name = type_data.get("name", "Tower")
	cost = type_data.get("cost", 1)
	damage = type_data.get("damage", 1.0)
	fire_rate = type_data.get("fire_rate", 1.0)
	attack_range = type_data.get("range", 120.0)
	tower_color = Color(type_data.get("color_r", 1.0), type_data.get("color_g", 1.0), type_data.get("color_b", 1.0))
	shape_name = type_data.get("shape", "square")
	size = type_data.get("size", 30.0)

	setup_visuals()
	setup_detection_area()
	setup_click_area()

func setup_visuals():
	# Main body
	shape_polygon = Polygon2D.new()
	shape_polygon.color = tower_color
	shape_polygon.polygon = get_shape_points(shape_name, size)
	add_child(shape_polygon)

	# Turret
	turret_polygon = Polygon2D.new()
	turret_polygon.color = tower_color.darkened(0.3)
	turret_polygon.polygon = get_shape_points("triangle", size * 0.4)
	add_child(turret_polygon)

	# Range circle (hidden by default)
	range_circle = Line2D.new()
	range_circle.default_color = Color(1, 1, 1, 0.2)
	range_circle.width = 1.0
	var points = PackedVector2Array()
	for i in range(33):
		var angle = (i / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * attack_range)
	range_circle.points = points
	range_circle.visible = false
	add_child(range_circle)

func setup_detection_area():
	detection_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = attack_range
	collision.shape = shape
	detection_area.add_child(collision)
	add_child(detection_area)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func setup_click_area():
	click_area = Area2D.new()
	click_area.input_pickable = true
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	click_area.add_child(collision)
	add_child(click_area)
	click_area.input_event.connect(_on_click_area_input)

func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tower_clicked", self)

func _on_body_entered(body: Node2D):
	if body.is_in_group("enemies"):
		if body not in enemies_in_range:
			enemies_in_range.append(body)

func _on_body_exited(body: Node2D):
	enemies_in_range.erase(body)
	if body == target_enemy:
		target_enemy = null

func _process(delta: float):
	if not active:
		return

	# Clean dead enemies
	var valid_enemies = []
	for e in enemies_in_range:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			valid_enemies.append(e)
	enemies_in_range = valid_enemies

	# Find target
	if target_enemy == null or not is_instance_valid(target_enemy) or target_enemy not in enemies_in_range:
		target_enemy = find_nearest_enemy()

	# Rotate turret towards target
	if target_enemy and is_instance_valid(target_enemy):
		var dir = (target_enemy.global_position - global_position).normalized()
		turret_polygon.rotation = dir.angle() + PI / 2

	# Fire
	fire_timer -= delta
	if fire_timer <= 0 and target_enemy and is_instance_valid(target_enemy):
		fire_at(target_enemy)
		fire_timer = 1.0 / fire_rate

func find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist = INF
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func fire_at(enemy: Node2D):
	# Create projectile as a line
	var projectile = Line2D.new()
	projectile.default_color = Color(0.0, 1.0, 1.0, 0.8)
	projectile.width = 2.0
	projectile.points = PackedVector2Array([Vector2.ZERO, enemy.global_position - global_position])
	add_child(projectile)

	# Deal damage
	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(damage)

	# Remove projectile after short delay
	var tween = create_tween()
	tween.tween_property(projectile, "modulate:a", 0.0, 0.15)
	tween.tween_callback(projectile.queue_free)

func show_range():
	if range_circle:
		range_circle.visible = true

func hide_range():
	if range_circle:
		range_circle.visible = false

static func get_shape_points(p_shape_name: String, p_size: float) -> PackedVector2Array:
	var half = p_size / 2.0
	match p_shape_name:
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
		"pentagon":
			var points = PackedVector2Array()
			for i in range(5):
				var angle = (i / 5.0) * TAU - PI / 2
				points.append(Vector2(cos(angle), sin(angle)) * half)
			return points
		_:
			return PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half)
			])
