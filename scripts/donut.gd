class_name Donut
extends Node3D
## Procedural donut. Torus meshes are built once and shared, frosting is painted on the CPU
## with Image.blend_rect and uploaded at most once per frame, and toppings are three
## MultiMeshes so a fully decorated donut stays at a handful of draw calls on a phone.
const R := 0.88
const TUBE := 0.43
const HEIGHT := 0.34
const TEX_SIZE := 256
const EXTENT := 1.4
const MAX_TOPPINGS := 220
const BRUSH_RADIUS := 24
## Coverage grid resolution used for the frosting progress bar.
const GRID := 32
const GROW_TIME := 0.18
const BREAD_RAW := Color("efc485")
const BREAD_BAKED := Color("bf783b")
const TOPPING_KINDS := ["sprinkles", "stars", "pearls"]
const SPRINKLE_COLORS := [
	Color("f2c957"), Color("f3eddb"), Color("dd6c90"), Color("83baa6"), Color("9f89c4")
]
const PEARL_COLOR := Color("fff1ca")
const STAR_COLOR := Color("f5ce64")
const QUAD_CORNERS := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)
]

static var bread_mesh: ArrayMesh
static var frosting_mesh: ArrayMesh
static var topping_meshes: Dictionary = {}
static var topping_material: StandardMaterial3D
static var brushes: Dictionary = {}

var bread: MeshInstance3D
var frosting: MeshInstance3D
var paint_image: Image
var paint_texture: ImageTexture
var paint_dirty := false
## Number of brush dabs applied since the last reset.
var dab_count := 0
## Coverage cells on the ring that have been painted; see coverage().
var painted_cells := 0
var ring_cells := 0
var coverage_grid := PackedByteArray()
var topping_count := 0
var multimeshes: Dictionary = {}
var growing: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	if bread_mesh == null:
		bread_mesh = _torus(false)
		frosting_mesh = _torus(true)
		topping_meshes["pearls"] = _pearl_mesh()
		topping_meshes["stars"] = _star_mesh()
		topping_meshes["sprinkles"] = _sprinkle_mesh()
		topping_material = StandardMaterial3D.new()
		topping_material.roughness = .65
		topping_material.vertex_color_use_as_albedo = true
	bread = MeshInstance3D.new()
	bread.mesh = bread_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = BREAD_RAW
	material.roughness = .85
	bread.material_override = material
	add_child(bread)
	paint_image = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	paint_image.fill(Color.TRANSPARENT)
	paint_texture = ImageTexture.create_from_image(paint_image)
	frosting = MeshInstance3D.new()
	frosting.mesh = frosting_mesh
	frosting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frosting_material := StandardMaterial3D.new()
	frosting_material.albedo_texture = paint_texture
	frosting_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	frosting_material.alpha_scissor_threshold = .2
	frosting_material.roughness = .48
	frosting.material_override = frosting_material
	add_child(frosting)
	for kind in TOPPING_KINDS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = topping_meshes[kind]
		mm.instance_count = MAX_TOPPINGS
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = topping_material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		multimeshes[kind] = mmi
	_build_coverage_grid()


func _process(delta: float) -> void:
	if paint_dirty:
		paint_texture.update(paint_image)
		paint_dirty = false
	for i in range(growing.size() - 1, -1, -1):
		var g: Dictionary = growing[i]
		g.t += delta
		var s: float = Tween.interpolate_value(
			.05, .95, minf(g.t, GROW_TIME), GROW_TIME, Tween.TRANS_BACK, Tween.EASE_OUT
		)
		_set_topping_transform(g.kind, g.index, g.basis, g.origin, s)
		if g.t >= GROW_TIME:
			growing.remove_at(i)


## Clears frosting, toppings and bake color so the same instance serves the next recipe.
func reset() -> void:
	paint_image.fill(Color.TRANSPARENT)
	paint_texture.update(paint_image)
	paint_dirty = false
	dab_count = 0
	painted_cells = 0
	_build_coverage_grid()
	clear_toppings()
	bake(0)
	rotation = Vector3.ZERO


func bake(amount: float) -> void:
	bread.material_override.albedo_color = BREAD_RAW.lerp(BREAD_BAKED, amount)


func surface_height(p: Vector2) -> float:
	var v := clampf((p.length() - R) / TUBE, -1, 1)
	return HEIGHT * sqrt(maxf(0, 1 - v * v)) + .025


func is_on_ring(p: Vector2, margin := 0.0) -> bool:
	var d := p.length()
	return d > R - TUBE - margin and d < R + TUBE + margin


## Fraction (0-1) of the ring that has received frosting.
func coverage() -> float:
	return float(painted_cells) / ring_cells if ring_cells > 0 else 0.0


