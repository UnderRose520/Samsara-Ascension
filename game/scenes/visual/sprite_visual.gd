extends Sprite2D
## Loads a texture from `texture_path`; draws a placeholder circle when missing.

@export var texture_path: String = ""
@export var fallback_radius: float = 8.0
@export var fallback_color: Color = Color(0.5, 0.5, 0.55, 0.85)


func _ready() -> void:
	_apply_texture()


func set_texture_path(path: String) -> void:
	texture_path = path
	_apply_texture()


func _apply_texture() -> void:
	texture = null
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var loaded: Resource = load(texture_path)
		if loaded is Texture2D:
			texture = loaded
	queue_redraw()


func _draw() -> void:
	if texture != null:
		return
	draw_circle(Vector2.ZERO, fallback_radius, fallback_color)
