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
var art_body: String = ""
var art_trait: String = ""
var rarity: String = "common"
var _ornate: bool = false
var _phase: float = 0.0

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
	var art: Dictionary = p.get("art", {})
	art_body = "" if boss else str(art.get("body", ""))
	art_trait = "" if boss else str(art.get("trait", ""))
	rarity = "boss" if boss else str(p.get("rarity", "common"))
	_ornate = rarity == "legend" or rarity == "hero" or rarity == "demon" or rarity == "boss"
	set_process(_ornate)
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
	art_body = ""
	art_trait = ""
	rarity = "boss"
	_ornate = true
	set_process(true)
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
	if not is_boss:
		r *= 0.90 if stage <= 0 else (1.0 if stage == 1 else 1.08)
	_draw_aura(c, r)
	_draw_shadow(c, r)
	if art_body != "":
		_draw_species(c, r)
		_draw_face(c, r)
		_draw_trait(c, r)
	else:
		_draw_weapon(c, r)
		_draw_element_head(c, r)
		if is_boss:
			_draw_crown(c, r)
		_draw_body(c, r)
		_draw_face(c, r)
		_draw_element_mark(c, r)
		if stage >= 2 and not is_boss:
			_draw_crown(c, r, 0.16)
	_draw_evolution(c, r)
	_draw_rarity(c, r)
	_draw_life(c, r)


func _process(delta: float) -> void:
	if not _ornate:
		set_process(false)
		return
	_phase += delta
	queue_redraw()


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
	if is_boss or rarity == "demon":
		var pulse := 0.94 + 0.06 * sin(_phase * 2.6)
		_ellipse(c, r * 1.32 * pulse, r * 1.16 * pulse, Color(0.45, 0.05, 0.08, 0.32))
		draw_arc(c, r * 1.20, -_phase, -_phase + 1.6, 12, Color(1, 0.28, 0.18, 0.7), 1.8, true)
	elif rarity == "hero":
		var pulse := 0.94 + 0.06 * sin(_phase * 2.2)
		_ellipse(c, r * 1.30 * pulse, r * 1.14 * pulse, Color(1.0, 0.82, 0.35, 0.20))
		_outline_circle(c, r * 1.18, Color(1.0, 0.86, 0.45, 0.75), 1.8)
	elif rarity == "legend":
		var pulse := 0.92 + 0.08 * sin(_phase * 2.4)
		_ellipse(c, r * 1.35 * pulse, r * 1.18 * pulse, Color(_base.r, _base.g, _base.b, 0.18))
		draw_arc(c, r * 1.22, _phase, _phase + 1.4, 12, Color(_light.r, _light.g, _light.b, 0.75), 1.8, true)
		draw_arc(c, r * 1.22, _phase + PI, _phase + PI + 1.1, 10, Color(1, 0.86, 0.45, 0.55), 1.4, true)
	elif stage >= 2 or rarity == "epic":
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
	var blink := _ornate and sin(_phase * 0.7) > 0.94
	for side in [-1.0, 1.0]:
		var ec := Vector2(c.x + side * eye_dx, eye_y)
		if blink:
			draw_line(ec + Vector2(-eye_rx, 0), ec + Vector2(eye_rx, 0), _dark, 1.6, true)
			continue
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


func _draw_evolution(c: Vector2, r: float) -> void:
	if is_boss or stage <= 0:
		return
	_circle(c + Vector2(0, r * 0.46), r * 0.09, Color(1, 0.95, 0.72, 0.92), 12)
	_outline_circle(c + Vector2(0, r * 0.46), r * 0.15, Color(1, 1, 1, 0.55), 1.2)
	draw_arc(c, r * 1.12, -0.7, 0.8, 12, Color(_light.r, _light.g, _light.b, 0.6), 1.3, true)
	if stage < 2:
		return
	for side in [-1.0, 1.0]:
		var plate := PackedVector2Array([
			c + Vector2(side * r * 0.48, -r * 0.18),
			c + Vector2(side * r * 1.02, -r * 0.38),
			c + Vector2(side * r * 0.92, r * 0.12),
			c + Vector2(side * r * 0.40, r * 0.04),
		])
		draw_colored_polygon(plate, _light)
		draw_polyline(plate + PackedVector2Array([plate[0]]), Color(1, 0.9, 0.55, 0.85), 1.2, true)
		var wing := PackedVector2Array([
			c + Vector2(side * r * 0.30, r * 0.10),
			c + Vector2(side * r * 1.22, r * 0.48),
			c + Vector2(side * r * 0.36, r * 0.42),
		])
		draw_colored_polygon(wing, Color(_base.r, _base.g, _base.b, 0.5))
	var crest := PackedVector2Array([
		c + Vector2(0, -r * 0.92),
		c + Vector2(-r * 0.13, -r * 1.32),
		c + Vector2(r * 0.13, -r * 0.92),
	])
	draw_colored_polygon(crest, Color(1, 0.86, 0.45, 0.95))


