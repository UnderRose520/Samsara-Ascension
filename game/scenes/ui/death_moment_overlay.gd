extends CanvasLayer

@onready var dimmer: ColorRect = $Dimmer
@onready var regret_label: Label = $Regret
@onready var detail_label: Label = $Detail
@onready var line_label: Label = $Line
@onready var totem: Control = $Totem

var _tween: Tween
var _time_scale_modified := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	regret_label.visible = false
	detail_label.visible = false
	line_label.visible = false
	totem.visible = false
	totem.draw.connect(_draw_totem)
	EventBus.death_moment_requested.connect(_on_death_moment_requested)
	EventBus.run_completed.connect(_force_cleanup)


func _on_death_moment_requested(summary: Dictionary) -> void:
	_kill_tween()
	_restore_time_scale()
	visible = true
	RunContext.ui_blocking = true
	get_tree().paused = true
	regret_label.text = str(summary.get("title", "本局遗憾"))
	detail_label.text = str(summary.get("detail", "这一世的路还未走完。"))
	line_label.text = str(summary.get("line", "来世再证大道。"))
	for node in [regret_label, detail_label, line_label, totem]:
		node.visible = true
		node.modulate.a = 0.0
	regret_label.scale = Vector2(0.9, 0.9)
	line_label.scale = Vector2(1.08, 1.08)
	if not VfxManager.should_reduce_motion():
		Engine.time_scale = 0.1
		_time_scale_modified = true
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(dimmer, "modulate:a", 0.72, 0.5)
	_tween.tween_property(regret_label, "modulate:a", 1.0, 0.28).set_delay(0.5)
	_tween.tween_property(regret_label, "scale", Vector2.ONE, 0.32).set_delay(0.5).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(detail_label, "modulate:a", 1.0, 0.35).set_delay(1.15)
	_tween.tween_property(totem, "modulate:a", 0.9, 0.35).set_delay(1.7)
	_tween.tween_property(totem, "position:y", totem.position.y - 22.0, 1.0).set_delay(1.7)
	_tween.tween_property(line_label, "modulate:a", 1.0, 0.45).set_delay(2.65)
	_tween.tween_property(line_label, "scale", Vector2.ONE, 0.45).set_delay(2.65)
	_tween.tween_callback(_finish).set_delay(4.0)


func _draw_totem() -> void:
	var center := totem.size * 0.5
	var color := Color(1.0, 0.76, 0.28, 0.72)
	for i in 5:
		var radius := 26.0 + float(i) * 14.0
		totem.draw_arc(center, radius, -PI * 0.6, PI * (0.65 + float(i) * 0.08), 42, color, 2.0)
		totem.draw_line(center + Vector2(-radius * 0.45, -radius * 0.25), center + Vector2(radius * 0.45, radius * 0.25), Color(1.0, 0.92, 0.5, 0.36), 1.5)


func _finish() -> void:
	_kill_tween()
	_restore_time_scale()
	visible = false
	dimmer.modulate.a = 0.0
	RunContext.ui_blocking = false
	EventBus.death_moment_finished.emit()


func _force_cleanup(_victory: bool = false) -> void:
	_kill_tween()
	_restore_time_scale()
	visible = false
	RunContext.ui_blocking = false


func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null


func _restore_time_scale() -> void:
	if not _time_scale_modified:
		return
	_time_scale_modified = false
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	_force_cleanup()
