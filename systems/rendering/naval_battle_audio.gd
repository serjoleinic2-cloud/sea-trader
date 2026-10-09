extends RefCounted

## Positional sound with a fixed voice budget; shares the game's master volume.
const LIMIT: int = 12
var _voices: Array[AudioStreamPlayer3D] = []
var _streams: Dictionary = {}

func play(world: Node3D, event: String, at: Vector3) -> void:
	if not is_instance_valid(world) or DisplayServer.get_name()=="headless": return
	for index in range(_voices.size()-1,-1,-1):
		if not is_instance_valid(_voices[index]): _voices.remove_at(index)
	if _voices.size()>=LIMIT:
		var oldest: AudioStreamPlayer3D = _voices.pop_front()
		if is_instance_valid(oldest): oldest.queue_free()
	if not _streams.has(event):
		_streams[event] = load("res://assets/audio/naval/"+event+".ogg") as AudioStream
	if _streams[event]==null: return
	if AudioServer.get_bus_index("NavalBattle")<0:
		var index: int = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index,"NavalBattle")
		AudioServer.set_bus_send(index,"Master")
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db=-6.0
		limiter.ceiling_db=-1.0
		AudioServer.add_bus_effect(index,limiter)
	var voice := AudioStreamPlayer3D.new()
	voice.bus="NavalBattle"
	voice.stream = _streams[event]
	voice.position = at
	voice.unit_size = 14.0
	voice.max_distance = 120.0
	voice.max_db = -6.0
	voice.volume_db = -9.0 if event=="cannon_fire" else -13.0
	voice.pitch_scale = randf_range(.94,1.05)
	voice.finished.connect(voice.queue_free)
	world.add_child(voice)
	_voices.append(voice)
	voice.play()
