extends CanvasLayer

const CritSlashDraw = preload("res://vfx/crit_slash_draw.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

@onready var banner: Label = $Banner
@onready var desaturate: ColorRect = $Desaturate
@onready var vignette: ColorRect = $Vignette
@onready var slash: CritSlashDraw = $Slash
@onready var edge_glow: Control = $EdgeGlow

var _end_ms := 0
var _banner_tween: Tween
var _unity_tween: Tween
var _freeze_timer: SceneTreeTimer
var _freeze_token := 0
var _time_scale_modified := false
var _pause_modified := false
var _was_paused_before_freeze := false
var _active_priority := 0
var _edge_glow_time := 0.0
var _edge_glow_color := Color(1.0, 0.82, 0.24, 0.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.visible = false
	_set_desaturate_strength(0.0)
	vignette.modulate.a = 0.0
	slash.visible = false
	edge_glow.visible = false
	edge_glow.draw.connect(_draw_edge_glow)
	EventBus.crit_moment_requested.connect(_on_moment)
	EventBus.damage_dealt.connect(_on_damage_crit)
	EventBus.perfect_dodge_triggered.connect(_on_perfect_dodge)
	EventBus.unity_burst_visual_requested.connect(_on_unity_burst_visual)
	EventBus.run_completed.connect(_force_cleanup)
	EventBus.room_entered.connect(_on_room_entered)


func _on_room_entered(_room: Dictionary, _stage: Dictionary) -> void:
	_force_cleanup()


func _on_moment(text: String, duration: float) -> void:
	var color := Color(1.0, 0.95, 0.34) if text == "道之极致" else Color(1.0, 0.88, 0.25)
	_play_moment(text, duration, color, 3 if text == "道之极致" else 2)


func _on_damage_crit(result: Dictionary) -> void:
	if not VariantUtils.as_bool(result.get("is_crit", false)):
		return
	if VariantUtils.as_bool(result.get("target_is_player", false)):
		return
	_play_moment("天机一击!", 0.45, Color(1.0, 0.92, 0.35), 1)


func _on_perfect_dodge(_world_position: Vector2) -> void:
	_play_moment("完美闪避", 0.1, Color(1.0, 0.92, 0.45), 3)


func _on_unity_burst_visual(payload: Dictionary) -> void:
	var color: Color = payload.get("color", Color(1.0, 0.82, 0.24))
	_edge_glow_time = 3.0
	_edge_glow_color = color
	_play_moment("万法归一", 2.0, color, 4)
	if VfxManager.should_reduce_motion():
		return
	_kill_unity_tween()
	vignette.color = color
	vignette.modulate.a = 0.0
	_unity_tween = create_tween().set_parallel(true)
	_unity_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_unity_tween.tween_property(vignette, "modulate:a", 0.84, 0.08)
	_unity_tween.tween_property(vignette, "modulate:a", 0.38, 0.42).set_delay(0.08)


func _play_moment(text: String, duration: float, slash_color: Color, priority: int = 1) -> void:
	if _end_ms > 0 and _active_priority > priority:
		return
	_active_priority = priority
	_kill_banner_tween()
	_restore_time_scale()
	_restore_pause()

	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	var is_extreme := text == "道之极致"
	var is_unity := text == "万法归一"
	var is_perfect_dodge := text == "完美闪避"
	banner.scale = Vector2(1.45, 1.45) if is_extreme or is_unity else Vector2(1.15, 1.15)
	banner.pivot_offset = banner.size * 0.5
	banner.add_theme_constant_override("outline_size", 5 if is_extreme or is_unity else 2)
	banner.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 0.95) if is_extreme or is_unity else Color(0.35, 0.25, 0.0, 0.9))
	banner.add_theme_color_override("font_color", slash_color)
	slash.visible = true
	slash.set_anchors_preset(Control.PRESET_FULL_RECT)
	slash.play(0.62 if is_unity else (0.55 if is_extreme else 0.35), slash_color)
	vignette.modulate.a = 0.0
	_end_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.08)
	_banner_tween.tween_property(banner, "scale", Vector2(1.12, 1.12) if is_extreme or is_unity else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	if not VfxManager.should_reduce_motion():
		vignette.color = (Color(0.78, 0.76, 0.68, 1.0) if is_extreme else (slash_color if is_unity else Color.BLACK))
		_banner_tween.tween_property(vignette, "modulate:a", 0.78 if is_unity else (0.72 if is_extreme else 0.55), 0.1)
		if is_perfect_dodge:
			_freeze_game(0.1)
		else:
			Engine.time_scale = 0.22 if is_unity else (0.25 if is_extreme else 0.35)
			_time_scale_modified = true
		if is_extreme:
			_set_desaturate_strength(0.82)
		var center := _screen_center()
		VfxManager.spawn_screen(self, center * Vector2(1.0, 0.84), "crit", slash_color)
	else:
		_banner_tween.tween_property(vignette, "modulate:a", 0.25, 0.08)


func _screen_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _process(_delta: float) -> void:
	if _edge_glow_time > 0.0:
		_edge_glow_time = maxf(_edge_glow_time - _delta, 0.0)
		edge_glow.visible = _edge_glow_time > 0.0
		edge_glow.queue_redraw()
	if _end_ms <= 0:
		return
	if Time.get_ticks_msec() < _end_ms:
		return
	_finish_moment()


func _finish_moment() -> void:
	if _end_ms <= 0:
		return
	_end_ms = 0
	_active_priority = 0
	_kill_banner_tween()
	banner.visible = false
	_set_desaturate_strength(0.0)
	vignette.modulate.a = 0.0
	vignette.color = Color.BLACK
	slash.visible = false
	_restore_time_scale()
	_restore_pause()


func _draw_edge_glow() -> void:
	if _edge_glow_time <= 0.0:
		return
	var rect := get_viewport().get_visible_rect()
	var alpha := clampf(_edge_glow_time / 3.0, 0.0, 1.0) * 0.42
	var color := Color(_edge_glow_color.r, _edge_glow_color.g, _edge_glow_color.b, alpha)
	var thickness := 26.0
	edge_glow.draw_rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, thickness)), color, true)
	edge_glow.draw_rect(Rect2(Vector2(0.0, rect.size.y - thickness), Vector2(rect.size.x, thickness)), color, true)
	edge_glow.draw_rect(Rect2(Vector2.ZERO, Vector2(thickness, rect.size.y)), color, true)
	edge_glow.draw_rect(Rect2(Vector2(rect.size.x - thickness, 0.0), Vector2(thickness, rect.size.y)), color, true)