func _draw_rarity(c: Vector2, r: float) -> void:
	match rarity:
		"rare":
			_outline_circle(c, r * 1.28, Color(_light.r, _light.g, _light.b, 0.7), 1.6)
		"epic":
			_outline_circle(c, r * 1.22, Color(_light.r, _light.g, _light.b, 0.85), 1.8)
			_outline_circle(c, r * 1.40, Color(_base.r, _base.g, _base.b, 0.45), 1.2)
		"legend":
			var lift := sin(_phase * 2.2) * r * 0.06
			for side in [-1.0, 1.0]:
				var wing := PackedVector2Array([
					c + Vector2(side * r * 0.55, -r * 0.05 + lift),
					c + Vector2(side * r * 1.18, -r * 0.62 + lift),
					c + Vector2(side * r * 0.95, r * 0.18),
				])
				draw_colored_polygon(wing, Color(_light.r, _light.g, _light.b, 0.50))
				var feather := PackedVector2Array([
					c + Vector2(side * r * 0.62, r * 0.02),
					c + Vector2(side * r * 1.08, r * 0.28),
					c + Vector2(side * r * 0.78, r * 0.32),
				])
				draw_colored_polygon(feather, Color(1, 0.86, 0.45, 0.35))
		"hero":
			_outline_circle(c, r * 1.28, Color(1, 0.9, 0.45, 0.85), 2.2)
			draw_arc(c + Vector2(0, -r * 1.02), r * 0.34, PI * 1.05, PI * 1.95, 14, Color(1, 0.92, 0.55, 0.9), 2.0, true)
			_circle(c + Vector2(0, -r * 1.22), r * 0.09, Color(1, 0.95, 0.7, 0.9))
		"demon":
			for side in [-1.0, 1.0]:
				var horn := PackedVector2Array([
					c + Vector2(side * r * 0.32, -r * 0.62),
					c + Vector2(side * r * 0.12, -r * 1.22),
					c + Vector2(side * r * 0.55, -r * 0.48),
				])
				draw_colored_polygon(horn, Color(0.42, 0.06, 0.08))
				draw_line(c + Vector2(side * r * 0.22, -r * 0.78), c + Vector2(side * r * 0.16, -r * 1.08), Color(1, 0.35, 0.2, 0.8), 1.3, true)
			_circle(c + Vector2(0, -r * 1.05), r * 0.08, Color(1, 0.28, 0.16, 0.9))
		"boss":
			pass


func _draw_life(c: Vector2, r: float) -> void:
	if not _ornate:
		return
	var spark := Color(1, 0.94, 0.62, 0.8)
	if rarity == "demon" or rarity == "boss":
		spark = Color(1, 0.42, 0.28, 0.8)
	elif rarity == "hero":
		spark = Color(1, 0.9, 0.45, 0.85)
	for i in range(5):
		var ang := _phase * 1.35 + TAU * float(i) / 5.0
		var rad := r * (1.02 + 0.10 * sin(_phase * 2.1 + float(i)))
		var p := c + Vector2(cos(ang), sin(ang) * 0.78) * rad
		var alpha := 0.35 + 0.5 * (0.5 + 0.5 * sin(_phase * 3.2 + float(i)))
		_circle(p, r * 0.055, Color(spark.r, spark.g, spark.b, alpha), 8)
	if rarity == "demon" or rarity == "boss":
		for i in range(3):
			var t := fposmod(_phase * 0.35 + float(i) * 0.33, 1.0)
			var ember := c + Vector2(sin(_phase * 2.0 + float(i)) * r * 0.55, r * 0.7 - t * r * 1.5)
			_circle(ember, r * 0.05, Color(1, 0.35, 0.15, 0.7 * (1.0 - t)), 8)
	var bob := sin(_phase * 1.7) * r * 0.035
	_ellipse(c + Vector2(-r * 0.22, -r * 0.28 + bob), r * 0.24, r * 0.12, Color(1, 1, 1, 0.16), 10)


