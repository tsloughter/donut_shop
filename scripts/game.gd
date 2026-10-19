extends Node3D
## One cozy, repeatable recipe: cut, bake, frost, top, serve. This script owns the recipe
## state machine and the gestures on the 3D workbench. The HUD scene reports button presses
## and jar drags, and the Donut node owns frosting and toppings.

enum Stage { CUT, LOAD, BAKING, FROST, TOP, SERVE }

const DONUT_POS := Vector3(0, 1.35, 1.7)
const DONUT_SCALE := Vector3(1.3, 1.3, 1.3)
const OVEN_POS := Vector3(0, 1.3, .25)
const BAKE_SECONDS := 4.0
const PINK := Color("e58ca0")
const GREEN := Color("427963")
const FROSTING_COLORS: Array[Color] = [
	Color("e68ca4"), Color("744331"), Color("f7e6bd"), Color("ae9bd1")
]
const FROSTING_NAMES := ["Strawberry", "Chocolate", "Vanilla", "Blueberry"]
const TOPPING_NAMES := ["Rainbow", "Little stars", "Sugar pearls"]
const TOPPING_TINTS: Array[Color] = [PINK, Color("e1b860"), Color("9bbcaa")]
## Index of the "Clear tops" tool in the topping stage.
const CLEAR_TOOL := 3
const SETTINGS_PATH := "user://bakery.cfg"
const SOURCE_URL := "https://github.com/tsloughter/donut_shop"

var stage: Stage = Stage.CUT
var selected_tool := 0
var pointer_id := Hud.NO_POINTER
var painting := false
var dragging_donut := false
var dragging_jar := false
var last_paint := Vector2(INF, INF)
var last_screen := Vector2.ZERO
var elapsed := 0.0
var bake_time := 0.0
var cut_done := false
var transitioning := false
var sound_on := true
var completed := 0
var sound_cooldown := 0.0
var chime_cache: Dictionary = {}

@onready var camera: Camera3D = %Camera3D
@onready var dough: MeshInstance3D = %Dough
@onready var cutter: Node3D = %Cutter
@onready var oven: Node3D = %Oven
@onready var door: Node3D = %Door
@onready var bear: Node3D = %Bear
@onready var bunny: Node3D = %Bunny
@onready var bear_paw: Node3D = %Bear/Paw
@onready var bunny_paw: Node3D = %Bunny/Paw
@onready var spoon: Node3D = %Spoon
@onready var confetti_small: CPUParticles3D = %ConfettiSmall
@onready var confetti_big: CPUParticles3D = %ConfettiBig
@onready var audio: AudioStreamPlayer = %Audio
@onready var donut: Donut = %Donut
@onready var hud: Hud = %Hud
@onready var license_dialog: AcceptDialog = %LicenseDialog


func _ready() -> void:
	hud.next_pressed.connect(_next)
	hud.licenses_pressed.connect(_show_licenses)
	hud.sound_toggled.connect(_toggle_sound)
	hud.tool_pressed.connect(_on_tool_pressed)
	hud.tool_drag_moved.connect(_on_tool_drag_moved)
	hud.tool_drag_ended.connect(_on_tool_drag_ended)
	hud.tool_drag_canceled.connect(_cancel_pointer)
	_load_settings()
	_reset_recipe()
	_warm_up_shaders()


func _process(delta: float) -> void:
	elapsed += delta
	sound_cooldown -= delta
	bear.position.y = .8 + sin(elapsed * 1.8) * .035
	bear.rotation.z = sin(elapsed * 1.3) * .025
	bunny.position.y = .8 + sin(elapsed * 2.1 + 1) * .045
	bunny.rotation.z = sin(elapsed * 1.6) * .03
	bear_paw.rotation.z = sin(elapsed * 3.2) * .27
	bunny_paw.rotation.x = sin(elapsed * 3) * .35
	spoon.rotation = Vector3(sin(elapsed * 3) * .2, 0, cos(elapsed * 3) * .2)
	if stage == Stage.BAKING and not transitioning:
		bake_time += delta
		hud.set_progress(true, bake_time / BAKE_SECONDS * 100)
		if bake_time >= BAKE_SECONDS:
			_finish_bake()
	if stage == Stage.SERVE:
		donut.rotation.y += delta * .16
	var hint_shown := (
		pointer_id == Hud.NO_POINTER
		and stage in [Stage.CUT, Stage.FROST, Stage.TOP]
		and not transitioning
	)
	var wobble := Vector2(sin(elapsed * 2) * 18, cos(elapsed * 2) * 10)
	hud.set_hint(
		hint_shown,
		camera.unproject_position(DONUT_POS + Vector3(.8, .5, 0)) + wobble,
		.65 + sin(elapsed * 3) * .2
	)


