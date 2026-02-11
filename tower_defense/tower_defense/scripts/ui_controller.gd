extends CanvasLayer

# Top bar labels
var currency_label: Label = null
var hp_label: Label = null
var round_label: Label = null
var wave_label: Label = null

# Bottom bar
var catalog_button: Button = null
var start_wave_button: Button = null

# Right panel
var right_panel: PanelContainer = null
var right_panel_tower_list: VBoxContainer = null

# Catalog modal
var catalog_panel: PanelContainer = null
var catalog_list: VBoxContainer = null

# Demolish popup
var demolish_popup: PanelContainer = null
var demolish_tower_name: Label = null
var demolish_refund: Label = null
var selected_tower_for_demolish: Node2D = null

# Difficulty selection
var difficulty_panel: PanelContainer = null

# Game over panel
var game_over_panel: PanelContainer = null
var game_over_label: Label = null

# HUD container
var hud_container: Control = null

# Layout values computed from grid config
var grid_px: int = 720
var board_x: int = 10
var viewport_w: int = 1000
var viewport_h: int = 800

func _ready():
	await get_tree().process_frame

	# Compute layout from grid config (must match game_board.gd constants)
	var grid_size = mini(ConfigManager.get_game_setting("grid_size", 9), 20)
	var cell_size = ConfigManager.get_game_setting("cell_size", 80)
	grid_px = grid_size * cell_size
	board_x = 10
	var top_bar_h = 40
	var bottom_bar_h = 38
	var panel_gap = 20
	var right_panel_w = 250
	viewport_w = board_x + grid_px + panel_gap + right_panel_w
	viewport_h = top_bar_h + 2 + grid_px + bottom_bar_h

	build_difficulty_screen()
	build_hud()
	build_right_panel()
	build_catalog_modal()
	build_demolish_popup()
	build_game_over_panel()

	# Connect signals
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.base_hp_changed.connect(_on_hp_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.tower_unlocked.connect(_on_tower_unlocked)
	GameManager.game_over.connect(_on_game_over)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.wave_changed.connect(_on_wave_changed)

	# Start with difficulty screen visible
	if hud_container:
		hud_container.visible = false
	right_panel.visible = false

# ===== DIFFICULTY SCREEN =====
func build_difficulty_screen():
	difficulty_panel = PanelContainer.new()
	difficulty_panel.name = "DifficultyPanel"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	difficulty_panel.add_theme_stylebox_override("panel", style)

	difficulty_panel.custom_minimum_size = Vector2(400, 350)
	difficulty_panel.anchor_left = 0.5
	difficulty_panel.anchor_right = 0.5
	difficulty_panel.anchor_top = 0.5
	difficulty_panel.anchor_bottom = 0.5
	difficulty_panel.offset_left = -200
	difficulty_panel.offset_right = 200
	difficulty_panel.offset_top = -175
	difficulty_panel.offset_bottom = 175

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 15)

	var title = Label.new()
	title.text = "Tower Defense"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	inner_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Select Difficulty"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	inner_vbox.add_child(subtitle)

	var sep = HSeparator.new()
	inner_vbox.add_child(sep)

	var diff_names = ["Easy (1 Path)", "Normal (2 Paths)", "Hard (3 Paths)", "Extreme (4 Paths)"]
	for i in range(4):
		var btn = Button.new()
		btn.text = diff_names[i]
		btn.custom_minimum_size = Vector2(0, 45)
		btn.pressed.connect(func(): select_difficulty(i + 1))
		inner_vbox.add_child(btn)

	margin.add_child(inner_vbox)
	vbox.add_child(margin)
	difficulty_panel.add_child(vbox)
	add_child(difficulty_panel)

