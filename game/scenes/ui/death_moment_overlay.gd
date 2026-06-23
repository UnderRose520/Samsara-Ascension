extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var dimmer: TextureRect = $Dimmer
@onready var vignette: TextureRect = $Vignette
@onready var regret_label: Label = $Regret
@onready var detail_label: Label = $Detail
@onready var phase_label: Label = $Phase
@onready var soul_field: PanelContainer = $SoulField
@onready var room_metric: PanelContainer = $SoulField/Margin/VBox/MetricRow/RoomMetric
@onready var combo_metric: PanelContainer = $SoulField/Margin/VBox/MetricRow/ComboMetric
@onready var dao_metric: PanelContainer = $SoulField/Margin/VBox/MetricRow/DaoMetric
@onready var soul_hint: Label = $SoulField/Margin/VBox/Hint
@onready var body_fall: Control = $BodyFall
@onready var player_echo: TextureRect = $BodyFall/PlayerEcho
@onready var line_label: Label = $Line
@onready var totem: Control = $Totem
@onready var totem_disc: TextureRect = $Totem/TotemDisc
@onready var soul_seal: TextureRect = $Totem/SoulSeal

var _tween: Tween
var _time_scale_modified := false
var _body_fall_progress := 0.0
var _totem_progress := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	vignette.visible = false
	vignette.modulate.a = 0.0
	regret_label.visible = false
	detail_label.visible = false
	phase_label.visible = false
	soul_field.visible = false
	body_fall.visible = false
	line_label.visible = false
	totem.visible = false
	_apply_death_assets()
	_apply_soul_field_style()
	EventBus.death_moment_requested.connect(_on_death_moment_requested)
	EventBus.run_completed.connect(_force_cleanup)


func _on_death_moment_requested(summary: Dictionary) -> void:
	_kill_tween()
	_restore_time_scale()
	visible = true
	RunContext.ui_blocking = true
	get_tree().paused = true
	vignette.visible = true
	regret_label.text = str(summary.get("title", "本局遗憾"))
	detail_label.text = str(summary.get("detail", "这一世的路还未走完。"))
	line_label.text = str(summary.get("line", "来世再证大道。"))
	phase_label.text = "时间凝固"
	_update_soul_metrics(summary)
	_body_fall_progress = 0.0
	_totem_progress = 0.0
	soul_field.scale = Vector2(0.98, 0.98)
	body_fall.rotation = -0.08
	totem.position.y = 0.0
	player_echo.rotation = -0.12
	player_echo.scale = Vector2.ONE
	totem_disc.scale = Vector2(0.58, 0.58)
	soul_seal.scale = Vector2(0.58, 0.58)
	for node in [regret_label, detail_label, phase_label, soul_field, body_fall, line_label, totem]:
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
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(dimmer, "modulate:a", 0.44, 0.5)
	_tween.tween_property(vignette, "modulate:a", 0.92, 0.52)
	_tween.tween_property(regret_label, "modulate:a", 1.0, 0.28).set_delay(0.5)
	_tween.tween_property(regret_label, "scale", Vector2.ONE, 0.32).set_delay(0.5).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(detail_label, "modulate:a", 1.0, 0.35).set_delay(1.15)
	_tween.tween_property(phase_label, "modulate:a", 0.85, 0.22).set_delay(0.25)
	_tween.tween_property(soul_field, "modulate:a", 0.92, 0.30).set_delay(1.18)
	_tween.tween_property(soul_field, "scale", Vector2.ONE, 0.40).set_delay(1.18).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_set_phase_text.bind("遗憾标注")).set_delay(1.05)
	_tween.tween_callback(_set_phase_text.bind("魂魄离身")).set_delay(1.72)
	_tween.tween_callback(_set_phase_text.bind("遗言留世")).set_delay(2.65)
	_tween.tween_property(body_fall, "modulate:a", 0.78, 0.28).set_delay(1.35)
	_tween.tween_property(self, "_body_fall_progress", 1.0, 1.05).set_delay(1.45)
	_tween.tween_method(_queue_death_visuals_redraw, 0.0, 1.0, 1.05).set_delay(1.45)
	_tween.tween_property(body_fall, "rotation", 1.18, 1.05).set_delay(1.45).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(player_echo, "modulate", Color(0.66, 0.86, 0.78, 0.42), 1.05).set_delay(1.45)
	_tween.tween_property(totem, "modulate:a", 0.9, 0.35).set_delay(1.75)
	_tween.tween_property(self, "_totem_progress", 1.0, 1.25).set_delay(1.75)
	_tween.tween_method(_queue_death_visuals_redraw, 0.0, 1.0, 1.25).set_delay(1.75)
	_tween.tween_property(totem, "position:y", totem.position.y - 28.0, 1.0).set_delay(1.7)
	_tween.tween_property(totem_disc, "scale", Vector2(0.82, 0.82), 1.25).set_delay(1.75)
	_tween.tween_property(soul_seal, "scale", Vector2.ONE, 1.0).set_delay(1.9).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(soul_seal, "rotation", 0.18, 1.0).set_delay(1.9)
	_tween.tween_property(line_label, "modulate:a", 1.0, 0.45).set_delay(2.65)
	_tween.tween_property(line_label, "scale", Vector2.ONE, 0.45).set_delay(2.65)
	_tween.tween_callback(_finish).set_delay(4.0)


