# =============================================================================
# TTS MANAGER - Text-to-Speech using Groq API
# =============================================================================
# Manages text-to-speech for NPC dialogues using Groq TTS API
# Path: res://scripts/autoloads/tts_manager.gd
# =============================================================================

extends Node

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal tts_started(text: String)
signal tts_finished
signal tts_error(error_message: String)

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------
const GROQ_TTS_URL := "https://api.groq.com/openai/v1/audio/speech"
const AUDIO_CACHE_DIR := "user://tts_cache/"
const TTS_MODEL := "playai-tts-arabic"  # Arabic TTS model

# Available Groq PlayAI Arabic voices
enum Voice {
	KHALID,
	ARABIC_DEFAULT
}

const VOICE_NAMES := {
	Voice.KHALID: "Khalid-PlayAI",
	Voice.ARABIC_DEFAULT: "Khalid-PlayAI"
}

# NPC voice mapping - all using Khalid Arabic voice
const NPC_VOICES := {
	"Cyber Expert": Voice.KHALID,
	"Security Expert": Voice.KHALID,
	"Privacy Expert": Voice.KHALID,
	"Tech Expert": Voice.KHALID,
	"Network Expert": Voice.KHALID,
	"default": Voice.KHALID
}

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var api_key: String = ""  # Set via environment variable GROQ_API_KEY
@export var default_voice: Voice = Voice.KHALID
@export var speech_speed: float = 1.0
@export var enable_caching: bool = true
@export var tts_enabled: bool = true

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _http_request: HTTPRequest
var _audio_player: AudioStreamPlayer
var _current_text: String = ""
var _is_speaking: bool = false
var _audio_cache: Dictionary = {}
var _pending_requests: Array[Dictionary] = []

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_http_request()
	_setup_audio_player()
	_ensure_cache_directory()
	_load_api_key()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func speak(text: String, speaker_name: String = "default", on_complete: Callable = Callable()) -> void:
	"""Convert text to speech and play it."""
	if not tts_enabled or text.is_empty():
		if on_complete.is_valid():
			on_complete.call()
		return
	
	if api_key.is_empty():
		push_warning("[TTSManager] No API key set! Set GROQ_API_KEY environment variable or api_key property.")
		tts_error.emit("No API key configured")
		if on_complete.is_valid():
			on_complete.call()
		return
	
	# Queue the request
	_pending_requests.append({
		"text": text,
		"speaker": speaker_name,
		"callback": on_complete
	})
	
	# Process if not currently speaking
	if not _is_speaking:
		_process_next_request()


func stop_speaking() -> void:
	"""Stop current speech playback."""
	if _audio_player and _audio_player.playing:
		_audio_player.stop()
	_is_speaking = false
	_pending_requests.clear()
	tts_finished.emit()


func is_speaking() -> bool:
	"""Check if TTS is currently playing."""
	return _is_speaking


func set_api_key(key: String) -> void:
	"""Set the Groq API key."""
	api_key = key


func get_voice_for_speaker(speaker_name: String) -> Voice:
	"""Get the voice assigned to a speaker."""
	if NPC_VOICES.has(speaker_name):
		return NPC_VOICES[speaker_name]
	return NPC_VOICES.get("default", default_voice)


func clear_cache() -> void:
	"""Clear the TTS audio cache."""
	_audio_cache.clear()
	var dir = DirAccess.open(AUDIO_CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _setup_http_request() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 30.0
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)


func _setup_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "SFX"
	_audio_player.finished.connect(_on_audio_finished)
	add_child(_audio_player)


