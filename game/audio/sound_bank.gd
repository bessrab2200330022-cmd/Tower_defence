extends RefCounted
## Every sound in the game, synthesised at load time. No .ogg files, no .wav
## files, nothing to commit.
##
## Why generate rather than ship samples. The rest of this project is built on
## the same idea - models are Python scripts, the board is an ASCII file, balance
## is .tres - and a binary blob is the one asset type an agent cannot review,
## diff or adjust. A recipe of "140 Hz falling to 60 over 120 ms, with a noise
## transient" is readable and tunable; a 40 KB .ogg is not. These are frankly
## placeholders and should be replaced by a sound designer before ship, but a
## placeholder that exists beats a perfect sample that does not.
##
## Cost is about 40 ms of startup and roughly 200 KB of RAM for the whole bank.
##
## Nothing here touches the simulation. It builds AudioStreamWAV resources and
## hands them over.

## 22 kHz is plenty for short percussive noises and halves both the build time
## and the memory against 44.1.
const MIX_RATE: int = 22050

const FIRE_KINETIC: String = "fire_kinetic"
const FIRE_ENERGY: String = "fire_energy"
const IMPACT_SMALL: String = "impact_small"
const IMPACT_SPLASH: String = "impact_splash"
const ENEMY_DEATH: String = "enemy_death"
const ENEMY_DEATH_HEAVY: String = "enemy_death_heavy"
const LEAK: String = "leak"
const WAVE_START: String = "wave_start"
const BUILD: String = "build"
const UPGRADE: String = "upgrade"
const DENIED: String = "denied"

var _streams: Dictionary = {}
## Deterministic noise, so two runs of the game produce byte-identical audio and
## a regression in the synthesis is diffable. randf() would work - this is the
## view layer - but reproducibility is free here.
var _noise_state: int = 0x2f6e2b1


func build() -> void:
	_streams[FIRE_KINETIC] = _make(0.13, 190.0, 70.0, 2.6, 0.55, 0.35)
	_streams[FIRE_ENERGY] = _make(0.19, 1150.0, 260.0, 3.4, 0.12, 0.6)
	_streams[IMPACT_SMALL] = _make(0.10, 520.0, 170.0, 3.8, 0.5, 0.2)
	_streams[IMPACT_SPLASH] = _make(0.46, 130.0, 38.0, 2.0, 0.45, 0.5)
	_streams[ENEMY_DEATH] = _make(0.20, 300.0, 90.0, 3.0, 0.4, 0.3)
	_streams[ENEMY_DEATH_HEAVY] = _make(0.34, 170.0, 45.0, 2.2, 0.5, 0.45)
	_streams[DENIED] = _make(0.14, 150.0, 120.0, 4.0, 0.15, 0.0)

	# The three that carry information rather than texture get written as tone
	# sequences, because a player has to be able to tell them apart across a
	# noisy wave without looking at the HUD.
	_streams[LEAK] = _sequence([
		{"f": 440.0, "to": 415.0, "d": 0.16, "gain": 0.5},
		{"f": 330.0, "to": 300.0, "d": 0.16, "gain": 0.5},
		{"f": 220.0, "to": 180.0, "d": 0.34, "gain": 0.55},
	])
	_streams[WAVE_START] = _sequence([
		{"f": 392.0, "to": 392.0, "d": 0.13, "gain": 0.4},
		{"f": 523.0, "to": 523.0, "d": 0.13, "gain": 0.4},
		{"f": 659.0, "to": 659.0, "d": 0.30, "gain": 0.45},
	])
	_streams[BUILD] = _sequence([
		{"f": 160.0, "to": 90.0, "d": 0.07, "gain": 0.6, "noise": 0.7},
		{"f": 880.0, "to": 880.0, "d": 0.22, "gain": 0.3},
	])
	# The same clunk as a build, then a rising third. An upgrade has to be
	# audibly a bigger event than placing a tower, or a 140-credit purchase
	# sounds identical to a 90-credit one.
	_streams[UPGRADE] = _sequence([
		{"f": 180.0, "to": 100.0, "d": 0.07, "gain": 0.6, "noise": 0.7},
		{"f": 659.0, "to": 659.0, "d": 0.11, "gain": 0.34},
		{"f": 880.0, "to": 880.0, "d": 0.11, "gain": 0.34},
		{"f": 1174.0, "to": 1174.0, "d": 0.30, "gain": 0.38},
	])


