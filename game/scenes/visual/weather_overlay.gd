class_name WeatherOverlay
extends Node2D

const AssetPaths = preload("res://assets/asset_paths.gd")

const WEATHER_PARTICLE_COUNTS := {
	"rain": 52,
	"thunder": 46,
	"snow": 34,
	"fog": 18,
	"sand": 38,
	"wind": 24,
	"fire": 30,
}

var _weather_id := "clear"
var _bounds := Rect2(-640.0, -360.0, 1280.0, 720.0)
var _particles: Array = []
var _rng := RandomNumberGenerator.new()
var _intensity := 1.0
var _step_accum := 0.0
var _particle_texture_cache: Dictionary = {}
var _active_particle_texture: Texture2D

const WEATHER_FRAME_INTERVAL := 1.0 / 30.0


func _ready() -> void:
	z_index = 2
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = 917263
	set_weather("clear", _bounds)


func set_weather(weather_id: String, camera_bounds: Rect2, intensity: float = 1.0) -> void:
	_weather_id = weather_id
	_bounds = camera_bounds
	_intensity = clampf(intensity, 0.55, 1.85)
	_particles.clear()
	_step_accum = 0.0
	_active_particle_texture = _weather_particle_texture(_weather_id)
	var area_scale := sqrt(maxf(_bounds.size.x * _bounds.size.y, 1.0) / (1280.0 * 720.0))
	var count := int(round(float(WEATHER_PARTICLE_COUNTS.get(weather_id, 0)) * area_scale * _intensity))
	for _i in range(count):
		_particles.append(_make_particle(true))
	visible = weather_id != "clear" and count > 0 and _active_particle_texture != null
	if weather_id != "clear" and count > 0 and _active_particle_texture == null:
		push_error("WeatherOverlay missing image2 particle texture for weather `%s`" % weather_id)
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_step_accum += delta
	if _step_accum < WEATHER_FRAME_INTERVAL:
		return
	var step := minf(_step_accum, WEATHER_FRAME_INTERVAL * 2.0)
	_step_accum -= step
	for i in range(_particles.size()):
		var p: Dictionary = _particles[i]
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * step
		if _is_outside(Vector2(p["pos"])):
			p = _make_particle(false)
		_particles[i] = p
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	match _weather_id:
		"rain":
			_draw_wash(Color(0.06, 0.12, 0.22, 0.05 + 0.02 * _intensity))
			_draw_textured_particles(Color(0.58, 0.82, 1.0, minf(0.52, 0.34 + 0.06 * _intensity)))
		"thunder":
			_draw_wash(Color(0.04, 0.06, 0.16, 0.06 + 0.02 * _intensity))
			_draw_textured_particles(Color(0.62, 0.78, 1.0, minf(0.58, 0.38 + 0.06 * _intensity)))
		"snow":
			_draw_wash(Color(0.24, 0.32, 0.42, 0.055 + 0.025 * _intensity))
			_draw_textured_particles(Color(0.74, 0.92, 1.0, minf(0.52, 0.34 + 0.05 * _intensity)))
		"fog":
			_draw_wash(Color(0.30, 0.36, 0.34, 0.12))
			_draw_textured_particles(Color(0.64, 0.76, 0.70, 0.18 + 0.04 * _intensity))
		"sand":
			_draw_wash(Color(0.05, 0.10, 0.09, 0.065))
			_draw_textured_particles(Color(0.64, 0.72, 0.58, 0.18))
		"wind":
			_draw_textured_particles(Color(0.55, 1.0, 0.78, 0.25))
		"fire":
			_draw_wash(Color(0.04, 0.095, 0.085, 0.055))
			_draw_textured_particles(Color(0.82, 0.78, 0.44, 0.20))


func _make_particle(random_y: bool) -> Dictionary:
	var pos := Vector2(
		_rng.randf_range(_bounds.position.x - 80.0, _bounds.end.x + 80.0),
		_rng.randf_range(_bounds.position.y - 40.0, _bounds.end.y + 40.0) if random_y else _bounds.position.y - _rng.randf_range(16.0, 90.0)
	)
	var vel := Vector2.ZERO
	var size := 1.0
	match _weather_id:
		"rain", "thunder":
			vel = Vector2(_rng.randf_range(-90.0, -42.0), _rng.randf_range(560.0, 760.0))
			size = _rng.randf_range(0.85, 1.35)
		"snow":
			vel = Vector2(_rng.randf_range(-34.0, 22.0), _rng.randf_range(42.0, 92.0))
			size = _rng.randf_range(1.2, 2.8)
		"fog":
			vel = Vector2(_rng.randf_range(24.0, 78.0), _rng.randf_range(-8.0, 14.0))
			size = _rng.randf_range(1.0, 2.5)
		"sand":
			vel = Vector2(_rng.randf_range(220.0, 360.0), _rng.randf_range(-18.0, 46.0))
			size = _rng.randf_range(0.8, 1.8)
		"wind":
			vel = Vector2(_rng.randf_range(68.0, 170.0), _rng.randf_range(-10.0, 18.0))
			size = _rng.randf_range(1.0, 2.2)
		"fire":
			vel = Vector2(_rng.randf_range(-28.0, 36.0), _rng.randf_range(-90.0, -36.0))
			size = _rng.randf_range(0.75, 1.55)
	return {"pos": pos, "vel": vel, "size": size, "phase": _rng.randf_range(0.0, TAU)}


