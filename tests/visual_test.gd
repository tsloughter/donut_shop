extends SceneTree
## Renders each recipe stage into builds/previews. Needs a display. Pass `-- --showcase` after
## the script to capture a single decorated donut instead, and `--size=1778x800` to render at
## the logical viewport size a different screen shape would get (a 20:9 phone here).
const MAIN_SCENE := "res://scenes/main.tscn"
const PREVIEW_DIR := "res://builds/previews"
var game: Node3D
var host: Viewport


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	host = root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var dims := arg.trim_prefix("--size=").split("x")
			var sub := SubViewport.new()
			sub.size = Vector2i(int(dims[0]), int(dims[1]))
			sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(sub)
			host = sub
	game = load(MAIN_SCENE).instantiate()
	host.add_child(game)
	game.sound_on = false
	for i in range(3):
		await process_frame
	DirAccess.make_dir_recursive_absolute(PREVIEW_DIR)
	if "--showcase" in OS.get_cmdline_user_args():
		showcase()
		await capture("00-showcase")
		quit()
		return
	await capture("01-cut")
	game._cut()
	await create_timer(1).timeout
	await capture("02-oven")
	game._start_bake()
	await create_timer(6).timeout
	for i in range(50):
		var a := i * TAU / 50
		game._apply_at(
			game.camera.unproject_position(
				game.DONUT_POS + Vector3(cos(a) * .88, .37, sin(a) * .88)
			)
		)
	await capture("03-frost")
	game._next()
	for i in range(80):
		var a := i * TAU / 80
		var r := randf_range(.6, 1.17)
		var local := Vector2(cos(a) * r, sin(a) * r)
		game._apply_at(
			game.camera.unproject_position(
				game.DONUT_POS + Vector3(local.x, game.donut.surface_height(local) + .04, local.y)
			)
		)
	await capture("04-toppings")
	game._next()
	await capture("05-serve")
	print("VISUAL TEST COMPLETE")
	quit()


func showcase() -> void:
	game.dough.visible = false
	game.cutter.visible = false
	game.donut.visible = true
	game.donut.bake(1)
	game._set_stage(game.Stage.TOP)
	for i in range(70):
		var angle := float(i) * TAU / 70
		game.donut.paint(Vector2(cos(angle), sin(angle)) * .88, game.FROSTING_COLORS[0])
	for i in range(95):
		var a := randf() * TAU
		var r := randf_range(.62, 1.16)
		game.donut.add_topping(Vector2(cos(a), sin(a)) * r, "sprinkles" if i % 4 else "stars")


func capture(name: String) -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	host.get_texture().get_image().save_png(PREVIEW_DIR + "/" + name + ".png")
