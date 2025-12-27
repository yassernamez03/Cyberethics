# =============================================================================
# SETTINGS MENU - UI Controller
# =============================================================================
# Handles settings menu including city selection and TTS settings
# Path: res://scripts/ui/settings_menu.gd
# =============================================================================

extends Control

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal settings_closed
signal city_changed(city_path: String)

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------
const CITY_SCENES := {
	0: "res://scenes/levels/modern_city.tscn",  # Modern Commercial City
	1: "res://scenes/levels/kenney_city.tscn",  # Industrial City
}

const CITY_NAMES := {
	0: "Modern Commercial City",
	1: "Industrial City",
}

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var city_option: OptionButton = $VBoxContainer/CitySection/CityOptionButton
@onready var tts_toggle: CheckButton = $VBoxContainer/TTSSection/TTSToggle if has_node("VBoxContainer/TTSSection/TTSToggle") else null

# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------
var selected_city_index: int = 0
var tts_enabled: bool = true

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Load saved city preference
	if has_node("/root/GameManager"):
		selected_city_index = GameManager.get_selected_city_index()
		city_option.selected = selected_city_index
	
	# Load TTS setting
	if has_node("/root/TTSManager"):
		tts_enabled = TTSManager.tts_enabled
		if tts_toggle:
			tts_toggle.button_pressed = tts_enabled


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func get_selected_city_path() -> String:
	return CITY_SCENES.get(selected_city_index, CITY_SCENES[0])


# -----------------------------------------------------------------------------
# BUTTON HANDLERS
# -----------------------------------------------------------------------------
func _on_city_option_selected(index: int) -> void:
	selected_city_index = index
	print("City selected: ", CITY_NAMES.get(index, "Unknown"))


func _on_tts_toggle_toggled(toggled_on: bool) -> void:
	tts_enabled = toggled_on
	if has_node("/root/TTSManager"):
		TTSManager.tts_enabled = toggled_on
	print("TTS enabled: ", toggled_on)


func _on_apply_pressed() -> void:
	# Save settings
	if has_node("/root/GameManager"):
		GameManager.set_selected_city_index(selected_city_index)
	
	# Apply TTS setting
	if has_node("/root/TTSManager"):
		TTSManager.tts_enabled = tts_enabled
	
	city_changed.emit(get_selected_city_path())
	print("Settings applied! Selected city: ", CITY_NAMES.get(selected_city_index, "Unknown"))


func _on_back_pressed() -> void:
	settings_closed.emit()
	hide()
