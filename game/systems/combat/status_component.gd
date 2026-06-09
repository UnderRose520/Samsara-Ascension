class_name StatusComponent
extends Node

signal status_changed

var _burn_time := 0.0
var _burn_stacks := 0
var _slow_time := 0.0
var _paralyze_time := 0.0


func apply_status(status_name: String, duration: float) -> void:
	match status_name:
		"burn":
			_burn_time = maxf(_burn_time, duration)
			_burn_stacks = mini(_burn_stacks + 1, 5)
		"slow":
			_slow_time = maxf(_slow_time, duration)
		"paralyze":
			_paralyze_time = maxf(_paralyze_time, duration)
	status_changed.emit()


func get_burn_stacks() -> int:
	return _burn_stacks if _burn_time > 0.0 else 0


func is_burning() -> bool:
	return _burn_time > 0.0


func is_paralyzed() -> bool:
	return _paralyze_time > 0.0


func is_slowed() -> bool:
	return _slow_time > 0.0


func get_move_speed_mult() -> float:
	if _paralyze_time > 0.0:
		return 0.0
	if _slow_time > 0.0:
		return 0.55
	return 1.0


func get_visual_tint() -> Color:
	if _burn_time > 0.0:
		return Color(1.0, 0.45, 0.2)
	if _paralyze_time > 0.0:
		return Color(1.0, 0.95, 0.4)
	if _slow_time > 0.0:
		return Color(0.55, 0.85, 1.0)
	return Color.WHITE


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
	if _burn_time <= 0.0:
		_burn_stacks = 0
	var dot := 0.0
	if _burn_stacks > 0 and owner.has_node("HealthComponent"):
		dot = _burn_stacks * 2.0 * delta
	status_changed.emit()
	return dot
