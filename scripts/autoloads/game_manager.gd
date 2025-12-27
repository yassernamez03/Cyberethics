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
signal score_changed(new_score: int, delta: int)

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
var current_score: int = 0
var correct_decisions: int = 0
var wrong_decisions: int = 0

# Score configuration
const SCORE_CORRECT_DECISION := 100  # Points for avoiding scam
const SCORE_WRONG_DECISION := -50    # Points deducted for falling for scam
const SCORE_BONUS_STREAK := 25       # Bonus per consecutive correct answer

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _current_level: Node = null
var _player_data: Dictionary = {}
var _selected_city_index: int = 0
var _current_streak: int = 0  # Consecutive correct decisions

# City scene paths
const CITY_SCENES := {
	0: "res://scenes/levels/modern_city.tscn",  # Modern Commercial City
	1: "res://scenes/levels/kenney_city.tscn",  # Industrial City
}

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
# CITY SELECTION METHODS
# -----------------------------------------------------------------------------
func get_selected_city_index() -> int:
	return _selected_city_index


func set_selected_city_index(index: int) -> void:
	_selected_city_index = index
	print("[GameManager] City set to index: ", index)


func get_selected_city_path() -> String:
	return CITY_SCENES.get(_selected_city_index, CITY_SCENES[0])


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _initialize_game() -> void:
	# Initialize any game systems here
	reset_score()
	print("[GameManager] Initialized")


# -----------------------------------------------------------------------------
# SCORE METHODS
# -----------------------------------------------------------------------------
func add_score(amount: int) -> void:
	"""Add or subtract score and emit signal."""
	current_score += amount
	current_score = max(0, current_score)  # Don't go below 0
	score_changed.emit(current_score, amount)
	print("[GameManager] Score: %d (%+d)" % [current_score, amount])


func record_decision(was_correct: bool) -> void:
	"""Record a phishing decision and update score accordingly."""
	if was_correct:
		correct_decisions += 1
		_current_streak += 1
		var bonus = SCORE_BONUS_STREAK * (_current_streak - 1)
		add_score(SCORE_CORRECT_DECISION + bonus)
		print("[GameManager] ✅ Correct! Streak: %d, Bonus: +%d" % [_current_streak, bonus])
	else:
		wrong_decisions += 1
		_current_streak = 0  # Reset streak
		add_score(SCORE_WRONG_DECISION)
		print("[GameManager] ❌ Wrong! Streak reset.")


func reset_score() -> void:
	"""Reset all score data."""
	current_score = 0
	correct_decisions = 0
	wrong_decisions = 0
	_current_streak = 0
	score_changed.emit(current_score, 0)


func get_score_stats() -> Dictionary:
	"""Get detailed score statistics."""
	return {
		"score": current_score,
		"correct": correct_decisions,
		"wrong": wrong_decisions,
		"streak": _current_streak,
		"accuracy": float(correct_decisions) / max(1, correct_decisions + wrong_decisions) * 100
	}
