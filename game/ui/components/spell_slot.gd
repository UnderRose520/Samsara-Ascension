extends PanelContainer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var icon_wrap: Control = $Margin/HBox/IconWrap
@onready var slot_frame: TextureRect = $Margin/HBox/IconWrap/SlotFrame
@onready var icon: TextureRect = $Margin/HBox/IconWrap/Icon
@onready var cd_ring: SpellIconFrame = $Margin/HBox/IconWrap/CdRing
@onready var cooldown_sweep: TextureRect = $Margin/HBox/IconWrap/CooldownSweep
@onready var shortcut_badge: TextureRect = $Margin/HBox/IconWrap/ShortcutBadge
@onready var key_label: Label = $Margin/HBox/Info/KeyLabel
@onready var name_label: Label = $Margin/HBox/Info/NameLabel
@onready var state_label: Label = $Margin/HBox/Info/StateLabel
@onready var info_box: VBoxContainer = $Margin/HBox/Info
@onready var hbox: HBoxContainer = $Margin/HBox

var _dock := false
var _ready_state := true
var _unlocked := true
var _cd_text: Label
var _slot_frame_texture_hits := 0
var _shortcut_badge_texture_hits := 0


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
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_apply_shortcut_badge_texture()
	_apply_slot_frame_texture(true, true)
	if key_label.get_parent() == info_box:
		info_box.remove_child(key_label)
		icon_wrap.add_child(key_label)
		key_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		key_label.offset_left = -12
		key_label.offset_top = -10
		key_label.offset_right = 12
		key_label.offset_bottom = 12
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		key_label.remove_theme_stylebox_override("normal")
	icon_wrap.custom_minimum_size = Vector2(56, 56)
	icon.offset_left = -27
	icon.offset_top = -27
	icon.offset_right = 27
	icon.offset_bottom = 27
	icon.modulate = Color.WHITE
	_layout_texture_chrome()
	_cd_text.visible = false


func apply_state(
	slot: String,
	spell_name: String,
	unlocked: bool,
	cd_remaining: float,
	cd_total: float,
	casting: bool,
	spell_id: String = "",
	element: String = ""
) -> void:
	key_label.text = slot.to_upper()
	if not _dock:
		name_label.text = spell_name
	var icon_path: String = AssetPaths.spell_icon(spell_id, element, slot, unlocked)
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
		_apply_slot_frame_texture(ready, unlocked)
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


func _layout_texture_chrome() -> void:
	for node in [slot_frame, cooldown_sweep, cd_ring]:
		if node == null:
			continue
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
		node.offset_left = 0
		node.offset_top = 0
		node.offset_right = 0
		node.offset_bottom = 0
	if shortcut_badge != null:
		shortcut_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
		shortcut_badge.offset_left = -16
		shortcut_badge.offset_top = -14
		shortcut_badge.offset_right = 16
		shortcut_badge.offset_bottom = 18


func _apply_slot_frame_texture(ready: bool, unlocked: bool) -> void:
	if slot_frame == null:
		return
	var texture := AssetPaths.load_texture(AssetPaths.spell_slot_frame(ready, unlocked))
	if texture != null:
		slot_frame.texture = texture
		_slot_frame_texture_hits += 1
	slot_frame.visible = texture != null


func _apply_shortcut_badge_texture() -> void:
	if shortcut_badge == null:
		return
	var texture := AssetPaths.load_texture(AssetPaths.spell_shortcut_badge())
	if texture != null:
		shortcut_badge.texture = texture
		_shortcut_badge_texture_hits += 1
	shortcut_badge.visible = texture != null


func get_slot_frame_texture_hit_count() -> int:
	return _slot_frame_texture_hits


func get_shortcut_badge_texture_hit_count() -> int:
	return _shortcut_badge_texture_hits


func get_cooldown_texture_hit_count() -> int:
	if cd_ring == null or not cd_ring.has_method("get_cooldown_texture_hit_count"):
		return 0
	return int(cd_ring.call("get_cooldown_texture_hit_count"))