# ===== HUD =====
func build_hud():
	hud_container = Control.new()
	hud_container.name = "HUD"
	hud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Top bar
	var top_bar = PanelContainer.new()
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	top_bar.add_theme_stylebox_override("panel", top_style)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 40)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 30)

	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 15)
	top_margin.add_theme_constant_override("margin_right", 15)

	currency_label = Label.new()
	currency_label.text = "Currency: $10"
	currency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(currency_label)

	hp_label = Label.new()
	hp_label.text = "Base HP: 10/10"
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(hp_label)

	round_label = Label.new()
	round_label.text = "Round: 0/6"
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(round_label)

	wave_label = Label.new()
	wave_label.text = "Wave: -/-"
	wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(wave_label)

	top_margin.add_child(top_hbox)
	top_bar.add_child(top_margin)
	hud_container.add_child(top_bar)

	# Bottom bar
	var bottom_bar = PanelContainer.new()
	var bot_style = StyleBoxFlat.new()
	bot_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bottom_bar.add_theme_stylebox_override("panel", bot_style)
	var bottom_bar_w = board_x + grid_px + 5
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 0.0
	bottom_bar.offset_top = -38
	bottom_bar.offset_bottom = 0
	bottom_bar.offset_right = bottom_bar_w
	bottom_bar.custom_minimum_size = Vector2(bottom_bar_w, 38)

	var bot_margin = MarginContainer.new()
	bot_margin.add_theme_constant_override("margin_left", 15)
	bot_margin.add_theme_constant_override("margin_right", 15)
	bot_margin.add_theme_constant_override("margin_top", 5)
	bot_margin.add_theme_constant_override("margin_bottom", 5)

	var bot_hbox = HBoxContainer.new()

	catalog_button = Button.new()
	catalog_button.text = "Tower Catalog"
	catalog_button.custom_minimum_size = Vector2(150, 0)
	catalog_button.pressed.connect(_on_catalog_pressed)
	bot_hbox.add_child(catalog_button)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_hbox.add_child(spacer)

	start_wave_button = Button.new()
	start_wave_button.text = "Start Wave"
	start_wave_button.custom_minimum_size = Vector2(150, 0)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	bot_hbox.add_child(start_wave_button)

	bot_margin.add_child(bot_hbox)
	bottom_bar.add_child(bot_margin)
	hud_container.add_child(bottom_bar)

	add_child(hud_container)

# ===== RIGHT PANEL =====
func build_right_panel():
	right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.border_width_left = 2
	right_panel.add_theme_stylebox_override("panel", style)

	var panel_left = board_x + grid_px + 20
	right_panel.anchor_left = 0.0
	right_panel.anchor_right = 0.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = panel_left
	right_panel.offset_right = viewport_w
	right_panel.offset_top = 45
	right_panel.offset_bottom = -43

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title_label = Label.new()
	title_label.text = "Available Towers"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	right_panel_tower_list = VBoxContainer.new()
	right_panel_tower_list.add_theme_constant_override("separation", 10)
	scroll.add_child(right_panel_tower_list)
	vbox.add_child(scroll)

	margin.add_child(vbox)
	right_panel.add_child(margin)
	add_child(right_panel)

# ===== CATALOG MODAL =====
func build_catalog_modal():
	catalog_panel = PanelContainer.new()
	catalog_panel.name = "CatalogPanel"
	catalog_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.97)
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	catalog_panel.add_theme_stylebox_override("panel", style)

	catalog_panel.custom_minimum_size = Vector2(600, 500)
	catalog_panel.anchor_left = 0.5
	catalog_panel.anchor_right = 0.5
	catalog_panel.anchor_top = 0.5
	catalog_panel.anchor_bottom = 0.5
	catalog_panel.offset_left = -300
	catalog_panel.offset_right = 300
	catalog_panel.offset_top = -250
	catalog_panel.offset_bottom = 250

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Title bar
	var title_hbox = HBoxContainer.new()
	var cat_title = Label.new()
	cat_title.text = "Tower Catalog - Unlock New Towers"
	cat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_title.add_theme_font_size_override("font_size", 18)
	title_hbox.add_child(cat_title)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): catalog_panel.visible = false)
	title_hbox.add_child(close_btn)
	vbox.add_child(title_hbox)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	catalog_list = VBoxContainer.new()
	catalog_list.add_theme_constant_override("separation", 8)
	scroll.add_child(catalog_list)
	vbox.add_child(scroll)

	margin.add_child(vbox)
	catalog_panel.add_child(margin)
	add_child(catalog_panel)

# ===== DEMOLISH POPUP =====
func build_demolish_popup():
	demolish_popup = PanelContainer.new()
	demolish_popup.name = "DemolishPopup"
	demolish_popup.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.1, 0.97)
	style.border_color = Color(0.7, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	demolish_popup.add_theme_stylebox_override("panel", style)

	demolish_popup.custom_minimum_size = Vector2(300, 200)
	demolish_popup.anchor_left = 0.5
	demolish_popup.anchor_right = 0.5
	demolish_popup.anchor_top = 0.5
	demolish_popup.anchor_bottom = 0.5
	demolish_popup.offset_left = -150
	demolish_popup.offset_right = 150
	demolish_popup.offset_top = -100
	demolish_popup.offset_bottom = 100

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "Demolish Tower?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	demolish_tower_name = Label.new()
	demolish_tower_name.text = ""
	demolish_tower_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(demolish_tower_name)

	demolish_refund = Label.new()
	demolish_refund.text = "Refund: $0"
	demolish_refund.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(demolish_refund)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)

	var demolish_btn = Button.new()
	demolish_btn.text = "Demolish"
	demolish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demolish_btn.pressed.connect(_on_demolish_confirmed)
	btn_hbox.add_child(demolish_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): demolish_popup.visible = false)
	btn_hbox.add_child(cancel_btn)

	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	demolish_popup.add_child(margin)
	add_child(demolish_popup)

