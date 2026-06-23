extends Control
class_name SpellIconFrame
## UIUX §6.3 — 40px 法术槽 + 冷却环描边

const AssetPaths = preload("res://assets/asset_paths.gd")

@export var ring_color: Color = Color(1.0, 0.843, 0.0, 0.85)
@export var cd_color: Color = Color(0.08, 0.08, 0.12, 0.72)
@export var ready_glow: Color = Color(1.0, 0.92, 0.55, 0.9)

var cd_ratio: float = 0.0
var is_ready: bool = true
var _pulse: float = 0.0
var _cooldown_texture_hits := 0
@onready var _cooldown_sweep: TextureRect = $"../CooldownSweep"


func _ready() -> void:
	_apply_cooldown_texture()
	_update_cooldown_texture()

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.5)
		_update_cooldown_texture()
	if _pulse <= 0.01 and is_ready:
		set_process(false)

func set_cooldown(ratio: float, ready: bool) -> void:
	var was_ready := is_ready
	cd_ratio = clampf(ratio, 0.0, 1.0)
	is_ready = ready
	if ready and not was_ready:
		_pulse = 1.0
		set_process(true)
	_update_cooldown_texture()


func _apply_cooldown_texture() -> void:
	if _cooldown_sweep == null:
		return
	var texture := AssetPaths.load_texture(AssetPaths.spell_cooldown_sweep())
	if texture != null:
		_cooldown_sweep.texture = texture
		_cooldown_texture_hits += 1


func _update_cooldown_texture() -> void:
	if _cooldown_sweep == null:
		return
	if _cooldown_sweep.texture == null:
		_apply_cooldown_texture()
	var active := (not is_ready and cd_ratio > 0.001) or _pulse > 0.01
	_cooldown_sweep.visible = active
	if not active:
		_cooldown_sweep.modulate = Color(1, 1, 1, 0)
		return
	var alpha := clampf(cd_ratio * 0.72 + _pulse * 0.34, 0.18, 0.88)
	_cooldown_sweep.modulate = Color(1, 1, 1, alpha)
	_cooldown_sweep.rotation = -TAU * clampf(cd_ratio, 0.0, 1.0) * 0.18


func get_cooldown_texture_hit_count() -> int:
	return _cooldown_texture_hits
