extends Node3D
## The game's ears. Turns drained simulation events into sound.
##
## Reads events, plays voices, decides nothing. It never touches simulation
## state, is never consulted by it, and removing this node entirely must leave
## the game playing identically - which is the property that lets it be muted,
## rate-limited or stolen from without any of that being a rules change.
##
## Three constraints shape the design:
##
##   * Fixed pools. Sixteen drones dying in the same frame allocate no players;
##     they compete for the same fourteen voices. Nothing can leak, at any speed
##     or while paused, because nothing is ever created after build().
##   * Real-time throttling. The minimum gap between two plays of one sound is
##     in seconds, not ticks, so 4x speed does not turn a firing line into a
##     buzzsaw - it drops the sounds that would have overlapped inaudibly anyway.
##   * Variation. Every voice gets a pitch and volume jitter, and a sound that
##     repeats within a moment is ducked. Identical samples stacking on the same
##     frame is what produces the machine-gun artefact.

const Types := preload("res://sim/sim_types.gd")
const SoundBank := preload("res://game/audio/sound_bank.gd")

## Positional voices for things that happen somewhere on the board, plus a
## smaller flat pool for the ones that are really UI: a wave starting, a life
## lost. Fourteen is about four simultaneous explosions' worth.
const VOICES_3D: int = 14
const VOICES_2D: int = 6

## How fast the "this just played" counter decays, per second. It is what drives
## the ducking, so it doubles as the length of a burst the mix will tolerate.
const REPEAT_DECAY: float = 5.0
const MAX_DUCK_STEPS: float = 4.0
const DUCK_DB_PER_STEP: float = 3.0

## Radius over which a 3D voice stays at full volume. The board is about 40 units
## across, so a smaller figure makes the far half of the map inaudible.
const UNIT_SIZE: float = 18.0
const MAX_DISTANCE: float = 140.0

## Per-sound mix. `gap` is the minimum real-time spacing in seconds, `db` the
## base level, `pitch` the +/- jitter as a fraction.
const MIX: Dictionary = {
	SoundBank.FIRE_KINETIC: {"gap": 0.035, "db": -9.0, "pitch": 0.10},
	SoundBank.FIRE_ENERGY: {"gap": 0.045, "db": -11.0, "pitch": 0.08},
	SoundBank.IMPACT_SMALL: {"gap": 0.030, "db": -12.0, "pitch": 0.14},
	SoundBank.IMPACT_SPLASH: {"gap": 0.060, "db": -6.0, "pitch": 0.08},
	SoundBank.ENEMY_DEATH: {"gap": 0.040, "db": -9.0, "pitch": 0.13},
	SoundBank.ENEMY_DEATH_HEAVY: {"gap": 0.060, "db": -5.0, "pitch": 0.08},
	SoundBank.LEAK: {"gap": 0.250, "db": -3.0, "pitch": 0.02},
	SoundBank.WAVE_START: {"gap": 0.500, "db": -5.0, "pitch": 0.00},
	SoundBank.BUILD: {"gap": 0.050, "db": -7.0, "pitch": 0.05},
	SoundBank.UPGRADE: {"gap": 0.080, "db": -5.0, "pitch": 0.02},
	SoundBank.DENIED: {"gap": 0.120, "db": -10.0, "pitch": 0.03},
}

## Resolved by name - see the same constant in game/level.gd for why. -1 until
## the simulation declares the member, and -1 matches no event.
## `static var`, not `const`: a Dictionary lookup is not a constant
## expression, and the whole point is that this is resolved at load time
## rather than written down.
static var EVENT_TOWER_UPGRADED: int = int(Types.Event.get("TOWER_UPGRADED", -1))

## An enemy at or above this radius dies with the heavy sound. Same threshold
## game/level.gd uses to decide between an explosion and a plain death effect,
## so what you see and what you hear agree.
const HEAVY_RADIUS: float = 0.585

var enabled: bool = true
var master_db: float = 0.0

var catalog

var _bank
var _voices_3d: Array[AudioStreamPlayer3D] = []
var _voices_2d: Array[AudioStreamPlayer] = []

## When each voice is expected to fall silent, on this node's own clock.
##
## Deliberately bookkeeping rather than reading `AudioStreamPlayer.playing`.
## Under the Dummy audio driver — which is what `--headless` gives you, and
## therefore what the autoplay gate runs on — nothing ever mixes, so `playing`
## latches true forever and every voice looks permanently busy after the first
## twenty sounds. Owning the timing makes the pool behave the same way in the
## gate as it does on a machine with speakers.
var _busy_until_3d: PackedFloat64Array = PackedFloat64Array()
var _busy_until_2d: PackedFloat64Array = PackedFloat64Array()
var _clock: float = 0.0

var _cooldowns: Dictionary = {}
var _repeats: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _plays: int = 0
var _dropped: int = 0

