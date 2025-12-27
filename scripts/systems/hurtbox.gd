# =============================================================================
# HURTBOX COMPONENT - Damage Receiving
# =============================================================================
# Attach to anything that can receive damage
# Path: res://scripts/systems/hurtbox.gd
# =============================================================================

extends Area3D
class_name Hurtbox

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal hit_received(hit_data: Dictionary)
signal invincibility_started
signal invincibility_ended

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var owner_group: String = "player"
@export var invincibility_duration: float = 0.5

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var is_invincible: bool = false

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Ensure proper collision setup
	pass


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func take_hit(hit_data: Dictionary) -> void:
	if is_invincible:
		return
	
	hit_received.emit(hit_data)
	
	if invincibility_duration > 0:
		_start_invincibility()


func set_invincible(duration: float) -> void:
	is_invincible = true
	invincibility_started.emit()
	
	await get_tree().create_timer(duration).timeout
	
	is_invincible = false
	invincibility_ended.emit()


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _start_invincibility() -> void:
	set_invincible(invincibility_duration)
