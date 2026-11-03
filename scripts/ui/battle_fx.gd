extends Control
## Canvas-based battle effects and floating numbers.
## Everything is drawn in one node with short-lived effect records, which avoids
## creating Labels/Tweens for every hit (the main source of late-floor stutter).

const MAX_EFFECTS := 180
const TEXT_WIDTH := 300.0

var effects: Array = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UI.theme.default_font if UI.theme != null else get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	set_process(false)


func clear() -> void:
	effects.clear()
	set_process(false)
	queue_redraw()


func add_text(text: String, pos: Vector2, color: Color, size: int = 26, crit: bool = false) -> void:
	var y := pos.y
	for e in effects:
		if str(e.get("kind", "")) == "text" and e["life"] > e["max"] * 0.35:
			if absf(float(e["pos"].x) - pos.x) < 90.0 and absf(float(e["pos"].y) - y) < 46.0:
				y -= 28.0
	_push({
		"kind": "text", "text": text, "pos": Vector2(pos.x, y), "color": color,
		"size": size, "crit": crit, "life": 1.05, "max": 1.05,
		"vx": randf_range(-10.0, 10.0), "vy": -52.0,
	})


func add_projectile(from: Vector2, to: Vector2, color: Color, duration: float = 0.30) -> void:
	_push({"kind": "projectile", "from": from, "to": to, "pos": from, "color": color,
		"life": duration, "max": duration})


func add_hit(pos: Vector2, color: Color, crit: bool = false, strength: float = 1.0) -> void:
	var radius := (28.0 if crit else 17.0) * strength
	_push({"kind": "spark", "pos": pos, "color": color, "life": 0.26, "max": 0.26,
		"radius": radius, "crit": crit})
	_push({"kind": "ring", "pos": pos, "color": color, "life": 0.34, "max": 0.34,
		"r0": 6.0, "r1": radius * 2.0})


func add_slash(pos: Vector2, color: Color) -> void:
	_push({"kind": "slash", "pos": pos, "color": color, "life": 0.22, "max": 0.22,
		"angle": randf_range(-0.7, 0.7)})


func add_burst(pos: Vector2, color: Color, radius: float = 72.0) -> void:
	_push({"kind": "burst", "pos": pos, "color": color, "life": 0.55, "max": 0.55,
		"radius": radius, "phase": randf_range(0.0, TAU)})


func add_charge(pos: Vector2, color: Color) -> void:
	_push({"kind": "charge", "pos": pos, "color": color, "life": 0.45, "max": 0.45,
		"radius": 54.0})


func add_heal(pos: Vector2, color: Color) -> void:
	_push({"kind": "heal", "pos": pos, "color": color, "life": 0.5, "max": 0.5})


# ---------------------------------------------------------------- ultimate

## Full cast sequence: rune sigil + light pillar at the caster, then an
## element-specific strike and shockwave on every target.
func add_ultimate_cast(actor_pos: Vector2, targets: Array, element: String,
		color: Color, is_hero: bool = false) -> void:
	add_sigil(actor_pos, color, 70.0 if is_hero else 58.0)
	_push_delayed(0.02, {"kind": "charge", "pos": actor_pos, "color": color,
		"life": 0.55, "max": 0.55, "radius": 70.0 if is_hero else 56.0})
	_push_delayed(0.08, {"kind": "pillar", "pos": actor_pos, "color": color,
		"life": 0.72, "max": 0.72, "height": 300.0 if is_hero else 250.0,
		"width": 60.0 if is_hero else 46.0})
	if is_hero:
		_push_delayed(0.10, {"kind": "radiance", "pos": actor_pos,
			"color": Color(1.0, 0.85, 0.45), "life": 0.8, "max": 0.8, "radius": 96.0})
	var i := 0
	for t in targets:
		var pos: Vector2 = t
		var stagger := 0.14 + 0.055 * float(i)
		_push_delayed(stagger, {"kind": "strike", "pos": pos, "element": element,
			"color": color, "life": 0.62, "max": 0.62})
		_push_delayed(stagger + 0.16, {"kind": "shockwave", "pos": pos, "color": color,
			"life": 0.46, "max": 0.46, "radius": 96.0})
		_push_delayed(stagger + 0.18, {"kind": "burst", "pos": pos, "color": color,
			"life": 0.5, "max": 0.5, "radius": 70.0, "phase": float(i) * 1.4})
		i += 1


