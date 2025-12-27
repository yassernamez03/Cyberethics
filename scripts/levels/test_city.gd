# =============================================================================
# TEST CITY - Simple Test Level
# =============================================================================
# Basic city scene for testing avatar walking
# Path: res://scripts/levels/test_city.gd
# =============================================================================

extends Node3D

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var player_scene: PackedScene
@export var spawn_player_on_ready: bool = true

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var entities: Node3D = $Entities
@onready var buildings: Node3D = $Buildings

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _current_player: CharacterBody3D

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Add collision to all buildings
	_setup_building_collision()
	
	if spawn_player_on_ready:
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("[TestCity] Level ready - WASD to move, Mouse to look, Space to jump")


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_warning("[TestCity] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	_current_player.global_position = spawn_point.global_position
	
	print("[TestCity] Player spawned at ", spawn_point.global_position)
	return _current_player


func get_player() -> CharacterBody3D:
	return _current_player


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _setup_building_collision() -> void:
	"""Add collision shapes to all building meshes."""
	for building in buildings.get_children():
		_add_collision_to_node(building)
	print("[TestCity] Building collisions setup complete")


func _add_collision_to_node(node: Node) -> void:
	"""Recursively add collision to mesh instances."""
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			mesh_instance.create_trimesh_collision()
	
	for child in node.get_children():
		_add_collision_to_node(child)
