extends Control
## Canvas-based battle effects and floating numbers.
## Everything is drawn in one node with short-lived effect records, which avoids
## creating Labels/Tweens for every hit (the main source of late-floor stutter).

const MAX_EFFECTS := 72
const TEXT_WIDTH := 300.0

var effects: Array = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()
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