## Only touches the HUD did not consume reach the workbench. Touch and mouse share one path;
## emulated mouse events are skipped so a finger never counts twice.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == pointer_id:
				_cancel_pointer()
		elif event.pressed:
			if pointer_id == Hud.NO_POINTER:
				_pointer_down(event.position, event.index)
		elif event.index == pointer_id:
			_pointer_up(event.position)
	elif event is InputEventScreenDrag:
		if event.index == pointer_id:
			_pointer_move(event.position)
	elif event is InputEventMouseButton:
		if (
			event.button_index != MOUSE_BUTTON_LEFT
			or event.device == InputEvent.DEVICE_ID_EMULATION
		):
			return
		if event.pressed:
			if pointer_id == Hud.NO_POINTER:
				_pointer_down(event.position, Hud.MOUSE_POINTER)
		elif pointer_id == Hud.MOUSE_POINTER:
			_pointer_up(event.position)
	elif event is InputEventMouseMotion:
		if pointer_id == Hud.MOUSE_POINTER:
			_pointer_move(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Android Back must not discard a toddler's creation.
		_cancel_pointer()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST]:
		_cancel_pointer()


func _reset_recipe() -> void:
	_cancel_pointer()
	transitioning = false
	cut_done = false
	donut.reset()
	donut.position = DONUT_POS
	donut.scale = DONUT_SCALE
	donut.visible = false
	dough.visible = true
	cutter.visible = true
	cutter.position = DONUT_POS + Vector3(0, .65, 0)
	oven.visible = false
	door.rotation.x = PI * .43
	hud.set_celebration("")
	_set_stage(Stage.CUT)


func _set_stage(value: Stage) -> void:
	stage = value
	selected_tool = 0
	_cancel_pointer()
	var active_step := 0
	var tools: Array = []
	match stage:
		Stage.CUT:
			hud.set_stage_text(
				"Let's make a donut!",
				"Press the cutter into the soft dough.",
				"Hello, little baker!\nLet's do this together.",
				"Tap the round cutter.",
				"Cut the dough"
			)
			tools = [["Round cutter", "cut", Color("e3bd77")]]
		Stage.LOAD:
			active_step = 1
			hud.set_stage_text(
				"Time to get cozy",
				"Slide your donut into the oven.",
				"I'll help with the oven. In it goes!",
				"Drag the donut up to the oven, or tap Bake.",
				"Bake  >"
			)
			tools = [["Little oven", "oven", Color("e6a17b")]]
		Stage.BAKING:
			active_step = 1
			hud.set_stage_text(
				"A little donut magic",
				"Warm and golden. Almost ready!",
				"Mmm… our shop smells so lovely.",
				"Pip is taking care of the baking.",
				"Baking…"
			)
			tools = [["Getting golden", "oven", Color("e6a17b")]]
		Stage.FROST:
			active_step = 2
			hud.set_stage_text(
				"A swirl of something sweet",
				"Pick a frosting. Rub your finger over the donut.",
				"Pink? Chocolate?\nYou can mix them all!",
				"Little circles, big swirls. Every donut is lovely.",
				"Toppings  >"
			)
			for i in range(FROSTING_NAMES.size()):
				tools.append([FROSTING_NAMES[i], "bowl", FROSTING_COLORS[i]])
		Stage.TOP:
			active_step = 3
			hud.set_stage_text(
				"Sprinkle a little happiness",
				"Drag a jar over your donut and give it a sprinkle.",
				"Ooh, that looks delicious! More sprinkles?",
				"Drag from a jar, or tap the donut to decorate.",
				"Serve it!  >"
			)
			for i in range(TOPPING_NAMES.size()):
				tools.append([TOPPING_NAMES[i], Donut.TOPPING_KINDS[i], TOPPING_TINTS[i]])
			tools.append(["Clear tops", "reset", GREEN])
		Stage.SERVE:
			active_step = 4
			hud.set_stage_text(
				"Made with a little love",
				"A one-of-a-kind donut, made by you.",
				"Thank you, little baker! It's wonderful.",
				"Make another whenever you're ready.",
				"Make another"
			)
			tools = [["You're a baker!", "serve", PINK]]
			hud.set_celebration("Hooray for your donut!")
	hud.set_tools(tools)
	hud.set_step(active_step)
	hud.set_progress(stage in [Stage.FROST, Stage.BAKING], 0)
	hud.set_next_enabled(stage != Stage.BAKING)
	_select_tool(0)


