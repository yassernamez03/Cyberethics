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
@export var default_scene_path: String = "res://scenes/levels/modern_city.tscn"

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var settings_menu: Control = $SettingsMenu

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Hide continue button if no save exists
	if has_node("/root/SaveManager"):
		continue_button.visible = SaveManager.has_save(0)
	else:
		continue_button.visible = false
	
	# Hide settings menu initially
	if settings_menu:
		settings_menu.hide()
		settings_menu.settings_closed.connect(_on_settings_closed)
	
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _get_game_scene_path() -> String:
	if has_node("/root/GameManager"):
		return GameManager.get_selected_city_path()
	return default_scene_path


# -----------------------------------------------------------------------------
# BUTTON HANDLERS
# -----------------------------------------------------------------------------
func _on_new_game_pressed() -> void:
	var scene_path = _get_game_scene_path()
	print("Starting game with city: ", scene_path)
	
	if has_node("/root/GameManager"):
		GameManager.start_game()
		GameManager.load_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _on_continue_pressed() -> void:
	var scene_path = _get_game_scene_path()
	
	if has_node("/root/SaveManager"):
		SaveManager.load_game(0)
		if has_node("/root/GameManager"):
			GameManager.load_scene(scene_path)
		else:
			get_tree().change_scene_to_file(scene_path)


func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.show()
	else:
		print("Settings menu not found!")


func _on_settings_closed() -> void:
	# Settings menu closed, refresh any UI if needed
	pass


func _on_quit_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.quit_game()
	else:
		get_tree().quit()
