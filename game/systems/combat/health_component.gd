class_name HealthComponent
extends Node

signal died
signal changed(current: float, maximum: float)

const HP_EPSILON := 0.01

@export var max_hp: float = 100.0
@export var defense: float = 5.0

var current_hp: float


func _ready() -> void:
	current_hp = max_hp
	_emit()


func is_alive() -> bool:
	return current_hp > HP_EPSILON


func take_damage(amount: float) -> float:
	if current_hp <= HP_EPSILON:
		return 0.0
	var applied := minf(amount, current_hp)
	current_hp -= applied
	if current_hp <= HP_EPSILON:
		current_hp = 0.0
		_emit()
		died.emit()
	else:
		_emit()
	return applied


func _emit() -> void:
	changed.emit(current_hp, max_hp)
