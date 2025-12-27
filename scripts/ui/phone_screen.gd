# =============================================================================
# PHONE SCREEN UI - iPhone-style phishing message overlay
# =============================================================================
# Displays an iPhone-style phone screen with phishing message when triggered
# Path: res://scripts/ui/phone_screen.gd
# =============================================================================

extends CanvasLayer

signal dismissed

@onready var background: ColorRect = $Background
@onready var phone_frame: Panel = $PhoneFrame
@onready var message_label: Label = $PhoneFrame/ScreenArea/MessagesArea/MessagesContainer/MessageBubble/MarginContainer/MessageLabel
@onready var contact_name: Label = $PhoneFrame/ScreenArea/MessageHeader/ContactName
@onready var time_label: Label = $PhoneFrame/ScreenArea/StatusBar/Time
@onready var time_stamp: Label = $PhoneFrame/ScreenArea/MessagesArea/MessagesContainer/TimeLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _can_dismiss: bool = false


func _ready() -> void:
	# Update time to current
	var time = Time.get_time_dict_from_system()
	var hour_12 = time.hour if time.hour <= 12 else time.hour - 12
	if hour_12 == 0:
		hour_12 = 12
	var am_pm = "AM" if time.hour < 12 else "PM"
	time_label.text = "%d:%02d" % [hour_12, time.minute]
	time_stamp.text = "%d:%02d %s" % [hour_12, time.minute, am_pm]
	
	# Initially hidden
	visible = false
	
	# Setup animations
	_setup_animations()


func _setup_animations() -> void:
	# Create show animation
	var show_anim = Animation.new()
	show_anim.length = 0.5
	
	# Background fade in
	var bg_track = show_anim.add_track(Animation.TYPE_VALUE)
	show_anim.track_set_path(bg_track, "Background:modulate")
	show_anim.track_insert_key(bg_track, 0.0, Color(1, 1, 1, 0))
	show_anim.track_insert_key(bg_track, 0.3, Color(1, 1, 1, 1))
	
	# Phone slide up
	var phone_track = show_anim.add_track(Animation.TYPE_VALUE)
	show_anim.track_set_path(phone_track, "PhoneFrame:offset_top")
	show_anim.track_insert_key(phone_track, 0.0, 400.0)
	show_anim.track_insert_key(phone_track, 0.4, -320.0)
	show_anim.track_set_interpolation_type(phone_track, Animation.INTERPOLATION_CUBIC)
	
	var phone_track2 = show_anim.add_track(Animation.TYPE_VALUE)
	show_anim.track_set_path(phone_track2, "PhoneFrame:offset_bottom")
	show_anim.track_insert_key(phone_track2, 0.0, 1040.0)
	show_anim.track_insert_key(phone_track2, 0.4, 320.0)
	show_anim.track_set_interpolation_type(phone_track2, Animation.INTERPOLATION_CUBIC)
	
	# Create hide animation
	var hide_anim = Animation.new()
	hide_anim.length = 0.3
	
	# Background fade out
	var bg_track2 = hide_anim.add_track(Animation.TYPE_VALUE)
	hide_anim.track_set_path(bg_track2, "Background:modulate")
	hide_anim.track_insert_key(bg_track2, 0.0, Color(1, 1, 1, 1))
	hide_anim.track_insert_key(bg_track2, 0.3, Color(1, 1, 1, 0))
	
	# Phone slide down
	var phone_track3 = hide_anim.add_track(Animation.TYPE_VALUE)
	hide_anim.track_set_path(phone_track3, "PhoneFrame:offset_top")
	hide_anim.track_insert_key(phone_track3, 0.0, -320.0)
	hide_anim.track_insert_key(phone_track3, 0.3, 400.0)
	
	var phone_track4 = hide_anim.add_track(Animation.TYPE_VALUE)
	hide_anim.track_set_path(phone_track4, "PhoneFrame:offset_bottom")
	hide_anim.track_insert_key(phone_track4, 0.0, 320.0)
	hide_anim.track_insert_key(phone_track4, 0.3, 1040.0)
	
	# Add animations to library
	var lib = AnimationLibrary.new()
	lib.add_animation("show", show_anim)
	lib.add_animation("hide", hide_anim)
	animation_player.add_animation_library("", lib)


func show_message(sender: String = "", message: String = "") -> void:
	"""Display the phone screen with a phishing message."""
	if message != "":
		message_label.text = message
	if sender != "":
		contact_name.text = sender
	
	visible = true
	_can_dismiss = false
	
	# Pause the game
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Release mouse for UI interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Play show animation
	animation_player.play("show")
	
	# Allow dismiss after animation
	await animation_player.animation_finished
	_can_dismiss = true
	
	print("Phone screen displayed - Press SPACE to dismiss")


func hide_phone() -> void:
	"""Hide the phone screen and resume game."""
	if not _can_dismiss:
		return
	
	_can_dismiss = false
	
	# Play hide animation
	animation_player.play("hide")
	await animation_player.animation_finished
	
	visible = false
	
	# Resume the game
	get_tree().paused = false
	
	# Recapture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	dismissed.emit()
	print("Phone dismissed - Resuming gameplay")


func _input(event: InputEvent) -> void:
	if not visible or not _can_dismiss:
		return
	
	# Dismiss on space, enter, or click
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		hide_phone()
	elif event is InputEventMouseButton and event.pressed:
		hide_phone()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _can_dismiss:
		return
	
	# Also catch escape to dismiss
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		hide_phone()
