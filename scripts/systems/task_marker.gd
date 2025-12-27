# =============================================================================
# TASK MARKER - Interactive Task Point
# =============================================================================
# Place in the world for avatars to interact with and complete tasks
# Path: res://scripts/systems/task_marker.gd
# =============================================================================

extends Area3D
class_name TaskMarker

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal task_triggered(marker: TaskMarker)
signal task_interaction_started(marker: TaskMarker, actor: Node3D)
signal task_interaction_completed(marker: TaskMarker, actor: Node3D)

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var task_id: String = "task_01"
@export var task_name: String = "Unnamed Task"
@export var task_description: String = "Complete this task"
@export var interaction_time: float = 2.0 # Time to complete task
@export var required_items: Array[String] = []
@export var reward_points: int = 10
@export var one_time_only: bool = true
@export var show_indicator: bool = true

# Visual settings
@export_group("Visuals")
@export var indicator_color: Color = Color.YELLOW
@export var indicator_height: float = 2.0

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var is_completed: bool = false
var is_being_used: bool = false
var current_actor: Node3D = null

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _interaction_progress: float = 0.0
var _indicator: MeshInstance3D

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if show_indicator:
		_create_indicator()


func _process(delta: float) -> void:
	if is_being_used and current_actor:
		_interaction_progress += delta
		
		if _interaction_progress >= interaction_time:
			_complete_interaction()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func start_interaction(actor: Node3D) -> bool:
	"""Start interacting with this task marker."""
	if is_completed and one_time_only:
		return false
	
	if is_being_used:
		return false
	
	# Check required items (implement inventory check here)
	# for item in required_items:
	#     if not actor has item:
	#         return false
	
	is_being_used = true
	current_actor = actor
	_interaction_progress = 0.0
	
	task_interaction_started.emit(self, actor)
	return true


func cancel_interaction() -> void:
	"""Cancel the current interaction."""
	is_being_used = false
	current_actor = null
	_interaction_progress = 0.0


func get_progress() -> float:
	"""Get interaction progress from 0.0 to 1.0."""
	if interaction_time <= 0:
		return 1.0
	return clamp(_interaction_progress / interaction_time, 0.0, 1.0)


func reset() -> void:
	"""Reset the task marker to initial state."""
	is_completed = false
	is_being_used = false
	current_actor = null
	_interaction_progress = 0.0
	
	if _indicator:
		_indicator.visible = show_indicator


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _complete_interaction() -> void:
	"""Complete the task interaction."""
	is_completed = true
	is_being_used = false
	
	task_interaction_completed.emit(self, current_actor)
	task_triggered.emit(self)
	
	# Hide indicator after completion
	if _indicator and one_time_only:
		_indicator.visible = false
	
	# Notify level if available
	var level := get_parent()
	while level and not level.has_method("complete_task"):
		level = level.get_parent()
	
	if level and level.has_method("complete_task"):
		level.complete_task(task_id)
	
	current_actor = null
	_interaction_progress = 0.0


func _on_body_entered(body: Node3D) -> void:
	"""Handle body entering the task area."""
	if body is CharacterBody3D:
		# Could show UI prompt here
		pass


func _on_body_exited(body: Node3D) -> void:
	"""Handle body leaving the task area."""
	if body == current_actor:
		cancel_interaction()


func _create_indicator() -> void:
	"""Create visual indicator above task marker."""
	_indicator = MeshInstance3D.new()
	
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 0.5
	_indicator.mesh = capsule
	
	var material := StandardMaterial3D.new()
	material.albedo_color = indicator_color
	material.emission_enabled = true
	material.emission = indicator_color
	material.emission_energy_multiplier = 2.0
	_indicator.material_override = material
	
	_indicator.position.y = indicator_height
	add_child(_indicator)
