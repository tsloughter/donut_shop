extends SceneTree
## Exercises the public Godot input pipeline, rather than calling gesture handlers.
var game:Node3D
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(condition:bool,message:String) -> void:
	if not condition:
		failures+=1
		push_error(message)

func touch(pos:Vector2,pressed:bool,index:=0) -> void:
	var e:=InputEventScreenTouch.new();e.position=pos;e.pressed=pressed;e.index=index
	root.push_input(e,true)

func drag(pos:Vector2,index:=0) -> void:
	var e:=InputEventScreenDrag.new();e.position=pos;e.index=index
	root.push_input(e,true)

func run() -> void:
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.sound_on=false
	await process_frame
	var center:Vector2=game.camera.unproject_position(game.DONUT_POS)
	touch(center,true);touch(center,false)
	await create_timer(1).timeout
	check(game.stage==game.Stage.LOAD,"Touching cutter must cut the dough")
	# Pull the donut toward the oven and release.
	touch(center,true)
	var oven_target:Vector2=game.camera.unproject_position(Vector3(0,1.25,.1))
	drag(oven_target);touch(oven_target,false)
	await create_timer(6).timeout
	check(game.stage==game.Stage.FROST,"Dragging to oven must complete a bake")
	var spot:Vector2=game.camera.unproject_position(game.donut.to_global(Vector3(.88,.38,0)))
	touch(spot,true,2)
	check(game.pointer_id==2,"First finger must own the stroke")
	touch(spot+Vector2(20,0),true,7)
	touch(spot,false,7)
	check(game.pointer_id==2,"Extra fingers must not interrupt the stroke")
	drag(spot+Vector2(22,12),2);touch(spot+Vector2(22,12),false,2)
	check(game.donut.painted_pixels>50,"Screen drag must paint the 3D frosting")
	check(game.pointer_id==-999,"Touch release must clear gesture state")
	var before:PackedByteArray=game.donut.paint_image.get_data()
	game._select_tool(1)
	touch(spot,true,0);touch(spot,false,0)
	check(before!=game.donut.paint_image.get_data(),"A second frosting color must change painted pixels")
	# Mouse goes through the same input pipeline, for desktop play.
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=spot+Vector2(-25,0);mouse.pressed=true
	root.push_input(mouse,true);mouse=mouse.duplicate();mouse.pressed=false;root.push_input(mouse,true)
	check(game.pointer_id==-999,"Mouse release must clear gesture state")
	game._next();await process_frame
	if game.stage!=game.Stage.TOP:
		quit(1);return
	var jar:Vector2=game.tool_buttons[1].get_global_rect().get_center()
	touch(jar,true,1)
	check(game.dragging_jar and game.selected_tool==1,"Touching star jar must pick it up")
	drag(spot,1);touch(spot,false,1)
	check(game.donut.topping_count>0,"Dragging a jar onto donut must add toppings")
	check(not game.dragging_jar and not game.cursor.visible,"Dropping jar must reset cursor")
	var count:int=game.donut.topping_count
	touch(Vector2(50,50),true);touch(Vector2(50,50),false)
	check(game.donut.topping_count==count,"Header touches must not decorate")
	check(not game.donut.add_topping(Vector2.ZERO,"stars"),"Donut hole must stay empty")
	game._next();check(game.stage==game.Stage.SERVE,"Decorated donut must serve")
	game._next();check(game.stage==game.Stage.CUT and game.donut.topping_count==0,"Replay must clear last creation")
	print("INPUT TEST: %s" % ("PASS — cutter, oven drag, frosting, mixed colors, mouse, multi-touch, jar drag, replay" if failures==0 else "FAIL (%d)" % failures))
	quit(0 if failures==0 else 1)
