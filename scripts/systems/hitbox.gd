# =============================================================================
# HITBOX COMPONENT - Attack/Damage Dealing
# =============================================================================
# Attach to anything that can deal damage
# Path: res://scripts/systems/hitbox.gd
# =============================================================================

extends Area3D
class_name Hitbox

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal hit_landed(hurtbox: Hurtbox)

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var damage: float = 10.0
@export var knockback_force: float = 5.0
@export var hit_stun_duration: float = 0.2
@export var damage_type: String = "physical"
@export var owner_group: String = "player" # Used to prevent self-damage

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var is_active: bool = false:
	set(value):
		is_active = value
		monitoring = value
		monitorable = value

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	is_active = false


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func activate(duration: float = -1.0) -> void:
	is_active = true
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		deactivate()


func deactivate() -> void:
	is_active = false


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox:
		var hurtbox := area as Hurtbox
		
		# Don't hit self or allies
		if hurtbox.owner_group == owner_group:
			return
		
		var hit_data := {
			"damage": damage,
			"knockback_force": knockback_force,
			"hit_stun_duration": hit_stun_duration,
			"damage_type": damage_type,
			"hit_position": global_position,
			"hit_direction": (hurtbox.global_position - global_position).normalized(),
		}
		
		hurtbox.take_hit(hit_data)
		hit_landed.emit(hurtbox)
