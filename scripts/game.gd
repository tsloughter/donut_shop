extends Node3D
## One cozy, repeatable recipe. All interactions use the same pointer path on touch and desktop.
const Donut = preload("res://scripts/donut.gd")
const Icon = preload("res://scripts/toy_icon.gd")
enum Stage { CUT, LOAD, BAKING, FROST, TOP, SERVE }
const INK := Color("543f35")
const CREAM := Color("fff7e9")
const GREEN := Color("427963")
const PINK := Color("e58ca0")
const DONUT_POS := Vector3(0,1.35,1.7)
const DONUT_SCALE := Vector3(1.3,1.3,1.3)
var stage:Stage=Stage.CUT
var camera:Camera3D
var donut:Node3D
var dough:MeshInstance3D
var cutter:Node3D
var oven:Node3D
var door:Node3D
var bear:Node3D
var bunny:Node3D
var ui:Control
var title:Label
var subtitle:Label
var speech:Label
var helper:Label
var next_button:Button
var tool_row:HBoxContainer
var step_row:HBoxContainer
var sound_button:Button
var progress:ProgressBar
var cursor:Control
var hint:Control
var stage_icons:Array[Control]=[]
var tool_buttons:Array[Button]=[]
var selected_tool:=0
var frosting_colors:=[Color("e68ca4"),Color("744331"),Color("f7e6bd"),Color("ae9bd1")]
var topping_kinds:=["sprinkles","stars","pearls"]
var pointer_id:=-999
var painting:=false
var dragging_jar:=false
var last_paint:=Vector2(INF,INF)
var last_screen:=Vector2.ZERO
var elapsed:=0.0
var bake_time:=0.0
var cut_done:=false
var transitioning:=false
var sound_on:=true
var completed:=0
var audio:AudioStreamPlayer
var sound_cooldown:=0.0
var sparkle_root:Node3D
var confetti:Array[Dictionary]=[]
var tool_panel:Panel
var celebration:Label
var smoke_test:=false
var bear_paw:Node3D
var bunny_paw:Node3D
var spoon:Node3D

func _ready() -> void:
	smoke_test="--smoke-test" in OS.get_cmdline_user_args()
	_build_world()
	_build_ui()
	_load_settings()
	_reset_recipe()
	if "--showcase" in OS.get_cmdline_user_args():call_deferred("_showcase")
	if smoke_test:call_deferred("_run_smoke_test")
	if "--visual-test" in OS.get_cmdline_user_args():call_deferred("_visual_test")
	if "--capture-only" in OS.get_cmdline_user_args():call_deferred("_capture_only")

func _build_world() -> void:
	add_child(preload("res://assets/shop.glb").instantiate())
	bear=preload("res://assets/bear.glb").instantiate()
	add_child(bear);bear.position=Vector3(-2.75,.8,-1.35);bear.rotation.y=.18
	bunny=preload("res://assets/bunny.glb").instantiate()
	add_child(bunny);bunny.position=Vector3(2.80,.8,-1.45);bunny.rotation.y=-.18
	_build_helper_props()
	var env:=WorldEnvironment.new()
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color("f4e3c9")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("ffe6cc");e.ambient_light_energy=.25
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment=e;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_color=Color("fff0da");sun.light_energy=.45
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=22;add_child(sun)
	var fill:=OmniLight3D.new();fill.position=Vector3(0,4,4);fill.light_color=Color("ffe8dd");fill.light_energy=.05;fill.omni_range=12;add_child(fill)
	camera=Camera3D.new();add_child(camera)
	camera.position=Vector3(0,7.1,10.2);camera.look_at(Vector3(0,1.95,.3));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9.8;camera.current=true
	var sign:=Label3D.new();sign.text="little donut";sign.outline_size=0;sign.font_size=80;sign.pixel_size=.0048;sign.modulate=GREEN;sign.position=Vector3(0,3.84,-3.88);add_child(sign)
	var sign_sub:=Label3D.new();sign_sub.text="MADE WITH A LITTLE LOVE";sign_sub.outline_size=0;sign_sub.font_size=30;sign_sub.pixel_size=.004;sign_sub.modulate=INK;sign_sub.position=Vector3(0,3.35,-3.87);add_child(sign_sub)
	# Ceramic plate / pastry board.
	_mesh(CylinderMesh.new(),Vector3(0,.83,1.7),Color("ead7b5"),Vector3(4.45,.06,4.45))
	_mesh(CylinderMesh.new(),Vector3(0,.875,1.7),Color("fff1d5"),Vector3(4.16,.05,4.16))
	dough=_mesh(CylinderMesh.new(),Vector3(0,1.02,1.7),Color("e8bd7c"),Vector3(3.9,.23,3.9))
	cutter=Node3D.new();add_child(cutter);cutter.position=DONUT_POS+Vector3(0,.65,0);cutter.scale=DONUT_SCALE
	for radius in [1.31,.45]:
		var mesh:=TorusMesh.new();mesh.inner_radius=radius-.035;mesh.outer_radius=radius+.035;mesh.rings=48;mesh.ring_segments=10
		var ring:=MeshInstance3D.new();ring.mesh=mesh;ring.material_override=_material(Color("88b7b0"));cutter.add_child(ring)
		var ring2:=ring.duplicate();ring2.position.y=.15;cutter.add_child(ring2)
	var bar:=MeshInstance3D.new();bar.mesh=BoxMesh.new();bar.scale=Vector3(2.7,.06,.06);bar.position.y=.17;bar.material_override=_material(Color("88b7b0"));cutter.add_child(bar)
	_build_oven()
	sparkle_root=Node3D.new();add_child(sparkle_root)
	audio=AudioStreamPlayer.new();add_child(audio)

