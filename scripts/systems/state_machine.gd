# =============================================================================
# STATE MACHINE - Generic Finite State Machine
# =============================================================================
# Reusable state machine for player, enemies, NPCs, etc.
# Path: res://scripts/systems/state_machine.gd
# =============================================================================

extends Node
class_name StateMachine

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal state_changed(old_state: State, new_state: State)

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var initial_state: State

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var current_state: State
var states: Dictionary = {}

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	await owner.ready
	
	# Collect all State children
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.actor = owner
	
	# Initialize first state
	if initial_state:
		current_state = initial_state
		current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func transition_to(state_name: String, params: Dictionary = {}) -> void:
	var new_state: State = states.get(state_name.to_lower())
	
	if new_state == null:
		push_error("[StateMachine] State not found: " + state_name)
		return
	
	if new_state == current_state:
		return
	
	var old_state := current_state
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter(params)
	
	state_changed.emit(old_state, current_state)


func get_state(state_name: String) -> State:
	return states.get(state_name.to_lower())


func is_current_state(state_name: String) -> bool:
	return current_state and current_state.name.to_lower() == state_name.to_lower()
