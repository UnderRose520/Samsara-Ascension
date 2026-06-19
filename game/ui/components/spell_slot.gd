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
var _cd_text: Label


func _ready() -> void:
	_ensure_cd_text()


func set_dock(enabled: bool) -> void:
	if not enabled:
		return
	_ensure_cd_text()
	_dock = true
	custom_minimum_size = Vector2(68, 68)
	info_box.visible = false
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_stylebox_override("panel", HudStyles.spell_dock_slot(true, true))
	if key_label.get_parent() == info_box:
		info_box.remove_child(key_label)
		icon_wrap.add_child(key_label)
		# small circular gold key badge pinned to the top of the round slot
		key_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		key_label.offset_left = -9
		key_label.offset_top = -11
		key_label.offset_right = 9
		key_label.offset_bottom = 7
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", UiTokens.BG_DEEP)
		var key_bg := StyleBoxFlat.new()
		key_bg.bg_color = UiTokens.ACCENT_GOLD
		key_bg.corner_radius_top_left = 9
		key_bg.corner_radius_top_right = 9
		key_bg.corner_radius_bottom_left = 9
		key_bg.corner_radius_bottom_right = 9
		key_bg.border_width_left = 1
		key_bg.border_width_top = 1
		key_bg.border_width_right = 1
		key_bg.border_width_bottom = 1
		key_bg.border_color = Color(0.35, 0.28, 0.08, 0.8)
		key_bg.content_margin_left = 2
		key_bg.content_margin_top = 0
		key_bg.content_margin_right = 2
		key_bg.content_margin_bottom = 0
		key_label.add_theme_stylebox_override("normal", key_bg)
	icon_wrap.custom_minimum_size = Vector2(56, 56)
	icon.offset_left = -27
	icon.offset_top = -27
	icon.offset_right = 27
	icon.offset_bottom = 27
	icon.modulate = Color.WHITE
	_cd_text.visible = false


func apply_state(slot: String, spell_name: String, unlocked: bool, cd_remaining: float, cd_total: float, casting: bool) -> void:
	key_label.text = slot.to_upper()
	if not _dock:
		name_label.text = spell_name
	var icon_key: String = slot if unlocked else "%s_locked" % slot
	var icon_path: String = AssetPaths.SPELL_ICONS.get(icon_key, AssetPaths.SPELL_ICONS["q_locked"])
	icon.texture = AssetPaths.load_texture(icon_path)
	var ready: bool = unlocked and not casting and cd_remaining <= 0.05
	var ratio: float = 0.0
	if unlocked and cd_total > 0.01 and cd_remaining > 0.05:
		ratio = cd_remaining / cd_total
	cd_ring.set_cooldown(ratio, ready)
	_ready_state = ready
	_unlocked = unlocked
	if _dock:
		_update_cd_text(cd_remaining, casting)
		add_theme_stylebox_override("panel", HudStyles.spell_dock_slot(ready, unlocked))
		tooltip_text = spell_name if unlocked else "未解锁"
		modulate = Color(0.5, 0.5, 0.52) if not unlocked else Color.WHITE
		return
	_update_cd_text(0.0, false)
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


func _ensure_cd_text() -> void:
	if _cd_text != null:
		return
	_cd_text = Label.new()
	_cd_text.name = "CdText"
	_cd_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cd_text.add_theme_font_size_override("font_size", 13)
	_cd_text.add_theme_color_override("font_color", Color.WHITE)
	_cd_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_cd_text.add_theme_constant_override("shadow_offset_x", 1)
	_cd_text.add_theme_constant_override("shadow_offset_y", 1)
	_cd_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_wrap.add_child(_cd_text)
	_cd_text.visible = false


func _update_cd_text(cd_remaining: float, casting: bool) -> void:
	if _cd_text == null:
		return
	if not _dock or not _unlocked or casting or cd_remaining <= 0.05:
		_cd_text.visible = false
		return
	_cd_text.text = "%.1f" % cd_remaining if cd_remaining < 10.0 else "%d" % ceili(cd_remaining)
	_cd_text.visible = true
