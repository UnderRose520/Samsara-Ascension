extends CanvasLayer

@onready var dimmer: ColorRect = $Dimmer
@onready var regret_label: Label = $Regret
@onready var detail_label: Label = $Detail
@onready var phase_label: Label = $Phase
@onready var body_fall: Control = $BodyFall
@onready var line_label: Label = $Line
@onready var totem: Control = $Totem

var _tween: Tween
var _time_scale_modified := false
var _body_fall_progress := 0.0
var _totem_progress := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	regret_label.visible = false
	detail_label.visible = false
	phase_label.visible = false
	body_fall.visible = false
	line_label.visible = false
	totem.visible = false
	body_fall.draw.connect(_draw_body_fall)
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
	phase_label.text = "时间凝固"
	_body_fall_progress = 0.0
	_totem_progress = 0.0
	body_fall.rotation = -0.08
	totem.position.y = 0.0
	for node in [regret_label, detail_label, phase_label, body_fall, line_label, totem]:
		node.visible = true
		node.modulate.a = 0.0
	regret_label.scale = Vector2(0.9, 0.9)
	body_fall.scale = Vector2(1.0, 1.0)
	line_label.scale = Vector2(1.08, 1.08)
	EventBus.feedback_anchor_requested.emit("death_regret", {
		"world_position": EntityCache.get_player().global_position if EntityCache.get_player() else Vector2.INF,
	})
	if not VfxManager.should_reduce_motion():
		Engine.time_scale = 0.1
		_time_scale_modified = true
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(dimmer, "modulate:a", 0.72, 0.5)
	_tween.tween_property(regret_label, "modulate:a", 1.0, 0.28).set_delay(0.5)
	_tween.tween_property(regret_label, "scale", Vector2.ONE, 0.32).set_delay(0.5).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(detail_label, "modulate:a", 1.0, 0.35).set_delay(1.15)
	_tween.tween_property(phase_label, "modulate:a", 0.85, 0.22).set_delay(0.25)
	_tween.tween_callback(_set_phase_text.bind("遗憾标注")).set_delay(1.05)
	_tween.tween_callback(_set_phase_text.bind("魂魄离身")).set_delay(1.72)
	_tween.tween_callback(_set_phase_text.bind("遗言留世")).set_delay(2.65)
	_tween.tween_property(body_fall, "modulate:a", 0.78, 0.28).set_delay(1.35)
	_tween.tween_property(self, "_body_fall_progress", 1.0, 1.05).set_delay(1.45)
	_tween.tween_method(_queue_death_visuals_redraw, 0.0, 1.0, 1.05).set_delay(1.45)
	_tween.tween_property(totem, "modulate:a", 0.9, 0.35).set_delay(1.75)
	_tween.tween_property(self, "_totem_progress", 1.0, 1.25).set_delay(1.75)
	_tween.tween_method(_queue_death_visuals_redraw, 0.0, 1.0, 1.25).set_delay(1.75)
	_tween.tween_property(totem, "position:y", totem.position.y - 28.0, 1.0).set_delay(1.7)
	_tween.tween_property(line_label, "modulate:a", 1.0, 0.45).set_delay(2.65)
	_tween.tween_property(line_label, "scale", Vector2.ONE, 0.45).set_delay(2.65)
	_tween.tween_callback(_finish).set_delay(4.0)


func _set_phase_text(text: String) -> void:
	phase_label.text = text
	phase_label.modulate.a = 0.95


func _queue_death_visuals_redraw(_value: float = 0.0) -> void:
	if body_fall:
		body_fall.queue_redraw()
	if totem:
		totem.queue_redraw()


func _draw_body_fall() -> void:
	var center := body_fall.size * 0.5
	var t := clampf(_body_fall_progress, 0.0, 1.0)
	var lean := lerpf(-0.12, 1.22, t)
	var base_alpha := lerpf(0.72, 0.28, t)
	var body_color := Color(0.12, 0.08, 0.05, base_alpha)
	var glow := Color(1.0, 0.68, 0.24, 0.18 + t * 0.18)
	body_fall.draw_circle(center + Vector2(0.0, -30.0).rotated(lean), 12.0, Color(1.0, 0.78, 0.38, base_alpha))
	body_fall.draw_line(center + Vector2(0.0, -18.0).rotated(lean), center + Vector2(0.0, 30.0).rotated(lean), body_color, 10.0)
	body_fall.draw_line(center + Vector2(-24.0, 0.0).rotated(lean), center + Vector2(24.0, 6.0).rotated(lean), body_color, 6.0)
	body_fall.draw_arc(center + Vector2(0.0, 14.0), 42.0 + t * 10.0, PI * 0.08, PI * 0.92, 24, glow, 3.0)


func _draw_totem() -> void:
	var center := totem.size * 0.5
	var color := Color(1.0, 0.76, 0.28, 0.72)
	for i in 5:
		var radius := 26.0 + float(i) * 14.0
		var fade := 1.0 - clampf(_totem_progress - float(i) * 0.08, 0.0, 0.85)
		var ring_color := Color(color.r, color.g, color.b, color.a * fade)
		totem.draw_arc(center, radius, -PI * 0.6, PI * (0.65 + float(i) * 0.08), 42, ring_color, 2.0)
		totem.draw_line(center + Vector2(-radius * 0.45, -radius * 0.25), center + Vector2(radius * 0.45, radius * 0.25), Color(1.0, 0.92, 0.5, 0.36 * fade), 1.5)


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
