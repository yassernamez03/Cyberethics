# =============================================================================
# PAUSE MENU - UI Controller
# =============================================================================
# Handles pause menu functionality and in-game exit
# Path: res://scripts/ui/pause_menu.gd
# =============================================================================

extends Control

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var main_menu_path: String = "res://scenes/ui/main_menu.tscn"

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Ensure pause menu starts hidden
	hide()
	# Make sure mouse is visible when pause menu is shown
	visibility_changed.connect(_on_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	# Toggle pause menu with ESC key
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# PAUSE METHODS
# -----------------------------------------------------------------------------
func toggle_pause() -> void:
	"""Toggle pause state."""
	if visible:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	"""Pause the game and show menu."""
	show()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func resume_game() -> void:
	"""Resume the game and hide menu."""
	hide()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# -----------------------------------------------------------------------------
# BUTTON HANDLERS
# -----------------------------------------------------------------------------
func _on_resume_pressed() -> void:
	resume_game()


func _on_settings_pressed() -> void:
	# TODO: Implement settings menu
	print("Settings pressed - implement settings menu")


func _on_main_menu_pressed() -> void:
	"""Return to main menu."""
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if has_node("/root/GameManager"):
		GameManager.load_scene(main_menu_path)
	else:
		get_tree().change_scene_to_file(main_menu_path)


func _on_exit_pressed() -> void:
	"""Exit the game completely."""
	get_tree().paused = false
	if has_node("/root/GameManager"):
		GameManager.quit_game()
	else:
		get_tree().quit()


# -----------------------------------------------------------------------------
# SIGNAL HANDLERS
# -----------------------------------------------------------------------------
func _on_visibility_changed() -> void:
	"""Handle visibility changes."""
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
