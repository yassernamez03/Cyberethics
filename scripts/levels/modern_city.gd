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
@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D

var _current_player: CharacterBody3D
var _player_in_entrance_zone: bool = false
var _current_entrance: Area3D = null
var _phone_screen: CanvasLayer = null
var _notification_popup: CanvasLayer = null
var _score_hud: CanvasLayer = null
var _dialogue_ui: CanvasLayer = null
var _current_dialogue_npc: Node3D = null

const PHONE_SCREEN_SCENE := preload("res://scenes/ui/phone_screen.tscn")
const NOTIFICATION_POPUP_SCENE := preload("res://scenes/ui/notification_popup.tscn")
const SCORE_HUD_SCENE := preload("res://scenes/ui/score_hud.tscn")
const DIALOGUE_UI_SCENE := preload("res://scenes/ui/dialogue_ui.tscn")


func _ready() -> void:
	# Add collision to all buildings
	_setup_building_collision()
	
	# Setup building entrances
	_setup_building_entrances()
	
	# Bake navigation mesh for NPCs
	_bake_navigation()
	
	# Setup phone screen UI
	_setup_phone_screen()
	
	# Setup score HUD
	_setup_score_hud()
	
	# Setup notification popup
	_setup_notification_popup()
	
	# Setup dialogue UI
	_setup_dialogue_ui()
	
	# Connect NPCs to dialogue system
	_connect_npcs()
	
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
		_notification_popup.show_notification(
			"⚡ NEW MESSAGE",
			"You have unread messages waiting...",
			"Press [T] to open phone"
		)


func _setup_dialogue_ui() -> void:
	"""Setup the dialogue UI for NPC conversations."""
	_dialogue_ui = DIALOGUE_UI_SCENE.instantiate()
	add_child(_dialogue_ui)
	
	# Connect dialogue finished signal
	if _dialogue_ui.has_signal("dialogue_finished"):
		_dialogue_ui.dialogue_finished.connect(_on_dialogue_completed)


func _connect_npcs() -> void:
	"""Connect all NPCs to the dialogue system."""
	# Find all NPCs in the Entities node
	for child in entities.get_children():
		if child.has_signal("interaction_requested"):
			child.interaction_requested.connect(_on_npc_interaction_requested)
			print("[ModernCity] Connected NPC: ", child.name)
	
	# Also check NPCs node if it exists
	var npcs_node = get_node_or_null("NPCs")
	if npcs_node:
		for child in npcs_node.get_children():
			if child.has_signal("interaction_requested"):
				child.interaction_requested.connect(_on_npc_interaction_requested)
				print("[ModernCity] Connected NPC: ", child.name)


func _on_npc_interaction_requested(npc: Node3D) -> void:
	"""Handle NPC interaction request - start dialogue."""
	if _dialogue_ui and npc.has_method("get_dialogue"):
		_current_dialogue_npc = npc
		var dialogue = npc.get_dialogue()
		_dialogue_ui.start_dialogue(dialogue)
		
		# Freeze player movement during dialogue
		if _current_player and _current_player.has_method("set_can_move"):
			_current_player.set_can_move(false)


func _on_dialogue_completed() -> void:
	"""Handle dialogue completion."""
	# End dialogue on NPC
	if _current_dialogue_npc and _current_dialogue_npc.has_method("end_dialogue"):
		_current_dialogue_npc.end_dialogue()
	_current_dialogue_npc = null
	
	# Unfreeze player movement
	if _current_player and _current_player.has_method("set_can_move"):
		_current_player.set_can_move(true)


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
	
	# Connect text_received signal to show phone screen
	if _current_player.has_signal("text_received"):
		_current_player.text_received.connect(_on_player_text_received)
		print("[ModernCity] Connected to player text_received signal")
	
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


func _bake_navigation() -> void:
	"""Bake the navigation mesh for NPC pathfinding."""
	if navigation_region and navigation_region.navigation_mesh:
		# Create a simple flat navigation mesh for the streets
		var nav_mesh = NavigationMesh.new()
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_height = 2.0
		nav_mesh.agent_max_climb = 0.5
		nav_mesh.agent_max_slope = 45.0
		
		# Bake from geometry
		navigation_region.navigation_mesh = nav_mesh
		navigation_region.bake_navigation_mesh()
		print("[ModernCity] Navigation mesh baked for NPCs")


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
