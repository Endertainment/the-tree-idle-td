## AudioService — music/SFX playback and bus management (autoload).
##
## Creates the Music, SFX and UI buses at runtime when missing, keeps a single
## music player alive across scene changes, and applies SettingsService volumes.
extends Node

const BUS_MASTER := &"Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const SILENT_DB := -40.0

var _music_player: AudioStreamPlayer
var _initialized: bool = false
var _music_generation: int = 0


func _ready() -> void:
	_ensure_buses()
	_ensure_music_player()


## Connects settings (if not done yet) and applies current volumes.
func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	_ensure_buses()
	_ensure_music_player()
	_apply_settings()
	if not SettingsService.changed.is_connected(_on_setting_changed):
		SettingsService.changed.connect(_on_setting_changed)


## Sets a bus volume from a linear 0..1 value. Mutes at 0, otherwise uses dB.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		push_warning("AudioService: bus '%s' does not exist" % bus)
		return
	var value := clampf(linear, 0.0, 1.0)
	if value <= 0.001:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(value))


## Crossfades to `stream`. Passing null stops the current music.
func play_music(stream: AudioStream, fade: float = 0.8) -> void:
	if stream == null:
		await stop_music(fade)
		return
	_ensure_music_player()
	if _music_player.stream == stream and _music_player.playing:
		return

	_music_generation += 1
	var generation := _music_generation
	_ensure_music_player()

	if _music_player.playing and fade > 0.0:
		var fade_out := create_tween()
		fade_out.tween_property(_music_player, "volume_db", SILENT_DB, fade * 0.5)
		await fade_out.finished
		if generation != _music_generation:
			return

	_music_player.stream = stream
	_music_player.volume_db = SILENT_DB if fade > 0.0 else 0.0
	_music_player.play()

	if fade > 0.0:
		var fade_in := create_tween()
		fade_in.tween_property(_music_player, "volume_db", 0.0, fade * 0.5)


## Fades out and stops the current music.
func stop_music(fade: float = 0.5) -> void:
	_music_generation += 1
	var generation := _music_generation
	_ensure_music_player()
	if not _music_player.playing:
		return
	if fade > 0.0:
		var fade_out := create_tween()
		fade_out.tween_property(_music_player, "volume_db", SILENT_DB, fade)
		await fade_out.finished
		if generation != _music_generation:
			return
	_music_player.stop()
	_music_player.stream = null


## Plays a one-shot sound on the SFX bus with optional pitch variation (±ratio).
func play_sfx(stream: AudioStream, pitch_variation: float = 0.05) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _ensure_buses() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_UI)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, BUS_MASTER)


func _ensure_music_player() -> void:
	if _music_player != null and is_instance_valid(_music_player):
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)


func _apply_settings() -> void:
	set_bus_volume(BUS_MASTER, SettingsService.master_volume)
	set_bus_volume(BUS_MUSIC, SettingsService.music_volume)
	set_bus_volume(BUS_SFX, SettingsService.sfx_volume)
	set_bus_volume(BUS_UI, SettingsService.ui_volume)


func _on_setting_changed(key: StringName) -> void:
	match key:
		&"master":
			set_bus_volume(BUS_MASTER, SettingsService.master_volume)
		&"music":
			set_bus_volume(BUS_MUSIC, SettingsService.music_volume)
		&"sfx":
			set_bus_volume(BUS_SFX, SettingsService.sfx_volume)
		&"ui":
			set_bus_volume(BUS_UI, SettingsService.ui_volume)
