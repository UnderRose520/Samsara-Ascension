class_name WeatherOverlay
extends Node2D

const WEATHER_PARTICLE_COUNTS := {
	"rain": 52,
	"thunder": 46,
	"snow": 34,
	"fog": 18,
	"sand": 38,
	"wind": 24,
}

var _weather_id := "clear"
var _bounds := Rect2(-640.0, -360.0, 1280.0, 720.0)
var _particles: Array = []
var _rng := RandomNumberGenerator.new()
var _intensity := 1.0
var _step_accum := 0.0

const WEATHER_FRAME_INTERVAL := 1.0 / 30.0


func _ready() -> void:
	z_index = 80
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = 917263
	set_weather("clear", _bounds)


func set_weather(weather_id: String, camera_bounds: Rect2, intensity: float = 1.0) -> void:
	_weather_id = weather_id
	_bounds = camera_bounds
	_intensity = clampf(intensity, 0.55, 1.85)
	_particles.clear()
	_step_accum = 0.0
	var area_scale := sqrt(maxf(_bounds.size.x * _bounds.size.y, 1.0) / (1280.0 * 720.0))
	var count := int(round(float(WEATHER_PARTICLE_COUNTS.get(weather_id, 0)) * area_scale * _intensity))
	for _i in range(count):
		_particles.append(_make_particle(true))
	visible = weather_id != "clear" and count > 0
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_step_accum += delta
	if _step_accum < WEATHER_FRAME_INTERVAL:
		return
	var step := minf(_step_accum, WEATHER_FRAME_INTERVAL * 2.0)
	_step_accum = 0.0
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
			_draw_wash(Color(0.20, 0.34, 0.52, 0.07 + 0.04 * _intensity))
			_draw_rain(Color(0.62, 0.80, 1.0, minf(0.72, 0.44 + 0.12 * _intensity)), 18.0 * _intensity, 1.15)
		"thunder":
			_draw_wash(Color(0.12, 0.16, 0.34, 0.11 + 0.05 * _intensity))
			_draw_rain(Color(0.70, 0.86, 1.0, minf(0.78, 0.48 + 0.13 * _intensity)), 20.0 * _intensity, 1.25)
		"snow":
			_draw_wash(Color(0.72, 0.88, 1.0, 0.07 + 0.04 * _intensity))
			_draw_snow()
		"fog":
			_draw_fog()
		"sand":
			_draw_wash(Color(0.88, 0.68, 0.36, 0.13))
			_draw_streaks(Color(0.95, 0.76, 0.42, 0.34), 14.0, 0.9)
		"wind":
			_draw_streaks(Color(0.72, 0.95, 0.84, 0.22), 24.0, 0.65)


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
		"sand":
			vel = Vector2(_rng.randf_range(220.0, 360.0), _rng.randf_range(-18.0, 46.0))
			size = _rng.randf_range(0.8, 1.8)
		"wind", "fog":
			vel = Vector2(_rng.randf_range(68.0, 170.0), _rng.randf_range(-10.0, 18.0))
			size = _rng.randf_range(1.0, 2.2)
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


func _draw_rain(color: Color, length: float, width: float) -> void:
	for p in _particles:
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var vel: Vector2 = p.get("vel", Vector2.DOWN)
		var dir := vel.normalized()
		draw_line(pos, pos - dir * length * float(p.get("size", 1.0)), color, width)


func _draw_snow() -> void:
	for p in _particles:
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var size := float(p.get("size", 1.0))
		var alpha := clampf(0.28 + size * 0.12, 0.32, 0.68)
		draw_circle(pos, size, Color(0.88, 0.96, 1.0, alpha))


func _draw_fog() -> void:
	_draw_wash(Color(0.72, 0.78, 0.74, 0.17))
	for p in _particles:
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var size := 26.0 + float(p.get("size", 1.0)) * 18.0
		draw_circle(pos, size, Color(0.80, 0.86, 0.82, 0.045))


func _draw_streaks(color: Color, length: float, width: float) -> void:
	for p in _particles:
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var vel: Vector2 = p.get("vel", Vector2.RIGHT)
		var dir := vel.normalized()
		draw_line(pos, pos - dir * length * float(p.get("size", 1.0)), color, width)