# ===== GAME OVER =====
func build_game_over_panel():
	game_over_panel = PanelContainer.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = Color(0.5, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	game_over_panel.add_theme_stylebox_override("panel", style)

	game_over_panel.custom_minimum_size = Vector2(400, 250)
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -200
	game_over_panel.offset_right = 200
	game_over_panel.offset_top = -125
	game_over_panel.offset_bottom = 125

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	game_over_label = Label.new()
	game_over_label.text = "Game Over"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(game_over_label)

	var restart_btn = Button.new()
	restart_btn.text = "Play Again"
	restart_btn.custom_minimum_size = Vector2(0, 45)
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(restart_btn)

	margin.add_child(vbox)
	game_over_panel.add_child(margin)
	add_child(game_over_panel)

# ===== ACTIONS =====
func select_difficulty(difficulty: int):
	difficulty_panel.visible = false

	var game_board = get_node_or_null("../GameBoard")
	if game_board:
		game_board.generate_paths(difficulty)

	GameManager.start_game(difficulty)

	if hud_container:
		hud_container.visible = true
	right_panel.visible = true

	await get_tree().process_frame
	create_tower_buttons()

func create_tower_buttons():
	for child in right_panel_tower_list.get_children():
		child.queue_free()

	var tower_types = ConfigManager.get_tower_types()
	for i in range(tower_types.size()):
		var tower_type = tower_types[i]
		if GameManager.is_tower_unlocked(tower_type.name):
			create_tower_card(tower_type, i)

func create_tower_card(tower_type: Dictionary, tower_index: int):
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.18, 0.18, 0.22, 1.0)
	card_style.set_corner_radius_all(4)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(0.3, 0.3, 0.35)
	card.add_theme_stylebox_override("panel", card_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Tower preview
	var preview_container = CenterContainer.new()
	preview_container.custom_minimum_size = Vector2(60, 60)
	var preview = create_tower_preview(tower_type)
	preview_container.add_child(preview)
	vbox.add_child(preview_container)

	# Tower name
	var name_label = Label.new()
	name_label.text = tower_type.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Cost
	var cost_label = Label.new()
	cost_label.text = "Cost: $" + str(tower_type.cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(cost_label)

	# Place button
	var button = Button.new()
	button.text = "Place Tower"
	button.pressed.connect(func(): _on_tower_button_pressed(tower_index))
	vbox.add_child(button)

	margin.add_child(vbox)
	card.add_child(margin)
	right_panel_tower_list.add_child(card)

func create_tower_preview(tower_type: Dictionary) -> Control:
	var sub_viewport_container = SubViewportContainer.new()
	sub_viewport_container.custom_minimum_size = Vector2(60, 60)
	sub_viewport_container.stretch = true

	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(60, 60)
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var shape = Polygon2D.new()
	shape.color = Color(tower_type.get("color_r", 1.0), tower_type.get("color_g", 1.0), tower_type.get("color_b", 1.0))
	var s = min(tower_type.get("size", 30), 25)
	shape.polygon = _get_preview_shape(tower_type.get("shape", "square"), s)
	shape.position = Vector2(30, 30)
	sub_viewport.add_child(shape)

	sub_viewport_container.add_child(sub_viewport)
	return sub_viewport_container

func _get_preview_shape(shape_name: String, p_size: float) -> PackedVector2Array:
	var half = p_size / 2.0
	match shape_name:
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

func _on_tower_button_pressed(tower_index: int):
	if not GameManager.is_building_phase():
		return
	var tower_types = ConfigManager.get_tower_types()
	if tower_index < tower_types.size():
		var game_board = get_node_or_null("../GameBoard")
		if game_board:
			game_board.start_placing_tower(tower_types[tower_index])

func _on_catalog_pressed():
	populate_catalog()
	catalog_panel.visible = true

func populate_catalog():
	for child in catalog_list.get_children():
		child.queue_free()

	var tower_types = ConfigManager.get_tower_types()
	for tower_type in tower_types:
		create_catalog_entry(tower_type)

func create_catalog_entry(tower_type: Dictionary):
	var entry = PanelContainer.new()
	var entry_style = StyleBoxFlat.new()
	entry_style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	entry_style.set_corner_radius_all(4)
	entry.add_theme_stylebox_override("panel", entry_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)

	# Preview
	var preview = create_tower_preview(tower_type)
	hbox.add_child(preview)

	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)

	var name_label = Label.new()
	name_label.text = tower_type.get("name", "Tower")
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = tower_type.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_label)

	var stats_label = Label.new()
	stats_label.text = "Dmg: %s | Rate: %s/s | Range: %s | Cost: $%s" % [
		str(tower_type.get("damage", 0)),
		str(tower_type.get("fire_rate", 0)),
		str(int(tower_type.get("range", 0))),
		str(tower_type.get("cost", 0))
	]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	info_vbox.add_child(stats_label)

	hbox.add_child(info_vbox)

	# Unlock section
	var unlock_vbox = VBoxContainer.new()
	unlock_vbox.custom_minimum_size = Vector2(100, 0)

	var is_unlocked = GameManager.is_tower_unlocked(tower_type.get("name", ""))
	if is_unlocked:
		var unlocked_label = Label.new()
		unlocked_label.text = "✓ UNLOCKED"
		unlocked_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		unlocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_vbox.add_child(unlocked_label)
	else:
		var cost_label = Label.new()
		cost_label.text = "Unlock: $" + str(tower_type.get("unlock_cost", 0))
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_vbox.add_child(cost_label)

		var unlock_btn = Button.new()
		unlock_btn.text = "Unlock"
		var unlock_cost = tower_type.get("unlock_cost", 0)
		if GameManager.currency < unlock_cost:
			unlock_btn.disabled = true
		unlock_btn.pressed.connect(func():
			var tower_name = tower_type.get("name", "")
			if GameManager.unlock_tower(tower_name, unlock_cost):
				populate_catalog()
				create_tower_buttons()
		)
		unlock_vbox.add_child(unlock_btn)

	hbox.add_child(unlock_vbox)

	margin.add_child(hbox)
	entry.add_child(margin)
	catalog_list.add_child(entry)

