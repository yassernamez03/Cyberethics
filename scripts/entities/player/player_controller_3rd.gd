# =============================================================================
# PLAYER CONTROLLER 3RD PERSON - Third Person Character Controller
# =============================================================================
# Handles player movement with third-person camera following avatar
# Path: res://scripts/entities/player/player_controller_3rd.gd
# =============================================================================

extends CharacterBody3D
class_name PlayerController3rd

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal jumped
signal landed
signal text_received  # Emitted when player receives a "text message" after 3 min

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES - Movement
# -----------------------------------------------------------------------------
@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 10.0
@export var deceleration: float = 15.0
@export var rotation_speed: float = 10.0

@export_group("Jump")
@export var jump_height: float = 1.8
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.4

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -40.0
@export var max_pitch: float = 60.0

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var avatar: Node3D = $Avatar
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Animation paths
const WALKING_ANIM_PATH := "res://assets/animations/Walking.fbx"
const IDLE_ANIM_PATH := "res://assets/animations/Idle.fbx"
const RUNNING_ANIM_PATH := "res://assets/animations/Running.fbx"
const JUMPING_ANIM_PATH := "res://assets/animations/Jumping.fbx"
const TEXTING_ANIM_PATH := "res://assets/animations/Texting While Standing.fbx"
const TALKING_ANIM_PATH := "res://assets/animations/Talking.fbx"

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _jump_velocity: float
var _jump_gravity: float
var _fall_gravity: float
var _was_on_floor: bool = true
var _target_rotation: float = 0.0
var _is_moving: bool = false
var _is_sprinting: bool = false
var _skeleton: Skeleton3D = null
var _is_jump_animating: bool = false  # Track if jump animation is playing
var _game_time: float = 0.0  # Track total game time
var _texting_triggered: bool = false  # Has the texting event been triggered?
var _is_texting: bool = false  # Currently playing texting animation?
var _can_move: bool = true  # Can the player move? (disabled during dialogue)
var _is_in_dialogue: bool = false  # Is the player in dialogue with an NPC?
const TEXTING_TRIGGER_TIME: float = 20.0  # 3 minutes = 180 seconds

# Footstep sound variables
var _footstep_timer: float = 0.0
var _footstep_interval: float = 0.25  # Time between footsteps when walking
var _footstep_sprint_interval: float = 0.3  # Faster when sprinting

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Only capture mouse on desktop, not on mobile
	if not _is_mobile():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_calculate_jump_physics()
	_setup_animations()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func set_can_move(can_move: bool) -> void:
	"""Enable or disable player movement (used during dialogue)."""
	_can_move = can_move
	_is_in_dialogue = not can_move
	if not can_move:
		velocity.x = 0
		velocity.z = 0
		# Stop walking sound
		if AudioManager:
			AudioManager.stop_walking_sound()
		# Play talking animation during dialogue
		if animation_player:
			var talk_anim = _get_available_animation(["Talking", "talking", "Talk"])
			if talk_anim != "":
				animation_player.play(talk_anim)
	else:
		# Return to idle when dialogue ends
		if animation_player:
			var idle_anim = _get_available_animation(["Idle", "idle"])
			if idle_anim != "":
				animation_player.play(idle_anim)


func _setup_animations() -> void:
	# Find the skeleton in the avatar
	_skeleton = _find_skeleton(avatar)
	if _skeleton:
		print("Found skeleton: ", _skeleton.name)
	else:
		push_warning("No Skeleton3D found in Avatar")
	
	# First, check if avatar has its own AnimationPlayer
	var avatar_anim_player = _find_animation_player(avatar)
	if avatar_anim_player:
		animation_player = avatar_anim_player
		print("Using Avatar's AnimationPlayer")
	
	# Load animations from external FBX files into the animation player
	_load_external_animations()
	
	print("Available animations: ", animation_player.get_animation_list() if animation_player else "None")


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null


func _load_external_animations() -> void:
	if not animation_player:
		push_warning("No AnimationPlayer available")
		return
	
	if not _skeleton:
		push_warning("No skeleton found - cannot load animations")
		return
		
	# Ensure we have an animation library
	if not animation_player.has_animation_library(""):
		animation_player.add_animation_library("", AnimationLibrary.new())
	
	var anim_library = animation_player.get_animation_library("")
	
	# Print skeleton bone names for debugging (only once)
	print("Avatar skeleton has ", _skeleton.get_bone_count(), " bones")
	
	# Load all animations
	_load_single_animation(IDLE_ANIM_PATH, "Idle", anim_library)
	_load_single_animation(WALKING_ANIM_PATH, "Walking", anim_library)
	_load_single_animation(RUNNING_ANIM_PATH, "Running", anim_library)
	_load_single_animation(JUMPING_ANIM_PATH, "Jumping", anim_library, false)  # Don't loop jump
	_load_single_animation(TEXTING_ANIM_PATH, "Texting", anim_library)  # Texting animation
	_load_single_animation(TALKING_ANIM_PATH, "Talking", anim_library)  # Talking animation for dialogue
	
	print("All available animations: ", animation_player.get_animation_list())


