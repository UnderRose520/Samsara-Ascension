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
	var duration := 0.2
	var label := "灵机初动"
	if count >= 200:
		RunContext.trigger_dao_clarity("combo_200")
		return
	elif count >= 100:
		duration = 0.5
		label = "万法将成"
	elif count >= 60:
		duration = 0.3
		label = "道势奔流"
	elif count >= 30:
		label = "势如破竹"
	EventBus.crit_moment_requested.emit(label, duration)


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
