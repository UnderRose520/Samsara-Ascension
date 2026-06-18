extends CanvasLayer

const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const CultivationPathRegistry = preload("res://systems/realm/cultivation_path_registry.gd")
const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const DAO_HEART_CARD := preload("res://ui/components/dao_heart_card.tscn")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var start_button: Button = $Panel/Margin/Scroll/VBox/StartButton
@onready var title_label: Label = $Panel/Margin/Scroll/VBox/Title
@onready var detail_label: Label = $Panel/Margin/Scroll/VBox/Detail
@onready var shard_label: Label = $Panel/Margin/Scroll/VBox/ShardLabel
@onready var heart_demon_check: CheckButton = $Panel/Margin/Scroll/VBox/HeartDemonCheck
@onready var points_label: Label = $Panel/Margin/Scroll/VBox/PointsLabel
@onready var seed_input: LineEdit = $Panel/Margin/Scroll/VBox/SeedRow/SeedInput
@onready var random_seed_button: Button = $Panel/Margin/Scroll/VBox/SeedRow/RandomSeedButton
@onready var meta_button: Button = $Panel/Margin/Scroll/VBox/MetaButton
@onready var hearts_box: HBoxContainer = $Panel/Margin/Scroll/VBox/Hearts
@onready var vbox: VBoxContainer = $Panel/Margin/Scroll/VBox

var _selected: int = DaoHeartConfig.DaoHeart.ENLIGHTEN
var _selected_path := CultivationPathRegistry.DEFAULT_PATH_ID
var _meta_panel: CanvasLayer
var _heart_cards: Array[DaoHeartCard] = []
var _path_buttons: Dictionary = {}
var _path_detail_label: Label
var _paths_box: HBoxContainer

const HEART_DEFS := [
	{
		"heart": DaoHeartConfig.DaoHeart.ASK_DAO,
		"key": "ask",
		"title": "问道",
		"subtitle": "平易入道",
		"detail": "问道：敌人 -20% 真元，数量 -1，无心魔试炼台",
	},
	{
		"heart": DaoHeartConfig.DaoHeart.ENLIGHTEN,
		"key": "enlighten",
		"title": "悟道",
		"subtitle": "标准体验",
		"detail": "悟道：标准体验，机缘房 20% 出现心魔试炼台",
	},
	{
		"heart": DaoHeartConfig.DaoHeart.PROVE_DAO,
		"key": "prove",
		"title": "证道",
		"subtitle": "极限试炼",
		"detail": "证道：敌人 +20% 真元，数量 +1，必遇心魔试炼台",
	},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	UiHelpers.apply_panel_polish(panel, false)
	UiHelpers.decorate_modal_header($Panel/Margin/Scroll/VBox, title_label)
	start_button.pressed.connect(_on_start_pressed)
	meta_button.pressed.connect(_on_meta_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	_spawn_heart_cards()
	_spawn_path_picker()
	_refresh_meta()
	_setup_seed_input()
	_add_couplets()
	_select(DaoHeartConfig.DaoHeart.ENLIGHTEN)
	_select_path(CultivationPathRegistry.DEFAULT_PATH_ID)
	call_deferred("_play_open")


func _fit_panel_to_viewport() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_margin := 48.0
	var panel_width := minf(720.0, maxf(viewport_size.x - safe_margin * 2.0, 560.0))
	var panel_height := minf(680.0, maxf(viewport_size.y - safe_margin * 2.0, 520.0))
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5


func _add_couplets() -> void:
	_make_couplet("大道无形", -480.0)
	_make_couplet("仙途无尽", 480.0)


func _make_couplet(text: String, x_offset: float) -> void:
	var lbl := Label.new()
	var vertical := ""
	for i in text.length():
		vertical += text[i]
		if i < text.length() - 1:
			vertical += "\n"
	lbl.text = vertical
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.93, 0.83, 0.55, 0.55))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.12, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_constant_override("line_spacing", 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.anchor_left = 0.5
	lbl.anchor_top = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_bottom = 0.5
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.offset_left = x_offset - 24.0
	lbl.offset_right = x_offset + 24.0
	lbl.offset_top = -110.0
	lbl.offset_bottom = 130.0
	add_child(lbl)
	move_child(lbl, 2)


func _spawn_heart_cards() -> void:
	for child in hearts_box.get_children():
		child.queue_free()
	_heart_cards.clear()
	for def in HEART_DEFS:
		var card: DaoHeartCard = DAO_HEART_CARD.instantiate()
		hearts_box.add_child(card)
		var icon_path: String = AssetPaths.DAO_HEART_ICONS.get(def["key"], "")
		card.setup(str(def["key"]), str(def["title"]), str(def["subtitle"]), icon_path)
		var heart_val: int = int(def["heart"])
		card.selected.connect(func(_id: String) -> void: _select(heart_val))
		_heart_cards.append(card)
		card.modulate.a = 0.0


func _play_open() -> void:
	if not is_inside_tree():
		return
	UiAnimations.modal_open(panel, dimmer)
	for i in _heart_cards.size():
		var card := _heart_cards[i]
		var tw := card.create_tween()
		tw.tween_interval(float(i) * UiAnimations.CARD_STAGGER)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)
	for child in _paths_box.get_children():
		child.modulate.a = 0.0
	for i in _paths_box.get_child_count():
		var button := _paths_box.get_child(i) as Control
		if button == null:
			continue
		var tw := button.create_tween()
		tw.tween_interval(0.12 + float(i) * UiAnimations.CARD_STAGGER)
		tw.tween_property(button, "modulate:a", 1.0, 0.2)


