extends SceneTree
## In-engine checks on recipe transitions and the topping bound, driven through the game's
## gesture handlers. tests/input_test.gd covers the real input pipeline.
const MAIN_SCENE := "res://scenes/main.tscn"
var game: Node3D
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	game = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	game.sound_on = false
	for i in range(3):
		await process_frame
	check(
		game.stage == game.Stage.CUT and not game.donut.visible, "Recipe must start at the cutter"
	)
	game._cut()
	await create_timer(.85).timeout
	check(
		game.stage == game.Stage.LOAD and game.donut.visible and not game.dough.visible,
		"Cutting must reveal the donut"
	)
	game._start_bake()
	await create_timer(6).timeout
	check(game.stage == game.Stage.FROST and not game.oven.visible, "Baking must end at frosting")
	var screen: Vector2 = game.camera.unproject_position(game.DONUT_POS + Vector3(.88, .37, 0))
	game._pointer_down(screen, 3)
	game._pointer_move(screen + Vector2(15, 8))
	game._pointer_up(screen)
	check(game.donut.painted_cells > 0 and game.donut.coverage() > 0, "Touch must paint frosting")
	check(game.pointer_id == Hud.NO_POINTER, "Pointer must reset on release")
	var before: int = game.donut.dab_count
	game._apply_at(Vector2(10, 10))
	check(game.donut.dab_count == before, "Strokes away from the donut must not paint")
	game._next()
	check(game.stage == game.Stage.TOP, "Frosting must lead to toppings")
	game._pointer_down(screen, 4)
	game._pointer_up(screen)
	check(game.donut.topping_count > 0, "Touch must add toppings")
	check(not game.donut.add_topping(Vector2.ZERO, "stars"), "Hole must reject toppings")
	for i in range(250):
		game.donut.add_topping(Vector2(.88, 0), "pearls")
	check(game.donut.topping_count == Donut.MAX_TOPPINGS, "Toppings must be bounded")
	game._tool_pressed(game.CLEAR_TOOL)
	check(game.donut.topping_count == 0, "Clear tops must remove toppings")
	game._next()
	check(game.stage == game.Stage.SERVE, "Toppings must lead to serving")
	game._next()
	check(
		(
			game.stage == game.Stage.CUT
			and game.donut.painted_cells == 0
			and game.donut.dab_count == 0
			and game.donut.topping_count == 0
		),
		"Replay must reset the donut"
	)
	print(
		(
			"SMOKE TEST %s"
			% (
				"PASS: cut, bake, touch frosting, toppings, limits, serve, replay"
				if failures == 0
				else "FAIL (%d)" % failures
			)
		)
	)
	quit(0 if failures == 0 else 1)