func _build_oven() -> void:
	oven=Node3D.new();add_child(oven);oven.position=Vector3(0,.80,-.1)
	_box_in(oven,Vector3(0,.83,0),Vector3(3.7,1.65,1.65),Color("e9a076"))
	_box_in(oven,Vector3(0,.75,.85),Vector3(3.22,1.15,.10),Color("594a41"))
	_box_in(oven,Vector3(0,.38,.98),Vector3(2.9,.09,1.5),Color("a7b8ae"))
	for x in [-1.2,0,1.2]:
		var knob:=SphereMesh.new();knob.radius=.10;knob.height=.20
		var k:=MeshInstance3D.new();k.mesh=knob;k.position=Vector3(x,1.47,.89);k.material_override=_material(CREAM);oven.add_child(k)
	door=Node3D.new();oven.add_child(door);door.position=Vector3(0,.18,.91)
	_box_in(door,Vector3(0,.54,0),Vector3(3.25,1.15,.12),Color("f5bf95"))
	_box_in(door,Vector3(0,.53,.08),Vector3(2.76,.72,.03),Color("725641"))
	_box_in(door,Vector3(0,.94,.17),Vector3(2.16,.09,.16),CREAM)
	var badge:=Label3D.new();badge.text="PIP'S OVEN";badge.position=Vector3(0,1.91,.86);badge.outline_size=0;badge.font_size=24;badge.pixel_size=.009;badge.modulate=INK;oven.add_child(badge)
	oven.visible=false

