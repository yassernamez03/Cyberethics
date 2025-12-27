# =============================================================================
# GAME MANAGER - Main Autoload Singleton
# =============================================================================
# Manages game state, scene transitions, and core game logic
# Path: res://scripts/autoloads/game_manager.gd
# =============================================================================

extends Node

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal game_state_changed(new_state: GameState)
signal scene_transition_started
signal scene_transition_completed
signal game_paused(is_paused: bool)

# -----------------------------------------------------------------------------
# ENUMS
# -----------------------------------------------------------------------------
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	CUTSCENE,
	LOADING,
	GAME_OVER
}

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var initial_scene: PackedScene
@export var transition_duration: float = 0.5

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var current_state: GameState = GameState.MAIN_MENU
var is_paused: bool = false

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _current_level: Node = null
var _player_data: Dictionary = {}

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_game()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and current_state == GameState.PLAYING:
		toggle_pause()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func start_game() -> void:
	change_state(GameState.PLAYING)


func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		change_state(GameState.PAUSED)
	else:
		change_state(GameState.PLAYING)
	
	game_paused.emit(is_paused)


func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	game_state_changed.emit(new_state)


func load_scene(scene_path: String) -> void:
	change_state(GameState.LOADING)
	scene_transition_started.emit()
	
	# Simple scene loading - extend with loading screen if needed
	await get_tree().create_timer(transition_duration).timeout
	get_tree().change_scene_to_file(scene_path)
	
	scene_transition_completed.emit()


func quit_game() -> void:
	# Save game data here if needed
	get_tree().quit()


func get_player_data() -> Dictionary:
	return _player_data.duplicate()


func set_player_data(key: String, value: Variant) -> void:
	_player_data[key] = value


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _initialize_game() -> void:
	# Initialize any game systems here
	print("[GameManager] Initialized")
