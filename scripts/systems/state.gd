# =============================================================================
# STATE - Base State Class
# =============================================================================
# Base class for all states used with StateMachine
# Path: res://scripts/systems/state.gd
# =============================================================================

extends Node
class_name State

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var state_machine: StateMachine
var actor: Node # The parent entity (Player, Enemy, etc.)

# -----------------------------------------------------------------------------
# VIRTUAL METHODS - Override these in child states
# -----------------------------------------------------------------------------

## Called when entering this state
func enter(_params: Dictionary = {}) -> void:
	pass


## Called when exiting this state
func exit() -> void:
	pass


## Called every frame (_process)
func update(_delta: float) -> void:
	pass


## Called every physics frame (_physics_process)
func physics_update(_delta: float) -> void:
	pass


## Called for unhandled input events
func handle_input(_event: InputEvent) -> void:
	pass