## A tapped tool does its job, not only highlight itself.
func _tool_pressed(index: int) -> void:
	match stage:
		Stage.CUT:
			_cut()
		Stage.LOAD:
			_start_bake()
		Stage.TOP when index == CLEAR_TOOL:
			donut.clear_toppings()
			_chime(440)
		_:
			_select_tool(index)


func _select_tool(index: int) -> void:
	selected_tool = index
	hud.select_tool(index)


func _on_tool_pressed(index: int, pointer: int, pos: Vector2) -> void:
	if transitioning or pointer_id != Hud.NO_POINTER:
		return
	_tool_pressed(index)
	if stage == Stage.TOP and index < CLEAR_TOOL:
		# The jar follows the finger until it is released over the donut.
		pointer_id = pointer
		dragging_jar = true
		last_screen = pos
		hud.show_cursor(Donut.TOPPING_KINDS[index], PINK, pos)


func _on_tool_drag_moved(pos: Vector2) -> void:
	if dragging_jar:
		_pointer_move(pos)


func _on_tool_drag_ended(pos: Vector2) -> void:
	if dragging_jar:
		_pointer_up(pos)


func _pointer_down(pos: Vector2, id: int) -> void:
	if transitioning:
		return
	pointer_id = id
	last_screen = pos
	match stage:
		Stage.CUT:
			if _near_donut(pos, 1.9):
				_cut()
		Stage.LOAD:
			if _near_donut(pos, 2):
				dragging_donut = true
		Stage.FROST, Stage.TOP:
			painting = true
			last_paint = Vector2(INF, INF)
			_apply_at(pos)


func _pointer_move(pos: Vector2) -> void:
	if dragging_donut:
		var p := _plane_point(pos, 1.25)
		if p != Vector3.INF:
			donut.position = Vector3(clampf(p.x, -2, 2), 1.25, clampf(p.z, -.1, 2.7))
	elif painting or dragging_jar:
		# Interpolate so quick toddler swipes leave a continuous trail.
		var steps := mini(24, maxi(1, int(last_screen.distance_to(pos) / 10)))
		for i in range(1, steps + 1):
			_apply_at(last_screen.lerp(pos, float(i) / steps))
	if dragging_jar:
		hud.move_cursor(pos)
	last_screen = pos


func _pointer_up(pos: Vector2) -> void:
	if dragging_donut:
		if donut.position.z < .9:
			_start_bake()
		else:
			create_tween().tween_property(donut, "position", DONUT_POS, .25)
		dragging_donut = false
	elif dragging_jar:
		_apply_at(pos)
	_cancel_pointer()


## Drops the gesture without applying it: canceled touches, focus loss, Back and dialogs.
func _cancel_pointer() -> void:
	if dragging_donut and not transitioning:
		create_tween().tween_property(donut, "position", DONUT_POS, .25)
	pointer_id = Hud.NO_POINTER
	painting = false
	dragging_donut = false
	dragging_jar = false
	last_paint = Vector2(INF, INF)
	hud.cancel_drag()


