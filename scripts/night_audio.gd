extends Node

var room: AudioStreamPlayer
var door: AudioStreamPlayer3D
var pulse: AudioStreamPlayer
var sounds: Dictionary = {}
var heartbeat_in := 1.5
var muted := false
var channels: Dictionary = {}
var channel_tweens: Dictionary = {}
var foot: AudioStreamPlayer
var left_foot := true

static func movement_profile(gait: String) -> Dictionary:
	match gait:
		"run": return {"speed": 3.7, "stride": 1.1, "volume": -12.0, "pitch": 1.05}
		"quiet": return {"speed": 0.85, "stride": 0.58, "volume": -29.0, "pitch": 0.93}
	return {"speed": 1.9, "stride": 0.8, "volume": -18.0, "pitch": 1.0}

func _ready() -> void:
	room = AudioStreamPlayer.new()
	room.volume_db = -32
	add_child(room)
	door = AudioStreamPlayer3D.new()
	door.position = Vector3(0, 1.4, -4.5)
	door.max_distance = 20
	door.volume_db = -11
	get_parent().add_child(door)
	pulse = AudioStreamPlayer.new()
	pulse.volume_db = -22
	add_child(pulse)
	foot = AudioStreamPlayer.new()
	foot.volume_db = -29
	add_child(foot)
	for key in ["bell", "knock", "shuffle", "steps_away", "steps_near", "unlock", "death", "hiss", "rustle", "typing"]:
		var channel := AudioStreamPlayer3D.new()
		channel.position = Vector3(0, 1.4, -4.5)
		channel.max_distance = 24
		channel.volume_db = -14
		get_parent().add_child(channel)
		channels[key] = channel
	if DisplayServer.get_name() == "headless":
		return
	for key in ["hum", "bell", "knock", "shuffle", "steps_away", "steps_near", "heart", "unlock", "death", "hiss", "foot", "rustle", "typing"]:
		sounds[key] = synth(key)
	for gait in ["walk", "run", "quiet"]:
		for side in ["left", "right"]:
			var key: String = "foot_%s_%s" % [gait, side]
			sounds[key] = synth_step(gait, side == "left")
	room.stream = sounds.hum
	room.play()

func synth(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var duration := 2.0 if kind in ["hum", "steps_away"] else 1.0
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 1023
	for i in range(count):
		var t := float(i) / rate
		var value := 0.0
		match kind:
			"hum": value = sin(TAU * 60 * t) * 0.23 + sin(TAU * 120 * t) * 0.06 + noise.randf_range(-0.03, 0.03)
			"bell": value = (sin(TAU * (620 if t < 0.35 else 415) * t) + sin(TAU * 1250 * t) * 0.25) * exp(-t * 4) * 0.45
			"knock":
				var hit := fmod(t, 0.3)
				value = (sin(TAU * 95 * hit) + noise.randf_range(-0.2, 0.2)) * exp(-hit * 45) * 0.65
			"shuffle", "hiss", "rustle": value = noise.randf_range(-0.6, 0.6) * sin(PI * t) * (0.3 if kind != "hiss" else 0.12)
			"steps_away", "steps_near":
				var hit := fmod(t, 0.42)
				value = sin(TAU * 75 * hit) * exp(-hit * 28) * (1.0 - t / duration) * 0.5
			"heart": value = sin(TAU * 53 * t) * (exp(-t * 35) + (exp(-(t - 0.18) * 40) * 0.6 if t > 0.18 else 0.0)) * 0.55
			"unlock": value = noise.randf_range(-0.5, 0.5) * exp(-fmod(t, 0.3) * 40) * 0.5
			"foot": value = (sin(TAU * 82 * t) + noise.randf_range(-0.12, 0.12)) * exp(-t * 24) * 0.28
			"typing": value = noise.randf_range(-0.4, 0.4) * exp(-fmod(t, 0.13) * 65) * 0.4
			"death": value = (sin(TAU * (78 + t * 35) * t) * 0.35 + noise.randf_range(-0.25, 0.25)) * (1 - t) * 0.65
		bytes.encode_s16(i * 2, int(clampf(value, -0.95, 0.95) * 22000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if kind == "hum":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func cue(kind: String) -> void:
	if muted or not sounds.has(kind): return
	var channel: AudioStreamPlayer3D = channels.get(kind, door)
	if channel_tweens.has(kind) and is_instance_valid(channel_tweens[kind]): channel_tweens[kind].kill()
	channel.position = Vector3(1.0 if kind == "shuffle" else 0.0, 1.4, -4.5)
	if kind == "typing": channel.position = Vector3(-3.4, 1.0, -3.9)
	channel.stream = sounds[kind]
	channel.play()
	if kind == "steps_away":
		var movement := create_tween()
		movement.tween_property(channel, "position", Vector3(-2, 1.4, -11), 1.8)
		channel_tweens[kind] = movement
	elif kind == "steps_near":
		var movement := create_tween()
		movement.tween_property(channel, "position", Vector3(1.3, 1.4, -4.6), 0.8)
		channel_tweens[kind] = movement

func synth_step(gait: String, left: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.32)
	var bytes := PackedByteArray()
	bytes.resize(count * 4)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7301 + (13 if left else 29)
	var filtered := 0.0
	var gain := 1.5 if gait == "run" else (0.65 if gait == "quiet" else 1.0)
	for i in range(count):
		var t := float(i) / rate
		filtered = filtered * 0.78 + noise.randf_range(-1, 1) * 0.22
		var heel := sin(TAU * (74 if gait == "run" else 92) * t) * exp(-t * 37) * 0.34
		var toe := sin(TAU * 136 * maxf(0, t - 0.065)) * exp(-maxf(0, t - 0.065) * 48) * 0.17 if t >= 0.065 else 0.0
		var value := (heel + toe + filtered * exp(-t * 18) * 0.16) * gain
		bytes.encode_s16(i * 4, int(clampf(value * (0.95 if left else 0.72), -1, 1) * 22000))
		bytes.encode_s16(i * 4 + 2, int(clampf(value * (0.72 if left else 0.95), -1, 1) * 22000))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.stereo = true
	result.mix_rate = rate
	result.data = bytes
	return result

func footstep(gait: String = "walk") -> void:
	var key := "foot_%s_%s" % [gait, "left" if left_foot else "right"]
	if muted or not sounds.has(key): return
	var profile := movement_profile(gait)
	foot.stream = sounds[key]
	foot.volume_db = profile.volume
	foot.pitch_scale = float(profile.pitch) * randf_range(0.975, 1.025)
	foot.play()
	left_foot = not left_foot

func stop_cue(kind: String) -> void:
	if channels.has(kind): channels[kind].stop()

func update(delta: float, anxious: bool) -> void:
	if muted: return
	heartbeat_in -= delta
	if heartbeat_in <= 0 and anxious and sounds.has("heart"):
		pulse.stream = sounds.heart
		pulse.play()
		heartbeat_in = 1.2

func set_muted(value: bool) -> void:
	muted = value
	if is_instance_valid(room): room.volume_db = -80 if muted else -32
	if muted:
		door.stop()
		pulse.stop()
		foot.stop()
		for channel in channels.values(): channel.stop()

func stop_all() -> void:
	for player in [room, door, pulse, foot] + channels.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	stop_all()
	for movement in channel_tweens.values():
		if is_instance_valid(movement): movement.kill()
	for channel in channels.values():
		if is_instance_valid(channel): channel.queue_free()
	if is_instance_valid(door): door.queue_free()
