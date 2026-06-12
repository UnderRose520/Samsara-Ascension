extends Control

var slash_color := Color(1.0, 0.88, 0.2, 0.0)
var _life := 0.0


func play(duration: float = 0.35, color: Color = Color(1.0, 0.88, 0.2, 1.0)) -> void:
	slash_color = Color(color.r, color.g, color.b, 0.0)
	_life = duration
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	var t := clampf(1.0 - _life / 0.35, 0.0, 1.0)
	slash_color.a = (1.0 - t) * 0.95
	queue_redraw()
	if _life <= 0.0:
		set_process(false)
		visible = false


func _draw() -> void:
	if slash_color.a <= 0.01:
		return
	var c := size * 0.5
	var len := minf(size.x, size.y) * 0.42
	draw_line(c + Vector2(-len, -len * 0.2), c + Vector2(len, len * 0.2), slash_color, 4.0, true)
	draw_line(c + Vector2(-len * 0.7, len * 0.1), c + Vector2(len * 0.8, -len * 0.15), Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * 0.55), 2.0, true)
