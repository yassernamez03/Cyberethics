# =============================================================================
# MAIN MENU - UI Controller
# =============================================================================
# Handles main menu navigation and buttons
# Path: res://scripts/ui/main_menu.gd
# =============================================================================

extends Control

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var game_scene_path: String = "res://scenes/levels/kenney_city.tscn"

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var continue_button: Button = $VBoxContainer/ContinueButton

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Hide continue button if no save exists
	if has_node("/root/SaveManager"):
		continue_button.visible = SaveManager.has_save(0)
	else:
		continue_button.visible = false
	
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# -----------------------------------------------------------------------------
# BUTTON HANDLERS
# -----------------------------------------------------------------------------
func _on_new_game_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.start_game()
		GameManager.load_scene(game_scene_path)
	else:
		get_tree().change_scene_to_file(game_scene_path)


func _on_continue_pressed() -> void:
	if has_node("/root/SaveManager"):
		SaveManager.load_game(0)
		if has_node("/root/GameManager"):
			GameManager.load_scene(game_scene_path)
		else:
			get_tree().change_scene_to_file(game_scene_path)


func _on_settings_pressed() -> void:
	# TODO: Implement settings menu
	print("Settings pressed - implement settings menu")


func _on_quit_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.quit_game()
	else:
		get_tree().quit()
