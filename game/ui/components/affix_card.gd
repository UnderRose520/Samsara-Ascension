extends PanelContainer

signal offer_selected

const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var frame_bg: TextureRect = $FrameBg
@onready var icon: TextureRect = $Margin/VBox/Icon
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var quality_label: Label = $Margin/VBox/QualityLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var combo_label: Label = $Margin/VBox/ComboLabel
@onready var select_button: Button = $Margin/VBox/SelectButton

var _tag = null
var _hover_bound := false
var _quality_glow: QualityGlow = null


func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)


func get_offer():
	return _tag


func bind_offer(tag, disabled: bool = false) -> void:
	_tag = tag
	if tag == null:
		visible = false
		return
	visible = true
	scale = Vector2.ONE
	name_label.text = tag.name
	quality_label.text = "%s · %s" % [UiHelpers.quality_name(tag.quality), UiHelpers.category_name(tag.category)]
	quality_label.add_theme_color_override("font_color", UiTokens.quality_color(tag.quality))
	desc_label.text = tag.description
	var combo_text := " · ".join(tag.combo_tags) if tag.combo_tags.size() > 0 else "—"
	combo_label.text = "Combo %s" % combo_text
	UiHelpers.set_icon(icon, AssetPaths.elem_icon(tag.element))
	UiHelpers.apply_quality_frame(frame_bg, tag.quality)
	_apply_quality_glow(tag.quality)
	select_button.disabled = disabled
	modulate = Color(0.72, 0.72, 0.72) if disabled else Color.WHITE
	if not disabled and not _hover_bound:
		UiAnimations.bind_hover_lift(self)
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
	if _tag == null or select_button.disabled:
		return
	frame_bg.modulate = Color(1.08, 1.05, 0.95, 1.0)


func _on_mouse_exit() -> void:
	frame_bg.modulate = Color.WHITE


func _on_select_pressed() -> void:
	if _tag != null:
		offer_selected.emit()


func _apply_quality_glow(quality: int) -> void:
	if quality < 2:
		if _quality_glow:
			_quality_glow.visible = false
		return
	if _quality_glow == null:
		_quality_glow = QualityGlow.new()
		add_child(_quality_glow)
		_quality_glow.z_index = 5
	_quality_glow.visible = true
	_quality_glow.glow_color = UiTokens.quality_color(quality)
	_quality_glow.glow_color.a = 0.45 if quality < 4 else 0.6
