# =============================================================================
# ROOM INTERIOR - Indoor Level Scene
# =============================================================================
# Interior room level where player can walk around
# Path: res://scripts/levels/room_interior.gd
# =============================================================================

extends Node3D

@export var player_scene: PackedScene
@export var spawn_player_on_ready: bool = true
@export var return_scene_path: String = "res://scenes/levels/modern_city.tscn"

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var entities: Node3D = $Entities
@onready var exit_door: Area3D = $ExitDoor

var _current_player: CharacterBody3D
var _player_in_exit_zone: bool = false


func _ready() -> void:
	# Connect exit door signal
	exit_door.body_entered.connect(_on_exit_door_body_entered)
	exit_door.body_exited.connect(_on_exit_door_body_exited)
	
	if spawn_player_on_ready:
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("===========================================")
	print("OLD ATTIC ROOM LOADED!")
	print("Controls: WASD = Move, Shift = Sprint, Mouse = Look, Space = Jump")
	print("Walk to the EXIT sign and press E to leave")
	print("===========================================")


func _input(event: InputEvent) -> void:
	# Check for exit interaction
	if event.is_action_pressed("interact") and _player_in_exit_zone:
		exit_room()
	# Fallback to E key if interact action doesn't exist
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E and _player_in_exit_zone:
		exit_room()


func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_error("[RoomInterior] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	_current_player.global_position = spawn_point.global_position
	
	print("[RoomInterior] Player spawned at ", spawn_point.global_position)
	return _current_player


func get_player() -> CharacterBody3D:
	return _current_player


func _on_exit_door_body_entered(body: Node3D) -> void:
	if body == _current_player:
		_player_in_exit_zone = true
		print("[RoomInterior] Player near exit - Press E to leave")


func _on_exit_door_body_exited(body: Node3D) -> void:
	if body == _current_player:
		_player_in_exit_zone = false


func exit_room() -> void:
	"""Exit the room and return to the city."""
	print("[RoomInterior] Exiting room...")
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.LOADING)
	
	get_tree().change_scene_to_file(return_scene_path)
