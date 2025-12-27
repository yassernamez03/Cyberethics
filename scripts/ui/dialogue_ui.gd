# =============================================================================
# DIALOGUE UI - NPC Conversation System
# =============================================================================
# Displays dialogue between player and NPCs with cyber security lessons
# Path: res://scripts/ui/dialogue_ui.gd
# =============================================================================

extends CanvasLayer

signal dialogue_finished

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $Panel/MarginContainer/VBoxContainer/DialogueLabel
@onready var continue_hint: Label = $Panel/MarginContainer/VBoxContainer/ContinueHint
@onready var avatar_icon: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/AvatarIcon

var _dialogue_queue: Array[Dictionary] = []
var _current_index: int = 0
var _is_showing: bool = false
var _can_advance: bool = false

# Typing effect
var _full_text: String = ""
var _current_char: int = 0
var _typing_speed: float = 0.008  # Fast typing speed
var _typing_timer: float = 0.0


func _ready() -> void:
	visible = false
	panel.visible = false


func _process(delta: float) -> void:
	if not _is_showing:
		return
	
	# Typing effect
	if _current_char < _full_text.length():
		_typing_timer += delta
		if _typing_timer >= _typing_speed:
			_typing_timer = 0.0
			_current_char += 1
			dialogue_label.text = _full_text.substr(0, _current_char)
			
			# Show continue hint when typing is done
			if _current_char >= _full_text.length():
				_can_advance = true
				continue_hint.visible = true


func _input(event: InputEvent) -> void:
	if not _is_showing:
		return
	
	# Quit dialogue with Escape or Q
	if event.is_action_pressed("ui_cancel") or \
	   (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q)):
		_end_dialogue()
		return
	
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or \
	   (event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		if _current_char < _full_text.length():
			# Skip typing, show full text
			_current_char = _full_text.length()
			dialogue_label.text = _full_text
			_can_advance = true
			continue_hint.visible = true
		elif _can_advance:
			_advance_dialogue()


func start_dialogue(dialogue_lines: Array[Dictionary]) -> void:
	"""Start a dialogue sequence. Each dict has: speaker, text, is_player"""
	_dialogue_queue = dialogue_lines
	_current_index = 0
	_is_showing = true
	visible = true
	panel.visible = true
	
	# Capture mouse for dialogue
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_show_current_line()


func _show_current_line() -> void:
	if _current_index >= _dialogue_queue.size():
		_end_dialogue()
		return
	
	var line = _dialogue_queue[_current_index]
	var speaker = line.get("speaker", "???")
	var text = line.get("text", "")
	var is_player = line.get("is_player", false)
	
	speaker_label.text = speaker
	_full_text = text
	_current_char = 0
	dialogue_label.text = ""
	_can_advance = false
	continue_hint.visible = false
	
	# Check if this is the last line
	var is_last_line = (_current_index >= _dialogue_queue.size() - 1)
	if is_last_line:
		continue_hint.text = "Press [E] to close  •  [Q] to quit"
	else:
		continue_hint.text = "Press [E] to continue  •  [Q] to quit"
	
	# Change colors based on speaker
	if is_player:
		speaker_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
		avatar_icon.text = "🧑"
	else:
		speaker_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
		avatar_icon.text = "👤"


func _advance_dialogue() -> void:
	_current_index += 1
	_show_current_line()


func _end_dialogue() -> void:
	_is_showing = false
	visible = false
	panel.visible = false
	_dialogue_queue.clear()
	
	# Return mouse to game mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	dialogue_finished.emit()
