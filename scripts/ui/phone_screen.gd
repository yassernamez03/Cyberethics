# =============================================================================
# PHONE SCREEN UI - iPhone-style phishing message with decision
# =============================================================================
# Displays an iPhone-style phone screen with phishing message
# User must make a Yes/No decision - teaches about phishing awareness
# Path: res://scripts/ui/phone_screen.gd
# =============================================================================

extends CanvasLayer

signal dismissed
signal decision_made(was_correct: bool)

@onready var background: ColorRect = $Background
@onready var phone_frame: Panel = $PhoneFrame
@onready var message_label: Label = $PhoneFrame/ScreenArea/MessagesArea/MessagesContainer/BubbleRow/MessageBubble/MarginContainer/MessageLabel
@onready var contact_name: Label = $PhoneFrame/ScreenArea/NavBar/ContactName
@onready var time_label: Label = $PhoneFrame/ScreenArea/StatusBar/Time
@onready var date_label: Label = $PhoneFrame/ScreenArea/MessagesArea/MessagesContainer/DateLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var yes_button: Button = $PhoneFrame/ScreenArea/InputBarBg/DecisionCard/Content/ButtonsContainer/YesButton
@onready var no_button: Button = $PhoneFrame/ScreenArea/InputBarBg/DecisionCard/Content/ButtonsContainer/NoButton
@onready var result_overlay: Panel = $ResultOverlay
@onready var result_icon: Label = $ResultOverlay/ResultContent/ResultIcon
@onready var result_title: Label = $ResultOverlay/ResultContent/ResultTitle
@onready var result_message: Label = $ResultOverlay/ResultContent/ResultMessage

var _can_dismiss: bool = false
var _showing_result: bool = false

# Sarcastic messages for when user falls for phishing (Moroccan Arabic)
const FAIL_MESSAGES := [
	"أُوف… شدّوك فالفخ 😬\nهادي فيشينغ!",
	"آي آي… تبلعتي الطُّعم 🎣\nرد بالك المرة الجاية!",
	"هاك شنو دار فيك الرابط 😅\nطاحتي فالفخ.",
]

# Success messages for avoiding phishing (Moroccan Arabic)
const SUCCESS_MESSAGES := [
	"برافو عليك! 🔐\nنْجّيتي راسك من الشفّارة!",
	"واعر بزاف! 🤝\nما طاحشتيش فالفخ.",
	"سْمَحْ ليهم 😂\nعينك فايقة وما تضحكوش عليك.",
]


func _ready() -> void:
	# Update time to current
	var time = Time.get_time_dict_from_system()
	var hour_12 = time.hour if time.hour <= 12 else time.hour - 12
	if hour_12 == 0:
		hour_12 = 12
	var am_pm = "AM" if time.hour < 12 else "PM"
	time_label.text = "%d:%02d" % [hour_12, time.minute]
	date_label.text = "Today %d:%02d %s" % [hour_12, time.minute, am_pm]
	
	# Connect button signals
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	
	# Initially hidden
	visible = false
	result_overlay.visible = false
	
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
	
	# Reset state
	_showing_result = false
	result_overlay.visible = false
	yes_button.disabled = false
	no_button.disabled = false
	
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
	
	print("📱 Phone screen displayed - Make your choice!")


func _on_yes_pressed() -> void:
	"""User chose YES - they fell for the phishing attack!"""
	if not _can_dismiss:
		return
	
	yes_button.disabled = true
	no_button.disabled = true
	_showing_result = true
	
	# Show failure result
	_show_result(false)
	
	decision_made.emit(false)
	print("❌ User fell for the phishing attack!")


func _on_no_pressed() -> void:
	"""User chose NO - they avoided the phishing attack!"""
	if not _can_dismiss:
		return
	
	yes_button.disabled = true
	no_button.disabled = true
	_showing_result = true
	
	# Show success result
	_show_result(true)
	
	decision_made.emit(true)
	print("✅ User avoided the phishing attack!")


func _show_result(success: bool) -> void:
	"""Show the result overlay with appropriate message."""
	if success:
		# Success - avoided phishing
		result_overlay.add_theme_stylebox_override("panel", _create_success_style())
		result_icon.text = "🛡️"
		result_title.text = "GREAT JOB!"
		result_message.text = SUCCESS_MESSAGES[randi() % SUCCESS_MESSAGES.size()]
	else:
		# Failure - fell for phishing
		result_overlay.add_theme_stylebox_override("panel", _create_fail_style())
		result_icon.text = "🎣"
		result_title.text = "OOH GOTCHA!"
		result_message.text = FAIL_MESSAGES[randi() % FAIL_MESSAGES.size()]
	
	# Show result overlay with animation
	result_overlay.visible = true
	result_overlay.modulate = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	tween.tween_property(result_overlay, "modulate", Color(1, 1, 1, 1), 0.3)


func _create_success_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.5, 0.1, 0.98)
	style.set_corner_radius_all(20)
	return style


func _create_fail_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.1, 0.1, 0.98)
	style.set_corner_radius_all(20)
	return style


func hide_phone() -> void:
	"""Hide the phone screen and resume game."""
	if not _can_dismiss:
		return
	
	_can_dismiss = false
	
	# Play hide animation
	animation_player.play("hide")
	
	# Also fade out result overlay if visible
	if result_overlay.visible:
		var tween = create_tween()
		tween.tween_property(result_overlay, "modulate", Color(1, 1, 1, 0), 0.2)
	
	await animation_player.animation_finished
	
	visible = false
	result_overlay.visible = false
	_showing_result = false
	
	# Resume the game
	get_tree().paused = false
	
	# Recapture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	dismissed.emit()
	print("📱 Phone dismissed - Resuming gameplay")


func _input(event: InputEvent) -> void:
	if not visible or not _can_dismiss:
		return
	
	# Only allow dismissing with F key AFTER showing result
	if _showing_result:
		if event is InputEventKey and event.pressed and event.keycode == KEY_F:
			hide_phone()


func _unhandled_input(event: InputEvent) -> void:
	# Block all other input while phone is visible
	pass