func add_sigil(pos: Vector2, color: Color, radius: float = 58.0) -> void:
	_push({"kind": "sigil", "pos": pos, "color": color, "life": 0.8, "max": 0.8,
		"radius": radius, "phase": randf_range(0.0, TAU)})


func add_shockwave(pos: Vector2, color: Color, radius: float = 96.0) -> void:
	_push({"kind": "shockwave", "pos": pos, "color": color, "life": 0.46, "max": 0.46,
		"radius": radius})


func _push_delayed(delay: float, e: Dictionary) -> void:
	e["delay"] = delay
	_push(e)


# ---------------------------------------------------------------- internals

func _push(e: Dictionary) -> void:
	effects.append(e)
	while effects.size() > MAX_EFFECTS:
		effects.pop_front()
	if not is_processing():
		set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if effects.is_empty():
		set_process(false)
		return
	var i := 0
	while i < effects.size():
		var e: Dictionary = effects[i]
		if float(e.get("delay", 0.0)) > 0.0:
			e["delay"] = float(e["delay"]) - delta
			i += 1
			continue
		e["life"] = float(e["life"]) - delta
		if float(e["life"]) <= 0.0:
			effects.remove_at(i)
			continue
		match str(e["kind"]):
			"text":
				e["pos"] = Vector2(float(e["pos"].x) + float(e["vx"]) * delta,
					float(e["pos"].y) + float(e["vy"]) * delta)
				e["vy"] = float(e["vy"]) + 34.0 * delta
			"projectile":
				var t := 1.0 - float(e["life"]) / float(e["max"])
				e["pos"] = (e["from"] as Vector2).lerp(e["to"] as Vector2, t)
		i += 1
	queue_redraw()


