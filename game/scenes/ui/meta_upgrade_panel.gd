extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var points_icon: TextureRect = $Panel/Margin/VBox/PointsRow/PointsIcon
@onready var points_label: Label = $Panel/Margin/VBox/PointsRow/PointsLabel
@onready var list_box: VBoxContainer = $Panel/Margin/VBox/ListScroll/List
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _was_paused_before_open := false
var _was_ui_blocking_before_open := false
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	UiHelpers.add_gold_divider($Panel/Margin/VBox, $Panel/Margin/VBox/ListScroll)
	points_icon.texture = AssetPaths.load_texture(AssetPaths.status_icon("dao"))
	close_button.icon = AssetPaths.load_texture(AssetPaths.status_icon("dao"))
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiHelpers.apply_button_asset(close_button, false)
	close_button.pressed.connect(_on_close_pressed)
	dimmer.gui_input.connect(_on_dimmer_gui_input)


func open_panel() -> void:
	if panel.visible:
		_refresh()
		return
	_closing = false
	_was_paused_before_open = get_tree().paused
	_was_ui_blocking_before_open = RunContext.ui_blocking
	RunContext.ui_blocking = true
	get_tree().paused = true
	_refresh()
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible or _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _refresh() -> void:
	var points := SaveManager.get_reincarnation_points()
	points_label.text = "轮回点 %d · 永久道基" % points
	for child in list_box.get_children():
		child.queue_free()
	for row in MetaUpgradeRegistry.get_all():
		list_box.add_child(_make_upgrade_row(row as Dictionary, points))


func _make_upgrade_row(row: Dictionary, points: int) -> PanelContainer:
	var id := str(row.get("id", ""))
	var level := int(SaveManager.get_meta_level(id))
	var max_level := int(row.get("max_level", 0))
	var cost := int(MetaUpgradeRegistry.next_cost(id))
	var effect_key := str(row.get("effect_key", ""))
	var effect_value := int(row.get("effect_value", 0))
	var maxed := max_level > 0 and level >= max_level
	var affordable := not maxed and cost >= 0 and points >= cost
	var accent := _upgrade_accent_color(id, effect_key)

	var row_panel := PanelContainer.new()
	row_panel.name = "MetaUpgradeRow_%s" % id
	row_panel.custom_minimum_size = Vector2(0, 96)
	var panel_style := UiHelpers.make_ninepatch_panel_style()
	panel_style.modulate_color = Color(0.84, 1.0, 0.92, 0.70 if affordable else 0.54)
	row_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.name = "MetaUpgradeMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	row_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.name = "MetaUpgradeRow"
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	var icon := TextureRect.new()
	icon.name = "MetaUpgradeIcon"
	icon.custom_minimum_size = Vector2(54, 54)
	icon.texture = AssetPaths.load_texture(_upgrade_icon_path(id, effect_key))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(
		minf(accent.r * 1.18 + 0.08, 1.0),
		minf(accent.g * 1.18 + 0.08, 1.0),
		minf(accent.b * 1.18 + 0.08, 1.0),
		1.0
	) if affordable or maxed else Color(0.70, 0.72, 0.66, 0.86)
	hbox.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.name = "MetaUpgradeText"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 5)
	hbox.add_child(text_box)

	var title_row := HBoxContainer.new()
	title_row.name = "MetaUpgradeTitleRow"
	title_row.add_theme_constant_override("separation", 8)
	text_box.add_child(title_row)

	var name_label := Label.new()
	name_label.name = "MetaUpgradeName"
	name_label.text = "%s  Lv.%d/%d" % [str(row.get("name", id)), level, max_level]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", accent if affordable or maxed else UiTokens.TEXT_SECONDARY)
	name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.84))
	name_label.add_theme_constant_override("outline_size", 1)
	title_row.add_child(name_label)

	var state_label := Label.new()
	state_label.name = "MetaUpgradeState"
	state_label.text = _upgrade_state_text(maxed, affordable)
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override("font_color", _upgrade_state_color(maxed, affordable))
	state_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.82))
	state_label.add_theme_constant_override("outline_size", 1)
	title_row.add_child(state_label)

	var desc := Label.new()
	desc.name = "MetaUpgradeDesc"
	desc.text = "%s · %s" % [str(row.get("description", "")), _effect_summary(effect_key, effect_value)]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	desc.custom_minimum_size = Vector2(0, 26)
	text_box.add_child(desc)

	var pips := HBoxContainer.new()
	pips.name = "MetaUpgradePips"
	pips.add_theme_constant_override("separation", 5)
	text_box.add_child(pips)
	for i in range(maxi(max_level, 1)):
		var pip := TextureRect.new()
		pip.name = "LevelPip_%d" % i
		pip.custom_minimum_size = Vector2(30, 8)
		pip.texture = AssetPaths.load_texture(AssetPaths.DIVIDER_GOLD)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_SCALE
		pip.modulate = Color(
			minf(accent.r * 1.24 + 0.10, 1.0),
			minf(accent.g * 1.24 + 0.10, 1.0),
			minf(accent.b * 1.24 + 0.10, 1.0),
			1.0
		) if i < level else Color(0.28, 0.34, 0.31, 0.66)
		pips.add_child(pip)

	var action_box := VBoxContainer.new()
	action_box.name = "MetaUpgradeAction"
	action_box.custom_minimum_size = Vector2(150, 0)
	action_box.add_theme_constant_override("separation", 8)
	hbox.add_child(action_box)

	var cost_row := HBoxContainer.new()
	cost_row.name = "CostRow"
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 5)
	action_box.add_child(cost_row)

	var cost_icon := TextureRect.new()
	cost_icon.name = "CostIcon"
	cost_icon.custom_minimum_size = Vector2(20, 20)
	cost_icon.texture = AssetPaths.load_texture(AssetPaths.status_icon("dao") if maxed else AssetPaths.ICON_SPIRIT_STONE)
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_row.add_child(cost_icon)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "已圆满" if maxed else "%d" % cost
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD if affordable or maxed else UiTokens.TEXT_MUTED)
	cost_row.add_child(cost_label)

	var btn := Button.new()
	btn.name = "MetaUpgradeButton"
	btn.text = _upgrade_button_text(maxed, affordable)
	btn.theme_type_variation = &"Primary"
	btn.custom_minimum_size = Vector2(132, 42)
	btn.disabled = maxed or not affordable
	btn.icon = AssetPaths.load_texture(AssetPaths.status_icon("dao") if maxed else AssetPaths.ICON_SPIRIT_STONE)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiHelpers.apply_button_asset(btn, true)
	btn.pressed.connect(_on_upgrade_pressed.bind(id))
	action_box.add_child(btn)
	return row_panel


