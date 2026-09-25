extends Node
## Session-wide debug display preference; gameplay stays in its own scenes.

signal debug_visibility_changed(is_visible: bool)

## Step id the tutorial resumes at after a reload. Session-only; there is no
## save-game persistence.
var tutorial_checkpoint: StringName = &""
## The squad scope seen isometrically (Syndicate style); false keeps the top-down view.
var squad_iso: bool = true

## Same idea for missions: the phase a restart resumes from.
var mission_checkpoint: StringName = &""

## Resources, faction standings and Harkonnen heat between missions.
## Session-only until the campaign loop brings a save game.
var campaign: CampaignState = CampaignState.new()

## Where a mission's "leave" goes back to: the Council when it was launched
## from there, the developer launcher otherwise.
var return_scene: String = ""
## Set by whatever launches a mission on purpose (the story, the launcher, the
## map room); the mission shows its briefing once and clears it. A retry
## reloads without it, so a failed attempt goes straight back in.
var pending_briefing: bool = false

## The campaign's chapters as the player walks them (menu -> intro -> prologue
## -> missions). Session-only for now.
var flow: CampaignFlow = CampaignFlow.new()

## The strategic map, once a campaign has reached it. Session-only for now.
var strategy: StrategicState = null
## The Council opened for one operation (a mission path), and where it goes
## back to afterwards - the map room.
var council_focus: String = ""
var council_home: String = ""

var debug_visible: bool = false:
	set(value):
		if debug_visible == value:
			return
		debug_visible = value
		debug_visibility_changed.emit(debug_visible)


# --------------------------------------------------------------------------
# Music: one player that outlives scene changes
# --------------------------------------------------------------------------

## The title screen and the story pages.
const THEME_MUSIC: String = "res://assets/audio/music/suspended_pressure.mp3"
const MUSIC_VOLUME_DB: float = -6.0

const SETTINGS_PATH: String = "user://settings.cfg"

## The player's choice, kept between sessions.
var music_enabled: bool = true:
	set(value):
		music_enabled = value
		_save_settings()
		if not value and _music != null:
			if _music_fade != null:
				_music_fade.kill()
			_music.stop()
			_music_path = ""

var _music: AudioStreamPlayer
var _music_path: String = ""
var _music_fade: Tween


func _ensure_music_player() -> void:
	if _music != null:
		return
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(&"Music") >= 0:
		_music.bus = &"Music"
	add_child(_music)


## Play a track, looping. The same track already playing simply carries on,
## so the music runs unbroken from the menu through the story pages.
func play_music(path: String = THEME_MUSIC, fade_in: float = 1.5) -> void:
	if not music_enabled:
		return
	_ensure_music_player()
	if _music_path == path and _music.playing:
		if _music_fade != null:
			_music_fade.kill()
		_music.volume_db = MUSIC_VOLUME_DB
		return
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_path = path
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	if _music_fade != null:
		_music_fade.kill()
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, fade_in)


func stop_music(fade_out: float = 1.2) -> void:
	if _music == null or not _music.playing:
		return
	if _music_fade != null:
		_music_fade.kill()
	# The fade runs even while the world waits (a briefing is up).
	_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_fade.tween_property(_music, "volume_db", -40.0, fade_out)
	_music_fade.tween_callback(func() -> void:
		_music.stop()
		_music_path = "")


func _ready() -> void:
	# Escape in play: resume, settings, main menu, quit.
	var pause_menu: PauseMenu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		music_enabled = settings.get_value("audio", "music", true)
		# Fullscreen by default (project setting); F11 is remembered.
		if settings.has_section_key("display", "fullscreen") and DisplayServer.get_name() != "headless":
			_apply_fullscreen(bool(settings.get_value("display", "fullscreen")))


## F11, kept between sessions.
func set_fullscreen(value: bool) -> void:
	_apply_fullscreen(value)
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("display", "fullscreen", value)
	settings.save(SETTINGS_PATH)


func _apply_fullscreen(value: bool) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if value else Window.MODE_WINDOWED


func _save_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", "music", music_enabled)
	settings.save(SETTINGS_PATH)


func music_playing() -> String:
	return _music_path if _music != null and _music.playing else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		var window: Window = get_window()
		var fullscreen: bool = window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()
