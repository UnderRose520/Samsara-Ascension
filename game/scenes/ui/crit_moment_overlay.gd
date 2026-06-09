extends CanvasLayer

@onready var banner: Label = $Banner

var _end_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.visible = false
	EventBus.crit_moment_requested.connect(_on_moment)


func _on_moment(text: String, duration: float) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	_end_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	Engine.time_scale = 0.35


func _process(_delta: float) -> void:
	if _end_ms <= 0:
		return
	if Time.get_ticks_msec() < _end_ms:
		return
	_end_ms = 0
	banner.visible = false
	if not get_tree().paused:
		Engine.time_scale = 1.0