func _load_single_animation(fbx_path: String, anim_name: String, anim_library: AnimationLibrary, should_loop: bool = true) -> void:
	if not ResourceLoader.exists(fbx_path):
		push_warning(anim_name + " animation not found at: " + fbx_path)
		return
	
	var scene = load(fbx_path)
	if not scene:
		push_warning("Failed to load: " + fbx_path)
		return
	
	var instance = scene.instantiate()
	var source_skeleton = _find_skeleton(instance)
	var source_anim_player = _find_animation_player(instance)
	
	if source_anim_player:
		for src_anim_name in source_anim_player.get_animation_list():
			var anim = source_anim_player.get_animation(src_anim_name)
			if anim:
				var remapped_anim = _remap_animation_tracks(anim, source_skeleton, should_loop)
				
				if not anim_library.has_animation(anim_name):
					anim_library.add_animation(anim_name, remapped_anim)
					print("Loaded ", anim_name, " animation successfully!")
				break  # Only take the first animation from each FBX
	else:
		push_warning("No AnimationPlayer found in " + fbx_path)
	
	instance.queue_free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null


func _remap_animation_tracks(source_anim: Animation, source_skeleton: Skeleton3D, should_loop: bool = true) -> Animation:
	var new_anim = source_anim.duplicate()
	
	# Get the skeleton path relative to the Player node
	var skeleton_path := ""
	if _skeleton:
		skeleton_path = str(get_path_to(_skeleton))
	
	# Build bone name mapping between source and target skeleton
	var bone_mapping := _build_bone_mapping(source_skeleton)
	
	print("Remapping animation tracks to skeleton path: ", skeleton_path)
	
	# Remap track paths to point to our skeleton
	var tracks_remapped := 0
	for i in range(new_anim.get_track_count()):
		var track_path = new_anim.track_get_path(i)
		var path_str = str(track_path)
		
		# Find the bone name (after the last colon)
		var colon_pos = path_str.rfind(":")
		if colon_pos != -1:
			var bone_name = path_str.substr(colon_pos + 1)
			
			# Try to find matching bone in our skeleton
			var target_bone = bone_mapping.get(bone_name, bone_name)
			
			# Check if this bone exists in our skeleton
			if _skeleton.find_bone(target_bone) != -1:
				var new_path = skeleton_path + ":" + target_bone
				new_anim.track_set_path(i, NodePath(new_path))
				tracks_remapped += 1
			else:
				# Try without prefix (some animations use mixamorig: prefix)
				var clean_bone = bone_name.replace("mixamorig:", "").replace("mixamorig_", "")
				if _skeleton.find_bone(clean_bone) != -1:
					var new_path = skeleton_path + ":" + clean_bone
					new_anim.track_set_path(i, NodePath(new_path))
					tracks_remapped += 1
	
	print("Remapped ", tracks_remapped, " of ", new_anim.get_track_count(), " tracks")
	
	# Set loop mode based on parameter
	if should_loop:
		new_anim.loop_mode = Animation.LOOP_LINEAR
	else:
		new_anim.loop_mode = Animation.LOOP_NONE
	return new_anim