func _spawn_path_picker() -> void:
	var title := Label.new()
	title.text = "选择道途 · 本命器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 0.92))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	vbox.move_child(title, detail_label.get_index() + 1)

	_paths_box = HBoxContainer.new()
	_paths_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_paths_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_paths_box)
	vbox.move_child(_paths_box, title.get_index() + 1)

	_path_detail_label = Label.new()
	_path_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_detail_label.add_theme_color_override("font_color", Color(0.769, 0.714, 0.612, 1))
	_path_detail_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_path_detail_label)
	vbox.move_child(_path_detail_label, _paths_box.get_index() + 1)

	_path_buttons.clear()
	for path in CultivationPathRegistry.get_all_paths():
		var path_id := str(path.get("path_id", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(118, 34)
		button.toggle_mode = true
		button.text = str(path.get("name", path_id))
		button.tooltip_text = "%s\n%s" % [
			CultivationPathRegistry.format_summary(path_id),
			str(path.get("description", "")),
		]
		button.pressed.connect(_on_path_button_pressed.bind(path_id))
		_paths_box.add_child(button)
		_path_buttons[path_id] = button


func _refresh_meta() -> void:
	var shards := SaveManager.get_heart_demon_shards()
	var dao_count: Array = SaveManager.get_awakened_dao_traditions()
	var points := SaveManager.get_reincarnation_points()
	shard_label.text = "心魔碎片 %d/3 · 已觉醒道统 %d" % [shards, dao_count.size()]
	points_label.text = "轮回点 %d · 可永久强化真元/灵石/重随" % points
	var can_boost := shards >= 3
	heart_demon_check.visible = can_boost
	heart_demon_check.disabled = not can_boost
	if can_boost:
		heart_demon_check.text = "心魔强化开局（消耗3碎片 · 仙品词条 · 敌人+10%）"
	else:
		heart_demon_check.button_pressed = false


func _select(heart: int) -> void:
	_selected = heart
	for i in _heart_cards.size():
		if i >= HEART_DEFS.size():
			continue
		var on := int(HEART_DEFS[i]["heart"]) == heart
		_heart_cards[i].set_selected(on)
		if on:
			detail_label.text = str(HEART_DEFS[i]["detail"])


func _select_path(path_id: String) -> void:
	var path := CultivationPathRegistry.get_path_def(path_id)
	_selected_path = str(path.get("path_id", CultivationPathRegistry.DEFAULT_PATH_ID))
	for id in _path_buttons.keys():
		var button := _path_buttons[id] as Button
		if button == null:
			continue
		button.set_pressed_no_signal(str(id) == _selected_path)
		var sb := StyleBoxFlat.new()
		var on := str(id) == _selected_path
		sb.bg_color = Color(0.094, 0.243, 0.196, 0.96) if on else Color(0.051, 0.137, 0.114, 0.78)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.95, 0.84, 0.5, 0.92) if on else Color(0.85, 0.78, 0.55, 0.35)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		button.add_theme_stylebox_override("normal", sb)
		button.add_theme_stylebox_override("pressed", sb)
		button.add_theme_stylebox_override("hover", sb)
	var weapon_id := str(path.get("weapon_id", WeaponRegistry.DEFAULT_WEAPON_ID))
	_path_detail_label.text = "%s：%s / 本命器：%s\n%s" % [
		str(path.get("name", _selected_path)),
		str(path.get("subtitle", "")),
		WeaponRegistry.get_weapon_name(weapon_id),
		str(path.get("description", "")),
	]


func _on_path_button_pressed(path_id: String) -> void:
	_select_path(path_id)


func _on_meta_pressed() -> void:
	if _meta_panel == null:
		_meta_panel = get_parent().get_node_or_null("MetaUpgradePanel")
	if _meta_panel and _meta_panel.has_method("open_panel"):
		_meta_panel.open_panel()
		_refresh_meta()


func _setup_seed_input() -> void:
	var last := SaveManager.get_last_run_seed()
	if last > 0:
		seed_input.placeholder_text = "留空随机 · 上局 %d" % last
	else:
		seed_input.placeholder_text = "留空则随机生成"


func _parse_seed_override() -> int:
	var text := seed_input.text.strip_edges()
	if text.is_empty():
		return -1
	if not text.is_valid_int():
		return -1
	return clampi(int(text), 0, 0x7FFFFFFF)


func _on_random_seed_pressed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	seed_input.text = str(rng.randi() & 0x7FFFFFFF)


func _on_start_pressed() -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		visible = false
		var use_boost := heart_demon_check.visible and heart_demon_check.button_pressed
		RunContext.begin_run(_selected, _parse_seed_override(), use_boost, false, _selected_path)
		EventBus.run_setup_confirmed.emit()
	)