func paint(p: Vector2, color: Color) -> bool:
	if not is_on_ring(p, .20):
		return false
	var center := (p / EXTENT + Vector2.ONE) * .5 * TEX_SIZE
	var brush := _brush_for(color)
	var dst := Vector2i(center) - Vector2i(BRUSH_RADIUS, BRUSH_RADIUS)
	paint_image.blend_rect(brush, Rect2i(Vector2i.ZERO, brush.get_size()), dst)
	paint_dirty = true
	dab_count += 1
	# Coverage grid: cells within the brush radius count as painted.
	var cell := Vector2i(center / (TEX_SIZE / GRID))
	var reach := ceili(float(BRUSH_RADIUS) / (TEX_SIZE / GRID))
	for cy in range(maxi(0, cell.y - reach), mini(GRID, cell.y + reach + 1)):
		for cx in range(maxi(0, cell.x - reach), mini(GRID, cell.x + reach + 1)):
			if Vector2i(cx, cy).distance_to(cell) > reach:
				continue
			var i := cy * GRID + cx
			if coverage_grid[i] == 1:
				coverage_grid[i] = 2
				painted_cells += 1
	return true


func add_topping(p: Vector2, kind: String) -> bool:
	if not is_on_ring(p) or topping_count >= MAX_TOPPINGS:
		return false
	var mm: MultiMesh = multimeshes[kind].multimesh
	var index := mm.visible_instance_count
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	var color: Color
	match kind:
		"pearls":
			color = PEARL_COLOR
		"stars":
			color = STAR_COLOR
		_:
			# Capsules lie flat, then take a random heading.
			basis = basis * Basis(Vector3.BACK, PI / 2)
			color = SPRINKLE_COLORS[rng.randi_range(0, SPRINKLE_COLORS.size() - 1)]
	var origin := Vector3(p.x, surface_height(p) + .046, p.y)
	_set_topping_transform(kind, index, basis, origin, .05)
	mm.set_instance_color(index, color)
	mm.visible_instance_count = index + 1
	growing.append({"kind": kind, "index": index, "basis": basis, "origin": origin, "t": 0.0})
	topping_count += 1
	return true


func clear_toppings() -> void:
	for mmi in multimeshes.values():
		mmi.multimesh.visible_instance_count = 0
	growing.clear()
	topping_count = 0


## Draws one instance of every topping kind for a frame so their shader compiles early.
func set_warm_up(enabled: bool) -> void:
	for kind in TOPPING_KINDS:
		var mm: MultiMesh = multimeshes[kind].multimesh
		if enabled:
			mm.set_instance_transform(
				0, Transform3D(Basis().scaled(Vector3.ONE * .01), Vector3.ZERO)
			)
			mm.set_instance_color(0, Color.WHITE)
			mm.visible_instance_count = 1
		else:
			mm.visible_instance_count = 0


func _set_topping_transform(
	kind: String, index: int, basis: Basis, origin: Vector3, s: float
) -> void:
	multimeshes[kind].multimesh.set_instance_transform(
		index, Transform3D(basis.scaled(Vector3.ONE * s), origin)
	)


func _build_coverage_grid() -> void:
	coverage_grid.resize(GRID * GRID)
	coverage_grid.fill(0)
	ring_cells = 0
	for cy in range(GRID):
		for cx in range(GRID):
			var local := (Vector2(cx + .5, cy + .5) / GRID * 2 - Vector2.ONE) * EXTENT
			if is_on_ring(local):
				coverage_grid[cy * GRID + cx] = 1
				ring_cells += 1


## A soft round stamp per frosting color, built once and alpha-blended by Image.blend_rect.
static func _brush_for(color: Color) -> Image:
	if brushes.has(color):
		return brushes[color]
	var size := BRUSH_RADIUS * 2 + 1
	var brush := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(Vector2.ONE * BRUSH_RADIUS) / BRUSH_RADIUS
			var col := color
			col.a = clampf((1 - d) * 5, 0, 1) * .8 if d <= 1 else 0.0
			brush.set_pixel(x, y, col)
	brushes[color] = brush
	return brush


static func _torus(top: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 96
	var sides := 20 if top else 32
	for i in range(rings):
		for j in range(sides):
			for corner in QUAD_CORNERS:
				var u: float = (i + corner.x) * TAU / rings
				var v: float = (j + corner.y) * (PI if top else TAU) / sides
				var rad: float = R + (TUBE + (.014 if top else 0)) * cos(v)
				var point := Vector3(
					rad * cos(u),
					(HEIGHT + (.015 if top else 0)) * sin(v) + (.008 if top else 0),
					rad * sin(u)
				)
				st.set_normal(
					Vector3(cos(u) * cos(v), sin(v) * TUBE / HEIGHT, sin(u) * cos(v)).normalized()
				)
				st.set_uv(Vector2(point.x, point.z) / EXTENT * .5 + Vector2.ONE * .5)
				st.add_vertex(point)
	st.index()
	return st.commit()


static func _pearl_mesh() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = .057
	m.height = .114
	m.radial_segments = 10
	m.rings = 6
	return m


static func _sprinkle_mesh() -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = .026
	m.height = .16
	m.radial_segments = 6
	m.rings = 2
	return m


static func _star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		var a := i * TAU / 10
		var b := (i + 1) * TAU / 10
		var r1 := .11 if i % 2 == 0 else .05
		var r2 := .05 if i % 2 == 0 else .11
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(b) * r2, 0, sin(b) * r2))
		st.add_vertex(Vector3(cos(a) * r1, 0, sin(a) * r1))
	return st.commit()