func _poly(pts: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p in pts:
		packed.append(p)
	draw_colored_polygon(packed, color)


func _draw_species(c: Vector2, r: float) -> void:
	match art_body:
		"bird", "hawk", "owl":
			_ellipse(c + Vector2(0, r * 0.15), r * 0.72, r * 0.95, _base)
			_poly([c + Vector2(-r * 0.2, r * 0.1), c + Vector2(-r * 1.35, -r * 0.15), c + Vector2(-r * 0.15, r * 0.45)], _dark)
			_poly([c + Vector2(r * 0.2, r * 0.1), c + Vector2(r * 1.35, -r * 0.15), c + Vector2(r * 0.15, r * 0.45)], _dark)
			_poly([c + Vector2(0, -r * 0.55), c + Vector2(r * 0.28, -r * 0.15), c + Vector2(-r * 0.08, -r * 0.15)], Color("#f4e2b0"))
		"fish", "shark":
			_ellipse(c, r * 1.15, r * 0.62, _base)
			_poly([c + Vector2(-r * 0.85, 0), c + Vector2(-r * 1.45, -r * 0.45), c + Vector2(-r * 1.45, r * 0.45)], _dark)
			_poly([c + Vector2(r * 0.1, -r * 0.45), c + Vector2(r * 0.45, -r * 1.05), c + Vector2(r * 0.55, -r * 0.35)], _light)
		"eel", "snake":
			_ellipse(c + Vector2(-r * 0.15, r * 0.05), r * 0.95, r * 0.42, _base)
			_ellipse(c + Vector2(r * 0.55, -r * 0.35), r * 0.55, r * 0.32, _base)
			_circle(c + Vector2(r * 0.95, -r * 0.45), r * 0.22, _dark)
		"lizard":
			_ellipse(c, r * 1.05, r * 0.48, _base)
			_circle(c + Vector2(r * 0.72, -r * 0.18), r * 0.38, _base)
			_poly([c + Vector2(-r * 0.9, 0), c + Vector2(-r * 1.4, r * 0.35), c + Vector2(-r * 0.7, r * 0.12)], _dark)
		"cat", "fox", "wolf", "hound", "panther":
			_ellipse(c + Vector2(0, r * 0.12), r * 0.92, r * 0.78, _base)
			_poly([c + Vector2(-r * 0.55, -r * 0.35), c + Vector2(-r * 0.85, -r * 1.15), c + Vector2(-r * 0.15, -r * 0.45)], _dark)
			_poly([c + Vector2(r * 0.55, -r * 0.35), c + Vector2(r * 0.85, -r * 1.15), c + Vector2(r * 0.15, -r * 0.45)], _dark)
			_ellipse(c + Vector2(r * 0.15, r * 0.18), r * 0.28, r * 0.18, _light)
		"frog":
			_ellipse(c + Vector2(0, r * 0.2), r * 1.0, r * 0.7, _base)
			_circle(c + Vector2(-r * 0.38, -r * 0.45), r * 0.28, _light)
			_circle(c + Vector2(r * 0.38, -r * 0.45), r * 0.28, _light)
		"moth", "bat":
			_ellipse(c, r * 0.45, r * 0.7, _dark)
			_poly([c + Vector2(-r * 0.1, -r * 0.1), c + Vector2(-r * 1.3, -r * 0.8), c + Vector2(-r * 0.9, r * 0.4)], Color(_base.r, _base.g, _base.b, 0.85))
			_poly([c + Vector2(r * 0.1, -r * 0.1), c + Vector2(r * 1.3, -r * 0.8), c + Vector2(r * 0.9, r * 0.4)], Color(_base.r, _base.g, _base.b, 0.85))
		"deer", "lion":
			_ellipse(c + Vector2(0, r * 0.15), r * 0.95, r * 0.8, _base)
			_poly([c + Vector2(-r * 0.2, -r * 0.45), c + Vector2(-r * 0.55, -r * 1.25), c + Vector2(-r * 0.05, -r * 0.55)], _dark)
			_poly([c + Vector2(r * 0.2, -r * 0.45), c + Vector2(r * 0.55, -r * 1.25), c + Vector2(r * 0.05, -r * 0.55)], _dark)
		"otter", "mouse", "badger":
			_ellipse(c + Vector2(0, r * 0.1), r * 1.05, r * 0.62, _base)
			_circle(c + Vector2(r * 0.55, -r * 0.15), r * 0.42, _base)
			_ellipse(c + Vector2(-r * 0.15, r * 0.15), r * 0.7, r * 0.4, _light)
		"rhino":
			_ellipse(c, r * 1.15, r * 0.75, _base)
			_poly([c + Vector2(r * 0.35, -r * 0.2), c + Vector2(r * 0.85, -r * 0.95), c + Vector2(r * 0.7, -r * 0.15)], Color("#f4e2b0"))
		"rabbit":
			_ellipse(c + Vector2(0, r * 0.2), r * 0.85, r * 0.75, _base)
			_ellipse(c + Vector2(-r * 0.28, -r * 0.85), r * 0.16, r * 0.55, _light)
			_ellipse(c + Vector2(r * 0.28, -r * 0.85), r * 0.16, r * 0.55, _light)
		"spider":
			_ellipse(c, r * 0.7, r * 0.55, _dark)
			for side in [-1.0, 1.0]:
				draw_line(c, c + Vector2(side * r * 1.2, -r * 0.7), _dark, 2.2, true)
				draw_line(c, c + Vector2(side * r * 1.25, r * 0.15), _dark, 2.2, true)
				draw_line(c, c + Vector2(side * r * 0.9, r * 0.85), _dark, 2.2, true)
		"jelly":
			_ellipse(c + Vector2(0, -r * 0.1), r * 0.9, r * 0.7, Color(_base.r, _base.g, _base.b, 0.75))
			draw_line(c + Vector2(-r * 0.3, r * 0.4), c + Vector2(-r * 0.45, r * 1.1), _light, 2.0, true)
			draw_line(c + Vector2(0, r * 0.5), c + Vector2(0.05 * r, r * 1.2), _light, 2.0, true)
			draw_line(c + Vector2(r * 0.3, r * 0.4), c + Vector2(r * 0.4, r * 1.05), _light, 2.0, true)
		"demon":
			_ellipse(c + Vector2(0, r * 0.1), r * 0.95, r * 0.9, Color(0.18, 0.05, 0.08))
			_ellipse(c + Vector2(0, r * 0.15), r * 0.7, r * 0.6, _base.darkened(0.35))
		_:
			_ellipse(c, r, r * 0.9, _base)
	_outline_circle(c, r * 0.95, _dark, 1.4)


func _draw_trait(c: Vector2, r: float) -> void:
	var accent := _light.lightened(0.2)
	match art_trait:
		"crest", "mane", "horn":
			_poly([c + Vector2(0, -r * 0.7), c + Vector2(-r * 0.16, -r * 1.25), c + Vector2(r * 0.16, -r * 0.7)], accent)
		"bladewing", "firewing", "blade":
			_poly([c + Vector2(r * 0.4, -r * 0.2), c + Vector2(r * 1.2, -r * 0.55), c + Vector2(r * 0.7, r * 0.1)], Color(1, 0.45, 0.2, 0.8))
		"bubble", "bell":
			_outline_circle(c + Vector2(r * 0.85, -r * 0.55), r * 0.22, Color(0.8, 0.95, 1, 0.8), 1.6)
		"fluff", "soft":
			_circle(c + Vector2(0, r * 0.85), r * 0.22, Color(1, 1, 1, 0.55))
		"spark", "bolt", "stars", "myth":
			_poly([c + Vector2(0, -r * 1.15), c + Vector2(r * 0.12, -r * 0.85), c + Vector2(-r * 0.12, -r * 0.85)], Color(1, 0.95, 0.6))
		"halo":
			_outline_circle(c + Vector2(0, -r * 1.05), r * 0.28, Color(1, 0.92, 0.6, 0.8), 1.8)
		"fang", "eye":
			_circle(c + Vector2(0, -r * 0.15), r * 0.08, Color(1, 0.3, 0.25))
		"web":
			draw_arc(c, r * 1.15, 0, TAU, 16, Color(1, 1, 1, 0.35), 1.0, true)
		"moon", "sun":
			_circle(c + Vector2(-r * 0.9, -r * 0.9), r * 0.16, Color(1, 0.95, 0.7, 0.85))
		"twin_tail":
			_ellipse(c + Vector2(-r * 0.9, r * 0.55), r * 0.16, r * 0.42, _dark)
			_ellipse(c + Vector2(r * 0.9, r * 0.55), r * 0.16, r * 0.42, _dark)
		"shell", "plate", "crystal", "boulder":
			_poly([c + Vector2(-r * 0.2, -r * 0.85), c + Vector2(r * 0.35, -r * 0.45), c + Vector2(-r * 0.05, -r * 0.35)], accent)
		"veil", "shroud", "wing":
			_poly([c + Vector2(-r * 0.2, -r * 0.2), c + Vector2(-r * 1.1, r * 0.2), c + Vector2(-r * 0.3, r * 0.7)], Color(0.1, 0.05, 0.16, 0.55))
		_:
			pass
