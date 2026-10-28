class_name MotionPlayback
extends RefCounted
## Presentation only: measured travel drives feet, never simulation or hit tests.
var initialized := false
var previous := Vector2.ZERO
var phase := 0.0
var weight := 0.0
var velocity := 0.0
var turn := 0.0
var last_direction := 1.0
var action_beat := -1
var action_kind := ""

func reset() -> void:
	initialized = false
	phase = 0
	weight = 0
	velocity = 0
	turn = 0
	action_beat = -1
	action_kind = ""

func sample(at: Vector2, delta: float, direction: float) -> Dictionary:
	var step := false
	if not initialized:
		previous = at
		last_direction = direction
		initialized = true
	if delta <= 0: return snapshot(false)
	var travel := at - previous
	previous = at
	# Loading, spawning and changing floors must not become a running stride.
	if travel.length() > 90 or delta > .5:
		weight = 0
		velocity = 0
		return snapshot(false)
	var pace := absf(travel.x) / delta
	var old_phase := phase
	phase += absf(travel.x) * TAU / 94.0
	step = floori(phase / PI) > floori(old_phase / PI) and pace > 8
	weight = move_toward(weight, clampf(pace / 115.0, 0, 1), delta * 9)
	velocity = lerpf(velocity, travel.x / delta, 1 - exp(-delta * 14))
	turn = move_toward(turn, 0, delta * 6)
	if direction != last_direction and pace > 8:
		turn = 1
	last_direction = direction
	return snapshot(step)

func snapshot(step: bool = false) -> Dictionary:
	return {"phase":phase,"weight":weight,"velocity":velocity,"turn":turn,"step":step}

func action_sound(mode: String, time: float, progress: float = 1.0) -> String:
	var cue := ("chop" if progress<.28 else "cook") if mode == "cook" else "search" if mode == "search" else "door" if mode in ["door","window"] else "hammer" if mode in ["build","repair","craft"] else ""
	var beat := floori(time / (.85 if mode == "cook" else .65))
	if mode != action_kind:
		action_kind = mode
		action_beat = beat
		return ""
	if beat == action_beat: return ""
	action_beat = beat
	return cue
