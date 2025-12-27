# =============================================================================
# AUDIO MANAGER - Audio Autoload Singleton
# =============================================================================
# Manages all audio playback including music and sound effects
# Path: res://scripts/autoloads/audio_manager.gd
# =============================================================================

extends Node

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal music_changed(track_name: String)
signal sfx_played(sfx_name: String)

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var music_volume: float = 0.8:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		_update_music_volume()

@export var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clamp(value, 0.0, 1.0)
		_update_sfx_volume()

@export var master_volume: float = 1.0:
	set(value):
		master_volume = clamp(value, 0.0, 1.0)
		_update_master_volume()

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8
var _current_music_track: String = ""

# Audio caches
var _music_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}

# Audio paths
const MUSIC_PATH := "res://assets/audio/music/"
const SFX_PATH := "res://assets/audio/sfx/"

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_setup_audio_buses()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if _current_music_track == track_name:
		return
	
	var stream := _load_music(track_name)
	if stream == null:
		push_warning("[AudioManager] Music not found: " + track_name)
		return
	
	# Crossfade to new track
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
	await tween.finished
	
	_music_player.stream = stream
	_music_player.play()
	_current_music_track = track_name
	
	var fade_in := create_tween()
	fade_in.tween_property(_music_player, "volume_db", linear_to_db(music_volume), fade_duration)
	
	music_changed.emit(track_name)


func stop_music(fade_duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
	await tween.finished
	_music_player.stop()
	_current_music_track = ""


func play_sfx(sfx_name: String, pitch_variation: float = 0.0) -> void:
	var stream := _load_sfx(sfx_name)
	if stream == null:
		push_warning("[AudioManager] SFX not found: " + sfx_name)
		return
	
	var player := _get_available_sfx_player()
	if player == null:
		return
	
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	
	sfx_played.emit(sfx_name)


func play_sfx_at_position(sfx_name: String, position: Vector3) -> void:
	# For 3D positional audio - implement with AudioStreamPlayer3D if needed
	play_sfx(sfx_name)


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _setup_audio_players() -> void:
	# Music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	# SFX pool
	for i in _sfx_pool_size:
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		_sfx_pool.append(sfx_player)


func _setup_audio_buses() -> void:
	# Ensure audio buses exist (create them in Godot Editor: Audio tab)
	pass


func _load_music(track_name: String) -> AudioStream:
	if _music_cache.has(track_name):
		return _music_cache[track_name]
	
	var path := MUSIC_PATH + track_name
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		_music_cache[track_name] = stream
		return stream
	
	return null


func _load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	
	var path := SFX_PATH + sfx_name
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		_sfx_cache[sfx_name] = stream
		return stream
	
	return null


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0] # Fallback: reuse first player


func _update_music_volume() -> void:
	if _music_player:
		_music_player.volume_db = linear_to_db(music_volume * master_volume)


func _update_sfx_volume() -> void:
	for player in _sfx_pool:
		player.volume_db = linear_to_db(sfx_volume * master_volume)


func _update_master_volume() -> void:
	_update_music_volume()
	_update_sfx_volume()