func _apply_death_assets() -> void:
	UiHelpers.apply_modal_veil(dimmer, 0.58)
	vignette.texture = AssetPaths.load_texture(AssetPaths.DEATH_MOMENT_VIGNETTE)
	var sprite_style := SaveManager.get_sprite_style()
	var sprite_path: String = str(AssetPaths.PLAYER_STYLE_PATHS.get(sprite_style, AssetPaths.PLAYER_STYLE_PATHS[AssetPaths.DEFAULT_SPRITE_STYLE]))
	player_echo.texture = AssetPaths.load_texture(sprite_path)
	player_echo.modulate = Color(0.92, 0.94, 0.82, 0.74)
	totem_disc.texture = AssetPaths.load_texture(AssetPaths.DEATH_SOUL_TOTEM_DISC)
	soul_seal.texture = AssetPaths.load_texture(AssetPaths.RUN_RESULT_VICTORY_SEAL)


func _apply_soul_field_style() -> void:
	UiHelpers.apply_panel_polish(soul_field)
	soul_field.modulate = Color(0.86, 1.0, 0.94, 0.0)
	for card in [room_metric, combo_metric, dao_metric]:
		UiHelpers.apply_card_polish(card)
		card.modulate = Color(0.9, 1.0, 0.96, 0.78)
		var value_label := card.get_node_or_null("Margin/VBox/Value") as Label
		var name_label := card.get_node_or_null("Margin/VBox/Name") as Label
		for label in [value_label, name_label]:
			if label == null:
				continue
			label.add_theme_constant_override("outline_size", 2)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	if soul_hint:
		soul_hint.add_theme_color_override("font_color", Color(UiTokens.TEXT_PRIMARY.r, UiTokens.TEXT_PRIMARY.g, UiTokens.TEXT_PRIMARY.b, 0.86))


func _update_soul_metrics(summary: Dictionary) -> void:
	_set_metric(room_metric, RunContext.rooms_cleared, "房间")
	_set_metric(combo_metric, int(summary.get("combo_peak", RunContext.peak_combo_count)), "最高连击")
	var dao_peak := int(summary.get("dao_peak", RunContext.dao_momentum))
	var dao_max := maxi(int(summary.get("dao_max", RunContext.dao_momentum_max)), 1)
	_set_metric(dao_metric, "%d/%d" % [dao_peak, dao_max], "道势峰值")
	if soul_hint:
		soul_hint.text = "魂魄已入轮回池，前世刻痕将写入玉简。"


func _set_metric(card: PanelContainer, value, label_text: String) -> void:
	if card == null:
		return
	var value_label := card.get_node_or_null("Margin/VBox/Value") as Label
	var name_label := card.get_node_or_null("Margin/VBox/Name") as Label
	if value_label:
		value_label.text = str(value)
	if name_label:
		name_label.text = label_text


func _set_phase_text(text: String) -> void:
	phase_label.text = text
	phase_label.modulate.a = 0.95


func _queue_death_visuals_redraw(_value: float = 0.0) -> void:
	if body_fall:
		body_fall.queue_redraw()
	if totem:
		totem.queue_redraw()


func _finish() -> void:
	_kill_tween()
	_restore_time_scale()
	visible = false
	dimmer.modulate.a = 0.0
	vignette.visible = false
	vignette.modulate.a = 0.0
	if soul_field:
		soul_field.visible = false
		soul_field.modulate.a = 0.0
	RunContext.ui_blocking = false
	EventBus.death_moment_finished.emit()


func _force_cleanup(_victory: bool = false) -> void:
	_kill_tween()
	_restore_time_scale()
	visible = false
	if vignette:
		vignette.visible = false
		vignette.modulate.a = 0.0
	if soul_field:
		soul_field.visible = false
		soul_field.modulate.a = 0.0
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
