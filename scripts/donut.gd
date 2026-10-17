extends Node3D
## UV frosting is painted in donut-local X/Z space. Stroke history survives recoloring.
const R := 0.88
const TUBE := 0.43
const HEIGHT := 0.34
const TEX_SIZE := 256
const EXTENT := 1.4
const MAX_TOPPINGS := 220
var bread:MeshInstance3D
var frosting:MeshInstance3D
var toppings:Node3D
var paint_image:Image
var paint_texture:ImageTexture
var painted_pixels := 0
var topping_count := 0
var rng := RandomNumberGenerator.new()
var frosting_material:StandardMaterial3D

func _ready() -> void:
	rng.randomize()
	bread = MeshInstance3D.new()
	bread.mesh = _torus(false)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("efc485")
	material.roughness=.85
	bread.material_override=material
	add_child(bread)
	paint_image=Image.create(TEX_SIZE,TEX_SIZE,false,Image.FORMAT_RGBA8)
	paint_image.fill(Color.TRANSPARENT)
	paint_texture=ImageTexture.create_from_image(paint_image)
	frosting=MeshInstance3D.new()
	frosting.mesh=_torus(true)
	frosting_material=StandardMaterial3D.new()
	frosting_material.albedo_texture=paint_texture
	frosting_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	frosting_material.alpha_scissor_threshold=.2
	frosting_material.roughness=.48
	frosting.material_override=frosting_material
	add_child(frosting)
	toppings=Node3D.new()
	add_child(toppings)

func bake(amount:float) -> void:
	bread.material_override.albedo_color=Color("efc485").lerp(Color("bf783b"),amount)

func surface_height(p:Vector2) -> float:
	var v:=clampf((p.length()-R)/TUBE,-1,1)
	return HEIGHT*sqrt(maxf(0,1-v*v))+.025

func is_on_ring(p:Vector2,margin:=0.0) -> bool:
	return p.length()>R-TUBE-margin and p.length()<R+TUBE+margin

func paint(p:Vector2,color:Color) -> bool:
	if not is_on_ring(p,.20):return false
	var center:Vector2=(p/EXTENT+Vector2.ONE)*.5*TEX_SIZE
	var radius:=24.0
	for y in range(maxi(0,int(center.y-radius)),mini(TEX_SIZE,int(center.y+radius+1))):
		for x in range(maxi(0,int(center.x-radius)),mini(TEX_SIZE,int(center.x+radius+1))):
			var d:=Vector2(x,y).distance_to(center)/radius
			if d>1:continue
			var old:=paint_image.get_pixel(x,y)
			var alpha:=clampf((1-d)*5,0,1)
			var col:=color
			col.a=maxf(old.a,alpha)
			if old.a>.1:col=old.lerp(col,alpha*.8)
			if old.a<.2 and col.a>=.2:painted_pixels+=1
			paint_image.set_pixel(x,y,col)
	paint_texture.update(paint_image)
	return true

func add_topping(p:Vector2,kind:String) -> bool:
	if not is_on_ring(p) or topping_count>=MAX_TOPPINGS:return false
	var item:=MeshInstance3D.new()
	var material:=StandardMaterial3D.new()
	material.roughness=.65
	var colors:=[Color("f2c957"),Color("f3eddb"),Color("dd6c90"),Color("83baa6"),Color("9f89c4")]
	material.albedo_color=colors[rng.randi_range(0,colors.size()-1)]
	match kind:
		"pearls":
			var m:=SphereMesh.new();m.radius=.057;m.height=.114;m.radial_segments=10;m.rings=6;item.mesh=m
			material.albedo_color=Color("fff1ca")
		"stars":
			item.mesh=_star_mesh()
			material.albedo_color=Color("f5ce64")
		_:
			var m:=CapsuleMesh.new();m.radius=.026;m.height=.16;m.radial_segments=6;m.rings=2;item.mesh=m
			item.rotation.z=PI/2
	item.material_override=material
	toppings.add_child(item)
	item.position=Vector3(p.x,surface_height(p)+.046,p.y)
	item.rotate_y(rng.randf()*TAU)
	item.scale=Vector3.ONE*.05
	create_tween().tween_property(item,"scale",Vector3.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	topping_count+=1
	return true

func clear_toppings() -> void:
	for child in toppings.get_children():child.queue_free()
	topping_count=0

func _torus(top:bool) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=96
	var sides:=20 if top else 32
	for i in range(rings):
		for j in range(sides):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var u:float=(i+corner.x)*TAU/rings
				var v:float=(j+corner.y)*(PI if top else TAU)/sides
				var rad:float=R+(TUBE+(.014 if top else 0))*cos(v)
				var point:=Vector3(rad*cos(u),(HEIGHT+(.015 if top else 0))*sin(v)+(.008 if top else 0),rad*sin(u))
				st.set_normal(Vector3(cos(u)*cos(v),sin(v)*TUBE/HEIGHT,sin(u)*cos(v)).normalized())
				st.set_uv(Vector2(point.x,point.z)/EXTENT*.5+Vector2.ONE*.5)
				st.add_vertex(point)
	st.index()
	return st.commit()

func _star_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		var a:=i*TAU/10;var b:=(i+1)*TAU/10
		var r1:=.11 if i%2==0 else .05;var r2:=.05 if i%2==0 else .11
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(b)*r2,0,sin(b)*r2))
		st.add_vertex(Vector3(cos(a)*r1,0,sin(a)*r1))
	return st.commit()
