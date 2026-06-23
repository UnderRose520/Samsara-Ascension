extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: TextureRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var art_frame: Control = $Panel/Margin/VBox/ArtFrame
@onready var art_banner: TextureRect = $Panel/Margin/VBox/ArtFrame/ArtBanner
@onready var art_icon_backing: TextureRect = $Panel/Margin/VBox/ArtFrame/ArtIconBacking
@onready var art_icon: TextureRect = $Panel/Margin/VBox/ArtFrame/ArtIcon
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var buttons_box: VBoxContainer = $Panel/Margin/VBox/Buttons

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_modal_veil(dimmer, 0.82)
	UiHelpers.apply_panel_polish(panel, true)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	EventBus.event_requested.connect(_on_event_requested)


func _on_event_requested(event: Dictionary, choices: Array) -> void:
	title_label.text = str(event.get("title", "机缘"))
	body_label.text = str(event.get("body", ""))
	art_banner.texture = AssetPaths.load_texture(_event_art_path(event))
	art_frame.custom_minimum_size = Vector2(0, _event_art_height(event))
	art_banner.modulate = _event_art_modulate(event)
	art_icon_backing.texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("status_badge_backing"))
	art_icon_backing.visible = art_icon_backing.texture != null
	art_icon_backing.modulate = Color(0.72, 0.94, 0.86, 0.62)
	art_icon.texture = AssetPaths.load_texture(_event_icon_path(event))
	art_icon.visible = art_icon.texture != null
	art_icon.custom_minimum_size = Vector2(44, 44)
	art_icon.modulate = _event_icon_modulate(event)
	for child in buttons_box.get_children():
		child.queue_free()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		var karma_key := _choice_karma_key(choice)
		var karma_tex := AssetPaths.load_texture(AssetPaths.karma_icon(karma_key))
		if karma_tex:
			icon.texture = karma_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.theme_type_variation = &"Secondary"
		btn.text = str(choice.get("label", "选择"))
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		UiHelpers.apply_button_asset(btn, false)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		row.add_child(btn)
		buttons_box.add_child(row)
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)


func _on_choice_pressed(index: int) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		EventBus.event_closed.emit(index)
	)


func _event_art_path(event: Dictionary) -> String:
	var category := str(event.get("category", "regular"))
	var event_id := str(event.get("id", ""))
	if category == "heart_demon" or event_id.begins_with("M"):
		return AssetPaths.EVENT_SECRET_ILLUSTRATION
	if category in ["weather", "karma"]:
		return AssetPaths.EVENT_ILLUSTRATION
	return AssetPaths.EVENT_BANNER


func _event_art_height(event: Dictionary) -> float:
	var category := str(event.get("category", "regular"))
	var event_id := str(event.get("id", ""))
	if category == "heart_demon" or event_id.begins_with("M"):
		return 250.0
	return 230.0 if category in ["weather", "karma"] else 210.0


func _event_art_modulate(event: Dictionary) -> Color:
	var category := str(event.get("category", "regular"))
	return Color(1.12, 1.10, 1.02, 1.0) if category in ["weather", "karma"] else Color.WHITE


func _event_icon_path(event: Dictionary) -> String:
	var category := str(event.get("category", "regular"))
	var event_id := str(event.get("id", ""))
	if category == "heart_demon" or event_id.begins_with("M"):
		return AssetPaths.ICON_HEART_DEMON_TRIAL
	if category == "weather":
		return AssetPaths.weather_icon(str(event.get("weather", "thunder")))
	if category == "karma":
		return AssetPaths.karma_icon("dao_heart")
	return AssetPaths.status_icon("dao")


func _event_icon_modulate(event: Dictionary) -> Color:
	var category := str(event.get("category", "regular"))
	match category:
		"weather":
			return Color(1.12, 1.22, 1.42, 0.84)
		"karma":
			return Color(1.14, 1.00, 0.70, 0.82)
		"heart_demon":
			return Color(1.22, 0.68, 0.96, 0.82)
	return Color(0.90, 1.08, 0.96, 0.78)


func _choice_karma_key(choice: Dictionary) -> String:
	var explicit := str(choice.get("karma", "")).strip_edges()
	if not explicit.is_empty():
		match explicit:
			"heart_demon":
				return "rebellion"
			"mercy":
				return "good"
			"dao":
				return "dao_heart"
			_:
				return explicit
	var effect := str(choice.get("effect", "")).strip_edges().to_lower()
	if effect.contains("trial_accept"):
		return "rebellion"
	if effect.contains("trial_contemplate"):
		return "dao_heart"
	if effect.contains("trial_leave"):
		return "good"
	if effect.contains("karma:good"):
		return "good"
	if effect.contains("karma:evil"):
		return "evil"
	if effect.contains("karma:greed"):
		return "greed"
	if effect.contains("karma:rebellion"):
		return "rebellion"
	if effect.contains("karma:dao") or effect.contains("trial_"):
		return "dao_heart"
	if effect.contains("gold:"):
		return "greed"
	if effect.contains("heal") or effect.contains("speed"):
		return "good"
	if effect.contains("bias:"):
		return "dao_heart"
	return "dao_heart"
