# =============================================================================
# MODERN CITY - Commercial City Level
# =============================================================================
# City level using Kenney commercial kit buildings with skyscrapers
# Path: res://scripts/levels/modern_city.gd
# =============================================================================

extends Node3D

@export var player_scene: PackedScene
@export var spawn_player_on_ready: bool = true
@export var room_scene_path: String = "res://scenes/levels/room_interior.tscn"

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var entities: Node3D = $Entities
@onready var buildings: Node3D = $Buildings

var _current_player: CharacterBody3D
var _player_in_entrance_zone: bool = false
var _current_entrance: Area3D = null


func _ready() -> void:
	# Add collision to all buildings
	_setup_building_collision()
	
	# Setup building entrances
	_setup_building_entrances()
	
	if spawn_player_on_ready:
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("===========================================")
	print("MODERN COMMERCIAL CITY LOADED!")
	print("Controls: WASD = Move, Shift = Sprint, Mouse = Look, Space = Jump")
	print("Press E near SkyF3 building entrance to enter")
	print("===========================================")


func _input(event: InputEvent) -> void:
	# Check for building entrance interaction
	if event.is_action_pressed("interact") and _player_in_entrance_zone:
		enter_building()
	# Fallback to E key if interact action doesn't exist
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E and _player_in_entrance_zone:
		enter_building()


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


func _setup_building_entrances() -> void:
	"""Setup entrance triggers for enterable buildings."""
	var skyf3_entrance = buildings.get_node_or_null("OuterRing/SkyF3Entrance")
	if skyf3_entrance:
		skyf3_entrance.body_entered.connect(_on_entrance_body_entered.bind(skyf3_entrance))
		skyf3_entrance.body_exited.connect(_on_entrance_body_exited.bind(skyf3_entrance))
		print("[ModernCity] SkyF3 entrance configured")


func _on_entrance_body_entered(body: Node3D, entrance: Area3D) -> void:
	if body == _current_player:
		_player_in_entrance_zone = true
		_current_entrance = entrance
		print("[ModernCity] Player near building entrance - Press E to enter")


func _on_entrance_body_exited(body: Node3D, entrance: Area3D) -> void:
	if body == _current_player and _current_entrance == entrance:
		_player_in_entrance_zone = false
		_current_entrance = null


func enter_building() -> void:
	"""Enter the building and switch to room scene."""
	print("[ModernCity] Entering building...")
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.LOADING)
	
	get_tree().change_scene_to_file(room_scene_path)
