extends PanelContainer
class_name HudWeatherPanel

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel_frame: TextureRect = $PanelFrame
@onready var weather_icon: TextureRect = %WeatherIcon
@onready var weather_label: Label = %WeatherLabel
@onready var next_label: Label = %NextLabel
@onready var meta_label: Label = %MetaLabel
@onready var pet_icon: TextureRect = %PetIcon
@onready var pet_label: Label = %PetLabel

var _weather_id := "clear"
var _thunder_sig: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_thunder_sig()
	apply_polish()
	next_label.text = "下一天象 未知"
	meta_label.visible = false


func _ensure_thunder_sig() -> void:
	if _thunder_sig != null:
		return
	_thunder_sig = TextureRect.new()
	_thunder_sig.name = "ThunderSig"
	_thunder_sig.texture = AssetPaths.load_texture(AssetPaths.HUD_WEATHER_THUNDER_SIG)
	_thunder_sig.custom_minimum_size = Vector2(64, 64)
	_thunder_sig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thunder_sig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thunder_sig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thunder_sig.modulate = Color(0.62, 0.82, 1.0, 0.0)
	_thunder_sig.visible = false
	add_child(_thunder_sig)
	_thunder_sig.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_thunder_sig.offset_left = -78.0
	_thunder_sig.offset_top = 8.0
	_thunder_sig.offset_right = -14.0
	_thunder_sig.offset_bottom = 72.0
	move_child(_thunder_sig, min(1, get_child_count() - 1))


func apply_polish() -> void:
	add_theme_stylebox_override("panel", HudStyles.transparent_panel())
	var tex := AssetPaths.load_texture(AssetPaths.weather_panel_frame(_weather_id))
	if tex and panel_frame:
		panel_frame.texture = tex
		panel_frame.modulate = Color(1.0, 1.0, 1.0, 0.82)
		panel_frame.visible = true
	var ring := AssetPaths.load_texture(AssetPaths.PET_AVATAR_RING)
	if ring:
		pet_icon.texture = ring
	weather_icon.texture = AssetPaths.load_texture(AssetPaths.weather_icon("clear"))
	weather_label.add_theme_constant_override("outline_size", 2)
	weather_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.78))
	weather_label.add_theme_font_size_override("font_size", 13)
	weather_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	call_deferred("_layout_frame")
	_refresh_thunder_sig()


func _layout_frame() -> void:
	if panel_frame:
		panel_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		move_child(panel_frame, 0)
	if _thunder_sig:
		_thunder_sig.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_thunder_sig.offset_left = -78.0
		_thunder_sig.offset_top = 8.0
		_thunder_sig.offset_right = -14.0
		_thunder_sig.offset_bottom = 72.0


func set_weather(icon: Texture2D, text: String, weather_id: String = "") -> void:
	if not weather_id.is_empty():
		_weather_id = weather_id
		var frame := AssetPaths.load_texture(AssetPaths.weather_panel_frame(_weather_id))
		if frame and panel_frame:
			panel_frame.texture = frame
			panel_frame.modulate = Color(1.0, 1.0, 1.0, 0.94 if _is_thunderstorm(_weather_id) else 0.82)
	if icon:
		weather_icon.texture = icon
	weather_label.text = text
	weather_label.add_theme_color_override("font_color", UiTokens.ELEM_THUNDER if _is_thunderstorm(_weather_id) else UiTokens.TEXT_PRIMARY)
	_refresh_thunder_sig()


func _is_thunderstorm(weather_id: String) -> bool:
	return weather_id == "thunder" or weather_id == "storm" or weather_id == "thunderstorm"


func _refresh_thunder_sig() -> void:
	if _thunder_sig == null:
		return
	_thunder_sig.visible = _is_thunderstorm(_weather_id) and _thunder_sig.texture != null
	_thunder_sig.modulate = Color(0.58, 0.80, 1.0, 0.34 if _thunder_sig.visible else 0.0)


func set_meta_summary(text: String) -> void:
	meta_label.text = text
	meta_label.visible = not text.strip_edges().is_empty()


func set_pet(icon: Texture2D, text: String, accent: Color) -> void:
	if icon:
		pet_icon.texture = icon
	elif AssetPaths.load_texture(AssetPaths.PET_AVATAR_RING):
		pet_icon.texture = AssetPaths.load_texture(AssetPaths.PET_AVATAR_RING)
	pet_label.text = text
	pet_label.add_theme_color_override("font_color", accent)
	var parent := pet_label.get_parent() as CanvasItem
	if parent:
		parent.visible = not text.strip_edges().is_empty()