func _build_bone_mapping(source_skeleton: Skeleton3D) -> Dictionary:
	var mapping := {}
	
	if not source_skeleton or not _skeleton:
		return mapping
	
	# Common bone name variations between Mixamo and Ready Player Me
	var name_variants := {
		# Mixamo naming -> common alternatives
		"mixamorig:Hips": ["Hips", "pelvis", "hip"],
		"mixamorig:Spine": ["Spine", "spine", "spine_01"],
		"mixamorig:Spine1": ["Spine1", "spine_02", "spine1"],
		"mixamorig:Spine2": ["Spine2", "spine_03", "spine2"],
		"mixamorig:Neck": ["Neck", "neck", "neck_01"],
		"mixamorig:Head": ["Head", "head"],
		"mixamorig:LeftShoulder": ["LeftShoulder", "shoulder_l", "clavicle_l"],
		"mixamorig:LeftArm": ["LeftArm", "upperarm_l", "upper_arm_l"],
		"mixamorig:LeftForeArm": ["LeftForeArm", "lowerarm_l", "forearm_l"],
		"mixamorig:LeftHand": ["LeftHand", "hand_l"],
		"mixamorig:RightShoulder": ["RightShoulder", "shoulder_r", "clavicle_r"],
		"mixamorig:RightArm": ["RightArm", "upperarm_r", "upper_arm_r"],
		"mixamorig:RightForeArm": ["RightForeArm", "lowerarm_r", "forearm_r"],
		"mixamorig:RightHand": ["RightHand", "hand_r"],
		"mixamorig:LeftUpLeg": ["LeftUpLeg", "thigh_l", "upper_leg_l"],
		"mixamorig:LeftLeg": ["LeftLeg", "calf_l", "lower_leg_l", "shin_l"],
		"mixamorig:LeftFoot": ["LeftFoot", "foot_l"],
		"mixamorig:LeftToeBase": ["LeftToeBase", "toe_l", "ball_l"],
		"mixamorig:RightUpLeg": ["RightUpLeg", "thigh_r", "upper_leg_r"],
		"mixamorig:RightLeg": ["RightLeg", "calf_r", "lower_leg_r", "shin_r"],
		"mixamorig:RightFoot": ["RightFoot", "foot_r"],
		"mixamorig:RightToeBase": ["RightToeBase", "toe_r", "ball_r"],
	}
	
	# Build mapping by finding matching bones
	for source_name in name_variants.keys():
		var variants = name_variants[source_name]
		for variant in variants:
			if _skeleton.find_bone(variant) != -1:
				mapping[source_name] = variant
				# Also map without mixamorig prefix
				var clean_name = source_name.replace("mixamorig:", "")
				mapping[clean_name] = variant
				break
	
	# Direct mapping for bones that might have same names
	for i in range(_skeleton.get_bone_count()):
		var bone_name = _skeleton.get_bone_name(i)
		mapping[bone_name] = bone_name
	
	return mapping


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event.relative)
	
	# Handle touch camera input (from mobile controller)
	if event is InputEventScreenDrag:
		_handle_touch_camera(event)
	
	# Toggle mouse capture with Escape (only on desktop)
	if event.is_action_pressed("pause"):
		if not _is_mobile():
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Press T to trigger phone/text message (for testing or manual trigger)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if not _is_texting:
			_trigger_texting_event()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_jump()
	_apply_gravity(delta)
	_check_landing()
	_update_animations()
	_handle_footsteps(delta)
	
	move_and_slide()
	
	_was_on_floor = is_on_floor()


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Animation
# -----------------------------------------------------------------------------
func _update_animations() -> void:
	if not animation_player:
		return
	
	# Don't update animations during dialogue - talking animation is handled by set_can_move
	if _is_in_dialogue:
		return
	
	# Determine current animation state
	var horizontal_velocity := Vector2(velocity.x, velocity.z).length()
	var is_moving := horizontal_velocity > 1.0  # Increased threshold
	var is_sprinting := Input.is_action_pressed("sprint") and is_moving
	var is_in_air := not is_on_floor()
	
	# Update game time
	_game_time += get_physics_process_delta_time()
	
	# Check if texting should be triggered (after 3 minutes, when idle)
	if not _texting_triggered and _game_time >= TEXTING_TRIGGER_TIME and not is_moving and not is_in_air:
		_trigger_texting_event()
	
	# If texting animation is playing, let it continue unless player moves
	if _is_texting:
		if is_moving or is_in_air:
			# Player moved - stop texting
			_is_texting = false
		else:
			# Keep texting animation playing
			var texting_anim = _get_available_animation(["Texting", "texting"])
			if texting_anim != "" and animation_player.current_animation != texting_anim:
				animation_player.play(texting_anim)
			return
	
	# Reset jump animation flag when landing
	if is_on_floor() and _is_jump_animating:
		_is_jump_animating = false
	
	# Start jump animation when leaving the ground with upward velocity
	if is_in_air and velocity.y > 0 and not _is_jump_animating:
		var jump_anim = _get_available_animation(["Jump", "jump", "Jumping"])
		if jump_anim != "":
			_is_jump_animating = true
			animation_player.play(jump_anim)
		return
	
	# Keep playing jump animation while in air (don't interrupt it)
	if _is_jump_animating and is_in_air:
		# Let the animation continue playing - don't interrupt
		return
	
	# Handle idle state - play idle animation when not moving and on ground
	if not is_moving and not is_in_air:
		var idle_anim = _get_available_animation(["Idle", "idle"])
		if idle_anim != "":
			if animation_player.current_animation != idle_anim:
				animation_player.play(idle_anim)
		else:
			# No idle animation - stop the current animation
			if animation_player.is_playing():
				animation_player.stop()
		return
	
	# Play appropriate animation - check multiple possible names
	var target_anim := ""
	
	if is_sprinting:
		target_anim = _get_available_animation(["Running", "Run", "run", "Sprint"])
	elif is_moving:
		target_anim = _get_available_animation(["Walking", "Walk", "walk"])
	
	# Only change animation if different from current and valid
	if target_anim != "" and animation_player.current_animation != target_anim:
		animation_player.play(target_anim)
	elif target_anim == "" and is_moving:
		# Fallback: try playing any available animation when moving
		var anims = animation_player.get_animation_list()
		if anims.size() > 0:
			animation_player.play(anims[0])


