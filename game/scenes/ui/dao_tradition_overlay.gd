extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var banner: Label = $Banner
@onready var subtitle: Label = $Subtitle
@onready var glow: ColorRect = $Glow
@onready var frame: TextureRect = $Frame

var _end_ms := 0
var _awaken_tween: Tween
var _time_scale_modified := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.visible = false
	subtitle.visible = false
	glow.modulate.a = 0.0
	frame.texture = AssetPaths.load_texture(AssetPaths.MODAL_TITLE_BAR)
	EventBus.dao_tradition_awakened.connect(_on_awakened)
	EventBus.run_completed.connect(_force_cleanup)


func _on_awakened(tradition: Dictionary) -> void:
	if _awaken_tween and _awaken_tween.is_running():
		_awaken_tween.kill()
	_awaken_tween = null
	_restore_time_scale()
	banner.text = str(tradition.get("name", "道统觉醒"))
	subtitle.text = "%s · %s" % [tradition.get("title", ""), tradition.get("description", "")]
	banner.visible = true
	subtitle.visible = true
	banner.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	banner.pivot_offset = banner.size * 0.5
	_end_ms = Time.get_ticks_msec() + 1500
	get_tree().paused = true
	RunContext.ui_blocking = true
	_awaken_tween = create_tween().set_parallel(true)
	_awaken_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_awaken_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_awaken_tween.tween_property(subtitle, "modulate:a", 1.0, 0.25)
	_awaken_tween.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
	_awaken_tween.tween_property(glow, "modulate:a", 0.35, 0.25)
	if not VfxManager.should_reduce_motion():
		Engine.time_scale = 0.2
		_time_scale_modified = true
		var center := get_viewport().get_visible_rect().size * 0.5
		VfxManager.spawn_screen(self, center * Vector2(1.0, 0.96), "dao", Color(1.0, 0.84, 0.0))
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
	glow.modulate.a = 0.0
	RunContext.ui_blocking = false
	get_tree().paused = false
	_restore_time_scale()


func _force_cleanup(_victory: bool = false) -> void:
	_finish_overlay()


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
	RunContext.ui_blocking = false
