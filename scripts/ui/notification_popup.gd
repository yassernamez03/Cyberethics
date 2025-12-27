# =============================================================================
# NOTIFICATION POPUP - Futuristic Notification System
# =============================================================================
# Displays futuristic-style notifications in the top right corner
# Path: res://scripts/ui/notification_popup.gd
# =============================================================================

extends CanvasLayer

signal notification_dismissed

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var notification_panel: Panel = $NotificationPanel
@onready var icon_label: Label = $NotificationPanel/MarginContainer/HBoxContainer/IconLabel
@onready var title_label: Label = $NotificationPanel/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $NotificationPanel/MarginContainer/HBoxContainer/VBoxContainer/MessageLabel
@onready var key_hint: Label = $NotificationPanel/MarginContainer/HBoxContainer/VBoxContainer/KeyHint
@onready var glow_effect: Panel = $NotificationPanel/GlowEffect
@onready var scan_line: ColorRect = $NotificationPanel/ScanLine

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
@export var display_duration: float = 6.0
@export var slide_in_duration: float = 0.4
@export var slide_out_duration: float = 0.3

# -----------------------------------------------------------------------------
# PRIVATE VARIABLES
# -----------------------------------------------------------------------------
var _is_showing: bool = false
var _tween: Tween

# -----------------------------------------------------------------------------
# LIFECYCLE METHODS
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	notification_panel.modulate.a = 0.0
	_setup_initial_position()
	_start_scan_line_animation()


func _input(event: InputEvent) -> void:
	# Dismiss notification when pressing T to open phone
	if _is_showing and event is InputEventKey and event.pressed and event.keycode == KEY_T:
		hide_notification()


# -----------------------------------------------------------------------------
# PUBLIC METHODS
# -----------------------------------------------------------------------------
func show_notification(title: String = "NEW MESSAGE", message: String = "You have a new message!", hint: String = "Press [T] to open phone") -> void:
	if _is_showing:
		return
	
	title_label.text = title
	message_label.text = message
	key_hint.text = hint
	
	visible = true
	_is_showing = true
	
	# Play notification sound
	if has_node("/root/AudioManager"):
		AudioManager.play_notification_sound()
	
	_animate_show()


func hide_notification() -> void:
	if not _is_showing:
		return
	
	_animate_hide()


# -----------------------------------------------------------------------------
# PRIVATE METHODS
# -----------------------------------------------------------------------------
func _setup_initial_position() -> void:
	notification_panel.anchor_left = 1.0
	notification_panel.anchor_right = 1.0
	notification_panel.anchor_top = 0.0
	notification_panel.anchor_bottom = 0.0
	notification_panel.offset_left = -420
	notification_panel.offset_right = -20
	notification_panel.offset_top = -150  # Start above screen
	notification_panel.offset_bottom = 0


func _animate_show() -> void:
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	
	# Slide in from top
	_tween.tween_property(notification_panel, "offset_top", 20.0, slide_in_duration)
	_tween.tween_property(notification_panel, "offset_bottom", 130.0, slide_in_duration)
	
	# Fade in
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(notification_panel, "modulate:a", 1.0, slide_in_duration * 0.5)
	
	# Glow pulse effect
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(glow_effect, "modulate:a", 0.8, slide_in_duration)
	
	_tween.set_parallel(false)
	
	# Start auto-hide timer
	_tween.tween_callback(_start_glow_pulse)
	_tween.tween_interval(display_duration)
	_tween.tween_callback(hide_notification)


func _animate_hide() -> void:
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_BACK)
	
	# Slide out to top
	_tween.tween_property(notification_panel, "offset_top", -150.0, slide_out_duration)
	_tween.tween_property(notification_panel, "offset_bottom", 0.0, slide_out_duration)
	
	# Fade out
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(notification_panel, "modulate:a", 0.0, slide_out_duration)
	
	_tween.set_parallel(false)
	_tween.tween_callback(_on_hide_complete)


func _on_hide_complete() -> void:
	visible = false
	_is_showing = false
	notification_dismissed.emit()


func _start_glow_pulse() -> void:
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow_effect, "modulate:a", 0.4, 0.8)
	glow_tween.tween_property(glow_effect, "modulate:a", 0.8, 0.8)


func _start_scan_line_animation() -> void:
	var scan_tween = create_tween()
	scan_tween.set_loops()
	scan_tween.set_trans(Tween.TRANS_LINEAR)
	scan_tween.tween_property(scan_line, "position:y", 110.0, 2.0).from(0.0)