func _build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var theme:=Theme.new();theme.default_font_size=20;ui.theme=theme
	var top_back:=Panel.new();top_back.position=Vector2.ZERO;top_back.size=Vector2(1280,202);top_back.add_theme_stylebox_override("panel",_style(CREAM,0));top_back.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(top_back)
	var brand:=_label("little donut",36,INK);brand.position=Vector2(36,22);ui.add_child(brand)
	var eyebrow:=_label("A HAPPY LITTLE BAKERY",11,GREEN);eyebrow.position=Vector2(38,65);ui.add_child(eyebrow)
	step_row=HBoxContainer.new();step_row.position=Vector2(445,25);step_row.add_theme_constant_override("separation",10);ui.add_child(step_row)
	for i in range(4):
		var panel:=Panel.new();panel.custom_minimum_size=Vector2(145,57);panel.add_theme_stylebox_override("panel",_style(CREAM,20));step_row.add_child(panel)
		var ic:=Icon.new();ic.kind=["cut","oven","bowl","sprinkles"][i];ic.tint=[Color("edcd90"),Color("dfa17b"),PINK,Color("ac9cc9")][i];ic.position=Vector2(6,2);ic.size=Vector2(49,49);panel.add_child(ic)
		var l:=_label(["1  Cut","2  Bake","3  Frost","4  Top"][i],17,INK);l.position=Vector2(56,18);panel.add_child(l);stage_icons.append(panel)
	sound_button=Button.new();sound_button.position=Vector2(1174,25);sound_button.size=Vector2(68,57);sound_button.add_theme_stylebox_override("normal",_style(CREAM,20));sound_button.pressed.connect(_toggle_sound);ui.add_child(sound_button)
	var sound_icon:=Icon.new();sound_icon.name="SoundIcon";sound_icon.kind="sound";sound_icon.tint=GREEN;sound_icon.position=Vector2(14,8);sound_icon.size=Vector2(40,40);sound_button.add_child(sound_icon)
	title=_label("",34,INK);title.position=Vector2(36,113);ui.add_child(title)
	subtitle=_label("",18,INK);subtitle.position=Vector2(38,158);ui.add_child(subtitle)
	var note:=Panel.new();note.position=Vector2(32,258);note.size=Vector2(226,127);note.add_theme_stylebox_override("panel",_style(CREAM,22));note.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(note)
	var name_label:=_label("PIP & BEAN",12,GREEN);name_label.position=Vector2(20,16);note.add_child(name_label)
	speech=_label("",19,INK);speech.position=Vector2(20,42);speech.size=Vector2(190,76);speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_child(speech)
	helper=_label("",15,GREEN);helper.position=Vector2(38,399);helper.size=Vector2(213,100);helper.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;ui.add_child(helper)
	progress=ProgressBar.new();progress.position=Vector2(37,512);progress.size=Vector2(210,12);progress.show_percentage=false;progress.add_theme_stylebox_override("background",_style(Color("e4d6c0"),6));progress.add_theme_stylebox_override("fill",_style(PINK,6));ui.add_child(progress)
	tool_panel=Panel.new();tool_panel.position=Vector2(30,642);tool_panel.size=Vector2(1220,132);tool_panel.add_theme_stylebox_override("panel",_style(CREAM,26));ui.add_child(tool_panel)
	var tools_label:=_label("YOUR TOOLS",11,GREEN);tools_label.position=Vector2(24,13);tool_panel.add_child(tools_label)
	tool_row=HBoxContainer.new();tool_row.position=Vector2(18,33);tool_row.add_theme_constant_override("separation",10);tool_panel.add_child(tool_row)
	next_button=Button.new();next_button.position=Vector2(992,30);next_button.size=Vector2(208,80);next_button.add_theme_font_size_override("font_size",22);next_button.add_theme_color_override("font_color",CREAM);next_button.add_theme_color_override("font_hover_color",CREAM);next_button.add_theme_color_override("font_pressed_color",CREAM);next_button.add_theme_stylebox_override("normal",_style(GREEN,23));next_button.add_theme_stylebox_override("hover",_style(GREEN.lightened(.08),23));next_button.add_theme_stylebox_override("pressed",_style(GREEN.darkened(.1),23));next_button.pressed.connect(_next);tool_panel.add_child(next_button)
	cursor=Icon.new();cursor.kind="bowl";cursor.size=Vector2(80,80);cursor.visible=false;ui.add_child(cursor)
	hint=Icon.new();hint.kind="hand";hint.tint=CREAM;hint.size=Vector2(65,65);ui.add_child(hint)
	celebration=_label("",34,GREEN);celebration.position=Vector2(385,560);celebration.size=Vector2(520,58);celebration.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ui.add_child(celebration)

func _reset_recipe() -> void:
	pointer_id=-999;painting=false;dragging_jar=false;cursor.visible=false;transitioning=false;cut_done=false
	if is_instance_valid(donut):
		remove_child(donut);donut.queue_free()
	donut=Donut.new();add_child(donut);donut.position=DONUT_POS;donut.scale=DONUT_SCALE;donut.visible=false
	dough.visible=true;cutter.visible=true;cutter.position=DONUT_POS+Vector3(0,.65,0);cutter.scale=DONUT_SCALE
	oven.visible=false;door.rotation.x=PI*.43
	celebration.text=""
	_set_stage(Stage.CUT)