func _get_available_animation(names: Array) -> String:
	for anim_name in names:
		if animation_player.has_animation(anim_name):
			return anim_name
	return ""


func _trigger_texting_event() -> void:
	_texting_triggered = true
	_is_texting = true
	
	# Play texting animation first
	var texting_anim = _get_available_animation(["Texting", "texting"])
	if texting_anim != "":
		animation_player.play(texting_anim)
		print("📱 Player checking phone...")
	
	# Wait for animation to play a bit before showing phone screen (2 seconds delay)
	await get_tree().create_timer(2.0).timeout
	
	# Emit signal for UI/game systems to show phone screen
	print("📱 Showing phone screen...")
	text_received.emit()


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Movement
# -----------------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	# Don't allow movement if disabled (e.g., during dialogue)
	if not _can_move:
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
		return
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Get camera's forward and right directions (ignoring Y)
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()
	
	# Calculate movement direction relative to camera
	var direction := (forward * -input_dir.y + right * input_dir.x).normalized()
	
	# Determine speed
	var is_sprinting := Input.is_action_pressed("sprint")
	var current_speed := sprint_speed if is_sprinting else walk_speed
	
	if direction.length() > 0.1:
		# Rotate avatar to face movement direction
		var target_angle := atan2(direction.x, direction.z)
		avatar.rotation.y = lerp_angle(avatar.rotation.y, target_angle, rotation_speed * delta)
		
		# Apply movement
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		# Decelerate when no input
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)


func _handle_mouse_look(relative: Vector2) -> void:
	# Rotate camera pivot horizontally
	camera_pivot.rotate_y(-relative.x * mouse_sensitivity)
	
	# Rotate spring arm vertically (pitch)
	spring_arm.rotate_x(-relative.y * mouse_sensitivity)
	spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))


func _handle_touch_camera(event: InputEventScreenDrag) -> void:
	"""Handle camera look from touch input (mobile)."""
	# Only process touch input from the right side of the screen (camera area)
	var screen_width := get_viewport().get_visible_rect().size.x
	if event.position.x < screen_width * 0.4:
		return  # Left side is for joystick
	
	var touch_sensitivity := mouse_sensitivity * 1.5  # Slightly higher for touch
	
	# Rotate camera pivot horizontally
	camera_pivot.rotate_y(-event.relative.x * touch_sensitivity)
	
	# Rotate spring arm vertically (pitch)
	spring_arm.rotate_x(-event.relative.y * touch_sensitivity)
	spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))


func _is_mobile() -> bool:
	"""Check if running on a mobile device."""
	if has_node("/root/InputManager"):
		return InputManager.is_touch_device()
	return DisplayServer.is_touchscreen_available()


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Jump & Gravity
# -----------------------------------------------------------------------------
func _calculate_jump_physics() -> void:
	_jump_velocity = (2.0 * jump_height) / jump_time_to_peak
	_jump_gravity = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	_fall_gravity = (-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _jump_velocity
		jumped.emit()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity := _jump_gravity if velocity.y > 0 else _fall_gravity
		velocity.y += gravity * delta


func _check_landing() -> void:
	if is_on_floor() and not _was_on_floor:
		landed.emit()


# -----------------------------------------------------------------------------
# PRIVATE METHODS - Audio
# -----------------------------------------------------------------------------
func _handle_footsteps(delta: float) -> void:
	"""Play footstep sounds when walking/running on ground."""
	# Stop walking sound if not on floor
	if not is_on_floor():
		_footstep_timer = 0.0
		if has_node("/root/AudioManager"):
			AudioManager.stop_walking_sound()
		return
	
	# Check if player is moving
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var is_moving := horizontal_velocity.length() > 0.5
	
	# Stop walking sound if not moving or texting
	if not is_moving or _is_texting:
		_footstep_timer = 0.0
		if has_node("/root/AudioManager"):
			AudioManager.stop_walking_sound()
		return
	
	# Check if sprinting
	var is_sprinting := Input.is_action_pressed("sprint")
	
	# Play walking sound (with running speed if sprinting)
	if has_node("/root/AudioManager"):
		AudioManager.play_walking_sound(is_sprinting)
