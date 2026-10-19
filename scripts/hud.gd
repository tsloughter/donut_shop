class_name Hud
extends Control
## Heads-up display: stage text, step indicator, tool buttons, drag cursor and hint.
## It reports what the player touched; the game decides what that means.

signal next_pressed
signal licenses_pressed
signal sound_toggled
## A tool button was pressed. For jar tools a drag may follow via the tool_drag_* signals.
signal tool_pressed(index: int, pointer: int, pos: Vector2)
signal tool_drag_moved(pos: Vector2)
signal tool_drag_ended(pos: Vector2)
signal tool_drag_canceled

const ToolButtonScene := preload("res://scenes/tool_button.tscn")
const NO_POINTER := -999
const MOUSE_POINTER := -1
const CURSOR_OFFSET := Vector2(36, 62)

@export var tool_normal_style: StyleBoxFlat
@export var tool_selected_style: StyleBoxFlat
@export var step_idle_style: StyleBoxFlat
@export var step_active_style: StyleBoxFlat

var tool_buttons: Array[Button] = []
var drag_pointer := NO_POINTER

@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var speech: Label = %Speech
@onready var helper: Label = %Helper
@onready var progress: ProgressBar = %Progress
@onready var celebration: Label = %Celebration
@onready var next_button: Button = %NextButton
@onready var tool_row: HBoxContainer = %ToolRow
@onready var steps: HBoxContainer = %Steps
@onready var sound_icon: ToyIcon = %SoundIcon
@onready var cursor: ToyIcon = %Cursor
@onready var hint: ToyIcon = %Hint


func _ready() -> void:
	next_button.pressed.connect(next_pressed.emit)
	(%LicensesButton as Button).pressed.connect(licenses_pressed.emit)
	(%SoundButton as Button).pressed.connect(sound_toggled.emit)


func set_stage_text(
	title_text: String,
	subtitle_text: String,
	speech_text: String,
	helper_text: String,
	next_text: String
) -> void:
	title.text = title_text
	subtitle.text = subtitle_text
	speech.text = speech_text
	helper.text = helper_text
	next_button.text = next_text


## Highlights steps 0..active in the header.
func set_step(active: int) -> void:
	for i in range(steps.get_child_count()):
		var panel: PanelContainer = steps.get_child(i)
		panel.add_theme_stylebox_override(
			"panel", step_active_style if i <= active else step_idle_style
		)
		panel.modulate.a = 1.0 if i <= active else 0.6


## Rebuilds the tool row. Each entry is [label, icon kind, tint].
func set_tools(tools: Array) -> void:
	for b in tool_buttons:
		tool_row.remove_child(b)
		b.queue_free()
	tool_buttons.clear()
	drag_pointer = NO_POINTER
	for i in range(tools.size()):
		var b: Button = ToolButtonScene.instantiate()
		(b.get_node("%Label") as Label).text = tools[i][0]
		var icon: ToyIcon = b.get_node("%Icon")
		icon.kind = tools[i][1]
		icon.tint = tools[i][2]
		b.gui_input.connect(_on_tool_gui_input.bind(i))
		tool_row.add_child(b)
		tool_buttons.append(b)


func select_tool(index: int) -> void:
	for i in range(tool_buttons.size()):
		tool_buttons[i].add_theme_stylebox_override(
			"normal", tool_selected_style if i == index else tool_normal_style
		)


func set_progress(shown: bool, value: float) -> void:
	progress.visible = shown
	progress.value = value


func set_next_enabled(enabled: bool) -> void:
	next_button.disabled = not enabled


func set_sound(on: bool) -> void:
	sound_icon.kind = "sound" if on else "mute"


func set_celebration(text: String) -> void:
	celebration.text = text


func show_cursor(kind: String, tint: Color, pos: Vector2) -> void:
	cursor.kind = kind
	cursor.tint = tint
	cursor.position = pos - CURSOR_OFFSET
	cursor.visible = true


func move_cursor(pos: Vector2) -> void:
	cursor.position = pos - CURSOR_OFFSET


func hide_cursor() -> void:
	cursor.visible = false


func set_hint(shown: bool, pos: Vector2, alpha: float) -> void:
	hint.visible = shown
	hint.position = pos
	hint.modulate.a = alpha


## Forget an in-progress tool drag, e.g. when the app loses focus.
func cancel_drag() -> void:
	drag_pointer = NO_POINTER
	hide_cursor()


## Tool buttons keep touch focus for the whole gesture, so a drag that starts on a jar and ends
## on the donut arrives here rather than in the game's _unhandled_input.
func _on_tool_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventScreenTouch:
		var pos := _screen_position(index, event.position)
		if event.canceled:
			if event.index == drag_pointer:
				_end_drag(true, pos)
		elif event.pressed:
			_begin_drag(index, event.index, pos)
		elif event.index == drag_pointer:
			_end_drag(false, pos)
	elif event is InputEventScreenDrag:
		if event.index == drag_pointer:
			tool_drag_moved.emit(_screen_position(index, event.position))
	elif event is InputEventMouseButton:
		# Touches arrive above; their emulated mouse clicks must not start a second gesture.
		if (
			event.button_index != MOUSE_BUTTON_LEFT
			or event.device == InputEvent.DEVICE_ID_EMULATION
		):
			return
		var pos := _screen_position(index, event.position)
		if event.pressed:
			_begin_drag(index, MOUSE_POINTER, pos)
		elif drag_pointer == MOUSE_POINTER:
			_end_drag(false, pos)
	elif event is InputEventMouseMotion:
		if drag_pointer == MOUSE_POINTER:
			tool_drag_moved.emit(_screen_position(index, event.position))


## gui_input positions are local to the button; gestures are tracked in viewport space.
func _screen_position(index: int, local: Vector2) -> Vector2:
	return tool_buttons[index].get_global_transform_with_canvas() * local


func _begin_drag(index: int, pointer: int, pos: Vector2) -> void:
	if drag_pointer != NO_POINTER:
		return
	drag_pointer = pointer
	tool_pressed.emit(index, pointer, pos)


func _end_drag(canceled: bool, pos: Vector2) -> void:
	drag_pointer = NO_POINTER
	if canceled:
		tool_drag_canceled.emit()
	else:
		tool_drag_ended.emit(pos)
