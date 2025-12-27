# =============================================================================
# SCORE HUD - Futuristic Score Display
# =============================================================================
# Displays player score with futuristic styling in top-left corner
# Shows score changes with animated feedback
# Path: res://scripts/ui/score_hud.gd
# =============================================================================

extends CanvasLayer

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var score_panel: Panel = $ScorePanel
@onready var score_value: Label = $ScorePanel/MarginContainer/VBoxContainer/ScoreRow/ScoreValue
@onready var score_label: Label = $ScorePanel/MarginContainer/VBoxContainer/ScoreRow/ScoreLabel
@onready var streak_label: Label = $ScorePanel/MarginContainer/VBoxContainer/StreakLabel
@onready var delta_label: Label = $ScorePanel/DeltaLabel
@onready var glow_effect: Panel = $ScorePanel/GlowEffect
@onready var scan_line: ColorRect = $ScorePanel/ScanLine

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _displayed_score: int = 0
var _target_score: int = 0
var _score_tween: Tween

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect to GameManager score signal
	if has_node("/root/GameManager"):
		GameManager.score_changed.connect(_on_score_changed)
		_displayed_score = GameManager.current_score
		_target_score = GameManager.current_score
		_update_display()
	
	# Start ambient animations
	_start_ambient_animations()
	
	# Hide delta label initially
	delta_label.modulate.a = 0.0


func _process(delta: float) -> void:
	# Smoothly animate score value
	if _displayed_score != _target_score:
		var diff = _target_score - _displayed_score
		var change = sign(diff) * max(1, abs(diff) * delta * 8)
		
		if abs(diff) < 2:
			_displayed_score = _target_score
		else:
			_displayed_score += int(change)
		
		score_value.text = str(_displayed_score)


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func show_score_change(amount: int) -> void:
	"""Display score change with animation."""
	if amount == 0:
		return
	
	# Set delta text and color
	if amount > 0:
		delta_label.text = "+%d" % amount
		delta_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
		_flash_panel(Color(0.2, 1.0, 0.4, 0.3))
	else:
		delta_label.text = "%d" % amount
		delta_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
		_flash_panel(Color(1.0, 0.3, 0.3, 0.3))
	
	# Animate delta label
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in and float up
	delta_label.position.y = 0
	tween.tween_property(delta_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(delta_label, "position:y", -30.0, 1.5).set_ease(Tween.EASE_OUT)
	
	tween.set_parallel(false)
	tween.tween_interval(0.8)
	tween.tween_property(delta_label, "modulate:a", 0.0, 0.5)


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _on_score_changed(new_score: int, delta: int) -> void:
	"""Handle score change from GameManager."""
	_target_score = new_score
	show_score_change(delta)
	
	# Update streak display
	if has_node("/root/GameManager"):
		var stats = GameManager.get_score_stats()
		if stats.streak > 1:
			streak_label.text = "🔥 STREAK x%d" % stats.streak
			streak_label.visible = true
		else:
			streak_label.visible = false


func _update_display() -> void:
	"""Update all display elements."""
	score_value.text = str(_displayed_score)


func _flash_panel(color: Color) -> void:
	"""Flash the panel with a color."""
	var original_color = glow_effect.modulate
	var tween = create_tween()
	tween.tween_property(glow_effect, "modulate", color, 0.1)
	tween.tween_property(glow_effect, "modulate", Color(0, 1, 1, 0.3), 0.4)


func _start_ambient_animations() -> void:
	"""Start ambient scanning line animation."""
	var scan_tween = create_tween()
	scan_tween.set_loops()
	scan_tween.set_trans(Tween.TRANS_LINEAR)
	scan_tween.tween_property(scan_line, "position:y", 80.0, 3.0).from(0.0)
	
	# Subtle glow pulse
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow_effect, "modulate:a", 0.2, 1.5)
	glow_tween.tween_property(glow_effect, "modulate:a", 0.4, 1.5)
