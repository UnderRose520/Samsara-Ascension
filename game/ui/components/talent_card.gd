extends PanelContainer

signal talent_selected(talent_id: String)

const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var frame_bg: TextureRect = $FrameBg
@onready var badge_icon: TextureRect = $BadgeIcon
@onready var icon: TextureRect = $Margin/VBox/IconRow/Icon
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var select_button: Button = $Margin/VBox/SelectButton

var _talent_id := ""
var _hover_bound := false


func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	add_theme_stylebox_override("panel", _make_talent_card_style(false))
	UiHelpers.apply_button_asset(select_button, true)
	frame_bg.texture = null
	badge_icon.texture = null
	_lock_decor_size()
	_lock_realm_icon_size()
	desc_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)


func bind_talent(talent: Dictionary) -> void:
	_talent_id = str(talent.get("id", ""))
	name_label.text = str(talent.get("name", "天赋"))
	desc_label.text = str(talent.get("description", ""))
	var realm_level := int(talent.get("realm_level", 1))
	UiHelpers.set_icon(icon, AssetPaths.talent_realm_icon(realm_level))
	_lock_realm_icon_size()
	icon.visible = false
	badge_icon.texture = null
	visible = not _talent_id.is_empty()
	scale = Vector2.ONE
	modulate = Color.WHITE
	frame_bg.modulate = Color(1, 1, 1, 0.36)
	_lock_decor_size()
	if visible and not _hover_bound:
		UiAnimations.bind_hover_lift(self, 3.0)
		_hover_bound = true


func play_entrance(delay: float = 0.0) -> void:
	call_deferred("_play_entrance_deferred", delay)


func _play_entrance_deferred(delay: float) -> void:
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.88, 0.88)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.28)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.32)


func _on_mouse_enter() -> void:
	if not visible or _talent_id.is_empty():
		return
	add_theme_stylebox_override("panel", _make_talent_card_style(true))
	frame_bg.texture = null
	frame_bg.modulate = Color(1.08, 1.05, 0.95, 0.48)
	_lock_decor_size()


func _on_mouse_exit() -> void:
	add_theme_stylebox_override("panel", _make_talent_card_style(false))
	frame_bg.texture = null
	frame_bg.modulate = Color(1, 1, 1, 0.36)
	_lock_decor_size()


func _on_select_pressed() -> void:
	if not _talent_id.is_empty():
		talent_selected.emit(_talent_id)


func _make_talent_card_style(hovered: bool) -> StyleBoxTexture:
	var style := UiHelpers.make_ninepatch_panel_style()
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.modulate_color = Color(0.58, 0.86, 0.78, 0.72) if hovered else Color(0.42, 0.64, 0.58, 0.62)
	return style


func _lock_realm_icon_size() -> void:
	icon.visible = false
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _lock_decor_size() -> void:
	frame_bg.visible = false
	badge_icon.visible = false
	frame_bg.custom_minimum_size = Vector2.ZERO
	frame_bg.position = Vector2(18, 4)
	frame_bg.size = Vector2(154, 36)
	frame_bg.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	frame_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge_icon.custom_minimum_size = Vector2.ZERO
	badge_icon.position = Vector2(150, 12)
	badge_icon.size = Vector2(24, 24)
	badge_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
