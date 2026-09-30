extends Node
## Autoload "Sfx": tiny procedurally synthesized blips (no audio files). Sfx.play("serve").

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# name: [[freq_start, freq_end, seconds], ...], wave, volume
	_make("grab", [[520.0, 780.0, 0.06]], "sine", 0.35)
	_make("drop", [[420.0, 260.0, 0.07]], "sine", 0.3)
	_make("pop", [[300.0, 900.0, 0.08]], "sine", 0.35)
	_make("plop", [[700.0, 350.0, 0.09]], "sine", 0.4)
	_make("chop", [[180.0, 90.0, 0.05]], "noise", 0.25)
	_make("ding", [[1320.0, 1320.0, 0.25]], "sine", 0.25)
	_make("serve", [[660.0, 660.0, 0.09], [880.0, 880.0, 0.09], [1320.0, 1320.0, 0.25]], "sine", 0.4)
	_make("buzz", [[140.0, 110.0, 0.35]], "square", 0.25)
	_make("fail", [[400.0, 200.0, 0.3]], "square", 0.2)
	_make("punch", [[160.0, 60.0, 0.12]], "noise", 0.45)
	_make("trash", [[500.0, 120.0, 0.2]], "noise", 0.25)
	_make("buy", [[520.0, 520.0, 0.07], [780.0, 780.0, 0.12]], "sine", 0.35)
	_make("start", [[440.0, 440.0, 0.1], [660.0, 660.0, 0.1], [880.0, 880.0, 0.2]], "sine", 0.35)
	_make("order", [[880.0, 990.0, 0.08]], "sine", 0.25)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sfx_name: String) -> void:
	if not _streams.has(sfx_name) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.play()


func _make(sfx_name: String, segments: Array, wave: String, vol: float) -> void:
	var data := PackedByteArray()
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for seg in segments:
		var f0: float = seg[0]
		var f1: float = seg[1]
		var dur: float = seg[2]
		var n := int(dur * RATE)
		var start := data.size()
		data.resize(start + n * 2)
		for i in n:
			var k := float(i) / float(n)
			phase += TAU * lerpf(f0, f1, k) / RATE
			var s := 0.0
			match wave:
				"square":
					s = 1.0 if sin(phase) >= 0.0 else -1.0
				"noise":
					s = rng.randf_range(-1.0, 1.0) * 0.7 + sin(phase) * 0.3
				_:
					s = sin(phase)
			var env := minf(1.0, float(i) / (RATE * 0.004)) * minf(1.0, float(n - i) / (RATE * 0.03))
			data.encode_s16(start + i * 2, int(clampf(s * vol * env, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_streams[sfx_name] = w
