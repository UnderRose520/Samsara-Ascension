extends Control
class_name SpellIconFrame
## UIUX §6.3 — 40px 法术槽 + 冷却环描边

@export var ring_color: Color = Color(1.0, 0.843, 0.0, 0.85)
@export var cd_color: Color = Color(0.08, 0.08, 0.12, 0.72)
@export var ready_glow: Color = Color(1.0, 0.92, 0.55, 0.9)

var cd_ratio: float = 0.0
var is_ready: bool = true
var _pulse: float = 0.0

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.5)
		queue_redraw()
	if _pulse <= 0.01 and is_ready:
		set_process(false)

func set_cooldown(ratio: float, ready: bool) -> void:
	var was_ready := is_ready
	cd_ratio = clampf(ratio, 0.0, 1.0)
	is_ready = ready
	if ready and not was_ready:
		_pulse = 1.0
		set_process(true)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_arc(center, radius + 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
	if not is_ready and cd_ratio > 0.001:
		var start := -PI * 0.5
		var sweep := TAU * cd_ratio
		draw_arc(center, radius, start, start + sweep, 32, cd_color, radius * 0.38, true)
	draw_arc(center, radius, 0.0, TAU, 48, ring_color, 2.5, true)
	if is_ready and _pulse > 0.01:
		var glow_a := _pulse * 0.55
		draw_arc(center, radius + 3.0, 0.0, TAU, 48, Color(ready_glow.r, ready_glow.g, ready_glow.b, glow_a), 3.0, true)
