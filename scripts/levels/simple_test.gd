# =============================================================================
# SIMPLE TEST - Basic Test Level
# =============================================================================
# Simple map with box buildings for basic testing
# Path: res://scripts/levels/simple_test.gd
# =============================================================================

extends Node3D

@export var player_scene: PackedScene
@export var spawn_player_on_ready: bool = true

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var entities: Node3D = $Entities

var _current_player: CharacterBody3D
var _mobile_controller: CanvasLayer = null

const MOBILE_CONTROLLER_SCENE := preload("res://scenes/ui/mobile_controller.tscn")


func _ready() -> void:
	# Setup mobile controller (only shows on mobile devices)
	_setup_mobile_controller()
	
	if spawn_player_on_ready:
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("===========================================")
	print("SIMPLE TEST LEVEL LOADED!")
	if InputManager.is_touch_device():
		print("Controls: Virtual Joystick = Move, Touch = Look, Buttons = Actions")
	else:
		print("Controls: WASD = Move, Mouse = Look, Space = Jump")
	print("===========================================")


func _setup_mobile_controller() -> void:
	"""Setup mobile controller (only visible on mobile/touch devices)."""
	_mobile_controller = MOBILE_CONTROLLER_SCENE.instantiate()
	add_child(_mobile_controller)
	
	# Register with InputManager for global access
	if has_node("/root/InputManager"):
		InputManager.register_mobile_controller(_mobile_controller)


func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_error("[SimpleTest] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	_current_player.global_position = spawn_point.global_position
	
	print("[SimpleTest] Player spawned!")
	return _current_player


func get_player() -> CharacterBody3D:
	return _current_player