func _draw() -> void:
	for e in effects:
		if float(e.get("delay", 0.0)) > 0.0:
			continue
		var life := float(e["life"])
		var max_life := float(e["max"])
		var t := clampf(1.0 - life / max_life, 0.0, 1.0)
		var alpha := clampf(life / (max_life * 0.55), 0.0, 1.0)
		var color: Color = e["color"]
		match str(e["kind"]):
			"text":
				_draw_text(e, alpha)
			"projectile":
				var from_pt: Vector2 = e["from"]
				var to_pt: Vector2 = e["to"]
				var tail: Vector2 = from_pt.lerp(to_pt, clampf(t - 0.16, 0.0, 1.0))
				draw_line(tail, e["pos"], Color(color.r, color.g, color.b, alpha * 0.45), 5.0, true)
				draw_circle(e["pos"], 6.0 + 4.0 * sin(t * PI), Color(color.r, color.g, color.b, alpha))
				draw_circle(e["pos"], 14.0, Color(color.r, color.g, color.b, alpha * 0.14))
			"spark":
				var radius := float(e["radius"])
				for k in range(8):
					var ang := TAU * float(k) / 8.0 + 0.3
					var inner: Vector2 = e["pos"] + Vector2(cos(ang), sin(ang)) * (radius * 0.25)
					var outer: Vector2 = e["pos"] + Vector2(cos(ang), sin(ang)) * (radius * (0.7 + 0.5 * t))
					draw_line(inner, outer, Color(color.r, color.g, color.b, alpha), 2.0 if not bool(e.get("crit", false)) else 3.0, true)
				draw_circle(e["pos"], radius * (0.35 + 0.25 * t), Color(1, 1, 1, alpha * 0.20))
			"ring":
				var radius2 := lerpf(float(e["r0"]), float(e["r1"]), t)
				draw_arc(e["pos"], radius2, 0.0, TAU, 28, Color(color.r, color.g, color.b, alpha * 0.8), 2.0, true)
			"slash":
				var ang2 := float(e["angle"])
				var length := 46.0
				var mid: Vector2 = e["pos"]
				var a1 := mid + Vector2(cos(ang2), sin(ang2)) * length * 0.5
				var a2 := mid - Vector2(cos(ang2), sin(ang2)) * length * 0.5
				draw_line(a1, a2, Color(1, 1, 1, alpha), 4.0, true)
				draw_line(a1, a2, Color(color.r, color.g, color.b, alpha * 0.6), 9.0, true)
			"burst":
				var radius3 := float(e["radius"]) * (0.25 + 0.75 * t)
				draw_arc(e["pos"], radius3, 0.0, TAU, 36, Color(color.r, color.g, color.b, alpha), 3.0, true)
				draw_arc(e["pos"], radius3 * 0.62, 0.0, TAU, 28, Color(color.r, color.g, color.b, alpha * 0.7), 1.6, true)
				for k in range(10):
					var ang3 := float(e["phase"]) + TAU * float(k) / 10.0
					var p1: Vector2 = e["pos"] + Vector2(cos(ang3), sin(ang3)) * radius3 * 0.45
					var p2: Vector2 = e["pos"] + Vector2(cos(ang3), sin(ang3)) * radius3 * (0.8 + 0.25 * sin(t * PI))
					draw_line(p1, p2, Color(color.r, color.g, color.b, alpha * 0.8), 2.0, true)
			"charge":
				var radius4 := float(e["radius"]) * (1.0 - t * 0.7)
				draw_arc(e["pos"], radius4, 0.0, TAU, 28, Color(color.r, color.g, color.b, alpha), 3.0, true)
				draw_circle(e["pos"], 20.0 * t, Color(color.r, color.g, color.b, alpha * 0.35))
			"heal":
				var rise := 16.0 * t
				var c := Color(color.r, color.g, color.b, alpha)
				var p: Vector2 = e["pos"] + Vector2(0, -rise)
				draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), c, 4.0, true)
				draw_line(p + Vector2(0, -12), p + Vector2(0, 12), c, 4.0, true)
				draw_arc(p, 20.0 + 8.0 * t, 0.0, TAU, 20, Color(color.r, color.g, color.b, alpha * 0.5), 1.5, true)
			"sigil":
				_draw_sigil(e, t, alpha, color)
			"pillar":
				_draw_pillar(e, t, alpha, color)
			"strike":
				_draw_strike(e, t, alpha, color)
			"shockwave":
				var sw := float(e["radius"]) * t
				draw_arc(e["pos"], 8.0 + sw, 0.0, TAU, 40, Color(color.r, color.g, color.b, alpha), 4.0, true)
				draw_arc(e["pos"], 8.0 + sw * 0.7, 0.0, TAU, 32, Color(1, 1, 1, alpha * 0.35), 2.0, true)
			"radiance":
				var rr := float(e["radius"]) * (0.3 + 0.7 * t)
				for k in range(12):
					var ang4 := TAU * float(k) / 12.0 + t * 0.6
					draw_line(e["pos"] + Vector2(cos(ang4), sin(ang4)) * rr * 0.25,
						e["pos"] + Vector2(cos(ang4), sin(ang4)) * rr,
						Color(1.0, 0.88, 0.5, alpha * 0.7), 2.5, true)
				draw_circle(e["pos"], 14.0 + 10.0 * sin(t * PI), Color(1, 0.95, 0.75, alpha * 0.5))


func _draw_sigil(e: Dictionary, t: float, alpha: float, color: Color) -> void:
	var c: Vector2 = e["pos"]
	var r := float(e["radius"]) * (0.72 + 0.28 * sin(t * PI))
	var a := float(e["phase"]) + t * 7.0
	for k in range(2):
		var rr := r * (1.0 - 0.18 * float(k))
		draw_arc(c, rr, a + float(k) * 2.0, a + float(k) * 2.0 + 4.6, 26,
			Color(color.r, color.g, color.b, alpha * (0.9 - 0.35 * float(k))), 2.6 - 0.8 * float(k), true)
	for k in range(10):
		var ang := -a * 0.6 + TAU * float(k) / 10.0
		var p1 := c + Vector2(cos(ang), sin(ang)) * r * 0.94
		var p2 := c + Vector2(cos(ang), sin(ang)) * r * 1.12
		draw_line(p1, p2, Color(color.r, color.g, color.b, alpha * 0.7), 2.0, true)
	draw_circle(c, r * 0.22, Color(color.r, color.g, color.b, alpha * 0.22))


