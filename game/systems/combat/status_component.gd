class_name StatusComponent
extends Node

signal status_changed

var _burn_time := 0.0
var _burn_stacks := 0
var _slow_time := 0.0
var _paralyze_time := 0.0
var _poison_time := 0.0
var _poison_stacks := 0
var _freeze_time := 0.0


func apply_status(status_name: String, duration: float) -> void:
	match status_name:
		"burn":
			_burn_time = maxf(_burn_time, duration)
			_burn_stacks = mini(_burn_stacks + 1, 5)
		"slow":
			_slow_time = maxf(_slow_time, duration)
		"paralyze":
			_paralyze_time = maxf(_paralyze_time, duration)
		"poison":
			_poison_time = maxf(_poison_time, duration)
			_poison_stacks = mini(_poison_stacks + 1, 8)
		"freeze":
			_freeze_time = maxf(_freeze_time, duration)
	status_changed.emit()


func get_burn_stacks() -> int:
	return _burn_stacks if _burn_time > 0.0 else 0


func is_burning() -> bool:
	return _burn_time > 0.0


func is_paralyzed() -> bool:
	return _paralyze_time > 0.0


func is_slowed() -> bool:
	return _slow_time > 0.0


func is_frozen() -> bool:
	return _freeze_time > 0.0


func is_poisoned() -> bool:
	return _poison_time > 0.0 and _poison_stacks > 0


func get_move_speed_mult() -> float:
	if _paralyze_time > 0.0 or _freeze_time > 0.0:
		return 0.0
	if _slow_time > 0.0:
		return 0.55
	return 1.0


func get_visual_tint() -> Color:
	if _burn_time > 0.0:
		return status_color("burn")
	if _freeze_time > 0.0:
		return status_color("freeze")
	if _paralyze_time > 0.0:
		return status_color("paralyze")
	if _poison_time > 0.0:
		return status_color("poison")
	if _slow_time > 0.0:
		return status_color("slow")
	return Color.WHITE


static func status_color(status_name: String) -> Color:
	match status_name:
		"burn":
			return Color(1.0, 0.24, 0.06)
		"slow", "freeze":
			return Color(0.25, 0.76, 1.0)
		"paralyze":
			return Color(0.66, 0.34, 1.0)
		"poison":
			return Color(0.18, 0.9, 0.42)
		"shield", "guard":
			return Color(0.88, 0.58, 0.22)
		"haste", "dodge":
			return Color(0.28, 0.82, 1.0)
		"boss":
			return Color(1.0, 0.32, 0.12)
		"elite":
			return Color(0.92, 0.58, 0.18)
		"promoted":
			return Color(0.9, 0.66, 0.22)
		"dao", "counter":
			return Color(0.92, 0.72, 0.22)
		"mutation", "windup":
			return Color(1.0, 0.24, 0.12)
	return Color(0.72, 0.58, 1.0)


func consume_combust(base_damage: float) -> float:
	if _burn_stacks < 5:
		return 0.0
	var dmg := base_damage * 2.0 + _burn_stacks * 8.0
	_burn_time = 0.0
	_burn_stacks = 0
	status_changed.emit()
	return dmg


func detonate_burn(_base_damage: float) -> float:
	return consume_combust(_base_damage)


func tick(owner: Node, delta: float) -> float:
	_burn_time = maxf(_burn_time - delta, 0.0)
	_slow_time = maxf(_slow_time - delta, 0.0)
	_paralyze_time = maxf(_paralyze_time - delta, 0.0)
	_poison_time = maxf(_poison_time - delta, 0.0)
	_freeze_time = maxf(_freeze_time - delta, 0.0)
	if _burn_time <= 0.0:
		_burn_stacks = 0
	if _poison_time <= 0.0:
		_poison_stacks = 0
	var dot := 0.0
	if owner.has_node("HealthComponent"):
		var health: Node = owner.get_node("HealthComponent")
		if _burn_stacks > 0:
			dot += _burn_stacks * 2.0 * delta
		if _poison_stacks > 0:
			dot += _poison_stacks * 1.5 * delta
	status_changed.emit()
	return dot
