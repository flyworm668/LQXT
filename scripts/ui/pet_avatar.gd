extends Control
## Procedural pet portrait.  Everything is vector art drawn at runtime so the
## project ships without any third-party assets.

var pid: String = ""
var element: String = "fire"
var pet_class: String = "warrior"
var stage: int = 0
var avatar_size: float = 72.0
var is_boss: bool = false
var is_enemy: bool = false
var variant: int = 0

var _base: Color = Color.WHITE
var _dark: Color = Color.BLACK
var _light: Color = Color.WHITE


func setup(species_id: String, px: float, level: int = 10, boss: bool = false, enemy: bool = false) -> void:
	pid = species_id
	avatar_size = px
	is_boss = boss
	is_enemy = enemy
	variant = abs(hash(pid)) % 5
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: Dictionary = ContentDB.pet(pid)
	if p.is_empty() and boss:
		# boss ids are not species ids; fall back by element/class set below
		pass
	element = str(p.get("element", "light"))
	pet_class = str(p.get("class", "warrior"))
	stage = 2 if boss else ContentDB.stage_for_level(level)
	_base = ContentDB.element_color(element)
	_dark = _base.darkened(0.52)
	_light = _base.lightened(0.38)
	queue_redraw()


func setup_boss(boss_data: Dictionary, px: float) -> void:
	pid = str(boss_data.get("id", "boss"))
	avatar_size = px
	is_boss = true
	is_enemy = true
	variant = abs(hash(pid)) % 5
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	element = str(boss_data.get("element", "dark"))
	pet_class = str(boss_data.get("class", "warrior"))
	stage = 2
	_base = ContentDB.element_color(element)
	_dark = _base.darkened(0.52)
	_light = _base.lightened(0.38)
	queue_redraw()


func _draw() -> void:
	var s := avatar_size
	if s <= 0.0:
		s = min(size.x, size.y)
	if s <= 0.0:
		return
	var c := Vector2(s * 0.5, s * 0.52)
	var r := s * (0.29 if not is_boss else 0.30)
	_draw_aura(c, r)
	_draw_shadow(c, r)
	_draw_weapon(c, r)
	_draw_element_head(c, r)
	if is_boss:
		_draw_crown(c, r)
	_draw_body(c, r)
	_draw_face(c, r)
	_draw_element_mark(c, r)
	if stage >= 2 and not is_boss:
		_draw_crown(c, r, 0.16)


