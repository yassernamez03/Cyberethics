# =============================================================================
# MOBILE CONTROLLER - Virtual Touch Controls for Mobile Devices
# =============================================================================
# Provides virtual joystick and action buttons for mobile gameplay
# Only visible on touch-capable devices
# Path: res://scripts/ui/mobile_controller.gd
# =============================================================================

extends CanvasLayer
class_name MobileController

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal joystick_input(direction: Vector2)
signal jump_pressed
signal sprint_toggled(is_sprinting: bool)
signal interact_pressed

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export_group("Joystick Settings")
@export var joystick_deadzone: float = 0.2
@export var joystick_max_distance: float = 100.0

@export_group("Visibility")
@export var force_visible: bool = false  # For testing on desktop
@export var auto_detect_mobile: bool = true

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var control_container: Control = $ControlContainer
@onready var joystick_base: TextureRect = $ControlContainer/JoystickContainer/JoystickBase
@onready var joystick_knob: TextureRect = $ControlContainer/JoystickContainer/JoystickBase/JoystickKnob
@onready var jump_button: TouchScreenButton = $ControlContainer/ActionButtons/JumpButton
@onready var sprint_button: TouchScreenButton = $ControlContainer/ActionButtons/SprintButton
@onready var interact_button: TouchScreenButton = $ControlContainer/ActionButtons/InteractButton
@onready var camera_touch_area: Control = $ControlContainer/CameraTouchArea

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _joystick_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_current: Vector2 = Vector2.ZERO
var _is_sprinting: bool = false
var _camera_touch_index: int = -1
var _camera_last_position: Vector2 = Vector2.ZERO
var _is_mobile: bool = false

# Store the movement direction for external access
var movement_direction: Vector2 = Vector2.ZERO
var camera_delta: Vector2 = Vector2.ZERO

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	_is_mobile = _detect_mobile_device()
	
	if auto_detect_mobile:
		visible = _is_mobile or force_visible
	else:
		visible = force_visible
	
	if visible:
		_setup_joystick()
		_setup_buttons()
		_setup_camera_touch()
		print("📱 Mobile controller enabled")
	else:
		print("🖥️ Mobile controller hidden (desktop detected)")


func _process(_delta: float) -> void:
	if not visible:
		return
	
	# Reset camera delta each frame
	camera_delta = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	_handle_joystick_input(event)
	_handle_camera_touch(event)


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func is_mobile() -> bool:
	"""Returns true if running on a mobile device."""
	return _is_mobile


func get_movement_vector() -> Vector2:
	"""Returns the current joystick movement direction."""
	return movement_direction


func get_camera_delta() -> Vector2:
	"""Returns the camera movement delta from touch."""
	return camera_delta


func show_controller() -> void:
	"""Force show the mobile controller."""
	visible = true


func hide_controller() -> void:
	"""Force hide the mobile controller."""
	visible = false


func set_sprint_state(sprinting: bool) -> void:
	"""Update the sprint button visual state."""
	_is_sprinting = sprinting
	if sprint_button and sprint_button.has_method("set_pressed"):
		# Update visual state if we have a custom button
		pass


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Mobile Detection
# -----------------------------------------------------------------------------
func _detect_mobile_device() -> bool:
	"""Detect if running on a mobile/touch device."""
	# Check for touch capability
	var has_touch := DisplayServer.is_touchscreen_available()
	
	# Check OS name for mobile platforms
	var os_name := OS.get_name().to_lower()
	var is_mobile_os := os_name in ["android", "ios", "web"]
	
	# For web builds, also check if it's a touch device
	if os_name == "web":
		return has_touch
	
	return has_touch or is_mobile_os


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Joystick
# -----------------------------------------------------------------------------
func _setup_joystick() -> void:
	"""Initialize the joystick."""
	if joystick_base:
		_joystick_center = joystick_base.size / 2.0
		if joystick_knob:
			joystick_knob.position = _joystick_center - joystick_knob.size / 2.0


func _handle_joystick_input(event: InputEvent) -> void:
	"""Process joystick touch input."""
	if not joystick_base:
		return
	
	var joystick_rect := joystick_base.get_global_rect()
	
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		
		if touch.pressed:
			# Check if touch is in joystick area
			if joystick_rect.has_point(touch.position) and _joystick_touch_index == -1:
				_joystick_touch_index = touch.index
				_update_joystick(touch.position)
		else:
			# Touch released
			if touch.index == _joystick_touch_index:
				_joystick_touch_index = -1
				_reset_joystick()
	
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joystick_touch_index:
			_update_joystick(drag.position)


