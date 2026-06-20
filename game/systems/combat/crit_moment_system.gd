extends Node

const GameConstants = preload("res://core/constants/game_constants.gd")

var _last_milestone := 0


func _ready() -> void:
	EventBus.combo_updated.connect(_on_combo_updated)


func _on_combo_updated(count: int) -> void:
	for milestone in GameConstants.COMBO_MILESTONES:
		if count >= milestone and _last_milestone < milestone:
			_last_milestone = milestone
			EventBus.combo_milestone.emit(milestone)
			RunContext.add_dao_momentum(_momentum_for_milestone(milestone), "combo_%d" % milestone)
			_play_moment(milestone)
	if count == 0:
		_last_milestone = 0


func _play_moment(count: int) -> void:
	if count >= 200:
		RunContext.trigger_dao_clarity("combo_200")


func _momentum_for_milestone(count: int) -> float:
	if count >= 200:
		return 32.0
	if count >= 100:
		return 22.0
	if count >= 60:
		return 14.0
	if count >= 30:
		return 8.0
	return 4.0