func _set_stage(value:Stage) -> void:
	stage=value;selected_tool=0;last_paint=Vector2(INF,INF)
	pointer_id=-999;painting=false;dragging_jar=false;cursor.visible=false
	for b in tool_row.get_children():tool_row.remove_child(b);b.queue_free()
	tool_buttons.clear()
	var active_step:=0
	match stage:
		Stage.CUT:
			title.text="Let's make a donut!";subtitle.text="Press the cutter into the soft dough."
			speech.text="Hello, little baker!\nLet's do this together.";helper.text="Tap the round cutter.";next_button.text="Cut the dough";_tool("Round cutter","cut",Color("e3bd77"),0)
		Stage.LOAD:
			active_step=1;title.text="Time to get cozy";subtitle.text="Slide your donut into the oven."
			speech.text="I'll help with the oven. In it goes!";helper.text="Drag the donut up to the oven, or tap Bake.";next_button.text="Bake  >"
			_tool("Little oven","oven",Color("e6a17b"),0)
		Stage.BAKING:
			active_step=1;title.text="A little donut magic";subtitle.text="Warm and golden. Almost ready!"
			speech.text="Mmm… our shop smells so lovely.";helper.text="Pip is taking care of the baking.";next_button.text="Baking…"
			_tool("Getting golden","oven",Color("e6a17b"),0)
		Stage.FROST:
			active_step=2;title.text="A swirl of something sweet";subtitle.text="Pick a frosting. Rub your finger over the donut."
			speech.text="Pink? Chocolate?\nYou can mix them all!";helper.text="Little circles, big swirls. Every donut is lovely.";next_button.text="Toppings  >"
			for i in range(4):_tool(["Strawberry","Chocolate","Vanilla","Blueberry"][i],"bowl",frosting_colors[i],i)
		Stage.TOP:
			active_step=3;title.text="Sprinkle a little happiness";subtitle.text="Drag a jar over your donut and give it a sprinkle."
			speech.text="Ooh, that looks delicious! More sprinkles?";helper.text="Drag from a jar, or tap the donut to decorate.";next_button.text="Serve it!  >"
			for i in range(3):_tool(["Rainbow","Little stars","Sugar pearls"][i],topping_kinds[i],[PINK,Color("e1b860"),Color("9bbcaa")][i],i)
			_tool("Clear tops","reset",GREEN,3)
		Stage.SERVE:
			active_step=4;title.text="Made with a little love";subtitle.text="A one-of-a-kind donut, made by you."
			speech.text="Thank you, little baker! It's wonderful.";helper.text="Make another whenever you're ready.";next_button.text="Make another"
			_tool("You're a baker!","serve",PINK,0)
			celebration.text="Hooray for your donut!"
	for i in range(stage_icons.size()):
		stage_icons[i].add_theme_stylebox_override("panel",_style(Color("d7e8d9") if i<=active_step else CREAM,20))
		stage_icons[i].modulate.a=1 if i<=active_step else .6
	progress.visible=stage in [Stage.FROST,Stage.BAKING]
	progress.value=0
	next_button.disabled=stage==Stage.BAKING
	_select_tool(0)

func _tool(text:String,kind:String,color:Color,index:int) -> void:
	var b:=Button.new();b.custom_minimum_size=Vector2(174,86);b.focus_mode=Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",_style(Color("f2eadc"),17));b.add_theme_stylebox_override("hover",_style(Color("e5e8d7"),17));b.add_theme_stylebox_override("pressed",_style(Color("d7e8d9"),17))
	b.pressed.connect(func():_select_tool(index))
	tool_row.add_child(b);tool_buttons.append(b)
	var ic:=Icon.new();ic.kind=kind;ic.tint=color;ic.position=Vector2(9,6);ic.size=Vector2(65,65);b.add_child(ic)
	var l:=_label(text,16,INK);l.position=Vector2(77,17);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size=Vector2(92,58);l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;b.add_child(l)

