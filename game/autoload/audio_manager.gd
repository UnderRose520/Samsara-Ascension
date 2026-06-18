extends Node

const EVENT_PROFILES := {
	"ui_toast": {"freq": 660.0, "duration": 0.09, "volume": -18.0},
	"hit_light": {"freq": 520.0, "duration": 0.045, "volume": -24.0},
	"hit_heavy": {"freq": 170.0, "duration": 0.08, "volume": -18.0},
	"enemy_death": {"freq": 260.0, "duration": 0.12, "volume": -20.0},
	"combo_10": {"freq": 620.0, "duration": 0.08, "volume": -19.0},
	"combo_30": {"freq": 740.0, "duration": 0.1, "volume": -17.0},
	"combo_60": {"freq": 880.0, "duration": 0.12, "volume": -16.0},
	"combo_100": {"freq": 1040.0, "duration": 0.18, "volume": -15.0},
	"combo_200": {"freq": 1240.0, "duration": 0.34, "volume": -14.0, "style": "combo_peak"},
	"crit": {"freq": 980.0, "duration": 0.11, "volume": -15.0},
	"perfect_dodge": {"freq": 1200.0, "duration": 0.14, "volume": -15.0, "style": "perfect_dodge"},
	"dao_ready": {"freq": 392.0, "duration": 0.18, "volume": -16.0},
	"dao_clarity": {"freq": 523.25, "duration": 0.22, "volume": -15.0},
	"unity": {"freq": 220.0, "duration": 0.42, "volume": -14.0, "style": "unity"},
	"dao_awaken": {"freq": 329.63, "duration": 0.5, "volume": -13.0, "style": "dao_awaken"},
	"death_regret": {"freq": 146.83, "duration": 0.35, "volume": -16.0},
	"legacy_pick": {"freq": 440.0, "duration": 0.18, "volume": -17.0},
}

const DEFAULT_PROFILE := {"freq": 440.0, "duration": 0.08, "volume": -20.0}
const SAMPLE_RATE := 44100.0
const MAX_PLAYERS := 6

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_play_ms: Dictionary = {}
var _stream_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in MAX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.enemy_killed.connect(func(_enemy: Node) -> void: play_sfx("enemy_death"))
	EventBus.combo_milestone.connect(_on_combo_milestone)
	EventBus.combo_discovered.connect(func(_combo_id: String) -> void: play_sfx("dao_ready"))
	EventBus.crit_moment_requested.connect(func(_text: String, _duration: float) -> void: play_sfx("crit"))
	EventBus.perfect_dodge_triggered.connect(func(_world_position: Vector2) -> void: play_sfx("perfect_dodge"))
	EventBus.dao_tradition_awakened.connect(func(_tradition: Dictionary) -> void: play_sfx("dao_awaken"))
	EventBus.dao_clarity_started.connect(func(_duration: float, _source: String) -> void: play_sfx("dao_clarity"))
	EventBus.unity_burst_requested.connect(func(_payload: Dictionary) -> void: play_sfx("unity"))
	EventBus.learn_feedback.connect(func(_text: String, _accent: String) -> void: play_sfx("ui_toast"))
	EventBus.legacy_choice_closed.connect(_on_legacy_choice_closed)
	EventBus.run_completed.connect(func(victory: bool) -> void:
		if not victory:
			play_sfx("death_regret")
	)


func play_sfx(event: String) -> void:
	if event.is_empty() or _players.is_empty():
		return
	if not _can_play(event):
		return
	var profile: Dictionary = EVENT_PROFILES.get(event, DEFAULT_PROFILE)
	var stream := _stream_for_event(event, profile)
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.volume_db = float(profile.get("volume", DEFAULT_PROFILE.volume))
	player.pitch_scale = 1.0
	player.stream = stream
	player.play()


func _stream_for_event(event: String, profile: Dictionary) -> AudioStreamWAV:
	if _stream_cache.has(event):
		return _stream_cache[event]
	var stream := _make_tone(
		float(profile.get("freq", DEFAULT_PROFILE.freq)),
		float(profile.get("duration", DEFAULT_PROFILE.duration)),
		str(profile.get("style", event))
	)
	_stream_cache[event] = stream
	return stream


func _can_play(event: String) -> bool:
	var now := Time.get_ticks_msec()
	var min_gap := 35
	if event in ["hit_light", "enemy_death"]:
		min_gap = 70
	elif event in ["crit", "ui_toast"]:
		min_gap = 120
	var last := int(_last_play_ms.get(event, -100000))
	if now - last < min_gap:
		return false
	_last_play_ms[event] = now
	return true


func _make_tone(freq: float, duration: float, style: String = "") -> AudioStreamWAV:
	var frames := maxi(int(SAMPLE_RATE * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var progress := clampf(float(i) / float(frames), 0.0, 1.0)
		var fade := 1.0 - progress
		var attack := clampf(float(i) / maxf(float(frames) * 0.08, 1.0), 0.0, 1.0)
		var sample := _sample_event(style, freq, t, progress) * fade * attack
		var value := int(clampf(sample, -1.0, 1.0) * 16000.0)
		bytes.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	wav.data = bytes
	return wav


func _sample_event(style: String, freq: float, t: float, progress: float) -> float:
	match style:
		"unity":
			var bass_freq := lerpf(90.0, 38.0, progress)
			var bass := sin(TAU * bass_freq * t) * 0.9
			var element_burst := sin(TAU * freq * t) * 0.28 + sin(TAU * freq * 1.5 * t) * 0.18
			var impact_noise := _noise_sample(t, 57.0) * maxf(1.0 - progress * 4.0, 0.0) * 0.42
			return bass + element_burst + impact_noise
		"dao_awaken":
			var bell := sin(TAU * freq * t) * 0.58 + sin(TAU * freq * 2.01 * t) * 0.25
			var low_resonance := sin(TAU * 196.0 * t) * 0.34
			var wind := _noise_sample(t, 19.0) * 0.14 * sin(progress * PI)
			return bell + low_resonance + wind
		"combo_peak":
			var chime := sin(TAU * freq * t) * 0.42 + sin(TAU * freq * 1.25 * t) * 0.26
			var lift := sin(TAU * lerpf(320.0, 760.0, progress) * t) * 0.24
			var strike := _noise_sample(t, 103.0) * maxf(1.0 - progress * 8.0, 0.0) * 0.35
			return chime + lift + strike
		"perfect_dodge":
			return sin(TAU * lerpf(1400.0, 820.0, progress) * t) * 0.55 + _noise_sample(t, 211.0) * maxf(1.0 - progress * 10.0, 0.0) * 0.28
	return sin(TAU * freq * t)


func _noise_sample(t: float, salt: float) -> float:
	var x := sin((t * SAMPLE_RATE + salt) * 12.9898) * 43758.5453
	return fposmod(x, 1.0) * 2.0 - 1.0


func _on_damage_dealt(result: Dictionary) -> void:
	if bool(result.get("target_is_player", false)):
		play_sfx("hit_heavy")
	elif bool(result.get("is_crit", false)):
		play_sfx("crit")
	elif bool(result.get("is_combo", false)):
		play_sfx("hit_heavy")
	else:
		play_sfx("hit_light")


func _on_combo_milestone(count: int) -> void:
	if count >= 200:
		play_sfx("combo_200")
	elif count >= 100:
		play_sfx("combo_100")
	elif count >= 60:
		play_sfx("combo_60")
	elif count >= 30:
		play_sfx("combo_30")
	else:
		play_sfx("combo_10")


func _on_legacy_choice_closed(affix_id: String) -> void:
	if not affix_id.is_empty():
		play_sfx("legacy_pick")
