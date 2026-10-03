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
	_make("crack", [[1400.0, 700.0, 0.03], [260.0, 140.0, 0.07]], "noise", 0.45)
	_make("fry", [[2400.0, 1600.0, 0.55]], "noise", 0.16)
	_make("ping", [[1175.0, 1175.0, 0.07], [1568.0, 1568.0, 0.3]], "sine", 0.2)
	_make("fizz", [[3200.0, 2600.0, 0.12], [2600.0, 3400.0, 0.45]], "noise", 0.14)
	# Plate rules (PlateSystem): tidy serve sparkle, messy serve shrug, scrape swoosh.
	_make("tidy", [[1568.0, 1568.0, 0.05], [2093.0, 2093.0, 0.05], [2637.0, 2637.0, 0.05], [3136.0, 3136.0, 0.2]], "sine", 0.22)
	_make("messy", [[520.0, 500.0, 0.1], [400.0, 360.0, 0.22]], "sine", 0.3)
	_make("scrape", [[900.0, 2200.0, 0.12], [2200.0, 300.0, 0.3]], "noise", 0.3)
	# Shift events (EventSystem): "ev_*" arrive as Net.event sfx, the paw ones play locally.
	_make("ev_vip", [[523.0, 523.0, 0.1], [659.0, 659.0, 0.1], [784.0, 784.0, 0.1], [1046.0, 1046.0, 0.3]], "sine", 0.35)
	_make("ev_vip_paid", [[784.0, 784.0, 0.08], [988.0, 988.0, 0.08], [1175.0, 1175.0, 0.08], [1568.0, 1568.0, 0.45]], "sine", 0.4)
	_make("ev_inspector", [[1800.0, 2400.0, 0.14], [2400.0, 1800.0, 0.14], [1800.0, 2500.0, 0.22]], "sine", 0.22)
	_make("ev_inspected", [[220.0, 60.0, 0.2]], "noise", 0.6)
	_make("ev_paw", [[380.0, 700.0, 0.12], [700.0, 820.0, 0.12], [820.0, 430.0, 0.4]], "square", 0.13)
	_make("paw_whoosh", [[300.0, 900.0, 0.35]], "noise", 0.3)
	_make("paw_swoosh", [[1100.0, 250.0, 0.6]], "noise", 0.4)
	_make_whoosh("gust", 3.8, 0.5)
	# Food truck lurch: a two-honk horn warning, then the clunk of the truck jolting.
	_make_horn("horn", 0.3)
	_make("clunk", [[170.0, 60.0, 0.05], [80.0, 36.0, 0.32]], "noise", 0.55)
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


## Truck horn: two honks of a two-tone chord (a minor third, ~311 + 370 Hz) built from a few saw
## harmonics, with a little pitch sag at the start and a soft low-pass (the food truck's lurch warning).
func _make_horn(sfx_name: String, vol: float) -> void:
	var honks := [[0.0, 0.26], [0.36, 0.5]]   # [start, length] seconds
	var seconds := 0.9
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := [0.0, 0.0]
	var freqs := [311.0, 370.0]
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		for h in honks:
			var lt: float = t - float(h[0])
			if lt >= 0.0 and lt <= float(h[1]):
				env = minf(1.0, lt / 0.012) * minf(1.0, (float(h[1]) - lt) / 0.04)
		var s := 0.0
		for k in 2:
			var sag := 1.0 - 0.03 * exp(-fmod(t, 0.36) * 30.0)
			ph[k] = fmod(float(ph[k]) + float(freqs[k]) * sag / RATE, 1.0)
			var p: float = ph[k]
			# Band-limited-ish saw: first four harmonics.
			for m in range(1, 5):
				s += sin(TAU * p * m) / m
		lp += (s * 0.25 - lp) * 0.35
		data.encode_s16(i * 2, int(clampf(lp * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_streams[sfx_name] = w


## Wind whoosh: low-passed noise whose cutoff and level swell to a peak at 55% and fade out, with a
## slow flutter (the wind hazard's gust).
func _make_whoosh(sfx_name: String, seconds: float, vol: float) -> void:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var k := float(i) / float(n)
		var swell := pow(sin(PI * pow(k, 0.8)), 1.6)
		var flutter := 0.8 + 0.2 * sin(k * TAU * 5.0) * sin(k * TAU * 1.7)
		var cutoff := lerpf(0.02, 0.16, swell)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cutoff
		lp2 += (lp - lp2) * cutoff
		var s := lp2 * 3.2 * swell * flutter
		data.encode_s16(i * 2, int(clampf(s * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_streams[sfx_name] = w
