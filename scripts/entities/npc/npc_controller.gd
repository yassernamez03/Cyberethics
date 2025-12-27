# =============================================================================
# NPC CONTROLLER - Walking NPC with patrol behavior and dialogue
# =============================================================================
# Handles NPC movement with patrol waypoints or random wandering
# NPCs can teach players about cyber security when interacted with
# Path: res://scripts/entities/npc/npc_controller.gd
# =============================================================================

extends CharacterBody3D
class_name NPCController

signal interaction_requested(npc: NPCController)
signal dialogue_started
signal dialogue_ended

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export_group("Movement")
@export var walk_speed: float = 2.5
@export var rotation_speed: float = 5.0

@export_group("Patrol")
@export var patrol_points: Array[Vector3] = []
@export var wait_time_min: float = 2.0
@export var wait_time_max: float = 5.0
@export var wander_radius: float = 15.0
@export var use_random_wander: bool = true

@export_group("Physics")
@export var gravity: float = 20.0

@export_group("Dialogue")
@export var npc_name: String = "Cyber Expert"
@export var lesson_type: int = 0  # 0=Phishing, 1=Password, 2=SocialEng, 3=Malware, 4=WiFi
@export var interaction_distance: float = 3.0

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var avatar: Node3D = $Avatar
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_label: Label3D = $InteractionLabel

# Animation paths
const WALKING_ANIM_PATH := "res://assets/animations/Walking.fbx"
const IDLE_ANIM_PATH := "res://assets/animations/Idle.fbx"
const SAD_IDLE_ANIM_PATH := "res://assets/animations/Sad Idle.fbx"

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _current_patrol_index: int = 0
var _is_waiting: bool = false
var _wait_timer: float = 0.0
var _skeleton: Skeleton3D = null
var _animation_player: AnimationPlayer = null
var _is_moving: bool = false
var _start_position: Vector3
var _animations_loaded: bool = false
var _player_nearby: bool = false
var _is_in_dialogue: bool = false
var _target_player: Node3D = null
var _dialogue_cooldown: float = 0.0  # Prevents immediate re-trigger

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	_start_position = global_position
	
	# Setup navigation
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 1.0
	navigation_agent.avoidance_enabled = true
	
	# Setup interaction area
	_setup_interaction_area()
	
	# Hide interaction label initially
	if interaction_label:
		interaction_label.visible = false
	
	# Setup animations
	call_deferred("_setup_animations")
	
	# Start patrol after a short delay
	await get_tree().create_timer(0.5).timeout
	_pick_next_destination()


func _physics_process(delta: float) -> void:
	# Update dialogue cooldown
	if _dialogue_cooldown > 0:
		_dialogue_cooldown -= delta
	
	# Don't move during dialogue
	if _is_in_dialogue:
		velocity = Vector3.ZERO
		_update_animation(false)
		# Face the player during dialogue
		if _target_player:
			var look_dir = (_target_player.global_position - global_position).normalized()
			look_dir.y = 0
			if look_dir.length() > 0.1:
				var target_rot = atan2(look_dir.x, look_dir.z)
				rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
		move_and_slide()
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0:
			_is_waiting = false
			_pick_next_destination()
		velocity.x = 0
		velocity.z = 0
		_update_animation(false)
	else:
		_move_along_path(delta)
	
	move_and_slide()


func _input(event: InputEvent) -> void:
	if _player_nearby and not _is_in_dialogue and _dialogue_cooldown <= 0:
		if event.is_action_pressed("interact") or \
		   (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			start_dialogue()


# -----------------------------------------------------------------------------
# INTERACTION METHODS
# -----------------------------------------------------------------------------
func _setup_interaction_area() -> void:
	# Create interaction area if it doesn't exist
	if not has_node("InteractionArea"):
		var area = Area3D.new()
		area.name = "InteractionArea"
		add_child(area)
		
		var collision = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = interaction_distance
		collision.shape = sphere
		collision.position = Vector3(0, 1, 0)
		area.add_child(collision)
		
		interaction_area = area
	
	# Create interaction label if it doesn't exist
	if not has_node("InteractionLabel"):
		var label = Label3D.new()
		label.name = "InteractionLabel"
		label.text = "Press [E] to talk"
		label.font_size = 32
		label.position = Vector3(0, 3, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.3, 0.8, 1.0)
		label.outline_size = 8
		add_child(label)
		interaction_label = label
	
	# Connect signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController3rd:
		_player_nearby = true
		_target_player = body
		if interaction_label:
			interaction_label.visible = true
			interaction_label.text = "Press [E] to talk\n" + npc_name


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController3rd:
		_player_nearby = false
		_target_player = null
		if interaction_label:
			interaction_label.visible = false


func start_dialogue() -> void:
	if _is_in_dialogue:
		return
	
	_is_in_dialogue = true
	dialogue_started.emit()
	interaction_requested.emit(self)
	
	if interaction_label:
		interaction_label.visible = false


func end_dialogue() -> void:
	_is_in_dialogue = false
	_dialogue_cooldown = 1.0  # 1 second cooldown before can talk again
	dialogue_ended.emit()
	
	if _player_nearby and interaction_label:
		interaction_label.visible = true


func get_dialogue() -> Array[Dictionary]:
	return NPCDialogues.get_dialogue(lesson_type as NPCDialogues.LessonType, "You")


# -----------------------------------------------------------------------------
# MOVEMENT METHODS
# -----------------------------------------------------------------------------
func _move_along_path(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		_arrive_at_destination()
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	direction.y = 0  # Keep movement horizontal
	
	if direction.length() > 0.1:
		# Rotate towards movement direction
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
		
		# Move
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		_is_moving = true
	else:
		velocity.x = 0
		velocity.z = 0
		_is_moving = false
	
	_update_animation(_is_moving)


func _pick_next_destination() -> void:
	var target_pos: Vector3
	
	if use_random_wander or patrol_points.is_empty():
		# Random wander within radius
		var random_offset = Vector3(
			randf_range(-wander_radius, wander_radius),
			0,
			randf_range(-wander_radius, wander_radius)
		)
		target_pos = _start_position + random_offset
	else:
		# Follow patrol points
		target_pos = patrol_points[_current_patrol_index]
		_current_patrol_index = (_current_patrol_index + 1) % patrol_points.size()
	
	navigation_agent.target_position = target_pos


func _arrive_at_destination() -> void:
	_is_waiting = true
	_wait_timer = randf_range(wait_time_min, wait_time_max)
	_is_moving = false
	velocity.x = 0
	velocity.z = 0
	_update_animation(false)


# -----------------------------------------------------------------------------
# ANIMATION METHODS
# -----------------------------------------------------------------------------
func _setup_animations() -> void:
	# Find skeleton in avatar
	_skeleton = _find_skeleton(avatar)
	
	# Find or create animation player
	_animation_player = _find_animation_player(avatar)
	if not _animation_player:
		_animation_player = AnimationPlayer.new()
		_animation_player.name = "NPCAnimationPlayer"
		add_child(_animation_player)
	
	# Load animations
	_load_external_animations()
	_animations_loaded = true
	
	# Start with idle
	_play_animation("Idle")


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null


func _load_external_animations() -> void:
	if not _animation_player or not _skeleton:
		return
	
	var animations_to_load = {
		"Walking": WALKING_ANIM_PATH,
		"Idle": IDLE_ANIM_PATH,
		"SadIdle": SAD_IDLE_ANIM_PATH
	}
	
	var anim_lib: AnimationLibrary
	if _animation_player.has_animation_library(""):
		anim_lib = _animation_player.get_animation_library("")
	else:
		anim_lib = AnimationLibrary.new()
		_animation_player.add_animation_library("", anim_lib)
	
	for anim_name in animations_to_load:
		var anim_path = animations_to_load[anim_name]
		if not ResourceLoader.exists(anim_path):
			continue
		
		var anim_scene = load(anim_path)
		if not anim_scene:
			continue
		
		var anim_instance = anim_scene.instantiate()
		var source_anim_player = _find_animation_player(anim_instance)
		
		if source_anim_player:
			for source_anim_name in source_anim_player.get_animation_list():
				var source_anim = source_anim_player.get_animation(source_anim_name)
				if source_anim:
					var new_anim = _retarget_animation(source_anim)
					if anim_lib.has_animation(anim_name):
						anim_lib.remove_animation(anim_name)
					anim_lib.add_animation(anim_name, new_anim)
					break
		
		anim_instance.queue_free()


func _retarget_animation(source_anim: Animation) -> Animation:
	var new_anim = source_anim.duplicate()
	new_anim.loop_mode = Animation.LOOP_LINEAR
	
	for track_idx in range(new_anim.get_track_count()):
		var track_path = new_anim.track_get_path(track_idx)
		var path_string = str(track_path)
		
		# Retarget to Avatar skeleton
		if "Skeleton3D" in path_string or "Armature" in path_string:
			var parts = path_string.split(":")
			if parts.size() >= 2:
				var bone_name = parts[1]
				var new_path = "Avatar/Armature/Skeleton3D:" + bone_name
				new_anim.track_set_path(track_idx, NodePath(new_path))
	
	return new_anim


func _update_animation(is_moving: bool) -> void:
	if not _animations_loaded:
		return
	
	if is_moving:
		_play_animation("Walking")
	else:
		# Randomly choose between Idle and SadIdle for variety
		if randf() < 0.3 and _animation_player.has_animation("SadIdle"):
			_play_animation("SadIdle")
		else:
			_play_animation("Idle")


func _play_animation(anim_name: String) -> void:
	if not _animation_player:
		return
	
	if _animation_player.has_animation(anim_name):
		if _animation_player.current_animation != anim_name:
			_animation_player.play(anim_name)
	elif _animation_player.has_animation(""):
		# Fallback to default
		pass
