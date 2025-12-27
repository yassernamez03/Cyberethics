# =============================================================================
# INPUT MANAGER - Input Autoload Singleton
# =============================================================================
# Centralized input handling with action buffering and device detection
# Path: res://scripts/autoloads/input_manager.gd
# =============================================================================

extends Node

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal input_device_changed(device: InputDevice)
signal action_just_pressed(action: String)
signal action_just_released(action: String)

# -----------------------------------------------------------------------------
# ENUMS
# -----------------------------------------------------------------------------
enum InputDevice {
	KEYBOARD_MOUSE,
	GAMEPAD
}

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var current_device: InputDevice = InputDevice.KEYBOARD_MOUSE
var mouse_sensitivity: float = 0.002
var gamepad_sensitivity: float = 2.0

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _action_buffer: Dictionary = {}
var _buffer_duration: float = 0.15

# Define all game actions here for easy reference
const ACTIONS := {
	"move_forward": "move_forward",
	"move_back": "move_back",
	"move_left": "move_left",
	"move_right": "move_right",
	"jump": "jump",
	"sprint": "sprint",
	"crouch": "crouch",
	"interact": "interact",
	"attack": "attack",
	"aim": "aim",
	"pause": "pause",
}

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_default_actions()


func _process(delta: float) -> void:
	_update_action_buffer(delta)
	_detect_input_device()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func get_movement_vector() -> Vector2:
	"""Returns normalized 2D movement input vector."""
	return Input.get_vector(
		ACTIONS.move_left,
		ACTIONS.move_right,
		ACTIONS.move_forward,
		ACTIONS.move_back
	)


func get_look_vector() -> Vector2:
	"""Returns look/aim input vector based on current device."""
	if current_device == InputDevice.GAMEPAD:
		return Input.get_vector("look_left", "look_right", "look_up", "look_down")
	return Vector2.ZERO


func is_action_buffered(action: String) -> bool:
	"""Check if action was pressed recently (within buffer window)."""
	return _action_buffer.has(action) and _action_buffer[action] > 0.0


func consume_buffered_action(action: String) -> bool:
	"""Consume a buffered action and return true if it was available."""
	if is_action_buffered(action):
		_action_buffer.erase(action)
		return true
	return false


func is_action(action: String) -> bool:
	"""Shorthand for Input.is_action_pressed()."""
	return Input.is_action_pressed(action)


func is_action_just(action: String) -> bool:
	"""Shorthand for Input.is_action_just_pressed()."""
	return Input.is_action_just_pressed(action)


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _setup_default_actions() -> void:
	# Setup default input mappings if they don't exist
	# These should be configured in Project Settings > Input Map
	_add_action_if_missing("move_forward", KEY_W)
	_add_action_if_missing("move_back", KEY_S)
	_add_action_if_missing("move_left", KEY_A)
	_add_action_if_missing("move_right", KEY_D)
	_add_action_if_missing("jump", KEY_SPACE)
	_add_action_if_missing("sprint", KEY_SHIFT)
	_add_action_if_missing("crouch", KEY_CTRL)
	_add_action_if_missing("interact", KEY_E)
	_add_action_if_missing("attack", MOUSE_BUTTON_LEFT)
	_add_action_if_missing("aim", MOUSE_BUTTON_RIGHT)
	_add_action_if_missing("pause", KEY_ESCAPE)


func _add_action_if_missing(action_name: String, key: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var event: InputEvent
		
		if key >= MOUSE_BUTTON_LEFT and key <= MOUSE_BUTTON_XBUTTON2:
			event = InputEventMouseButton.new()
			(event as InputEventMouseButton).button_index = key
		else:
			event = InputEventKey.new()
			(event as InputEventKey).keycode = key
		
		InputMap.action_add_event(action_name, event)


func _update_action_buffer(delta: float) -> void:
	# Buffer jump and similar actions for responsive gameplay
	var buffered_actions := ["jump", "attack", "interact"]
	
	for action in buffered_actions:
		if Input.is_action_just_pressed(action):
			_action_buffer[action] = _buffer_duration
			action_just_pressed.emit(action)
		elif _action_buffer.has(action):
			_action_buffer[action] -= delta
			if _action_buffer[action] <= 0:
				_action_buffer.erase(action)
	
	# Track released actions
	for action in ACTIONS.values():
		if Input.is_action_just_released(action):
			action_just_released.emit(action)


func _detect_input_device() -> void:
	var previous_device := current_device
	
	# Check for keyboard/mouse input
	if Input.is_anything_pressed():
		for action in ACTIONS.values():
			if Input.is_action_just_pressed(action):
				var events := InputMap.action_get_events(action)
				for event in events:
					if event is InputEventKey or event is InputEventMouseButton:
						current_device = InputDevice.KEYBOARD_MOUSE
						break
					elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
						current_device = InputDevice.GAMEPAD
						break
	
	if previous_device != current_device:
		input_device_changed.emit(current_device)