func _update_joystick(touch_position: Vector2) -> void:
	"""Update joystick position based on touch."""
	if not joystick_base or not joystick_knob:
		return
	
	var joystick_global_center := joystick_base.global_position + _joystick_center
	var direction := touch_position - joystick_global_center
	var distance := direction.length()
	
	# Clamp to max distance
	if distance > joystick_max_distance:
		direction = direction.normalized() * joystick_max_distance
		distance = joystick_max_distance
	
	# Update knob position
	joystick_knob.position = _joystick_center + direction - joystick_knob.size / 2.0
	
	# Calculate normalized direction with deadzone
	var normalized_distance := distance / joystick_max_distance
	if normalized_distance < joystick_deadzone:
		movement_direction = Vector2.ZERO
	else:
		# Remap to 0-1 range after deadzone
		var remapped := (normalized_distance - joystick_deadzone) / (1.0 - joystick_deadzone)
		movement_direction = direction.normalized() * remapped
	
	# Emit signal for listeners
	joystick_input.emit(movement_direction)
	
	# Also set input actions for compatibility
	_update_movement_actions()


func _reset_joystick() -> void:
	"""Reset joystick to center position."""
	if joystick_knob:
		joystick_knob.position = _joystick_center - joystick_knob.size / 2.0
	
	movement_direction = Vector2.ZERO
	joystick_input.emit(Vector2.ZERO)
	_update_movement_actions()


func _update_movement_actions() -> void:
	"""Update input actions based on joystick position."""
	# Simulate input actions for the movement system
	# This allows the existing player controller to work without modifications
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	
	if movement_direction.x < -joystick_deadzone:
		Input.action_press("move_left", abs(movement_direction.x))
	elif movement_direction.x > joystick_deadzone:
		Input.action_press("move_right", abs(movement_direction.x))
	
	if movement_direction.y < -joystick_deadzone:
		Input.action_press("move_forward", abs(movement_direction.y))
	elif movement_direction.y > joystick_deadzone:
		Input.action_press("move_back", abs(movement_direction.y))


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Action Buttons
# -----------------------------------------------------------------------------
func _setup_buttons() -> void:
	"""Setup action button connections."""
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
		jump_button.released.connect(_on_jump_released)
	
	if sprint_button:
		sprint_button.pressed.connect(_on_sprint_pressed)
		sprint_button.released.connect(_on_sprint_released)
	
	if interact_button:
		interact_button.pressed.connect(_on_interact_pressed)
		interact_button.released.connect(_on_interact_released)


func _on_jump_pressed() -> void:
	Input.action_press("jump")
	jump_pressed.emit()


func _on_jump_released() -> void:
	Input.action_release("jump")


func _on_sprint_pressed() -> void:
	_is_sprinting = true
	Input.action_press("sprint")
	sprint_toggled.emit(true)


func _on_sprint_released() -> void:
	_is_sprinting = false
	Input.action_release("sprint")
	sprint_toggled.emit(false)


func _on_interact_pressed() -> void:
	Input.action_press("interact")
	interact_pressed.emit()


func _on_interact_released() -> void:
	Input.action_release("interact")


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Camera Touch
# -----------------------------------------------------------------------------
func _setup_camera_touch() -> void:
	"""Setup the camera touch area for looking around."""
	if camera_touch_area:
		camera_touch_area.gui_input.connect(_on_camera_area_input)


func _handle_camera_touch(event: InputEvent) -> void:
	"""Handle touch input for camera control on the right side of screen."""
	if not camera_touch_area:
		return
	
	var camera_rect := camera_touch_area.get_global_rect()
	
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		
		if touch.pressed:
			if camera_rect.has_point(touch.position) and _camera_touch_index == -1:
				_camera_touch_index = touch.index
				_camera_last_position = touch.position
		else:
			if touch.index == _camera_touch_index:
				_camera_touch_index = -1
	
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _camera_touch_index:
			camera_delta = drag.relative * 0.5  # Adjust sensitivity


func _on_camera_area_input(event: InputEvent) -> void:
	"""Handle camera area GUI input."""
	# This is handled by _handle_camera_touch for screen-wide input
	pass