## True when the engine has no real audio output — `--headless` falls back to the
## Dummy driver, and so does any machine whose sound device fails to open.
##
## Everything above this still runs when it is set: events are mapped, the
## throttle admits or refuses, voices are picked, ducked and retired, and
## stats() reports honest numbers. Only the engine-side play() is skipped.
##
## The reason is narrow and worth writing down. Godot defers releasing an
## AudioStreamPlayback to the next mix step, and the Dummy driver's mixing stops
## the moment the SceneTree quits — so a sound started in the last frames of a
## run is still held by the audio server at shutdown and is reported as a leaked
## ObjectDB instance. The autoplay gate ends mid-wave with shots in the air, so
## it hit that on most runs. stop() cannot help: it is the release that is
## deferred, not the stop.
var _silent: bool = false


func build(catalog_ref) -> void:
	catalog = catalog_ref
	_silent = AudioServer.get_driver_name() == "Dummy"
	_rng.seed = 0x5EED
	_bank = SoundBank.new()
	_bank.build()

	for i in VOICES_3D:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice3D%d" % i
		voice.unit_size = UNIT_SIZE
		voice.max_distance = MAX_DISTANCE
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(voice)
		_voices_3d.append(voice)
		_busy_until_3d.append(0.0)

	for i in VOICES_2D:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice2D%d" % i
		add_child(voice)
		_voices_2d.append(voice)
		_busy_until_2d.append(0.0)


# ---------------------------------------------------------------------------
# Events in
# ---------------------------------------------------------------------------

## One drained simulation event. Unknown types are ignored rather than warned
## about: the sim is free to add events this layer has no opinion on.
func handle(event: Dictionary) -> void:
	var type: int = int(event.get("type", -1))
	if type == EVENT_TOWER_UPGRADED:
		# Flat, like the sell clunk and for the same reason: the contracted event
		# carries tower_id, def_id and tier but no world position, and playing a
		# positional voice at Vector3.ZERO would put every upgrade in the corner
		# of the board.
		_play_flat(SoundBank.UPGRADE)
		return

	match type:
		Types.Event.TOWER_FIRED:
			var hitscan: bool = int(event.get("fire_mode", Types.FireMode.PROJECTILE)) == Types.FireMode.HITSCAN
			_play(SoundBank.FIRE_ENERGY if hitscan else SoundBank.FIRE_KINETIC,
				event.get("origin", Vector3.ZERO))
		Types.Event.PROJECTILE_HIT:
			var splash: bool = float(event.get("splash_radius", 0.0)) > 0.05
			_play(SoundBank.IMPACT_SPLASH if splash else SoundBank.IMPACT_SMALL,
				event.get("position", Vector3.ZERO))
		Types.Event.ENEMY_KILLED:
			_play(_death_sound(str(event.get("def_id", ""))),
				event.get("position", Vector3.ZERO))
		Types.Event.ENEMY_LEAKED:
			# No position on this event, and none wanted. A life lost is not a
			# thing that happened over there, it is a thing that happened to you.
			_play_flat(SoundBank.LEAK)
		Types.Event.WAVE_STARTED:
			_play_flat(SoundBank.WAVE_START)
		Types.Event.TOWER_BUILT:
			_play(SoundBank.BUILD, event.get("position", Vector3.ZERO))
		Types.Event.TOWER_SOLD:
			# Same clunk, dropped most of an octave, so build and sell read as a
			# pair without a second recipe. Flat rather than positional: the
			# event carries a cell, not a world position, and converting one
			# would mean this node knowing about the grid.
			_play_flat(SoundBank.BUILD, 0.62)
		_:
			pass


## Rejected input. Not an event - the simulation does not consider a refused
## build to have happened at all - so game/main.gd calls this directly.
func play_denied() -> void:
	_play_flat(SoundBank.DENIED)


func _death_sound(def_id: String) -> String:
	if catalog == null or def_id == "":
		return SoundBank.ENEMY_DEATH
	var def = catalog.get_enemy(def_id)
	if def != null and def.radius >= HEAVY_RADIUS:
		return SoundBank.ENEMY_DEATH_HEAVY
	return SoundBank.ENEMY_DEATH


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

func _play(id: String, at: Vector3, pitch_bias: float = 1.0) -> void:
	if not _admit(id):
		return
	var index: int = _take(_busy_until_3d)
	var voice: AudioStreamPlayer3D = _voices_3d[index]
	var stream: AudioStreamWAV = _bank.get_stream(id)
	var pitch: float = _pitch(id) * pitch_bias

	if not _silent:
		# stop() before play(). Calling play() on a voice that is already
		# sounding leaves the previous playback to fade out, which is a second
		# live playback for a voice the pool already considers reassigned.
		voice.stop()
		voice.stream = stream
		voice.position = at
		voice.pitch_scale = pitch
		voice.volume_db = master_db + _level(id)
		voice.play()
	_busy_until_3d[index] = _clock + stream.get_length() / maxf(pitch, 0.05)
	_plays += 1


