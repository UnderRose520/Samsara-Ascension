extends PanelContainer

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var icon_wrap: Control = $Margin/HBox/IconWrap
@onready var icon: TextureRect = $Margin/HBox/IconWrap/Icon
@onready var cd_ring: SpellIconFrame = $Margin/HBox/IconWrap/CdRing
@onready var key_label: Label = $Margin/HBox/Info/KeyLabel
@onready var name_label: Label = $Margin/HBox/Info/NameLabel
@onready var state_label: Label = $Margin/HBox/Info/StateLabel
@onready var info_box: VBoxContainer = $Margin/HBox/Info
@onready var hbox: HBoxContainer = $Margin/HBox

var _dock := false
var _ready_state := true
var _unlocked := true


func _ready() -> void:
	pass


func set_dock(enabled: bool) -> void:
	if not enabled:
		return
	_dock = true
	custom_minimum_size = Vector2(52, 58)
	info_box.visible = false
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_stylebox_override("panel", HudStyles.spell_dock_slot(true, true))
	if key_label.get_parent() == info_box:
		info_box.remove_child(key_label)
		icon_wrap.add_child(key_label)
		key_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		key_label.offset_left = -2
		key_label.offset_top = -2
		key_label.offset_right = 14
		key_label.offset_bottom = 12
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.add_theme_font_size_override("font_size", 9)
		key_label.add_theme_color_override("font_color", UiTokens.BG_DEEP)
		var key_bg := StyleBoxFlat.new()
		key_bg.bg_color = UiTokens.ACCENT_GOLD
		key_bg.corner_radius_top_left = 4
		key_bg.corner_radius_top_right = 4
		key_bg.corner_radius_bottom_left = 4
		key_bg.corner_radius_bottom_right = 4
		key_bg.content_margin_left = 3
		key_bg.content_margin_top = 1
		key_bg.content_margin_right = 3
		key_bg.content_margin_bottom = 1
		key_label.add_theme_stylebox_override("normal", key_bg)
	icon_wrap.custom_minimum_size = Vector2(44, 44)


func apply_state(slot: String, spell_name: String, unlocked: bool, cd_remaining: float, cd_total: float, casting: bool) -> void:
	key_label.text = slot.to_upper()
	if not _dock:
		name_label.text = spell_name
	var icon_key := slot if unlocked else "%s_locked" % slot
	var icon_path: String = AssetPaths.SPELL_ICONS.get(icon_key, AssetPaths.SPELL_ICONS["q_locked"])
	icon.texture = AssetPaths.load_texture(icon_path)
	var ready := unlocked and not casting and cd_remaining <= 0.05
	var ratio := 0.0
	if unlocked and cd_total > 0.01 and cd_remaining > 0.05:
		ratio = cd_remaining / cd_total
	cd_ring.set_cooldown(ratio, ready)
	_ready_state = ready
	_unlocked = unlocked
	if _dock:
		add_theme_stylebox_override("panel", HudStyles.spell_dock_slot(ready, unlocked))
		tooltip_text = spell_name if unlocked else "未解锁"
		modulate = Color(0.5, 0.5, 0.52) if not unlocked else Color.WHITE
		return
	if not unlocked:
		state_label.text = "未解锁"
		modulate = Color(0.55, 0.55, 0.58)
	elif casting:
		state_label.text = "蓄力"
		state_label.add_theme_color_override("font_color", UiTokens.ELEM_FIRE)
		modulate = Color.WHITE
	elif cd_remaining > 0.05:
		state_label.text = "%.1fs" % cd_remaining
		state_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
		modulate = Color.WHITE
	else:
		state_label.text = "就绪"
		state_label.add_theme_color_override("font_color", UiTokens.STATE_BUFF)
		modulate = Color.WHITE