func _draw_pillar(e: Dictionary, t: float, alpha: float, color: Color) -> void:
	var c: Vector2 = e["pos"]
	var h := float(e["height"]) * clampf(t * 1.9, 0.0, 1.0)
	var w := float(e["width"]) * (0.45 + 0.55 * t)
	var top := c.y - h
	draw_rect(Rect2(c.x - w * 0.5, top, w, h), Color(color.r, color.g, color.b, alpha * 0.14))
	draw_rect(Rect2(c.x - w * 0.18, top, w * 0.36, h), Color(color.r, color.g, color.b, alpha * 0.30))
	draw_rect(Rect2(c.x - w * 0.06, top, w * 0.12, h), Color(1, 1, 1, alpha * 0.30))
	for k in range(3):
		var yy := c.y - h * fmod(t * 1.7 + float(k) * 0.33, 1.0)
		var spread := w * (0.55 + 0.25 * float(k))
		draw_line(Vector2(c.x - spread, yy), Vector2(c.x + spread, yy),
			Color(1, 1, 1, alpha * 0.22), 2.0, true)


func _draw_strike(e: Dictionary, t: float, alpha: float, color: Color) -> void:
	var c: Vector2 = e["pos"]
	var element := str(e.get("element", "fire"))
	match element:
		"fire":
			var start := c + Vector2(-150.0, -320.0)
			var travel := clampf(t * 1.5, 0.0, 1.0)
			var head := start.lerp(c, travel)
			if travel < 1.0:
				var tail := start.lerp(c, clampf(travel - 0.35, 0.0, 1.0))
				draw_line(tail, head, Color(1.0, 0.55, 0.2, alpha * 0.6), 14.0, true)
				draw_circle(head, 15.0, Color(1.0, 0.8, 0.35, alpha))
			draw_circle(c, 26.0 + 46.0 * t, Color(1.0, 0.45, 0.15, alpha * 0.30 * (1.0 - t)))
			for k in range(8):
				var ang := TAU * float(k) / 8.0 + 0.4
				draw_line(c + Vector2(cos(ang), sin(ang)) * 18.0,
					c + Vector2(cos(ang), sin(ang)) * (30.0 + 70.0 * t),
					Color(1.0, 0.7, 0.25, alpha * 0.75), 3.0, true)
		"water":
			for k in range(3):
				var rr := 22.0 + float(k) * 24.0 + 96.0 * t
				draw_arc(c, rr, PI * 0.08, PI * 0.92, 22,
					Color(0.45, 0.85, 1.0, alpha * (0.8 - 0.2 * float(k))), 3.0, true)
			for k in range(6):
				var ang2 := TAU * float(k) / 6.0 - 1.2
				draw_circle(c + Vector2(cos(ang2), sin(ang2)) * (30.0 + 80.0 * t),
					4.0, Color(0.7, 0.95, 1.0, alpha * 0.7))
		"wind":
			var base := t * 8.0
			for k in range(3):
				var a0 := base + float(k) * 2.1
				draw_arc(c, 28.0 + float(k) * 22.0 + 20.0 * t, a0, a0 + 3.8, 24,
					Color(0.6, 1.0, 0.75, alpha * (0.85 - 0.2 * float(k))), 3.0, true)
			for k in range(4):
				var a1 := -base * 0.7 + float(k) * 1.6
				draw_line(c + Vector2(cos(a1), sin(a1)) * 20.0,
					c + Vector2(cos(a1), sin(a1)) * (90.0 * t + 30.0),
					Color(0.85, 1.0, 0.9, alpha * 0.5), 2.0, true)
		"earth":
			for k in range(5):
				var x := c.x + (float(k) - 2.0) * 24.0
				var hgt := (34.0 + 16.0 * absf(float(k) - 2.0)) * clampf(t * 2.4, 0.0, 1.0)
				var half := 9.0
				var pts := PackedVector2Array([
					Vector2(x - half, c.y + 14.0),
					Vector2(x, c.y + 14.0 - hgt),
					Vector2(x + half, c.y + 14.0),
				])
				draw_colored_polygon(pts, Color(0.85, 0.62, 0.32, alpha * 0.8))
				draw_line(pts[0], pts[1], Color(1, 0.9, 0.7, alpha), 2.0, true)
				draw_line(pts[1], pts[2], Color(1, 0.9, 0.7, alpha), 2.0, true)
			draw_circle(c, 18.0 + 30.0 * t, Color(0.9, 0.7, 0.4, alpha * 0.2 * (1.0 - t)))
		"light":
			for k in range(10):
				var ang3 := TAU * float(k) / 10.0 + t * 0.4
				var r0 := 14.0
				var r1 := 30.0 + 78.0 * t
				draw_line(c + Vector2(cos(ang3), sin(ang3)) * r0,
					c + Vector2(cos(ang3), sin(ang3)) * r1,
					Color(1.0, 0.95, 0.7, alpha * 0.8), 3.0, true)
			draw_circle(c, 16.0 + 12.0 * sin(t * PI), Color(1, 1, 0.92, alpha * 0.55))
			draw_arc(c, 24.0 + 70.0 * t, 0.0, TAU, 32, Color(1, 1, 0.85, alpha * 0.6), 2.0, true)
		"dark":
			var rr2 := 74.0 * (1.0 - t) + 12.0
			for k in range(6):
				var ang4 := TAU * float(k) / 6.0 + t * 2.0
				var p0 := c + Vector2(cos(ang4), sin(ang4)) * rr2
				var p1 := c + Vector2(cos(ang4 + 0.5), sin(ang4 + 0.5)) * rr2 * 0.6
				var p2 := c + Vector2(cos(ang4 + 1.0), sin(ang4 + 1.0)) * rr2 * 0.25
				draw_line(p0, p1, Color(0.72, 0.42, 1.0, alpha * 0.75), 3.0, true)
				draw_line(p1, p2, Color(0.5, 0.2, 0.8, alpha * 0.6), 2.0, true)
			draw_circle(c, rr2 * 0.45, Color(0.35, 0.1, 0.55, alpha * 0.45))
			draw_arc(c, rr2, 0.0, TAU, 30, Color(0.7, 0.4, 1.0, alpha * 0.7), 2.0, true)
		"storm":
			var bolt := _bolt_points(c, 150.0, 6, t)
			for k in range(bolt.size() - 1):
				draw_line(bolt[k], bolt[k + 1], Color(1, 1, 0.75, alpha), 3.0, true)
				draw_line(bolt[k] + Vector2(3, 0), bolt[k + 1] + Vector2(3, 0),
					Color(0.6, 0.75, 1.0, alpha * 0.5), 6.0, true)
			draw_circle(c, 20.0 + 26.0 * t, Color(0.85, 0.9, 1.0, alpha * 0.3))
		_:
			draw_circle(c, 20.0 + 40.0 * t, Color(color.r, color.g, color.b, alpha * 0.5))


