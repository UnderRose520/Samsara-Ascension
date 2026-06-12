extends CanvasLayer

const CritSlashDraw = preload("res://vfx/crit_slash_draw.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

@onready var banner: Label = $Banner
@onready var vignette: ColorRect = $Vignette
@onready var slash: CritSlashDraw = $Slash

var _end_ms := 0
var _banner_tween: Tween
var _time_scale_modified := false
var _active_priority := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.visible = false
	vignette.modulate.a = 0.0
	slash.visible = false
	EventBus.crit_moment_requested.connect(_on_moment)
	EventBus.damage_dealt.connect(_on_damage_crit)
	EventBus.run_completed.connect(_force_cleanup)
	EventBus.room_entered.connect(_on_room_entered)


func _on_room_entered(_room: Dictionary, _stage: Dictionary) -> void:
	_force_cleanup()


func _on_moment(text: String, duration: float) -> void:
	_play_moment(text, duration, Color(1.0, 0.88, 0.25), 2)


func _on_damage_crit(result: Dictionary) -> void:
	if not VariantUtils.as_bool(result.get("is_crit", false)):
		return
	if VariantUtils.as_bool(result.get("target_is_player", false)):
		return
	_play_moment("天机一击!", 0.45, Color(1.0, 0.92, 0.35), 1)


func _play_moment(text: String, duration: float, slash_color: Color, priority: int = 1) -> void:
	if _end_ms > 0 and _active_priority > priority:
		return
	_active_priority = priority
	_kill_banner_tween()
	_restore_time_scale()

	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	banner.scale = Vector2(1.15, 1.15)
	banner.pivot_offset = banner.size * 0.5
	banner.add_theme_constant_override("outline_size", 2)
	banner.add_theme_color_override("font_outline_color", Color(0.35, 0.25, 0.0, 0.9))
	banner.add_theme_color_override("font_color", slash_color)
	slash.visible = true
	slash.set_anchors_preset(Control.PRESET_FULL_RECT)
	slash.play(0.35, slash_color)
	vignette.modulate.a = 0.0
	_end_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.08)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	if not VfxManager.should_reduce_motion():
		_banner_tween.tween_property(vignette, "modulate:a", 0.55, 0.1)
		Engine.time_scale = 0.35
		_time_scale_modified = true
		var center := _screen_center()
		VfxManager.spawn_screen(self, center * Vector2(1.0, 0.84), "crit", slash_color)
	else:
		_banner_tween.tween_property(vignette, "modulate:a", 0.25, 0.08)


func _screen_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _process(_delta: float) -> void:
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
	vignette.modulate.a = 0.0
	slash.visible = false
	_restore_time_scale()


func _force_cleanup(_victory: bool = false) -> void:
	_finish_moment()


func _kill_banner_tween() -> void:
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = null


func _restore_time_scale() -> void:
	if not _time_scale_modified:
		return
	_time_scale_modified = false
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	_kill_banner_tween()
	_restore_time_scale()
