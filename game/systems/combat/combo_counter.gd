class_name ComboCounter
extends Node

const GameConstants = preload("res://core/constants/game_constants.gd")

var count := 0
var _timer := 0.0


func register_hit() -> void:
	count += 1
	_timer = GameConstants.COMBO_BREAK_SEC
	EventBus.combo_updated.emit(count)


func _process(delta: float) -> void:
	if count <= 0:
		return
	_timer -= delta
	if _timer <= 0.0:
		count = 0
		EventBus.combo_updated.emit(count)
