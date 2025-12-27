# =============================================================================
# CITY LEVEL - Urban Map Controller
# =============================================================================
# Controls the city level with navigation and task system
# Path: res://scripts/levels/city_level.gd
# =============================================================================

extends Node3D

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal player_spawned(player: CharacterBody3D)
signal task_started(task_id: String)
signal task_completed(task_id: String)

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var player_scene: PackedScene
@export var spawn_player_on_ready: bool = true
@export var spawn_height_offset: float = 2.0

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var entities: Node3D = $Entities
@onready var city_map: Node3D = $CityMap
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _current_player: CharacterBody3D
var _active_tasks: Dictionary = {}
var _task_locations: Dictionary = {} # task_id -> Vector3

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	_setup_map_collision()
	_setup_navigation()
	
	if spawn_player_on_ready:
		# Wait a frame for physics to initialize
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("[CityLevel] City loaded successfully")


# -----------------------------------------------------------------------------
# PUBLIC METHODS - Player
# -----------------------------------------------------------------------------
func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_warning("[CityLevel] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	
	# Position player at spawn point with height offset
	var spawn_pos := spawn_point.global_position
	spawn_pos.y += spawn_height_offset
	_current_player.global_position = spawn_pos
	
	player_spawned.emit(_current_player)
	print("[CityLevel] Player spawned at ", spawn_pos)
	
	return _current_player


func get_player() -> CharacterBody3D:
	return _current_player


func respawn_player() -> void:
	if _current_player:
		var spawn_pos := spawn_point.global_position
		spawn_pos.y += spawn_height_offset
		_current_player.global_position = spawn_pos


# -----------------------------------------------------------------------------
# PUBLIC METHODS - Tasks
# -----------------------------------------------------------------------------
func register_task(task_id: String, location: Vector3, data: Dictionary = {}) -> void:
	"""Register a task at a specific location in the city."""
	_task_locations[task_id] = location
	_active_tasks[task_id] = {
		"id": task_id,
		"location": location,
		"data": data,
		"completed": false
	}


func start_task(task_id: String) -> bool:
	"""Start a task by ID."""
	if not _active_tasks.has(task_id):
		return false
	
	task_started.emit(task_id)
	return true


func complete_task(task_id: String) -> bool:
	"""Mark a task as completed."""
	if not _active_tasks.has(task_id):
		return false
	
	_active_tasks[task_id].completed = true
	task_completed.emit(task_id)
	return true


func get_task_location(task_id: String) -> Vector3:
	"""Get the world position of a task."""
	return _task_locations.get(task_id, Vector3.ZERO)


func get_all_tasks() -> Array:
	"""Get all registered tasks."""
	return _active_tasks.values()


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _setup_map_collision() -> void:
	"""Generate collision shapes from the map mesh."""
	if city_map == null:
		return
	
	# Find all MeshInstance3D nodes and create static body collisions
	_add_collision_recursive(city_map)
	print("[CityLevel] Collision setup complete")


func _add_collision_recursive(node: Node) -> void:
	"""Recursively add collision to mesh instances."""
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		
		# Check if it already has a collision sibling
		var has_collision := false
		for sibling in node.get_parent().get_children():
			if sibling is StaticBody3D or sibling is CollisionShape3D:
				has_collision = true
				break
		
		if not has_collision and mesh_instance.mesh:
			# Create static body with trimesh collision
			mesh_instance.create_trimesh_collision()
	
	# Recurse into children
	for child in node.get_children():
		_add_collision_recursive(child)


func _setup_navigation() -> void:
	"""Setup navigation mesh for AI pathfinding."""
	if nav_region == null:
		return
	
	# Create navigation mesh from geometry
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	
	nav_region.navigation_mesh = nav_mesh
	
	# Bake navigation in background (can be slow for large maps)
	# Uncomment when ready:
	# nav_region.bake_navigation_mesh()
	
	print("[CityLevel] Navigation region configured")
