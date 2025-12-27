# =============================================================================
# KENNEY CITY - Industrial City Level
# =============================================================================
# City level using Kenney industrial kit buildings
# Path: res://scripts/levels/kenney_city.gd
# =============================================================================

extends Node3D

@export var player_scene: PackedScene
@export var spawn_player_on_ready: bool = true

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var entities: Node3D = $Entities
@onready var buildings: Node3D = $Buildings

var _current_player: CharacterBody3D


func _ready() -> void:
	# Add collision to all buildings
	_setup_building_collision()
	
	if spawn_player_on_ready:
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("===========================================")
	print("KENNEY INDUSTRIAL CITY LOADED!")
	print("Controls: WASD = Move, Mouse = Look, Space = Jump")
	print("===========================================")


func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_error("[KenneyCity] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	_current_player.global_position = spawn_point.global_position
	
	print("[KenneyCity] Player spawned at ", spawn_point.global_position)
	return _current_player


func get_player() -> CharacterBody3D:
	return _current_player


func _setup_building_collision() -> void:
	"""Add collision shapes to all building meshes."""
	for building in buildings.get_children():
		_add_collision_to_node(building)
	print("[KenneyCity] Building collisions created")


func _add_collision_to_node(node: Node) -> void:
	"""Recursively add collision to mesh instances."""
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			mesh_instance.create_trimesh_collision()
	
	for child in node.get_children():
		_add_collision_to_node(child)
