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
var _phone_screen: CanvasLayer = null
var _notification_popup: CanvasLayer = null
var _score_hud: CanvasLayer = null
var _mobile_controller: CanvasLayer = null

const PHONE_SCREEN_SCENE := preload("res://scenes/ui/phone_screen.tscn")
const NOTIFICATION_POPUP_SCENE := preload("res://scenes/ui/notification_popup.tscn")
const SCORE_HUD_SCENE := preload("res://scenes/ui/score_hud.tscn")
const MOBILE_CONTROLLER_SCENE := preload("res://scenes/ui/mobile_controller.tscn")


func _ready() -> void:
	# Add collision to all buildings
	_setup_building_collision()
	
	# Setup phone screen UI
	_setup_phone_screen()
	
	# Setup score HUD
	_setup_score_hud()
	
	# Setup notification popup
	_setup_notification_popup()
	
	# Setup mobile controller (only shows on mobile devices)
	_setup_mobile_controller()
	
	if spawn_player_on_ready:
		await get_tree().physics_frame
		spawn_player()
	
	if has_node("/root/GameManager"):
		GameManager.change_state(GameManager.GameState.PLAYING)
	
	print("===========================================")
	print("KENNEY INDUSTRIAL CITY LOADED!")
	if InputManager.is_touch_device():
		print("Controls: Virtual Joystick = Move, Touch = Look, Buttons = Jump/Sprint/Interact")
	else:
		print("Controls: WASD = Move, Mouse = Look, Space = Jump")
	print("===========================================")


func _setup_phone_screen() -> void:
	"""Setup the phone screen UI for text message events."""
	_phone_screen = PHONE_SCREEN_SCENE.instantiate()
	add_child(_phone_screen)
	
	# Connect decision signal to scoring system
	if _phone_screen.has_signal("decision_made"):
		_phone_screen.decision_made.connect(_on_phone_decision_made)


func _setup_score_hud() -> void:
	"""Setup the score HUD display."""
	_score_hud = SCORE_HUD_SCENE.instantiate()
	add_child(_score_hud)


func _setup_notification_popup() -> void:
	"""Setup the notification popup and schedule first notification."""
	_notification_popup = NOTIFICATION_POPUP_SCENE.instantiate()
	add_child(_notification_popup)
	
	# Show notification after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if _notification_popup and is_instance_valid(_notification_popup):
		var hint_text := "Press [T] to open phone" if not InputManager.is_touch_device() else "Tap phone icon to open"
		_notification_popup.show_notification(
			"⚡ NEW MESSAGE",
			"You have unread messages waiting...",
			hint_text
		)


func _setup_mobile_controller() -> void:
	"""Setup mobile controller (only visible on mobile/touch devices)."""
	_mobile_controller = MOBILE_CONTROLLER_SCENE.instantiate()
	add_child(_mobile_controller)
	
	# Register with InputManager for global access
	if has_node("/root/InputManager"):
		InputManager.register_mobile_controller(_mobile_controller)
	
	if _mobile_controller.visible:
		print("[KenneyCity] Mobile controller enabled")
	else:
		print("[KenneyCity] Mobile controller hidden (desktop mode)")


func spawn_player() -> CharacterBody3D:
	if player_scene == null:
		push_error("[KenneyCity] No player scene assigned!")
		return null
	
	_current_player = player_scene.instantiate()
	entities.add_child(_current_player)
	_current_player.global_position = spawn_point.global_position
	
	# Connect text_received signal to show phone screen
	if _current_player.has_signal("text_received"):
		_current_player.text_received.connect(_on_player_text_received)
		print("[KenneyCity] Connected to player text_received signal")
	
	print("[KenneyCity] Player spawned at ", spawn_point.global_position)
	return _current_player


func _on_player_text_received() -> void:
	"""Called when player receives a phishing text message."""
	if _phone_screen:
		# Show the phishing message with default content
		_phone_screen.show_message()


func _on_phone_decision_made(was_correct: bool) -> void:
	"""Handle player's decision on phishing message."""
	if has_node("/root/GameManager"):
		GameManager.record_decision(was_correct)


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
