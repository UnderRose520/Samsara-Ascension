extends CanvasLayer

const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var bar: PanelContainer = $Bar
@onready var label: Label = $Bar/Margin/Label

var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 55
	bar.visible = false
	var bg := TextureRect.new()
	bg.name = "StripBg"
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.texture = AssetPaths.load_texture(AssetPaths.SCROLL_TOAST)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	bar.move_child(bg, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.pet_coord_feedback.connect(_on_announce)


func _on_announce(text: String) -> void:
	if text.is_empty():
		return
	_show(text, UiTokens.ACCENT_GOLD_SOFT, 2.0)


func _show(text: String, color: Color, duration: float) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	bar.visible = true
	bar.modulate.a = 0.0
	_timer = duration
	UiAnimations.modal_open(bar, null)


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer = maxf(_timer - delta, 0.0)
	if _timer <= 0.0:
		UiAnimations.modal_close(bar, null, func() -> void:
			bar.visible = false
		)