func _bolt_points(center: Vector2, height: float, segments: int, t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step_seed: float = floor(t * 24.0)
	for k in range(segments + 1):
		var frac := float(k) / float(segments)
		var jitter := sin(float(k) * 12.9898 + step_seed) * 22.0
		pts.append(center + Vector2(jitter * (1.0 - frac * 0.4), -height * (1.0 - frac)))
	return pts


func _draw_text(e: Dictionary, alpha: float) -> void:
	if _font == null:
		return
	var text := str(e["text"])
	var size := int(e["size"])
	var pos: Vector2 = e["pos"]
	var color: Color = e["color"]
	var x := pos.x - TEXT_WIDTH * 0.5
	var outline := Color(0.02, 0.03, 0.05, alpha * 0.92)
	var offsets := [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]
	for off in offsets:
		draw_string(_font, Vector2(x, pos.y) + off, text, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, size, outline)
	draw_string(_font, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, size,
		Color(color.r, color.g, color.b, alpha))
	if bool(e.get("crit", false)):
		var c := pos + Vector2(0, -size * 0.45)
		for k in range(6):
			var ang := TAU * float(k) / 6.0 + float(Time.get_ticks_msec() % 628) / 100.0
			draw_line(c + Vector2(cos(ang), sin(ang)) * 16.0,
				c + Vector2(cos(ang), sin(ang)) * 30.0, Color(1, 0.9, 0.5, alpha * 0.55), 2.0, true)