func _circle(center: Vector2, radius: float, color: Color, segments: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segments: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _outline_circle(center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	draw_arc(center, radius, 0.0, TAU, 40, color, width, true)


func _draw_aura(c: Vector2, r: float) -> void:
	if is_boss:
		_ellipse(c, r * 2.05, r * 1.9, Color(_base.r, _base.g, _base.b, 0.10))
		_outline_circle(c, r * 1.85, Color(_base.r, _base.g, _base.b, 0.28), 2.0)
		_outline_circle(c, r * 1.55, Color(_base.r, _base.g, _base.b, 0.18), 1.5)
	elif stage >= 2:
		_ellipse(c, r * 1.55, r * 1.45, Color(_base.r, _base.g, _base.b, 0.10))
		_outline_circle(c, r * 1.42, Color(_base.r, _base.g, _base.b, 0.22), 1.5)


func _draw_shadow(c: Vector2, r: float) -> void:
	_ellipse(c + Vector2(0, r * 0.96), r * 0.85, r * 0.22, Color(0, 0, 0, 0.28))


func _draw_body(c: Vector2, r: float) -> void:
	match pet_class:
		"guardian":
			_ellipse(c, r * 1.10, r * 0.98, _dark)
			_ellipse(c + Vector2(0, -r * 0.06), r * 1.02, r * 0.90, _base)
			_ellipse(c + Vector2(0, r * 0.18), r * 0.72, r * 0.55, _base.lightened(0.18))
		"warrior":
			var pts := PackedVector2Array()
			for i in range(6):
				var a := TAU * float(i) / 6.0 - PI / 2.0
				pts.append(c + Vector2(cos(a) * r * 1.02, sin(a) * r * 0.96))
			draw_colored_polygon(pts, _base)
			_ellipse(c + Vector2(0, r * 0.2), r * 0.62, r * 0.5, _base.lightened(0.18))
		"mage":
			_ellipse(c + Vector2(0, r * 0.18), r * 0.92, r * 1.02, _dark)
			_ellipse(c + Vector2(0, -r * 0.10), r * 0.82, r * 0.78, _base)
			var robe := PackedVector2Array([
				c + Vector2(-r * 0.92, r * 0.20),
				c + Vector2(r * 0.92, r * 0.20),
				c + Vector2(r * 0.62, r * 1.12),
				c + Vector2(-r * 0.62, r * 1.12),
			])
			draw_colored_polygon(robe, _dark)
			draw_polyline(robe + PackedVector2Array([robe[0]]), _base.lightened(0.1), 1.5, true)
		"archer":
			_ellipse(c, r * 0.82, r * 1.02, _base)
			_ellipse(c + Vector2(0, r * 0.18), r * 0.55, r * 0.52, _base.lightened(0.22))
			# hood tips
			var tip_l := PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.75), c + Vector2(-r * 0.15, -r * 0.55), c + Vector2(-r * 0.55, -r * 0.25)])
			var tip_r := PackedVector2Array([c + Vector2(r * 0.55, -r * 0.75), c + Vector2(r * 0.15, -r * 0.55), c + Vector2(r * 0.55, -r * 0.25)])
			draw_colored_polygon(tip_l, _dark)
			draw_colored_polygon(tip_r, _dark)
		"support":
			_ellipse(c, r * 1.0, r * 0.95, _base)
			_ellipse(c + Vector2(0, r * 0.18), r * 0.7, r * 0.56, _base.lightened(0.26))
		_:
			_circle(c, r, _base)
	# subtle outline
	_outline_circle(c, r * 1.0, _dark, 1.5)


func _draw_face(c: Vector2, r: float) -> void:
	var eye_y := c.y - r * 0.06
	var eye_dx := r * 0.33
	var eye_rx := r * 0.20
	var eye_ry := r * 0.25
	var pupil := Color("#1a1622") if not is_enemy else Color("#351420")
	for side in [-1.0, 1.0]:
		var ec := Vector2(c.x + side * eye_dx, eye_y)
		_ellipse(ec, eye_rx, eye_ry, Color("#f7f4ef"))
		var px := ec + Vector2(side * r * 0.03, r * 0.02)
		_ellipse(px, eye_rx * 0.55, eye_ry * 0.62, pupil)
		_ellipse(px + Vector2(-eye_rx * 0.14, -eye_ry * 0.18), eye_rx * 0.17, eye_ry * 0.18, Color(1, 1, 1, 0.9))
	# mouth
	var mouth_y := c.y + r * 0.40
	if variant % 2 == 0:
		draw_arc(Vector2(c.x, mouth_y), r * 0.17, 0.2, PI - 0.2, 10, _dark, 1.6, true)
	else:
		draw_line(Vector2(c.x - r * 0.13, mouth_y), Vector2(c.x + r * 0.13, mouth_y), _dark, 1.6, true)
	# blush
	_ellipse(Vector2(c.x - r * 0.62, c.y + r * 0.30), r * 0.13, r * 0.07, Color(1, 0.45, 0.5, 0.28))
	_ellipse(Vector2(c.x + r * 0.62, c.y + r * 0.30), r * 0.13, r * 0.07, Color(1, 0.45, 0.5, 0.28))


