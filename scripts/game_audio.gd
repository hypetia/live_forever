class_name GameAudio
extends Node
## Small original synthesized sounds; no external audio assets or service.

var persistent := true
var enabled := true
var ambience := false
var volume := 0.5
var fullscreen := false
var effects: AudioStreamPlayer
var wind: AudioStreamPlayer
var music: AudioStreamPlayer
var sounds: Dictionary = {}
var _last_cue := 0
var settings_path := SETTINGS_PATH
static var sound_bank: Dictionary = {}
static var users := 0
const SETTINGS_PATH := "user://preferences.cfg"


func _ready() -> void:
	users += 1
	if persistent:
		var config := ConfigFile.new()
		if config.load(settings_path) == OK:
			var setting: Variant = config.get_value("audio", "effects", true)
			if setting is bool: enabled = setting
			setting = config.get_value("audio", "ambience", false)
			if setting is bool: ambience = setting
			setting = config.get_value("audio", "volume", 0.5)
			if (setting is int or setting is float) and is_finite(float(setting)): volume = clampf(float(setting), 0, 1)
			setting = config.get_value("display", "fullscreen", false)
			if setting is bool: fullscreen = setting
	effects = AudioStreamPlayer.new()
	add_child(effects)
	wind = AudioStreamPlayer.new()
	add_child(wind)
	music = AudioStreamPlayer.new()
	add_child(music)
	if sound_bank.is_empty():
		for kind in ["work", "danger", "return", "notice", "hit", "push", "miss", "blocked", "shot"]: sound_bank[kind] = _tone(kind)
		sound_bank["wind"] = _wind()
	sounds = sound_bank
	wind.stream = sound_bank["wind"]
	apply_preferences(false)
	if fullscreen and DisplayServer.get_name() != "headless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func apply_preferences(save: bool = true) -> void:
	if not enabled and is_instance_valid(effects): effects.stop()
	if not enabled and is_instance_valid(music): music.stop()
	if is_instance_valid(music): music.volume_db = linear_to_db(maxf(volume * 0.25, 0.0001))
	if is_instance_valid(effects): effects.volume_db = linear_to_db(maxf(volume * 0.38, 0.0001))
	if is_instance_valid(wind):
		wind.volume_db = linear_to_db(maxf(volume * 0.18, 0.0001))
		if ambience and DisplayServer.get_name() != "headless":
			if not wind.playing: wind.play()
		else: wind.stop()
	if save and persistent:
		var config := ConfigFile.new()
		config.set_value("audio", "effects", enabled)
		config.set_value("audio", "ambience", ambience)
		config.set_value("audio", "volume", volume)
		config.set_value("display", "fullscreen", fullscreen)
		var error := config.save(settings_path)
		if error != OK: push_warning("偏好设置未能保存；本次运行设置仍有效。")


func cue(message: String) -> void:
	if DisplayServer.get_name() == "headless" or not enabled or not is_instance_valid(effects) or Time.get_ticks_msec() - _last_cue < 180: return
	var kind := "danger" if "死亡" in message or "发现" in message or "咬" in message else "return" if "归来" in message else "work" if "完成" in message else "notice"
	effects.stream = sounds[kind]
	effects.play()
	_last_cue = Time.get_ticks_msec()


func _tone(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.32 if kind == "return" else 0.16
	var bytes := PackedByteArray()
	bytes.resize(int(rate * seconds) * 2)
	for sample in range(bytes.size() / 2):
		var t := float(sample) / rate
		var frequency := 220.0 if kind == "danger" else 440.0 if kind == "notice" else 554.37 if kind == "work" else 659.25
		var envelope := sin(PI * t / seconds) * exp(-t * 8)
		var value := (sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2 * t)) * envelope * 0.35
		if kind in ["hit", "push", "miss", "blocked", "shot"]:
			var pitch := 65.0 if kind == "shot" else 115.0 if kind == "hit" else 165.0 if kind == "push" else 390.0 if kind == "miss" else 90.0
			value = sin(TAU * (pitch * t - 160 * t * t)) * exp(-t * 32) * 0.5 * minf(t * 700, 1)
		bytes.encode_s16(sample * 2, int(value * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound


func _wind() -> AudioStreamWAV:
	var rate := 22050
	var bytes := PackedByteArray()
	bytes.resize(rate * 4 * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73041
	var filtered := 0.0
	for sample in range(rate * 4):
		filtered = filtered * 0.97 + rng.randf_range(-1, 1) * 0.03
		var t := float(sample) / rate
		var fade := minf(1, minf(t * 4, (4 - t) * 4))
		bytes.encode_s16(sample * 2, int(filtered * (0.5 + 0.3 * sin(t * TAU / 4)) * fade * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = rate * 4
	return sound


func stop_audio() -> void:
	for player in [effects, wind, music]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_audio()
	users -= 1
	if users == 0: sound_bank.clear()


func combat_cue(kind: String) -> void:
	if DisplayServer.get_name() == "headless" or not enabled or not is_instance_valid(effects): return
	effects.stream = sounds.get(kind, sounds["notice"])
	effects.play()
	_last_cue = Time.get_ticks_msec()


func sync_music(performing: bool) -> void:
	if not is_instance_valid(music): return
	if not performing or not enabled or DisplayServer.get_name() == "headless":
		music.stop()
		return
	if music.playing: return
	if not sound_bank.has("guitar"): sound_bank["guitar"] = _plucked_phrase()
	music.stream = sound_bank["guitar"]
	music.play()


func _plucked_phrase() -> AudioStreamWAV:
	# Original synthesized arpeggio; no recording from another game.
	var rate := 22050
	var pitches := [164.81,246.94,329.63,196.0,146.83,220.0,293.66,196.0]
	var bytes := PackedByteArray()
	bytes.resize(int(rate * 6.4) * 2)
	for sample in range(bytes.size()/2):
		var time := float(sample)/rate
		var note := mini(7,int(time/0.8))
		var age := fmod(time,0.8)
		var hz: float = pitches[note]
		var envelope := minf(1,age*180) * exp(-age*6.5)
		var value := (sin(TAU*hz*age)+0.3*sin(TAU*hz*2*age)+0.13*sin(TAU*hz*3*age))*envelope*0.35
		bytes.encode_s16(sample*2,int(value*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = bytes.size()/2
	return sound