func _force_cleanup(_victory: bool = false) -> void:
	_finish_moment()
	_edge_glow_time = 0.0
	if edge_glow:
		edge_glow.visible = false


func _kill_banner_tween() -> void:
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = null


func _kill_unity_tween() -> void:
	if _unity_tween and _unity_tween.is_running():
		_unity_tween.kill()
	_unity_tween = null


func _set_desaturate_strength(value: float) -> void:
	if desaturate == null:
		return
	var material := desaturate.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("strength", clampf(value, 0.0, 1.0))
	desaturate.visible = value > 0.0


func _freeze_game(duration: float) -> void:
	_restore_pause()
	_freeze_token += 1
	var token := _freeze_token
	_was_paused_before_freeze = get_tree().paused
	get_tree().paused = true
	_pause_modified = not _was_paused_before_freeze
	_freeze_timer = get_tree().create_timer(duration, true, false, true)
	_freeze_timer.timeout.connect(func() -> void:
		if token == _freeze_token:
			_restore_pause()
	, CONNECT_ONE_SHOT)


func _restore_pause() -> void:
	if not _pause_modified:
		return
	_freeze_token += 1
	_pause_modified = false
	if get_tree():
		get_tree().paused = false


func _restore_time_scale() -> void:
	if not _time_scale_modified:
		return
	_time_scale_modified = false
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	_kill_banner_tween()
	_kill_unity_tween()
	_restore_time_scale()
	_restore_pause()