func _is_outside(pos: Vector2) -> bool:
	return (
		pos.x < _bounds.position.x - 140.0
		or pos.x > _bounds.end.x + 140.0
		or pos.y < _bounds.position.y - 140.0
		or pos.y > _bounds.end.y + 140.0
	)


func _draw_wash(color: Color) -> void:
	draw_rect(_bounds.grow(12.0), color, true)


func _draw_textured_particles(color: Color) -> void:
	if _active_particle_texture == null:
		return
	for p in _particles:
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var vel: Vector2 = p.get("vel", Vector2.RIGHT)
		var size := float(p.get("size", 1.0))
		var phase := float(p.get("phase", 0.0))
		var target_size := _particle_display_size(_active_particle_texture, size)
		var rotation := _particle_rotation(vel, phase)
		var modulate := _particle_modulate(color, size, phase)
		draw_set_transform(pos, rotation, Vector2.ONE)
		draw_texture_rect(
			_active_particle_texture,
			Rect2(-target_size * 0.5, target_size),
			false,
			modulate
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _particle_display_size(texture: Texture2D, size: float) -> Vector2:
	var tex_size := texture.get_size()
	var aspect := tex_size / maxf(maxf(tex_size.x, tex_size.y), 1.0)
	match _weather_id:
		"rain":
			return Vector2(10.0, 28.0) * clampf(size * _intensity, 0.75, 1.8)
		"thunder":
			return Vector2(14.0, 36.0) * clampf(size * _intensity, 0.78, 1.9)
		"snow":
			return Vector2.ONE * clampf(4.5 + size * 4.0 * _intensity, 6.0, 18.0)
		"fog":
			return tex_size * (0.42 + size * 0.25) * clampf(_intensity, 0.75, 1.35)
		"sand":
			return Vector2(36.0, 24.0) * clampf(size * _intensity, 0.75, 1.65)
		"wind":
			return Vector2(64.0, 32.0) * clampf(size * _intensity, 0.70, 1.7)
		"fire":
			return Vector2.ONE * clampf(8.0 + size * 7.0 * _intensity, 12.0, 26.0)
	var base := 18.0 * clampf(size, 0.8, 1.4)
	return Vector2(maxf(aspect.x, 0.2), maxf(aspect.y, 0.2)) * base


func _particle_rotation(vel: Vector2, phase: float) -> float:
	match _weather_id:
		"rain", "thunder", "sand", "wind":
			return vel.angle() + PI * 0.5
		"snow":
			return phase + Time.get_ticks_msec() * 0.0004
		"fog":
			return sin(phase + Time.get_ticks_msec() * 0.00025) * 0.18
		"fire":
			return vel.angle() + PI * 0.5 + sin(phase) * 0.18
	return phase


func _particle_modulate(base_color: Color, size: float, phase: float) -> Color:
	var pulse := 0.92 + 0.08 * sin(phase + Time.get_ticks_msec() * 0.0015)
	var color := base_color
	match _weather_id:
		"fog":
			color.a *= clampf(0.7 + size * 0.12, 0.7, 1.0)
		"snow":
			color.a *= clampf(0.72 + size * 0.08, 0.72, 1.0)
		"thunder", "fire":
			color.a *= pulse
		_:
			color.a *= clampf(pulse, 0.9, 1.0)
	return color


func _weather_particle_texture(weather_id: String) -> Texture2D:
	var key := weather_id.strip_edges().to_lower()
	if _particle_texture_cache.has(key):
		return _particle_texture_cache[key] as Texture2D
	var texture := AssetPaths.load_texture(AssetPaths.weather_overlay_particle(key))
	_particle_texture_cache[key] = texture
	return texture


func get_weather_particle_texture_hit_count() -> int:
	if _weather_id == "clear" or not visible:
		return 0
	return 1 if _active_particle_texture != null else 0


func get_weather_particle_count() -> int:
	return _particles.size()


func get_weather_particle_texture_path() -> String:
	return AssetPaths.weather_overlay_particle(_weather_id)
