class_name HordeController
extends Node

const CombatHordeConfig = preload("res://systems/world/combat_horde_config.gd")
const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")

signal spawn_batch_requested(count: int)
signal horde_finished(reason: String, kills: int, quota: int)

var active := false
var finishing := false
var kills := 0
var quota := 0
var time_left := 0.0
var wave := 0
var spawn_cooldown := 0.0
var spawn_seq := 0
var cfg: Dictionary = {}
var room_type := ""
var stage_idx := 1

var _ui_tick := 0.0
var _dao_heart_override := -1
var _last_progress_notice := 0
var _time_warning_sent := false


func reset() -> void:
	active = false
	finishing = false
	kills = 0
	quota = 0
	time_left = 0.0
	wave = 0
	spawn_cooldown = 0.0
	spawn_seq = 0
	cfg = {}
	room_type = ""
	stage_idx = 1
	_ui_tick = 0.0
	_dao_heart_override = -1
	_last_progress_notice = 0
	_time_warning_sent = false


func set_dao_heart_override(heart: int) -> void:
	_dao_heart_override = heart


func start(room: Dictionary) -> void:
	reset()
	room_type = str(room.get("type", "combat"))
	stage_idx = int(room.get("stage_index", RunContext.current_stage + 1))
	cfg = CombatHordeConfig.get_for_stage(stage_idx, room_type)
	var heart := _dao_heart_override if _dao_heart_override >= 0 else RunContext.dao_heart
	quota = int(cfg.get("kill_quota", 20)) + DaoHeartConfig.enemy_count_delta(heart)
	quota = maxi(quota, 5)
	time_left = float(cfg.get("time_limit_sec", 120.0))
	active = true
	wave = 1
	var initial := mini(
		_spawn_count_for_wave(wave),
		int(cfg.get("max_alive", 10)),
	)
	spawn_batch_requested.emit(initial)
	spawn_cooldown = float(cfg.get("opening_delay_sec", cfg.get("wave_interval_sec", 4.0)))
	_emit_horde_updated()
	EventBus.wave_changed.emit(wave)
	EventBus.pet_coord_feedback.emit(
		"魔劫涌潮：斩 %d 只，或撑过 %d 秒" % [quota, int(time_left)]
	)


func tick(delta: float, alive_count: int, blocked: bool) -> void:
	if not active or finishing:
		return
	if blocked:
		return
	time_left = maxf(time_left - delta, 0.0)
	spawn_cooldown -= delta
	_ui_tick += delta
	if _ui_tick >= 0.25:
		_ui_tick = 0.0
		_emit_horde_updated()
		_emit_progress_notice()
	if time_left <= 0.0:
		_finish_horde("quota" if kills >= quota else "time")
		return
	if kills >= quota:
		return
	if spawn_cooldown > 0.0:
		return
	var max_alive := int(cfg.get("max_alive", 10))
	if alive_count >= max_alive:
		return
	var spawn_per := _spawn_count_for_wave(wave + 1)
	var spawn_count := mini(spawn_per, max_alive - alive_count)
	if spawn_count <= 0:
		return
	wave += 1
	spawn_batch_requested.emit(spawn_count)
	spawn_cooldown = float(cfg.get("wave_interval_sec", 4.0))
	_emit_horde_updated()
	EventBus.wave_changed.emit(wave)
	EventBus.pet_coord_feedback.emit("第 %d 波来袭：保持走位" % wave)


func _spawn_count_for_wave(target_wave: int) -> int:
	var target := maxi(int(cfg.get("spawn_per_wave", 4)), 1)
	var initial := clampi(int(cfg.get("initial_spawn", target)), 1, target)
	var ramp_waves := maxi(int(cfg.get("ramp_waves", 1)), 1)
	if target_wave <= 1:
		return initial
	var progress := clampf(float(target_wave - 1) / float(ramp_waves), 0.0, 1.0)
	return maxi(int(ceil(lerpf(float(initial), float(target), progress))), 1)


func on_enemy_killed() -> bool:
	if not active or finishing:
		return false
	kills += 1
	_emit_horde_updated()
	_emit_progress_notice()
	if kills >= quota:
		_finish_horde("quota")
		return true
	return false


func _finish_horde(reason: String) -> void:
	if finishing:
		return
	finishing = true
	active = false
	var msg := "目标完成：魔劫已尽 %d/%d" % [kills, quota]
	if reason == "time":
		msg = "时限已至：成功脱身 %d/%d" % [kills, quota]
	EventBus.pet_coord_feedback.emit(msg)
	_emit_horde_updated()
	horde_finished.emit(reason, kills, quota)
	finishing = false


func _emit_horde_updated() -> void:
	EventBus.horde_updated.emit(kills, quota, time_left, wave, maxf(spawn_cooldown, 0.0))


func _emit_progress_notice() -> void:
	if quota <= 0:
		return
	var progress := int(floor(float(kills) / float(quota) * 100.0))
	for step in [75, 50, 25]:
		if progress >= step and _last_progress_notice < step:
			_last_progress_notice = step
			var remain := maxi(quota - kills, 0)
			EventBus.pet_coord_feedback.emit("魔劫进度 %d%%：还差 %d 只" % [step, remain])
			return
	if not _time_warning_sent and time_left <= 10.0 and kills < quota:
		_time_warning_sent = true
		EventBus.pet_coord_feedback.emit("最后 10 秒：撑住即可脱身")