func _draw_element_head(c: Vector2, r: float) -> void:
	match element:
		"fire":
			for i in range(3):
				var off := float(i - 1) * r * 0.34
				var h := r * (0.55 if i == 1 else 0.36)
				var pts := PackedVector2Array([
					c + Vector2(off - r * 0.19, -r * 0.78),
					c + Vector2(off, -r * 0.78 - h),
					c + Vector2(off + r * 0.19, -r * 0.78),
				])
				draw_colored_polygon(pts, _base.lightened(0.18))
				var inner := PackedVector2Array([
					c + Vector2(off - r * 0.08, -r * 0.80),
					c + Vector2(off, -r * 0.80 - h * 0.58),
					c + Vector2(off + r * 0.08, -r * 0.80),
				])
				draw_colored_polygon(inner, Color("#ffe8a3"))
		"water":
			var fin_l := PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.15), c + Vector2(-r * 1.30, -r * 0.55), c + Vector2(-r * 0.86, -r * 0.55)])
			var fin_r := PackedVector2Array([c + Vector2(r * 0.9, -r * 0.15), c + Vector2(r * 1.30, -r * 0.55), c + Vector2(r * 0.86, -r * 0.55)])
			draw_colored_polygon(fin_l, _base.lightened(0.25))
			draw_colored_polygon(fin_r, _base.lightened(0.25))
			_ellipse(c + Vector2(0, -r * 0.9), r * 0.11, r * 0.16, Color("#bfe9ff"))
		"wind":
			for side in [-1.0, 1.0]:
				var start := c + Vector2(side * r * 0.62, -r * 0.72)
				draw_line(start, start + Vector2(side * r * 0.35, -r * 0.32), _light, 2.4, true)
				draw_line(start + Vector2(side * r * 0.18, -r * 0.18), start + Vector2(side * r * 0.44, r * 0.02), _light, 1.8, true)
		"earth":
			for side in [-1.0, 1.0]:
				var pts := PackedVector2Array([
					c + Vector2(side * r * 0.55, -r * 0.65),
					c + Vector2(side * r * 0.78, -r * 1.10),
					c + Vector2(side * r * 0.92, -r * 0.62),
				])
				draw_colored_polygon(pts, _base.darkened(0.15))
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(side * r * 0.68, -r * 0.68),
					c + Vector2(side * r * 0.78, -r * 0.95),
					c + Vector2(side * r * 0.84, -r * 0.65),
				]), _light)
		"light":
			draw_arc(c + Vector2(0, -r * 0.98), r * 0.38, PI * 1.08, PI * 1.92, 18, Color("#ffe9a8"), 3.0, true)
			for side in [-1.0, 1.0]:
				var wing := PackedVector2Array([
					c + Vector2(side * r * 0.78, -r * 0.10),
					c + Vector2(side * r * 1.26, -r * 0.62),
					c + Vector2(side * r * 1.08, -r * 0.06),
				])
				draw_colored_polygon(wing, Color(1, 0.92, 0.62, 0.55))
		"dark":
			for side in [-1.0, 1.0]:
				var p0 := c + Vector2(side * r * 0.42, -r * 0.78)
				var p1 := c + Vector2(side * r * 0.72, -r * 1.22)
				var p2 := c + Vector2(side * r * 0.78, -r * 0.70)
				draw_colored_polygon(PackedVector2Array([p0, p1, p2]), _base.darkened(0.28))
				draw_line(p0, p1, _light, 1.4, true)
			_ellipse(c + Vector2(0, -r * 0.08), r * 0.09, r * 0.22, Color(0.75, 0.45, 1.0, 0.75))


func _draw_element_mark(c: Vector2, r: float) -> void:
	match element:
		"fire":
			_ellipse(c + Vector2(0, r * 0.60), r * 0.16, r * 0.10, Color(1, 0.55, 0.2, 0.55))
		"water":
			draw_arc(c + Vector2(0, r * 0.58), r * 0.20, 0.3, PI - 0.3, 10, Color(0.7, 0.9, 1, 0.55), 1.4, true)
		"wind":
			draw_arc(c + Vector2(0, r * 0.58), r * 0.18, -0.6, 1.8, 10, Color(0.7, 1, 0.85, 0.55), 1.4, true)
		"earth":
			draw_line(c + Vector2(-r * 0.14, r * 0.58), c + Vector2(r * 0.14, r * 0.58), Color(1, 0.88, 0.55, 0.6), 1.6, true)
		"light":
			var star := PackedVector2Array()
			for i in range(8):
				var ang := TAU * float(i) / 8.0
				var rad := r * (0.18 if i % 2 == 0 else 0.07)
				star.append(c + Vector2(0, r * 0.56) + Vector2(cos(ang), sin(ang)) * rad)
			draw_colored_polygon(star, Color(1, 0.92, 0.6, 0.7))
		"dark":
			_ellipse(c + Vector2(0, r * 0.58), r * 0.16, r * 0.09, Color(0.6, 0.3, 0.9, 0.45))


