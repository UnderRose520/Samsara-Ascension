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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_polish()
	next_label.text = "下一天象 · —"


func apply_polish() -> void:
	add_theme_stylebox_override("panel", HudStyles.weather_panel())
	var tex := AssetPaths.load_texture(AssetPaths.HUD_WEATHER_PANEL)
	if tex and panel_frame:
		panel_frame.texture = tex
		panel_frame.modulate = Color(1, 1, 1, 0.35)
	var ring := AssetPaths.load_texture(AssetPaths.PET_AVATAR_RING)
	if ring:
		pet_icon.texture = ring
	weather_icon.texture = AssetPaths.load_texture(AssetPaths.weather_icon("clear"))
	call_deferred("_layout_frame")


func _layout_frame() -> void:
	if panel_frame:
		panel_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		move_child(panel_frame, 0)


func set_weather(icon: Texture2D, text: String) -> void:
	if icon:
		weather_icon.texture = icon
	weather_label.text = text


func set_meta_summary(text: String) -> void:
	meta_label.text = text


func set_pet(icon: Texture2D, text: String, accent: Color) -> void:
	if icon:
		pet_icon.texture = icon
	elif AssetPaths.load_texture(AssetPaths.PET_AVATAR_RING):
		pet_icon.texture = AssetPaths.load_texture(AssetPaths.PET_AVATAR_RING)
	pet_label.text = text
	pet_label.add_theme_color_override("font_color", accent)
