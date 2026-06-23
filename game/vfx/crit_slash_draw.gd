extends Control

const AssetPaths = preload("res://assets/asset_paths.gd")

var slash_color := Color(1.0, 0.88, 0.2, 0.0)
var _life := 0.0
var _slash_texture: Texture2D
var _texture_hit := false


func play(duration: float = 0.35, color: Color = Color(1.0, 0.88, 0.2, 1.0)) -> void:
	slash_color = Color(color.r, color.g, color.b, 0.0)
	_life = duration
	_slash_texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("crit_screen_slash"))
	_texture_hit = _slash_texture != null
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


func get_slash_texture_hit_count() -> int:
	return int(_texture_hit)


func _draw() -> void:
	if slash_color.a <= 0.01:
		return
	var c := size * 0.5
	if _slash_texture:
		var draw_size := Vector2(minf(size.x * 0.72, 920.0), minf(size.y * 0.28, 260.0))
		var rect := Rect2(c - draw_size * 0.5, draw_size)
		draw_texture_rect(_slash_texture, rect, false, slash_color)