func _play_flat(id: String, pitch_bias: float = 1.0) -> void:
	if not _admit(id):
		return
	var index: int = _take(_busy_until_2d)
	var voice: AudioStreamPlayer = _voices_2d[index]
	var stream: AudioStreamWAV = _bank.get_stream(id)
	var pitch: float = _pitch(id) * pitch_bias

	if not _silent:
		voice.stop()
		voice.stream = stream
		voice.pitch_scale = pitch
		voice.volume_db = master_db + _level(id)
		voice.play()
	_busy_until_2d[index] = _clock + stream.get_length() / maxf(pitch, 0.05)
	_plays += 1


## The gate. Enforces mute, the minimum gap, and counts what it turned away so
## a mix problem shows up as a number rather than as a vague impression.
func _admit(id: String) -> bool:
	if not enabled or _bank == null or _bank.get_stream(id) == null:
		return false
	# AudioStreamPlayer.play() hard-errors when the node is outside the tree, and
	# a harness that builds a Level without parenting it is a reasonable thing to
	# write - the RtsCamera hit exactly this. Refuse quietly instead.
	if not is_inside_tree():
		return false
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		_dropped += 1
		return false
	_cooldowns[id] = float(_mix_for(id).get("gap", 0.03))
	_repeats[id] = minf(float(_repeats.get(id, 0.0)) + 1.0, MAX_DUCK_STEPS)
	return true


func _pitch(id: String) -> float:
	var spread: float = float(_mix_for(id).get("pitch", 0.0))
	if spread <= 0.0:
		return 1.0
	return 1.0 + _rng.randf_range(-spread, spread)


## Base level minus a duck proportional to how much of this sound is already in
## the air. Ten drones popping together should be one loud crunch, not ten.
func _level(id: String) -> float:
	var base: float = float(_mix_for(id).get("db", -8.0))
	var stacked: float = maxf(float(_repeats.get(id, 0.0)) - 1.0, 0.0)
	return base - stacked * DUCK_DB_PER_STEP


static func _mix_for(id: String) -> Dictionary:
	return MIX.get(id, {})


## Picks a voice index: a silent one if there is one, otherwise the one closest
## to finishing. Stealing the nearest-to-done costs the least audible material,
## and it can never fail, which is why callers do not have to handle a refusal.
func _take(busy_until: PackedFloat64Array) -> int:
	var soonest: int = 0
	for i in busy_until.size():
		if busy_until[i] <= _clock:
			return i
		if busy_until[i] < busy_until[soonest]:
			soonest = i
	return soonest


# ---------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------

## Driven from game/level.gd::sync() on the real frame delta, deliberately not
## from a Timer or from tick counts. The throttling has to be in wall-clock
## seconds or it would tighten fourfold at 4x speed, which is exactly when the
## mix most needs protecting.
func step(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	for id in _cooldowns.keys():
		var left: float = float(_cooldowns[id]) - delta
		_cooldowns[id] = maxf(left, 0.0)
	for id in _repeats.keys():
		var value: float = float(_repeats[id]) - REPEAT_DECAY * delta
		_repeats[id] = maxf(value, 0.0)

	# Retire finished voices explicitly rather than trusting
	# AudioStreamPlayer.playing, which is the only way the pool behaves the same
	# with and without a real audio device.
	for i in _busy_until_3d.size():
		if _busy_until_3d[i] > 0.0 and _busy_until_3d[i] <= _clock:
			_busy_until_3d[i] = 0.0
			if not _silent:
				_voices_3d[i].stop()
				_voices_3d[i].stream = null
	for i in _busy_until_2d.size():
		if _busy_until_2d[i] > 0.0 and _busy_until_2d[i] <= _clock:
			_busy_until_2d[i] = 0.0
			if not _silent:
				_voices_2d[i].stop()
				_voices_2d[i].stream = null


## A voice still playing when the engine shuts down leaves its stream and its
## AudioStreamPlayback alive inside the audio server, and Godot reports that as
## leaked ObjectDB instances at exit. The autoplay gate ends mid-wave with a
## dozen shots in the air, so it hits this every single run. Releasing the
## streams on the way out of the tree is the whole fix.
func _exit_tree() -> void:
	_release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release()


func _release() -> void:
	for voice in _voices_3d:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	for voice in _voices_2d:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null


func set_enabled(value: bool) -> void:
	enabled = value
	if value:
		return
	for voice in _voices_3d:
		voice.stop()
	for voice in _voices_2d:
		voice.stop()


## Diagnostics for the autoplay gate and for anyone tuning the mix. `active` is
## the honest test that the pools are bounded: it can never exceed the pool size.
func stats() -> Dictionary:
	var active: int = 0
	for value in _busy_until_3d:
		if value > _clock:
			active += 1
	for value in _busy_until_2d:
		if value > _clock:
			active += 1
	return {
		"voices": _voices_3d.size() + _voices_2d.size(),
		"active": active,
		"plays": _plays,
		"throttled": _dropped,
	}
