# =============================================================================
# GAME WORLD - Level Controller
# =============================================================================
# Controls the game world level
# Path: res://scripts/levels/game_world.gd
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

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _current_player: CharacterBody3D

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	if spawn_player_on_ready:
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_warning("[GameWorld] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	_current_player.global_position = spawn_point.global_position
	
	return _current_player


func get_player() -> CharacterBody3D:
	return _current_player


func respawn_player() -> void:
	if _current_player:
		_current_player.global_position = spawn_point.global_position
