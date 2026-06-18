extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var banner: Label = $Banner
@onready var subtitle: Label = $Subtitle
@onready var glow: ColorRect = $Glow
@onready var frame: TextureRect = $Frame
@onready var patterns: Control = $Patterns

var _end_ms := 0
var _awaken_tween: Tween
var _time_scale_modified := false
var _pattern_color := Color(1.0, 0.78, 0.24, 0.9)
var _pattern_style := "fire"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.visible = false
	subtitle.visible = false
	glow.modulate.a = 0.0
	patterns.visible = false
	patterns.draw.connect(_draw_patterns)
	frame.texture = AssetPaths.load_texture(AssetPaths.MODAL_TITLE_BAR)
	EventBus.dao_tradition_awakened.connect(_on_awakened)
	EventBus.run_completed.connect(_force_cleanup)


func _on_awakened(tradition: Dictionary) -> void:
	if _awaken_tween and _awaken_tween.is_running():
		_awaken_tween.kill()
	_awaken_tween = null
	_restore_time_scale()
	_pattern_style = _style_for_tradition(tradition)
	_pattern_color = _color_for_style(_pattern_style)
	glow.color = _pattern_color
	banner.text = "%s成道" % _short_dao_name(str(tradition.get("name", "道统")))
	subtitle.text = "%s · %s" % [tradition.get("title", ""), tradition.get("description", "")]
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
	_awaken_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_awaken_tween.tween_property(subtitle, "modulate:a", 1.0, 0.25)
	_awaken_tween.tween_property(patterns, "modulate:a", 1.0, 0.35)
	_awaken_tween.tween_property(banner, "scale", Vector2(1.06, 1.06), 0.28).set_trans(Tween.TRANS_BACK)
	_awaken_tween.tween_property(glow, "modulate:a", 0.55, 0.25)
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
	if _end_ms <= 0:
		return
	_end_ms = 0
	if _awaken_tween and _awaken_tween.is_running():
		_awaken_tween.kill()
	_awaken_tween = null
	banner.visible = false
	subtitle.visible = false
	patterns.visible = false
	glow.modulate.a = 0.0
	_restore_time_scale()


func _force_cleanup(_victory: bool = false) -> void:
	_finish_overlay()


func _draw_patterns() -> void:
	var rect := get_viewport().get_visible_rect()
	var corners := [
		Vector2(44, 44),
		Vector2(rect.size.x - 44, 44),
		Vector2(44, rect.size.y - 44),
		Vector2(rect.size.x - 44, rect.size.y - 44),
	]
	for corner in corners:
		_draw_corner_pattern(corner, rect.size * 0.5)


func _draw_corner_pattern(origin: Vector2, center: Vector2) -> void:
	var dir := (center - origin).normalized()
	var side := dir.orthogonal()
	for i in 5:
		var length := 54.0 + float(i) * 22.0
		var start := origin + side * (float(i) - 2.0) * 8.0
		var mid := start + dir * length * 0.58 + side * sin(float(i) * 1.7) * 18.0
		var end := start + dir * length
		var color := _pattern_color
		color.a = 0.78 - float(i) * 0.08
		patterns.draw_polyline(PackedVector2Array([start, mid, end]), color, 3.0)
		if _pattern_style == "thunder":
			patterns.draw_line(mid, mid + side * 18.0, Color(0.8, 0.95, 1.0, 0.62), 2.0)
		elif _pattern_style == "wood":
			patterns.draw_circle(mid, 4.0, Color(0.55, 1.0, 0.58, 0.45))
		elif _pattern_style == "water":
			patterns.draw_arc(mid, 12.0 + float(i) * 2.0, 0.0, PI * 1.3, 18, Color(0.55, 0.85, 1.0, 0.38), 1.5)


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