func _plane_point(pos: Vector2, height: float) -> Vector3:
	var origin := camera.project_ray_origin(pos)
	var ray := camera.project_ray_normal(pos)
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(origin, ray)
	return hit if hit != null else Vector3.INF


## Solves the ray against the upper torus surface so picking follows the visible icing.
func _local_hit(pos: Vector2) -> Vector2:
	var origin: Vector3 = donut.to_local(camera.project_ray_origin(pos))
	var ray: Vector3 = donut.global_transform.basis.inverse() * camera.project_ray_normal(pos)
	var top_t: float = (.39 - origin.y) / ray.y
	var bottom_t: float = (-.03 - origin.y) / ray.y
	var previous := 1.0
	for i in range(49):
		var t := lerpf(top_t, bottom_t, float(i) / 48)
		var p := origin + ray * t
		var xz := Vector2(p.x, p.z)
		if donut.is_on_ring(xz, .02):
			var gap: float = p.y - donut.surface_height(xz)
			if gap <= .012 and previous > 0:
				return xz
			previous = gap
	var fallback: Vector3 = donut.to_local(
		_plane_point(pos, donut.position.y + .16 * donut.scale.y)
	)
	return Vector2(fallback.x, fallback.z)


func _near_donut(pos: Vector2, radius: float) -> bool:
	var p := _plane_point(pos, donut.position.y) - donut.position
	return Vector2(p.x, p.z).length() < radius


func _apply_at(pos: Vector2) -> void:
	var p := _local_hit(pos)
	if stage == Stage.FROST:
		if p.distance_to(last_paint) < .045:
			return
		if donut.paint(p, FROSTING_COLORS[selected_tool]):
			last_paint = p
			hud.set_progress(true, minf(100, donut.coverage() / .8 * 100))
			if sound_cooldown <= 0:
				_chime(600 + selected_tool * 70, .055)
				sound_cooldown = .2
	elif stage == Stage.TOP:
		if p.distance_to(last_paint) < .13:
			return
		var kind: String = Donut.TOPPING_KINDS[mini(selected_tool, CLEAR_TOOL - 1)]
		if donut.add_topping(p, kind):
			last_paint = p
			# A little scatter makes a single finger feel like a real sprinkle jar.
			for i in range(2):
				donut.add_topping(p + Vector2(randf_range(-.15, .15), randf_range(-.15, .15)), kind)
			if sound_cooldown <= 0:
				_chime(850 + randi_range(0, 7) * 50, .055)
				sound_cooldown = .13


func _cut() -> void:
	if cut_done or transitioning:
		return
	cut_done = true
	transitioning = true
	_chime(430, .14)
	var tween := create_tween()
	tween.tween_property(cutter, "position:y", 1.04, .3).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tween.tween_callback(
		func() -> void:
			dough.visible = false
			donut.visible = true
			_burst(DONUT_POS, 12)
			_chime(660)
	)
	tween.tween_property(cutter, "position:y", 2.1, .35)
	tween.tween_callback(
		func() -> void:
			cutter.visible = false
			oven.visible = true
			transitioning = false
			_set_stage(Stage.LOAD)
	)


func _start_bake() -> void:
	if stage != Stage.LOAD or transitioning:
		return
	transitioning = true
	dragging_donut = false
	var tween := create_tween()
	tween.tween_property(donut, "position", OVEN_POS, .45)
	tween.parallel().tween_property(donut, "scale", Vector3.ONE * .85, .45)
	tween.tween_property(door, "rotation:x", 0.0, .35)
	tween.tween_callback(
		func() -> void:
			donut.visible = false
			transitioning = false
			bake_time = 0
			_set_stage(Stage.BAKING)
			_chime(510)
	)


func _finish_bake() -> void:
	transitioning = true
	donut.bake(1)
	donut.visible = true
	var tween := create_tween()
	tween.tween_property(door, "rotation:x", PI * .43, .35)
	tween.tween_property(donut, "position", DONUT_POS, .5)
	tween.parallel().tween_property(donut, "scale", DONUT_SCALE, .5)
	tween.tween_callback(
		func() -> void:
			oven.visible = false
			transitioning = false
			_set_stage(Stage.FROST)
			_chime(880, .3)
			_burst(DONUT_POS, 12)
	)


