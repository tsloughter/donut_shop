extends SceneTree
## Exercises the public Godot input pipeline, rather than calling gesture handlers.
const PASS_MESSAGE := "PASS — cut, cancel, oven, frost, mouse, multi-touch, jars, replay, tools"
var game: Node3D
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = index
	root.push_input(e, true)


func drag(pos: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	e.index = index
	root.push_input(e, true)


func cancel(pos: Vector2, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = false
	e.canceled = true
	e.index = index
	root.push_input(e, true)


func run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.sound_on = false
	for i in range(3):
		await process_frame
	var center: Vector2 = game.camera.unproject_position(game.DONUT_POS)
	touch(center, true)
	touch(center, false)
	await create_timer(1).timeout
	check(game.stage == game.Stage.LOAD, "Touching cutter must cut the dough")
	# A touch the OS cancels (system gesture) must drop the donut back, not bake it.
	touch(center, true)
	var oven_target: Vector2 = game.camera.unproject_position(Vector3(0, 1.25, .1))
	drag(oven_target)
	cancel(oven_target)
	check(
		game.stage == game.Stage.LOAD and game.pointer_id == Hud.NO_POINTER,
		"Canceled touch must not start the bake"
	)
	await create_timer(.4).timeout
	check(
		game.donut.position.is_equal_approx(game.DONUT_POS), "Canceled drag must return the donut"
	)
	# Pull the donut toward the oven and release.
	touch(center, true)
	drag(oven_target)
	touch(oven_target, false)
	await create_timer(6).timeout
	check(game.stage == game.Stage.FROST, "Dragging to oven must complete a bake")
	var spot: Vector2 = game.camera.unproject_position(game.donut.to_global(Vector3(.88, .38, 0)))
	# Legal notices must be readable without painting through the dialog.
	game.hud.get_node("%LicensesButton").pressed.emit()
	await process_frame
	check(game.license_dialog.visible, "Licenses button must open the notices")
	var tabs: TabContainer = game.license_dialog.get_node("Tabs")
	check(
		(
			tabs.get_child(0).text.contains("AGPL-3.0-or-later")
			and tabs.get_child(0).text.contains("END OF TERMS AND CONDITIONS")
		),
		"Project tab must include the full AGPL and version notice"
	)
	check(
		tabs.get_child(1).text.contains("THIRD-PARTY COMPONENTS"),
		"Godot tab must include engine and third-party notices"
	)
	var unpainted: PackedByteArray = game.donut.paint_image.get_data()
	touch(spot, true)
	touch(spot, false)
	check(
		game.donut.paint_image.get_data() == unpainted, "License dialog must block gameplay input"
	)
	game.license_dialog.hide()
	await process_frame
	touch(spot, true, 2)
	check(game.pointer_id == 2, "First finger must own the stroke")
	touch(spot + Vector2(20, 0), true, 7)
	touch(spot, false, 7)
	check(game.pointer_id == 2, "Extra fingers must not interrupt the stroke")
	drag(spot + Vector2(22, 12), 2)
	touch(spot + Vector2(22, 12), false, 2)
	check(
		game.donut.painted_cells > 0 and game.donut.dab_count >= 2,
		"Screen drag must paint the 3D frosting"
	)
	check(game.pointer_id == Hud.NO_POINTER, "Touch release must clear gesture state")
	var before: PackedByteArray = game.donut.paint_image.get_data()
	game._select_tool(1)
	touch(spot, true, 0)
	touch(spot, false, 0)
	check(
		before != game.donut.paint_image.get_data(),
		"A second frosting color must change painted pixels"
	)
	# Mouse goes through the same input pipeline, for desktop play.
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = spot + Vector2(-25, 0)
	mouse.pressed = true
	root.push_input(mouse, true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse, true)
	check(game.pointer_id == Hud.NO_POINTER, "Mouse release must clear gesture state")
	game._next()
	await process_frame
	if game.stage != game.Stage.TOP:
		quit(1)
		return
	var jar: Vector2 = game.hud.tool_buttons[1].get_global_rect().get_center()
	touch(jar, true, 1)
	check(game.dragging_jar and game.selected_tool == 1, "Touching star jar must pick it up")
	drag(spot, 1)
	touch(spot, false, 1)
	check(game.donut.topping_count > 0, "Dragging a jar onto donut must add toppings")
	check(not game.dragging_jar and not game.hud.cursor.visible, "Dropping jar must reset cursor")
	var count: int = game.donut.topping_count
	touch(Vector2(50, 50), true)
	touch(Vector2(50, 50), false)
	check(game.donut.topping_count == count, "Header touches must not decorate")
	check(not game.donut.add_topping(Vector2.ZERO, "stars"), "Donut hole must stay empty")
	game._next()
	check(game.stage == game.Stage.SERVE, "Decorated donut must serve")
	game._next()
	check(
		game.stage == game.Stage.CUT and game.donut.topping_count == 0,
		"Replay must clear last creation"
	)
	# The illustrated tool buttons act, instead of only highlighting themselves.
	var cutter_tool: Vector2 = game.hud.tool_buttons[0].get_global_rect().get_center()
	touch(cutter_tool, true)
	touch(cutter_tool, false)
	await create_timer(1).timeout
	check(game.stage == game.Stage.LOAD, "Tapping the cutter tool must cut the dough")
	var oven_tool: Vector2 = game.hud.tool_buttons[0].get_global_rect().get_center()
	touch(oven_tool, true)
	touch(oven_tool, false)
	await create_timer(1).timeout
	check(game.stage == game.Stage.BAKING, "Tapping the oven tool must start the bake")
	var verdict := PASS_MESSAGE if failures == 0 else "FAIL (%d)" % failures
	print("INPUT TEST: %s" % verdict)
	quit(0 if failures == 0 else 1)
