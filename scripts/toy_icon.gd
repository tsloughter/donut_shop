class_name ToyIcon
extends Control
## Small, language-independent illustrations for touch controls.
const INK = Color("624636")
const CREAM = Color("fff6e5")

@export var kind := "donut":
	set(value):
		kind = value
		queue_redraw()
@export var tint := Color("eb92a6"):
	set(value):
		tint = value
		queue_redraw()


func _init() -> void:
	# Icons decorate buttons and the workbench; they never take the touch themselves.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) / 80.0
	draw_set_transform(c, 0, Vector2.ONE * s)
	match kind:
		"donut", "cut":
			draw_circle(Vector2(0, 3), 27, Color("c68a4e"))
			draw_circle(Vector2.ZERO, 26, tint if kind == "donut" else Color("f1cf8c"))
			draw_circle(Vector2.ZERO, 9, CREAM)
			if kind == "donut":
				for i in range(9):
					var a := float(i) * TAU / 9.0
					var p := Vector2(cos(a), sin(a)) * 18
					draw_line(
						p,
						p + Vector2(4, -3),
						[CREAM, Color("83b9a4"), Color("8b78ae")][i % 3],
						3,
						true
					)
			else:
				draw_arc(Vector2.ZERO, 29, 0, TAU, 48, INK, 3, true)
		"oven":
			draw_style_box(_box(tint, 9), Rect2(-30, -28, 60, 55))
			draw_style_box(_box(INK, 6), Rect2(-23, -11, 46, 30))
			draw_line(Vector2(-16, -4), Vector2(16, -4), CREAM, 4, true)
			for x in [-18, 0, 18]:
				draw_circle(Vector2(x, -21), 3, CREAM)
			draw_arc(Vector2(0, 12), 11, PI, TAU, 24, Color("f1b769"), 5, true)
		"bowl":
			draw_circle(Vector2.ZERO, 25, Color("c8b8a2"))
			draw_circle(Vector2(0, -3), 25, CREAM)
			draw_circle(Vector2(0, -3), 20, tint)
			draw_arc(Vector2(0, -3), 13, PI, TAU * 1.3, 36, tint.lightened(.3), 3, true)
			draw_line(Vector2(8, 3), Vector2(28, -26), Color("b98052"), 7, true)
		"sprinkles", "stars", "pearls":
			draw_style_box(_box(Color("d9e5d6"), 8), Rect2(-22, -22, 44, 48))
			draw_style_box(_box(tint, 5), Rect2(-24, -30, 48, 12))
			for i in range(13):
				var p := Vector2(-13 + (i * 17) % 29, -11 + (i * 13) % 31)
				var col: Color = [
					Color("e17f95"), Color("e9b95f"), Color("87bca9"), Color("a196c7")
				][i % 4]
				if kind == "sprinkles":
					draw_line(p, p + Vector2(4, 3), col, 3, true)
				elif kind == "pearls":
					draw_circle(p, 3.2, CREAM)
				else:
					_star(p, 4, Color("e4b454"))
		"serve":
			draw_style_box(_box(CREAM, 8), Rect2(-31, 6, 62, 16))
			draw_circle(Vector2(0, -4), 22, Color("e997a9"))
			draw_circle(Vector2(0, -4), 8, CREAM)
			_star(Vector2(25, -23), 8, Color("e4b454"))
		"arrow":
			draw_line(Vector2(-20, 0), Vector2(20, 0), tint, 5, true)
			draw_polyline(
				PackedVector2Array([Vector2(5, -15), Vector2(20, 0), Vector2(5, 15)]), tint, 5, true
			)
		"sound", "mute":
			draw_style_box(_box(tint, 3), Rect2(-22, -8, 12, 16))
			draw_colored_polygon(
				PackedVector2Array(
					[Vector2(-10, -8), Vector2(3, -19), Vector2(3, 19), Vector2(-10, 8)]
				),
				tint
			)
			if kind == "sound":
				draw_arc(Vector2(1, 0), 23, -.8, .8, 24, tint, 3, true)
			else:
				draw_line(Vector2(10, -13), Vector2(26, 13), tint, 3, true)
		"hand":
			draw_style_box(_box(tint, 11), Rect2(-16, -2, 33, 29))
			draw_line(Vector2(-9, 8), Vector2(-9, -24), tint, 11, true)
			draw_circle(Vector2(-9, -24), 5.5, tint)
			draw_arc(Vector2(-9, -24), 14, PI, TAU, 24, tint, 2, true)
		"reset":
			draw_arc(Vector2.ZERO, 20, -1, 4.5, 40, tint, 4, true)
			draw_colored_polygon(
				PackedVector2Array([Vector2(-5, -22), Vector2(8, -27), Vector2(3, -13)]), tint
			)


func _star(p: Vector2, r: float, col: Color) -> void:
	var points := PackedVector2Array()
	for j in range(10):
		var a := j * PI / 5.0 - PI / 2
		points.append(p + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * .45))
	draw_colored_polygon(points, col)


func _box(col: Color, r: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(r)
	return b
