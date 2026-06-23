extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var banner: Label = $Banner
@onready var subtitle: Label = $Subtitle
@onready var glow: ColorRect = $Glow
@onready var frame: TextureRect = $Frame
@onready var patterns: Control = $Patterns
@onready var pattern_nodes: Array[TextureRect] = [
	$Patterns/TopLeftPattern,
	$Patterns/TopRightPattern,
	$Patterns/BottomLeftPattern,
	$Patterns/BottomRightPattern,
]

var _end_ms := 0
var _awaken_tween: Tween
var _time_scale_modified := false
var _pattern_color := Color(1.0, 0.78, 0.24, 0.9)
var _pattern_style := "fire"
var _pattern_texture_hits := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_top_band_layout()
	frame.texture = AssetPaths.load_texture(AssetPaths.DIVIDER_GOLD)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	_hide_all_visuals()
	EventBus.dao_tradition_awakened.connect(_on_awakened)
	EventBus.run_completed.connect(_force_cleanup)


func _on_awakened(tradition: Dictionary) -> void:
	if _awaken_tween and _awaken_tween.is_running():
		_awaken_tween.kill()
	_awaken_tween = null
	_restore_time_scale()
	_pattern_style = _style_for_tradition(tradition)
	_pattern_color = _color_for_style(_pattern_style)
	_apply_pattern_texture(_pattern_style)
	glow.color = _pattern_color
	frame.modulate = Color(_pattern_color.r, _pattern_color.g, _pattern_color.b, 0.0)
	banner.text = "%s成道" % _short_dao_name(str(tradition.get("name", "道统")))
	subtitle.text = "%s · %s" % [tradition.get("title", ""), tradition.get("description", "")]
	frame.visible = true
	banner.visible = true
	subtitle.visible = true
	patterns.visible = true
	patterns.modulate.a = 0.0
	banner.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	banner.scale = Vector2(1.34, 1.34)
	banner.pivot_offset = banner.size * 0.5
	_end_ms = Time.get_ticks_msec() + 3000
	_awaken_tween = create_tween().set_parallel(true)
	_awaken_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_awaken_tween.tween_property(frame, "modulate:a", 0.72, 0.18)
	_awaken_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_awaken_tween.tween_property(subtitle, "modulate:a", 1.0, 0.25)
	_awaken_tween.tween_property(patterns, "modulate:a", 1.0, 0.35)
	_awaken_tween.tween_property(banner, "scale", Vector2(1.06, 1.06), 0.28).set_trans(Tween.TRANS_BACK)
	_awaken_tween.tween_property(glow, "modulate:a", 0.06, 0.25)
	if not VfxManager.should_reduce_motion():
		Engine.time_scale = 0.3
		_time_scale_modified = true
		var center := get_viewport().get_visible_rect().size * 0.5
		VfxManager.spawn_screen(self, center * Vector2(1.0, 0.96), "dao", _pattern_color)
		VfxManager.spawn_screen(self, center * Vector2(1.0, 1.04), "gold", Color(1.0, 0.95, 0.6))


func _process(_delta: float) -> void:
	if _end_ms <= 0:
		return
	if Time.get_ticks_msec() < _end_ms:
		return
	_finish_overlay()


func _finish_overlay() -> void:
	_end_ms = 0
	if _awaken_tween and _awaken_tween.is_running():
		_awaken_tween.kill()
	_awaken_tween = null
	_hide_all_visuals()
	_restore_time_scale()


func _hide_all_visuals() -> void:
	_apply_top_band_layout()
	banner.visible = false
	subtitle.visible = false
	frame.visible = false
	patterns.visible = false
	banner.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	frame.modulate.a = 0.0
	patterns.modulate.a = 0.0
	glow.modulate.a = 0.0


func _apply_top_band_layout() -> void:
	_set_top_band_rect(banner, -320.0, 146.0, 640.0, 40.0)
	_set_top_band_rect(frame, -210.0, 194.0, 420.0, 4.0)
	_set_top_band_rect(subtitle, -340.0, 204.0, 680.0, 24.0)


func _set_top_band_rect(control: Control, left: float, top: float, width: float, height: float) -> void:
	if control == null:
		return
	control.anchor_left = 0.5
	control.anchor_top = 0.0
	control.anchor_right = 0.5
	control.anchor_bottom = 0.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = left + width
	control.offset_bottom = top + height


func _force_cleanup(_victory: bool = false) -> void:
	_finish_overlay()


func _apply_pattern_texture(style: String) -> void:
	_pattern_texture_hits = 0
	var texture := AssetPaths.load_texture(AssetPaths.combat_action_fx("dao_pattern_%s" % style))
	if texture == null and style != "fire":
		texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("dao_pattern_fire"))
	for node in pattern_nodes:
		node.texture = texture
		node.modulate = Color(1.0, 1.0, 1.0, 0.0 if texture == null else 0.92)
		_pattern_texture_hits += int(texture != null)


func get_pattern_texture_hit_count() -> int:
	return _pattern_texture_hits


func _style_for_tradition(tradition: Dictionary) -> String:
	var text := ("%s %s %s" % [tradition.get("id", ""), tradition.get("name", ""), tradition.get("description", "")]).to_lower()
	if "thunder" in text or "雷" in text:
		return "thunder"
	if "wood" in text or "poison" in text or "毒" in text:
		return "wood"
	if "water" in text or "ice" in text or "冰" in text:
		return "water"
	if "five" in text or "五" in text:
		return "five"
	return "fire"


func _color_for_style(style: String) -> Color:
	match style:
		"thunder": return Color(0.48, 0.86, 1.0, 1.0)
		"wood": return Color(0.54, 1.0, 0.58, 1.0)
		"water": return Color(0.55, 0.78, 1.0, 1.0)
		"five": return Color(1.0, 0.92, 0.48, 1.0)
	return Color(1.0, 0.42, 0.18, 1.0)


func _short_dao_name(name: String) -> String:
	for suffix in ["道统", "之道", "归元"]:
		name = name.replace(suffix, "")
	return name.strip_edges()


func _restore_time_scale() -> void:
	if not _time_scale_modified:
		return
	_time_scale_modified = false
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	if _awaken_tween and _awaken_tween.is_running():
		_awaken_tween.kill()
	_awaken_tween = null
	_restore_time_scale()