func _select_tool(index:int) -> void:
	if stage==Stage.TOP and index==3:
		donut.clear_toppings();_chime(440);return
	selected_tool=index
	for i in range(tool_buttons.size()):
		var style:=_style(Color("e0ecd9") if i==index else Color("f2eadc"),17)
		if i==index:style.border_color=Color("7ca58c");style.set_border_width_all(2)
		tool_buttons[i].add_theme_stylebox_override("normal",style)
	cursor.kind="bowl" if stage==Stage.FROST else topping_kinds[mini(index,2)]
	cursor.tint=frosting_colors[mini(index,3)] if stage==Stage.FROST else PINK
	cursor.queue_redraw()

func _input(event:InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id==-999:_pointer_down(event.position,event.index)
		elif not event.pressed and event.index==pointer_id:_pointer_up(event.position)
	elif event is InputEventScreenDrag and event.index==pointer_id:_pointer_move(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:
		if event.pressed and pointer_id==-999:_pointer_down(event.position,-1)
		elif not event.pressed and pointer_id==-1:_pointer_up(event.position)
	elif event is InputEventMouseMotion and pointer_id==-1:_pointer_move(event.position)
	elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		# Android Back must not discard a toddler's creation.
		pointer_id=-999;painting=false;dragging_jar=false;cursor.visible=false

func _pointer_down(pos:Vector2,id:int) -> void:
	if transitioning:return
	for i in range(tool_buttons.size()):
		if tool_buttons[i].get_global_rect().has_point(pos):
			_select_tool(i)
			if stage==Stage.TOP and i<3:
				pointer_id=id;dragging_jar=true;cursor.visible=true;cursor.position=pos-Vector2(36,62);last_screen=pos
			return
	if pos.y<195 or pos.y>630 or pos.x<267:return
	pointer_id=id;last_screen=pos
	if stage==Stage.CUT and _near_donut(pos,1.9):_cut()
	elif stage==Stage.LOAD and _near_donut(pos,2):painting=true
	elif stage in [Stage.FROST,Stage.TOP]:
		painting=true;last_paint=Vector2(INF,INF);_apply_at(pos)

func _pointer_move(pos:Vector2) -> void:
	if stage==Stage.LOAD and painting:
		var p:=_plane_point(pos,1.25)
		if p!=Vector3.INF:donut.position=Vector3(clampf(p.x,-2,2),1.25,clampf(p.z,-.1,2.7))
	elif painting or dragging_jar:
		if stage in [Stage.FROST,Stage.TOP]:
			# Interpolate so quick toddler swipes leave a continuous trail.
			var steps:=mini(24,maxi(1,int(last_screen.distance_to(pos)/10)))
			for i in range(1,steps+1):_apply_at(last_screen.lerp(pos,float(i)/steps))
	if dragging_jar:cursor.position=pos-Vector2(36,62)
	last_screen=pos

func _pointer_up(pos:Vector2) -> void:
	if stage==Stage.LOAD and painting:
		if donut.position.z<.9:_start_bake()
		else:create_tween().tween_property(donut,"position",DONUT_POS,.25)
	elif dragging_jar:_apply_at(pos)
	pointer_id=-999;painting=false;dragging_jar=false;cursor.visible=false;last_paint=Vector2(INF,INF)

func _plane_point(pos:Vector2,height:float) -> Vector3:
	var origin:=camera.project_ray_origin(pos)
	var ray:=camera.project_ray_normal(pos)
	var hit:Variant=Plane(Vector3.UP,height).intersects_ray(origin,ray)
	return hit if hit!=null else Vector3.INF

func _local_hit(pos:Vector2) -> Vector2:
	# Solve intersection with the upper torus surface. Picking follows the visible icing.
	var origin:Vector3=donut.to_local(camera.project_ray_origin(pos))
	var ray:Vector3=donut.global_transform.basis.inverse()*camera.project_ray_normal(pos)
	var top_t:float=(.39-origin.y)/ray.y
	var bottom_t:float=(-.03-origin.y)/ray.y
	var previous:=1.0
	for i in range(49):
		var t:=lerpf(top_t,bottom_t,float(i)/48)
		var p:=origin+ray*t
		var xz:=Vector2(p.x,p.z)
		if donut.is_on_ring(xz,.02):
			var gap:float=p.y-donut.surface_height(xz)
			if gap<=.012 and previous>0:return xz
			previous=gap
	var fallback:Vector3=donut.to_local(_plane_point(pos,donut.position.y+.16*donut.scale.y))
	return Vector2(fallback.x,fallback.z)

func _near_donut(pos:Vector2,radius:float) -> bool:
	var p:=_plane_point(pos,donut.position.y)-donut.position
	return Vector2(p.x,p.z).length()<radius

func _apply_at(pos:Vector2) -> void:
	if pos.y<190 or pos.y>630 or pos.x<267:return
	var p:=_local_hit(pos)
	if stage==Stage.FROST:
		if p.distance_to(last_paint)<.045:return
		if donut.paint(p,frosting_colors[selected_tool]):
			last_paint=p;progress.value=minf(100,float(donut.painted_pixels)/31000*100)
			if sound_cooldown<=0:_chime(600+selected_tool*70,.055);sound_cooldown=.2
	elif stage==Stage.TOP:
		if p.distance_to(last_paint)<.13:return
		if donut.add_topping(p,topping_kinds[mini(selected_tool,2)]):
			last_paint=p
			# A little scatter makes a single finger feel like a real sprinkle jar.
			for i in range(2):donut.add_topping(p+Vector2(randf_range(-.15,.15),randf_range(-.15,.15)),topping_kinds[mini(selected_tool,2)])
			if sound_cooldown<=0:_chime(randf_range(850,1200),.055);sound_cooldown=.13

func _cut() -> void:
	if cut_done or transitioning:return
	cut_done=true;transitioning=true;_chime(430,.14)
	var tween:=create_tween();tween.tween_property(cutter,"position:y",1.04,.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():dough.visible=false;donut.visible=true;_burst(DONUT_POS,12);_chime(660))
	tween.tween_property(cutter,"position:y",2.1,.35)
	tween.tween_callback(func():cutter.visible=false;oven.visible=true;transitioning=false;_set_stage(Stage.LOAD))

func _start_bake() -> void:
	if stage!=Stage.LOAD or transitioning:return
	transitioning=true;painting=false
	var tween:=create_tween();tween.tween_property(donut,"position",Vector3(0,1.3,.25),.45)
	tween.parallel().tween_property(donut,"scale",Vector3.ONE*.85,.45)
	tween.tween_property(door,"rotation:x",0.0,.35)
	tween.tween_callback(func():donut.visible=false;transitioning=false;bake_time=0;_set_stage(Stage.BAKING);_chime(510))

func _finish_bake() -> void:
	transitioning=true;donut.bake(1);donut.visible=true
	var tween:=create_tween();tween.tween_property(door,"rotation:x",PI*.43,.35)
	tween.tween_property(donut,"position",DONUT_POS,.5)
	tween.parallel().tween_property(donut,"scale",DONUT_SCALE,.5)
	tween.tween_callback(func():oven.visible=false;transitioning=false;_set_stage(Stage.FROST);_chime(880,.3);_burst(DONUT_POS,12))

func _next() -> void:
	if transitioning:return
	match stage:
		Stage.CUT:_cut()
		Stage.LOAD:_start_bake()
		Stage.FROST:_set_stage(Stage.TOP);_chime(720)
		Stage.TOP:
			_set_stage(Stage.SERVE);completed+=1;_save_settings();_burst(DONUT_POS+Vector3(0,1,0),50);_chime(880,.4)
		Stage.SERVE:_reset_recipe();_chime(520)

func _process(delta:float) -> void:
	elapsed+=delta;sound_cooldown-=delta
	if is_instance_valid(bear):
		bear.position.y=.8+sin(elapsed*1.8)*.035
		bear.rotation.z=sin(elapsed*1.3)*.025
		bunny.position.y=.8+sin(elapsed*2.1+1)*.045
		bunny.rotation.z=sin(elapsed*1.6)*.03
		if is_instance_valid(bear_paw):bear_paw.rotation.z=sin(elapsed*3.2)*.27
		if is_instance_valid(bunny_paw):bunny_paw.rotation.x=sin(elapsed*3)*.35
		if is_instance_valid(spoon):spoon.rotation=Vector3(sin(elapsed*3)*.2,0,cos(elapsed*3)*.2)
	if stage==Stage.BAKING and not transitioning:
		bake_time+=delta;progress.value=bake_time/4*100
		if bake_time>=4:_finish_bake()
	if stage==Stage.SERVE:donut.rotation.y+=delta*.16
	if is_instance_valid(hint):
		hint.visible=pointer_id==-999 and stage in [Stage.CUT,Stage.FROST,Stage.TOP] and not transitioning
		var target:=DONUT_POS+Vector3(.8,.5,0)
		hint.position=camera.unproject_position(target)+Vector2(sin(elapsed*2)*18,cos(elapsed*2)*10)
		hint.modulate.a=.65+sin(elapsed*3)*.2
	for i in range(confetti.size()-1,-1,-1):
		var f:Dictionary=confetti[i];f.life-=delta
		f.node.position+=f.velocity*delta;f.velocity.y-=delta*3
		f.node.rotation+=Vector3(2,1,3)*delta
		if f.life<.4:f.node.scale=Vector3.ONE*maxf(0,f.life/.4)
		if f.life<=0:f.node.queue_free();confetti.remove_at(i)

func _burst(center:Vector3,count:int) -> void:
	for i in range(count):
		var m:=BoxMesh.new();m.size=Vector3(.055,.015,.11)
		var n:=MeshInstance3D.new();n.mesh=m;n.material_override=_material([PINK,Color("a99acb"),Color("e9bd5e"),Color("8dbca0")][i%4]);sparkle_root.add_child(n);n.position=center
		confetti.append({"node":n,"velocity":Vector3(randf_range(-2,2),randf_range(2,4),randf_range(-1.5,1.5)),"life":randf_range(1,2)})

func _chime(hz:float,duration:=.13) -> void:
	if not sound_on or smoke_test:return
	var rate:=22050
	var data:=PackedByteArray();data.resize(int(duration*rate)*2)
	for i in range(data.size()/2):
		var t:=float(i)/rate;var envelope:=sin(PI*t/duration)*exp(-t*10)
		var value:=int((sin(TAU*hz*t)+.22*sin(TAU*hz*2*t))*envelope*6500)
		data.encode_s16(i*2,value)
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data;audio.stream=stream;audio.play()

func _toggle_sound() -> void:
	sound_on=not sound_on
	(sound_button.get_node("SoundIcon") as Control).kind="sound" if sound_on else "mute"
	sound_button.get_node("SoundIcon").queue_redraw();_save_settings();_chime(660)

func _load_settings() -> void:
	var config:=ConfigFile.new()
	if config.load("user://bakery.cfg")==OK:
		sound_on=config.get_value("bakery","sound",true);completed=config.get_value("bakery","completed",0)
	sound_button.get_node("SoundIcon").kind="sound" if sound_on else "mute";sound_button.get_node("SoundIcon").queue_redraw()

func _save_settings() -> void:
	var config:=ConfigFile.new();config.set_value("bakery","sound",sound_on);config.set_value("bakery","completed",completed);config.save("user://bakery.cfg")

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_GO_BACK_REQUEST]:
		pointer_id=-999;painting=false;dragging_jar=false
		if is_instance_valid(cursor):cursor.visible=false

func _material(col:Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=col;m.roughness=.72;return m

func _mesh(mesh:PrimitiveMesh,pos:Vector3,col:Color,scale_value:Vector3) -> MeshInstance3D:
	var m:=MeshInstance3D.new();m.mesh=mesh;m.position=pos;m.scale=scale_value;m.material_override=_material(col);add_child(m);return m

func _box_in(parent:Node3D,pos:Vector3,scale_value:Vector3,col:Color) -> void:
	var n:=MeshInstance3D.new();n.mesh=BoxMesh.new();n.position=pos;n.scale=scale_value;n.material_override=_material(col);parent.add_child(n)

func _label(text:String,font_size:int,color:Color) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;return l

func _style(color:Color,radius:int) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius);return s

func _showcase() -> void:
	dough.visible=false;cutter.visible=false;donut.visible=true;donut.bake(1);_set_stage(Stage.TOP)
	for i in range(70):
		var angle:=float(i)*TAU/70
		donut.paint(Vector2(cos(angle),sin(angle))*.88,frosting_colors[0])
	for i in range(95):
		var a:=randf()*TAU;var r:=randf_range(.62,1.16)
		donut.add_topping(Vector2(cos(a),sin(a))*r,"sprinkles" if i%4 else "stars")

func _run_smoke_test() -> void:
	await get_tree().process_frame
	assert(stage==Stage.CUT and not donut.visible)
	_cut();await get_tree().create_timer(.85).timeout
	assert(stage==Stage.LOAD and donut.visible and not dough.visible)
	_start_bake();await get_tree().create_timer(6).timeout
	assert(stage==Stage.FROST and not oven.visible)
	var screen:=camera.unproject_position(DONUT_POS+Vector3(.88,.37,0))
	_pointer_down(screen,3);_pointer_move(screen+Vector2(15,8));_pointer_up(screen)
	assert(donut.painted_pixels>0,"Touch must paint frosting")
	assert(pointer_id==-999,"Pointer must reset on release")
	var before:int=donut.painted_pixels
	_apply_at(Vector2(10,10));assert(donut.painted_pixels==before,"HUD must not paint")
	_next();assert(stage==Stage.TOP)
	_pointer_down(screen,4);_pointer_up(screen)
	assert(donut.topping_count>0,"Touch must add toppings")
	assert(not donut.add_topping(Vector2.ZERO,"stars"),"Hole must reject toppings")
	for i in range(250):donut.add_topping(Vector2(.88,0),"pearls")
	assert(donut.topping_count==Donut.MAX_TOPPINGS,"Toppings must be bounded")
	_select_tool(3);assert(donut.topping_count==0)
	_next();assert(stage==Stage.SERVE)
	_next();assert(stage==Stage.CUT and donut.painted_pixels==0 and donut.topping_count==0)
	print("SMOKE TEST PASS: cut, bake, touch frosting, toppings, limits, serve, replay")
	get_tree().quit()

func _capture(name:String) -> void:
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/previews")
	get_viewport().get_texture().get_image().save_png("res://builds/previews/"+name+".png")

func _visual_test() -> void:
	await _capture("01-cut")
	_cut();await get_tree().create_timer(1).timeout
	await _capture("02-oven")
	_start_bake();await get_tree().create_timer(6).timeout
	for i in range(50):
		var a:=i*TAU/50
		var p:=camera.unproject_position(DONUT_POS+Vector3(cos(a)*.88,.37,sin(a)*.88))
		_apply_at(p)
	await _capture("03-frost")
	_next()
	for i in range(80):
		var a:=i*TAU/80;var r:=randf_range(.6,1.17)
		var p:=camera.unproject_position(DONUT_POS+Vector3(cos(a)*r,donut.surface_height(Vector2(cos(a)*r,sin(a)*r))+.04,sin(a)*r))
		_apply_at(p)
	await _capture("04-toppings")
	_next()
	await _capture("05-serve")
	print("VISUAL TEST COMPLETE")
	get_tree().quit()

func _capture_only() -> void:
	_showcase()
	await _capture("00-showcase")
	get_tree().quit()

func _build_helper_props() -> void:
	for child in bear.find_children("*Paw*","Node3D",true,false):
		bear_paw=child;break
	for child in bunny.find_children("*Paw*","Node3D",true,false):
		bunny_paw=child;break
	# Bean stirs a bowl while Pip keeps a little rolling pin moving.
	var bowl:=SphereMesh.new();bowl.radius=.36;bowl.height=.48
	_mesh(bowl,Vector3(2.75,1.61,-.9),PINK,Vector3.ONE)
	var cream:=CylinderMesh.new();cream.top_radius=.29;cream.bottom_radius=.29;cream.height=.025
	_mesh(cream,Vector3(2.75,1.82,-.9),CREAM,Vector3.ONE)
	spoon=Node3D.new();add_child(spoon);spoon.position=Vector3(2.75,1.82,-.9)
	_box_in(spoon,Vector3(0,.23,0),Vector3(.055,.65,.055),Color("af784c"))
	var roller:=CylinderMesh.new();roller.top_radius=.10;roller.bottom_radius=.10;roller.height=.9
	var pin:=_mesh(roller,Vector3(-2.75,1.56,-.82),Color("c39560"),Vector3.ONE);pin.rotation.z=PI/2