func _draw_weapon(c: Vector2, r: float) -> void:
	var steel := Color("#cfd7e6")
	var gold := Color("#e8b95c")
	match pet_class:
		"warrior":
			var a := c + Vector2(-r * 1.18, r * 0.52)
			var b := c + Vector2(r * 1.18, -r * 1.02)
			draw_line(a, b, steel, max(2.0, r * 0.11), true)
			draw_line(b, b + Vector2(r * 0.16, -r * 0.02), steel, max(1.5, r * 0.07), true)
			draw_line(c + Vector2(-r * 0.38, r * 0.18), c + Vector2(-r * 0.65, r * 0.44), gold, max(2.0, r * 0.08), true)
		"mage":
			var top := c + Vector2(r * 1.10, -r * 0.95)
			draw_line(c + Vector2(r * 0.86, r * 0.72), top, Color("#8b6b4a"), max(2.0, r * 0.09), true)
			_circle(top + Vector2(0, -r * 0.08), r * 0.22, _base.lightened(0.25))
			_outline_circle(top + Vector2(0, -r * 0.08), r * 0.22, Color(1, 1, 1, 0.5), 1.5)
		"archer":
			draw_arc(c + Vector2(r * 1.02, 0), r * 0.72, -PI * 0.55, PI * 0.55, 20, Color("#c9a46a"), max(2.0, r * 0.075), true)
			draw_line(c + Vector2(r * 1.02, -r * 0.66), c + Vector2(r * 1.02, r * 0.66), Color(1, 1, 1, 0.55), 1.2, true)
		"guardian":
			var shield := PackedVector2Array([
				c + Vector2(-r * 1.05, -r * 0.28),
				c + Vector2(-r * 0.55, -r * 0.52),
				c + Vector2(-r * 0.55, r * 0.48),
				c + Vector2(-r * 1.05, r * 0.72),
			])
			draw_colored_polygon(shield, steel.darkened(0.15))
			draw_polyline(shield + PackedVector2Array([shield[0]]), gold, 1.4, true)
			draw_line(c + Vector2(-r * 0.80, -r * 0.22), c + Vector2(-r * 0.80, r * 0.46), gold, 1.2, true)
		"support":
			for i in range(3):
				var p := c + Vector2(r * (0.95 + 0.20 * (i % 2)), -r * (0.55 + 0.32 * i))
				draw_line(p + Vector2(-r * 0.09, 0), p + Vector2(r * 0.09, 0), Color(1, 0.9, 0.5, 0.8), 1.6, true)
				draw_line(p + Vector2(0, -r * 0.09), p + Vector2(0, r * 0.09), Color(1, 0.9, 0.5, 0.8), 1.6, true)


func _draw_crown(c: Vector2, r: float, scale_factor: float = 0.30) -> void:
	var w := r * (1.05 if is_boss else 0.72)
	var h := r * (0.68 if is_boss else 0.42)
	var top_y := c.y - r * (1.06 if is_boss else 0.98)
	var gold := Color("#f2c75c")
	var pts := PackedVector2Array([
		Vector2(c.x - w, top_y + h * 0.30),
		Vector2(c.x - w * 0.72, top_y - h * 0.55),
		Vector2(c.x - w * 0.30, top_y + h * 0.08),
		Vector2(c.x, top_y - h * 0.92),
		Vector2(c.x + w * 0.30, top_y + h * 0.08),
		Vector2(c.x + w * 0.72, top_y - h * 0.55),
		Vector2(c.x + w, top_y + h * 0.30),
	])
	draw_colored_polygon(pts, gold)
	draw_polyline(pts + PackedVector2Array([pts[0]]), gold.darkened(0.3), 1.2, true)
	_circle(Vector2(c.x, top_y - h * 0.20), r * 0.09, Color(1, 0.4, 0.35))