func _on_upgrade_pressed(id: String) -> void:
	if SaveManager.try_upgrade_meta(id):
		_refresh()


func _upgrade_icon_path(id: String, effect_key: String) -> String:
	match id:
		"vitality":
			return AssetPaths.status_icon("shield")
		"fortune":
			return AssetPaths.ICON_SPIRIT_STONE
		"insight":
			return AssetPaths.status_icon("dao")
	match effect_key:
		"hp":
			return AssetPaths.status_icon("shield")
		"start_gold":
			return AssetPaths.ICON_SPIRIT_STONE
		"reroll_discount":
			return AssetPaths.status_icon("counter")
	return AssetPaths.talent_realm_icon(1)


func _upgrade_accent_color(id: String, effect_key: String) -> Color:
	match id:
		"vitality":
			return UiTokens.ELEM_WOOD
		"fortune":
			return UiTokens.ACCENT_GOLD
		"insight":
			return UiTokens.ELEM_CHAOS
	match effect_key:
		"hp":
			return UiTokens.ELEM_WOOD
		"start_gold":
			return UiTokens.ACCENT_GOLD
		"reroll_discount":
			return UiTokens.ELEM_CHAOS
	return UiTokens.ACCENT_JADE


func _effect_summary(effect_key: String, effect_value: int) -> String:
	match effect_key:
		"hp":
			return "开局真元 +%d/级" % effect_value
		"start_gold":
			return "开局灵石 +%d/级" % effect_value
		"reroll_discount":
			return "重随费用 -%d/级" % effect_value
	return "%s %+d/级" % [effect_key, effect_value]


func _upgrade_state_text(maxed: bool, affordable: bool) -> String:
	if maxed:
		return "圆满"
	if affordable:
		return "可突破"
	return "道缘不足"


func _upgrade_state_color(maxed: bool, affordable: bool) -> Color:
	if maxed:
		return UiTokens.ACCENT_JADE
	if affordable:
		return UiTokens.ACCENT_GOLD
	return UiTokens.TEXT_MUTED


func _upgrade_button_text(maxed: bool, affordable: bool) -> String:
	if maxed:
		return "已满"
	if affordable:
		return "突破"
	return "不足"


func _on_close_pressed() -> void:
	_close()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:
	if _closing or not panel.visible:
		return
	_closing = true
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		RunContext.ui_blocking = _was_ui_blocking_before_open
		get_tree().paused = _was_paused_before_open
		_closing = false
	)
