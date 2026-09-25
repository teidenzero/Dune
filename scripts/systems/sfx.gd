extends Node
## Sound effects, by slot name: Sfx.play(&"pistol_shot", position).
##
## Slots are files under assets/audio/sfx/<category>/ named after the slot;
## numbered variations (step_sand_1, step_sand_2...) are picked at random, so
## repeated sounds never sound mechanical. A slot with no file plays nothing,
## so a hook can go in before its sound exists.
##
## World sounds play where they happen (positional, fading with distance);
## interface sounds play flat on the UI bus. Loops (an engine, a rumble)
## follow their node until stopped. Autoloaded as `Sfx`.

const ROOT: String = "res://assets/audio/sfx/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
## Players kept ready for one-shots, so a burst of gunfire allocates nothing.
const POOL_SIZE: int = 24
## How far a world sound carries before it is silent, in world units.
const HEARING: float = 2400.0

## The player's choice, kept with the other settings.
var enabled: bool = true
var _library: Dictionary = {}
var _pool: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next: int = 0
var _next_flat: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan(ROOT)
	for index in range(POOL_SIZE):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.bus = _bus(&"SFX")
		player.max_distance = HEARING
		player.attenuation = 1.6
		add_child(player)
		_pool.append(player)
	for index in range(8):
		var flat: AudioStreamPlayer = AudioStreamPlayer.new()
		flat.bus = _bus(&"UI")
		add_child(flat)
		_flat.append(flat)
	var director: SoundDirector = SoundDirector.new()
	director.name = "Director"
	add_child(director)


## Every audio file under the folder, by slot: the file name less any
## trailing _<number>.
func _scan(folder: String) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(folder.path_join(sub))
	for file in dir.get_files():
		# Exported builds list .import/.remap files; the resource keeps its name.
		var name: String = file.trim_suffix(".import").trim_suffix(".remap")
		if not EXTENSIONS.has(name.get_extension()):
			continue
		var slot: String = name.get_basename()
		var parts: PackedStringArray = slot.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			slot = parts[0]
		# worm_rumble_loop.ogg is the worm_rumble slot, made to loop.
		slot = slot.trim_suffix("_loop")
		var path: String = folder.path_join(name)
		var list: Array = _library.get(StringName(slot), [])
		if not list.has(path):
			list.append(path)
		_library[StringName(slot)] = list


func has(slot: StringName) -> bool:
	return _library.has(slot)


func slots() -> Array:
	return _library.keys()


func _stream(slot: StringName) -> AudioStream:
	var list: Array = _library.get(slot, [])
	if list.is_empty():
		return null
	return load(list[randi() % list.size()]) as AudioStream


## A world sound at `at`; without a position it plays flat (interface).
func play(slot: StringName, at: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not enabled:
		return
	var stream: AudioStream = _stream(slot)
	if stream == null:
		return
	var pitch: float = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if not at.is_finite():
		var flat: AudioStreamPlayer = _flat[_next_flat]
		_next_flat = (_next_flat + 1) % _flat.size()
		flat.stream = stream
		flat.volume_db = volume_db
		flat.pitch_scale = pitch
		flat.play()
		return
	var player: AudioStreamPlayer2D = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.global_position = at
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## An interface sound: flat, on the UI bus.
func ui(slot: StringName, volume_db: float = 0.0) -> void:
	play(slot, Vector2.INF, volume_db, 0.02)


## A looping sound carried by `node` (an engine, a rumble), until stop_loop.
## Returns the player, or null when the slot has no sound.
func loop(slot: StringName, node: Node2D, volume_db: float = 0.0) -> AudioStreamPlayer2D:
	if not enabled or not is_instance_valid(node):
		return null
	var stream: AudioStream = _stream(slot)
	if stream == null:
		return null
	_set_looping(stream)
	var player: AudioStreamPlayer2D = node.get_node_or_null("Loop_" + String(slot)) as AudioStreamPlayer2D
	if player == null:
		player = AudioStreamPlayer2D.new()
		player.name = "Loop_" + String(slot)
		player.bus = _bus(&"SFX")
		player.max_distance = HEARING
		player.attenuation = 1.4
		node.add_child(player)
	if player.playing:
		return player
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	return player


func stop_loop(slot: StringName, node: Node) -> void:
	if not is_instance_valid(node):
		return
	var player: AudioStreamPlayer2D = node.get_node_or_null("Loop_" + String(slot)) as AudioStreamPlayer2D
	if player != null:
		player.stop()


static func _set_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)


## The named bus if the layout has it, else Master.
static func _bus(name: StringName) -> StringName:
	return name if AudioServer.get_bus_index(name) >= 0 else &"Master"