func _on_start_wave_pressed():
	if GameManager.is_building_phase():
		GameManager.start_round()

func show_demolish_popup(tower: Node2D):
	selected_tower_for_demolish = tower
	demolish_tower_name.text = tower.tower_name
	demolish_refund.text = "Refund: $" + str(tower.cost)
	demolish_popup.visible = true

func _on_demolish_confirmed():
	if selected_tower_for_demolish and is_instance_valid(selected_tower_for_demolish):
		GameManager.add_currency(selected_tower_for_demolish.cost)
		var game_board = get_node_or_null("../GameBoard")
		if game_board:
			game_board.remove_tower(selected_tower_for_demolish)
		selected_tower_for_demolish.queue_free()
	demolish_popup.visible = false

func on_tower_clicked(tower: Node2D):
	if GameManager.is_building_phase():
		show_demolish_popup(tower)

# ===== SIGNAL HANDLERS =====
func _on_currency_changed(amount: int):
	if currency_label:
		currency_label.text = "Currency: $" + str(amount)
	# Refresh buttons that depend on currency
	update_button_states()

func _on_hp_changed(hp: int):
	if hp_label:
		hp_label.text = "Base HP: %d/%d" % [hp, GameManager.max_base_hp]

func _on_round_changed(round_num: int):
	if round_label:
		round_label.text = "Round: %d/%d" % [round_num, GameManager.max_rounds]

func _on_wave_changed(wave_num: int, total: int):
	if wave_label:
		wave_label.text = "Wave: %d/%d" % [wave_num, total]

func _on_state_changed(new_state: int):
	match new_state:
		GameManager.GameState.BUILDING:
			if start_wave_button:
				start_wave_button.disabled = false
				start_wave_button.text = "Start Wave"
			update_button_states()
		GameManager.GameState.COMBAT:
			if start_wave_button:
				start_wave_button.disabled = true
				start_wave_button.text = "In Combat..."
			update_button_states()

func _on_tower_unlocked(_tower_name: String):
	create_tower_buttons()

func _on_game_over(won: bool):
	game_over_panel.visible = true
	if won:
		game_over_label.text = "Victory!"
		game_over_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		game_over_label.text = "Game Over - Base Destroyed!"
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func update_button_states():
	# Update tower card place buttons based on affordability and state
	for card in right_panel_tower_list.get_children():
		var margin_node = card.get_child(0)
		if margin_node:
			var vbox = margin_node.get_child(0)
			if vbox and vbox.get_child_count() > 3:
				var btn = vbox.get_child(3) as Button
				if btn:
					btn.disabled = not GameManager.is_building_phase()