func get_stream(id: String) -> AudioStreamWAV:
	return _streams.get(id, null)


func ids() -> Array:
	return _streams.keys()


# ---------------------------------------------------------------------------
# Synthesis
# ---------------------------------------------------------------------------

## One percussive hit: a pitch sweeping from `from_hz` down to `to_hz`, mixed
## with a noise transient, under an exponential decay.
##
## `decay` is the envelope exponent - higher is snappier. `noise` is how much of
## the result is noise rather than tone, and `body` adds a sub-octave, which is
## what makes an impact feel heavy rather than thin.
func _make(duration: float, from_hz: float, to_hz: float, decay: float,
		noise: float, body: float) -> AudioStreamWAV:
	var count: int = int(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)

	var phase: float = 0.0
	var sub_phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		# Exponential glide reads as a natural pitch drop; a linear one sounds
		# like a synthesiser sweeping.
		var hz: float = from_hz * pow(to_hz / from_hz, t)
		phase += TAU * hz / float(MIX_RATE)
		sub_phase += TAU * hz * 0.5 / float(MIX_RATE)

		var tone: float = sin(phase) * (1.0 - body) + sin(sub_phase) * body
		# Noise decays much faster than the tone: it is the transient, the click
		# at the front, not a texture running through the whole sound.
		var value: float = lerpf(tone, _noise(), noise * pow(1.0 - t, 3.0))
		samples[i] = value * pow(1.0 - t, decay)

	return _to_stream(samples)


## A run of tones played back to back, for the sounds that have to be
## recognisable rather than merely present.
func _sequence(steps: Array) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for step in steps:
		var spec: Dictionary = step
		var duration: float = float(spec["d"])
		var count: int = int(duration * float(MIX_RATE))
		var from_hz: float = float(spec["f"])
		var to_hz: float = float(spec.get("to", spec["f"]))
		var gain: float = float(spec.get("gain", 0.5))
		var noise: float = float(spec.get("noise", 0.0))

		var phase: float = 0.0
		for i in count:
			var t: float = float(i) / float(count)
			var hz: float = from_hz * pow(to_hz / from_hz, t)
			phase += TAU * hz / float(MIX_RATE)
			# A touch of third harmonic, so a bare sine does not read as a
			# hearing test. Cheap way to sound like an instrument.
			var tone: float = sin(phase) * 0.8 + sin(phase * 3.0) * 0.2
			var value: float = lerpf(tone, _noise(), noise * pow(1.0 - t, 3.0))
			# A short attack ramp kills the click a hard start would produce at
			# the boundary between two steps.
			var attack: float = minf(float(i) / 96.0, 1.0)
			samples.append(value * gain * attack * pow(1.0 - t, 2.2))
	return _to_stream(samples)


## xorshift32, the same generator sim/rng.gd uses - but a private instance, so
## drawing from it can never perturb the simulation's stream.
func _noise() -> float:
	var x: int = _noise_state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= (x >> 17)
	x ^= (x << 5) & 0xFFFFFFFF
	_noise_state = x & 0xFFFFFFFF
	return float(_noise_state) / 2147483647.5 - 1.0


## Normalises, then packs to signed 16-bit little-endian PCM. Normalising rather
## than trusting the recipe means a tweak to one envelope cannot make one sound
## four times louder than the rest.
func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	var gain: float = 0.92 / maxf(peak, 0.0001)

	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var scaled: int = clampi(int(samples[i] * gain * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, scaled)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream
