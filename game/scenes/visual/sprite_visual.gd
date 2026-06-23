extends Sprite2D
## Loads a texture from `texture_path`, then auto-plays matching generated frames.

const AssetPaths = preload("res://assets/asset_paths.gd")

@export var texture_path: String = ""
@export var animation_dir: String = ""
@export var animation_prefix: String = ""
@export var animation_fps: float = 6.0
@export var auto_infer_animation: bool = true

var _animation_frames: Array[Texture2D] = []
var _frame_index := 0
var _frame_elapsed := 0.0


func _ready() -> void:
	_apply_texture()


func _process(delta: float) -> void:
	if _animation_frames.size() <= 1 or animation_fps <= 0.0:
		return
	_frame_elapsed += delta
	var frame_time := 1.0 / animation_fps
	while _frame_elapsed >= frame_time:
		_frame_elapsed -= frame_time
		_frame_index = (_frame_index + 1) % _animation_frames.size()
		texture = _animation_frames[_frame_index]


func set_texture_path(path: String) -> void:
	texture_path = path
	_apply_texture()


func set_animation_prefix_name(prefix: String) -> void:
	if animation_prefix == prefix:
		return
	animation_prefix = prefix
	_apply_texture()


func _apply_texture() -> void:
	_animation_frames.clear()
	_frame_index = 0
	_frame_elapsed = 0.0
	texture = null
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var loaded: Resource = load(texture_path)
		if loaded is Texture2D:
			texture = loaded
	_load_animation_frames()
	if not _animation_frames.is_empty():
		texture = _animation_frames[0]
	set_process(_animation_frames.size() > 1)
	queue_redraw()


func _load_animation_frames() -> void:
	var frame_paths := _frame_paths()
	for path in frame_paths:
		var loaded := AssetPaths.load_texture(path)
		if loaded:
			_animation_frames.append(loaded)


func _frame_paths() -> Array[String]:
	if not animation_dir.is_empty():
		return AssetPaths.animation_frame_paths(animation_dir, animation_prefix)
	if auto_infer_animation:
		return AssetPaths.animation_frame_paths_for_texture(texture_path, animation_prefix)
	return []


func _draw() -> void:
	if texture != null:
		return
	if not texture_path.is_empty():
		push_error("SpriteVisual missing image2 texture for `%s`" % texture_path)
