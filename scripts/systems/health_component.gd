# =============================================================================
# HEALTH COMPONENT - Health Management
# =============================================================================
# Attach to any entity with health
# Path: res://scripts/systems/health_component.gd
# =============================================================================

extends Node
class_name HealthComponent

# -----------------------------------------------------------------------------
# SIGNALS
# -----------------------------------------------------------------------------
signal health_changed(current: float, maximum: float)
signal damage_taken(amount: float, source: Dictionary)
signal healed(amount: float)
signal died
signal revived

# -----------------------------------------------------------------------------
# EXPORTED VARIABLES
# -----------------------------------------------------------------------------
@export var max_health: float = 100.0
@export var starting_health: float = -1.0 # -1 means use max_health
@export var can_overheal: bool = false
@export var regeneration_rate: float = 0.0 # HP per second
@export var regeneration_delay: float = 3.0 # Seconds after damage

# -----------------------------------------------------------------------------
# PUBLIC VARIABLES
# -----------------------------------------------------------------------------
var current_health: float:
	set(value):
		var old_health := current_health
		if can_overheal:
			current_health = max(0.0, value)
		else:
			current_health = clamp(value, 0.0, max_health)
		
		if current_health != old_health:
			health_changed.emit(current_health, max_health)

var is_dead: bool:
	get:
		return current_health <= 0.0

var health_percentage: float:
	get:
		return current_health / max_health if max_health > 0 else 0.0

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _regeneration_timer: float = 0.0
var _can_regenerate: bool = true

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	if starting_health < 0:
		current_health = max_health
	else:
		current_health = starting_health


func _process(delta: float) -> void:
	if regeneration_rate > 0 and _can_regenerate and not is_dead:
		_handle_regeneration(delta)


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func take_damage(amount: float, source: Dictionary = {}) -> float:
	if is_dead or amount <= 0:
		return 0.0
	
	var actual_damage := minf(amount, current_health)
	current_health -= actual_damage
	
	damage_taken.emit(actual_damage, source)
	
	# Reset regeneration delay
	_regeneration_timer = regeneration_delay
	_can_regenerate = false
	
	if is_dead:
		died.emit()
	
	return actual_damage


func heal(amount: float) -> float:
	if is_dead or amount <= 0:
		return 0.0
	
	var max_heal := max_health - current_health if not can_overheal else amount
	var actual_heal := minf(amount, max_heal)
	
	current_health += actual_heal
	healed.emit(actual_heal)
	
	return actual_heal


func revive(health_percent: float = 1.0) -> void:
	if not is_dead:
		return
	
	current_health = max_health * clamp(health_percent, 0.1, 1.0)
	revived.emit()


func kill() -> void:
	take_damage(current_health + 1)


func set_max_health(new_max: float, heal_to_max: bool = false) -> void:
	max_health = max(1.0, new_max)
	if heal_to_max:
		current_health = max_health
	else:
		current_health = minf(current_health, max_health)


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _handle_regeneration(delta: float) -> void:
	if _regeneration_timer > 0:
		_regeneration_timer -= delta
		if _regeneration_timer <= 0:
			_can_regenerate = true
	
	if _can_regenerate and current_health < max_health:
		heal(regeneration_rate * delta)
