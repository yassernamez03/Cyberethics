# =============================================================================
# PLAYER CONTROLLER - 3D Character Controller
# =============================================================================
# Handles player movement, jumping, camera, and basic interactions
# Path: res://scripts/entities/player/player_controller.gd
# =============================================================================

extends CharacterBody3D
class_name PlayerController

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal jumped
signal landed
signal sprinting_changed(is_sprinting: bool)

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES - Movement
# -----------------------------------------------------------------------------
@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var acceleration: float = 10.0
@export var deceleration: float = 15.0
@export var air_control: float = 0.3

@export_group("Jump")
@export var jump_height: float = 1.5
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_descent: float = 0.35
@export var max_air_jumps: int = 0 # Double jump support

@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var camera_smoothing: float = 15.0
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@export_group("Physics")
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _jump_velocity: float
var _jump_gravity: float
var _fall_gravity: float

var _is_sprinting: bool = false
var _is_crouching: bool = false
var _was_on_floor: bool = true
var _air_jumps_remaining: int = 0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

var _target_rotation: float = 0.0
var _target_pitch: float = 0.0

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_calculate_jump_physics()
	_air_jumps_remaining = max_air_jumps


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event.relative)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_movement(delta)
	_handle_jump()
	_apply_gravity(delta)
	_check_landing()
	
	move_and_slide()
	
	_was_on_floor = is_on_floor()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func get_current_speed() -> float:
	if _is_crouching:
		return crouch_speed
	elif _is_sprinting:
		return sprint_speed
	return walk_speed


func set_mouse_captured(captured: bool) -> void:
	if captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Movement
# -----------------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	
	if has_node("/root/InputManager"):
		input_dir = InputManager.get_movement_vector()
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Handle sprint
	var was_sprinting := _is_sprinting
	_is_sprinting = Input.is_action_pressed("sprint") and input_dir.y < 0 # Only forward sprint
	if was_sprinting != _is_sprinting:
		sprinting_changed.emit(_is_sprinting)
	
	# Handle crouch
	_is_crouching = Input.is_action_pressed("crouch")
	
	# Calculate direction relative to camera
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed := get_current_speed()
	var accel := acceleration if direction.length() > 0 else deceleration
	
	# Reduce control in air
	if not is_on_floor():
		accel *= air_control
	
	# Apply movement
	velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta)
	velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta)


func _handle_mouse_look(relative: Vector2) -> void:
	_target_rotation -= relative.x * mouse_sensitivity
	_target_pitch -= relative.y * mouse_sensitivity
	_target_pitch = clamp(_target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	rotation.y = _target_rotation
	camera_pivot.rotation.x = _target_pitch


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Jump & Gravity
# -----------------------------------------------------------------------------
func _calculate_jump_physics() -> void:
	# Calculate physics values from designer-friendly parameters
	_jump_velocity = (2.0 * jump_height) / jump_time_to_peak
	_jump_gravity = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	_fall_gravity = (-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)


func _handle_jump() -> void:
	var wants_jump := Input.is_action_just_pressed("jump")
	
	if wants_jump:
		_jump_buffer_timer = jump_buffer_time
	
	var can_jump := is_on_floor() or _coyote_timer > 0 or _air_jumps_remaining > 0
	var should_jump := _jump_buffer_timer > 0 and can_jump
	
	if should_jump:
		if not is_on_floor() and _coyote_timer <= 0:
			_air_jumps_remaining -= 1
		
		velocity.y = _jump_velocity
		_coyote_timer = 0
		_jump_buffer_timer = 0
		jumped.emit()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity := _jump_gravity if velocity.y > 0 else _fall_gravity
		velocity.y += gravity * delta


func _update_timers(delta: float) -> void:
	# Coyote time
	if is_on_floor():
		_coyote_timer = coyote_time
	elif _coyote_timer > 0:
		_coyote_timer -= delta
	
	# Jump buffer
	if _jump_buffer_timer > 0:
		_jump_buffer_timer -= delta


func _check_landing() -> void:
	if is_on_floor() and not _was_on_floor:
		_air_jumps_remaining = max_air_jumps
		landed.emit()