func _ensure_cache_directory() -> void:
	if not DirAccess.dir_exists_absolute(AUDIO_CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(AUDIO_CACHE_DIR)


func _load_api_key() -> void:
	# Try to load from environment variable first
	if OS.has_environment("GROQ_API_KEY"):
		api_key = OS.get_environment("GROQ_API_KEY")
		print("[TTSManager] API key loaded from environment")
		return
	
	# Try to load from a config file
	var config_path := "user://groq_config.cfg"
	if FileAccess.file_exists(config_path):
		var config := ConfigFile.new()
		if config.load(config_path) == OK:
			api_key = config.get_value("groq", "api_key", "")
			if not api_key.is_empty():
				print("[TTSManager] API key loaded from config file")
				return
	
	# Try to load from project settings
	if ProjectSettings.has_setting("groq/api_key"):
		api_key = ProjectSettings.get_setting("groq/api_key")
		print("[TTSManager] API key loaded from project settings")


func _process_next_request() -> void:
	if _pending_requests.is_empty():
		_is_speaking = false
		return
	
	var request = _pending_requests.pop_front()
	_current_text = request.text
	var speaker = request.speaker
	var callback = request.callback
	
	_is_speaking = true
	tts_started.emit(_current_text)
	
	# Check cache first
	var cache_key = _get_cache_key(_current_text, speaker)
	if enable_caching and _audio_cache.has(cache_key):
		_play_cached_audio(cache_key, callback)
		return
	
	# Check file cache
	var cache_file = AUDIO_CACHE_DIR + cache_key + ".mp3"
	if enable_caching and FileAccess.file_exists(cache_file):
		_load_and_play_cached_file(cache_file, cache_key, callback)
		return
	
	# Make API request
	_request_tts(_current_text, speaker, callback)


func _get_cache_key(text: String, speaker: String) -> String:
	"""Generate a cache key from text and speaker."""
	return str(text.hash()) + "_" + speaker.replace(" ", "_")


func _request_tts(text: String, speaker: String, callback: Callable) -> void:
	"""Make TTS API request to Groq."""
	var voice = get_voice_for_speaker(speaker)
	var voice_name = VOICE_NAMES[voice]
	
	var body := {
		"model": TTS_MODEL,
		"input": text,
		"voice": voice_name,
		"response_format": "mp3",
		"speed": speech_speed
	}
	
	var headers := [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var json_body := JSON.stringify(body)
	
	print("[TTSManager] Requesting TTS for: ", text.substr(0, 50), "...")
	
	# Store callback for later
	_http_request.set_meta("callback", callback)
	_http_request.set_meta("cache_key", _get_cache_key(text, speaker))
	
	var error = _http_request.request(GROQ_TTS_URL, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("[TTSManager] HTTP request failed: ", error)
		tts_error.emit("HTTP request failed")
		_on_audio_finished()


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var callback: Callable = _http_request.get_meta("callback", Callable())
	var cache_key: String = _http_request.get_meta("cache_key", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[TTSManager] Request failed with result: ", result)
		tts_error.emit("Request failed: " + str(result))
		_finish_speaking(callback)
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		push_error("[TTSManager] API error (", response_code, "): ", error_text)
		tts_error.emit("API error: " + str(response_code))
		_finish_speaking(callback)
		return
	
	# Save to cache
	if enable_caching and not cache_key.is_empty():
		var cache_file = AUDIO_CACHE_DIR + cache_key + ".mp3"
		var file = FileAccess.open(cache_file, FileAccess.WRITE)
		if file:
			file.store_buffer(body)
			file.close()
			print("[TTSManager] Cached audio to: ", cache_file)
	
	# Play the audio
	_play_audio_from_buffer(body, callback)


func _play_audio_from_buffer(buffer: PackedByteArray, callback: Callable) -> void:
	"""Play audio from raw MP3 buffer."""
	var stream := AudioStreamMP3.new()
	stream.data = buffer
	
	_audio_player.stream = stream
	_audio_player.play()
	
	# Store callback
	_audio_player.set_meta("callback", callback)


func _play_cached_audio(cache_key: String, callback: Callable) -> void:
	"""Play audio from memory cache."""
	if _audio_cache.has(cache_key):
		var stream = _audio_cache[cache_key]
		_audio_player.stream = stream
		_audio_player.play()
		_audio_player.set_meta("callback", callback)
		print("[TTSManager] Playing from memory cache")


func _load_and_play_cached_file(file_path: String, cache_key: String, callback: Callable) -> void:
	"""Load and play audio from file cache."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var buffer = file.get_buffer(file.get_length())
		file.close()
		
		var stream := AudioStreamMP3.new()
		stream.data = buffer
		
		# Store in memory cache
		if enable_caching:
			_audio_cache[cache_key] = stream
		
		_audio_player.stream = stream
		_audio_player.play()
		_audio_player.set_meta("callback", callback)
		print("[TTSManager] Playing from file cache: ", file_path)
	else:
		# Cache file corrupted, request new
		_request_tts(_current_text, "default", callback)


func _on_audio_finished() -> void:
	var callback: Callable = _audio_player.get_meta("callback", Callable())
	_finish_speaking(callback)


func _finish_speaking(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()
	
	# Process next in queue
	if _pending_requests.is_empty():
		_is_speaking = false
		tts_finished.emit()
	else:
		_process_next_request()


# -----------------------------------------------------------------------------
# SAVE API KEY HELPER
# -----------------------------------------------------------------------------
func save_api_key(key: String) -> void:
	"""Save API key to config file for persistence."""
	api_key = key
	var config := ConfigFile.new()
	config.set_value("groq", "api_key", key)
	config.save("user://groq_config.cfg")
	print("[TTSManager] API key saved to config")