func _next() -> void:
	if transitioning:
		return
	match stage:
		Stage.CUT:
			_cut()
		Stage.LOAD:
			_start_bake()
		Stage.FROST:
			_set_stage(Stage.TOP)
			_chime(720)
		Stage.TOP:
			_set_stage(Stage.SERVE)
			completed += 1
			_save_settings()
			_burst(DONUT_POS + Vector3(0, 1, 0), 50)
			_chime(880, .4)
		Stage.SERVE:
			_reset_recipe()
			_chime(520)


func _burst(center: Vector3, count: int) -> void:
	var particles := confetti_small if count <= confetti_small.amount else confetti_big
	particles.position = center
	particles.restart()


## GL Compatibility compiles each shader variant the first time it is drawn. Draw the donut,
## toppings and confetti once, tiny and hidden inside the dough, so the first cut does not stall.
func _warm_up_shaders() -> void:
	donut.visible = true
	donut.scale = Vector3.ONE * .02
	donut.position = dough.position
	donut.set_warm_up(true)
	var sparks: CPUParticles3D = confetti_small.duplicate()
	sparks.amount = 1
	sparks.scale_amount_min = 0
	sparks.scale_amount_max = 0
	add_child(sparks)
	sparks.position = dough.position
	sparks.restart()
	# Two process frames guarantee one draw in between, and still resolve under --headless.
	await get_tree().process_frame
	await get_tree().process_frame
	donut.set_warm_up(false)
	donut.visible = false
	donut.scale = DONUT_SCALE
	donut.position = DONUT_POS
	get_tree().create_timer(sparks.lifetime).timeout.connect(sparks.queue_free)


func _chime(hz: float, duration := .13) -> void:
	if not sound_on:
		return
	var key := Vector2i(int(hz), int(duration * 1000))
	if not chime_cache.has(key):
		chime_cache[key] = _synthesize_chime(hz, duration)
	audio.stream = chime_cache[key]
	audio.play()


func _synthesize_chime(hz: float, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(duration * rate) * 2)
	for i in range(data.size() / 2):
		var t := float(i) / rate
		var envelope := sin(PI * t / duration) * exp(-t * 10)
		var value := int((sin(TAU * hz * t) + .22 * sin(TAU * hz * 2 * t)) * envelope * 6500)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


func _toggle_sound() -> void:
	sound_on = not sound_on
	hud.set_sound(sound_on)
	_save_settings()
	_chime(660)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sound_on = config.get_value("bakery", "sound", true)
		completed = config.get_value("bakery", "completed", 0)
	hud.set_sound(sound_on)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("bakery", "sound", sound_on)
	config.set_value("bakery", "completed", completed)
	config.save(SETTINGS_PATH)


func _show_licenses() -> void:
	_cancel_pointer()
	var tabs: TabContainer = license_dialog.get_node("Tabs")
	var project_tab: RichTextLabel = tabs.get_child(0)
	if project_tab.text.is_empty():
		# The notices are long; lay them out the first time someone asks for them.
		var notice := "Little Donut\nCopyright (C) 2026 Little Donut contributors.\n\n"
		notice += "Original code and assets: GNU Affero General Public License, version 3 or "
		notice += "(at your option) any later version (AGPL-3.0-or-later).\n"
		notice += "This program comes with ABSOLUTELY NO WARRANTY. "
		notice += "You may redistribute and modify it under the license below.\n\n"
		notice += "Corresponding Source and build instructions:\n" + SOURCE_URL + "\n\n"
		project_tab.text = notice + FileAccess.get_file_as_string("res://LICENSE.txt")
		(tabs.get_child(1) as RichTextLabel).text = FileAccess.get_file_as_string(
			"res://assets/GODOT-LICENSE.txt"
		)
	license_dialog.popup_centered(Vector2i(1000, 600))
