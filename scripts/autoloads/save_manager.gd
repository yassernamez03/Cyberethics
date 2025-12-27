# =============================================================================
# SAVE MANAGER - Save/Load Autoload Singleton
# =============================================================================
# Handles game save/load operations with encryption support
# Path: res://scripts/autoloads/save_manager.gd
# =============================================================================

extends Node

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal save_completed(success: bool)
signal load_completed(success: bool)

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------
const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".sav"
const CONFIG_FILE := "user://settings.cfg"
const ENCRYPTION_KEY := "your_secret_key_here" # Change this!

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var current_save_slot: int = 0

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _settings: ConfigFile

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	_ensure_save_directory()
	_settings = ConfigFile.new()
	load_settings()


# -----------------------------------------------------------------------------
# PUBLIC METHODS - Game Saves
# -----------------------------------------------------------------------------
func save_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_save_slot
	
	var save_data := _collect_save_data()
	var file_path := _get_save_path(slot)
	
	var file := FileAccess.open_encrypted_with_pass(
		file_path,
		FileAccess.WRITE,
		ENCRYPTION_KEY
	)
	
	if file == null:
		# Fallback to unencrypted for debugging
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_error("[SaveManager] Failed to create save file: " + str(FileAccess.get_open_error()))
			save_completed.emit(false)
			return false
	
	file.store_var(save_data)
	file.close()
	
	print("[SaveManager] Game saved to slot ", slot)
	save_completed.emit(true)
	return true


func load_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_save_slot
	
	var file_path := _get_save_path(slot)
	
	if not FileAccess.file_exists(file_path):
		push_warning("[SaveManager] Save file not found: " + file_path)
		load_completed.emit(false)
		return false
	
	var file := FileAccess.open_encrypted_with_pass(
		file_path,
		FileAccess.READ,
		ENCRYPTION_KEY
	)
	
	if file == null:
		# Try unencrypted
		file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_error("[SaveManager] Failed to open save file")
			load_completed.emit(false)
			return false
	
	var save_data: Dictionary = file.get_var()
	file.close()
	
	_apply_save_data(save_data)
	current_save_slot = slot
	
	print("[SaveManager] Game loaded from slot ", slot)
	load_completed.emit(true)
	return true


func delete_save(slot: int) -> bool:
	var file_path := _get_save_path(slot)
	
	if FileAccess.file_exists(file_path):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove(file_path)
			print("[SaveManager] Deleted save slot ", slot)
			return true
	
	return false


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))


func get_save_info(slot: int) -> Dictionary:
	"""Returns metadata about a save slot without fully loading it."""
	var file_path := _get_save_path(slot)
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file := FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, ENCRYPTION_KEY)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		return {}
	
	var save_data: Dictionary = file.get_var()
	file.close()
	
	return {
		"slot": slot,
		"timestamp": save_data.get("timestamp", 0),
		"playtime": save_data.get("playtime", 0),
		"level": save_data.get("current_level", "Unknown"),
	}


# -----------------------------------------------------------------------------
# PUBLIC METHODS - Settings
# -----------------------------------------------------------------------------
func save_settings() -> void:
	_settings.save(CONFIG_FILE)
	print("[SaveManager] Settings saved")


func load_settings() -> void:
	if FileAccess.file_exists(CONFIG_FILE):
		_settings.load(CONFIG_FILE)
		print("[SaveManager] Settings loaded")


func set_setting(section: String, key: String, value: Variant) -> void:
	_settings.set_value(section, key, value)


func get_setting(section: String, key: String, default: Variant = null) -> Variant:
	return _settings.get_value(section, key, default)


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _ensure_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)


func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_" + str(slot) + SAVE_EXTENSION


func _collect_save_data() -> Dictionary:
	"""Collect all data that needs to be saved."""
	return {
		"version": ProjectSettings.get_setting("application/config/version", "1.0"),
		"timestamp": Time.get_unix_time_from_system(),
		"playtime": 0, # Track this in GameManager
		"current_level": "", # Get from GameManager
		"player_data": GameManager.get_player_data() if has_node("/root/GameManager") else {},
		# Add more save data here
	}


func _apply_save_data(data: Dictionary) -> void:
	"""Apply loaded save data to the game."""
	if has_node("/root/GameManager"):
		for key in data.get("player_data", {}).keys():
			GameManager.set_player_data(key, data.player_data[key])
	
	# Apply more save data here
