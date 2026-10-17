extends Control
## Procedural, animated backdrops.  Ten map styles share one renderer.

var map_id: String = "lava"
var style: String = "lava"
var sky_top: Color = Color("#1a0b10")
var sky_bottom: Color = Color("#4a1a1c")
var accent: Color = Color("#ff7043")
var map_name: String = ""
var _rng := RandomNumberGenerator.new()
var _particles: Array = []
var _distant: Array = []
var _time: float = 0.0
var _acc: float = 0.0
var _ready_for_draw: bool = false


func setup(mid: String) -> void:
	map_id = mid
	var m: Dictionary = ContentDB.map_data(mid)
	if m.is_empty():
		m = {"name": mid, "sky": ["#101624", "#24304a"], "accent": "#ff8a4c", "style": mid}
	style = str(m.get("style", mid))
	map_name = str(m.get("name", mid))
	var sky: Array = m.get("sky", ["#101624", "#24304a"])
	sky_top = Color.from_string(str(sky[0]), Color("#101624"))
	sky_bottom = Color.from_string(str(sky[1]), Color("#24304a"))
	accent = Color.from_string(str(m.get("accent", "#ff8a4c")), Color("#ff8a4c"))
	_rng.seed = abs(hash(mid)) + 913
	_build_particles()
	_ready_for_draw = true
	queue_redraw()


func _build_particles() -> void:
	_particles.clear()
	_distant.clear()
	var n := 34
	if style in ["storm", "night", "void"]:
		n = 60
	for i in range(n):
		var p := {
			"x": _rng.randf_range(0.0, 1.0),
			"y": _rng.randf_range(0.0, 1.0),
			"speed": _rng.randf_range(0.01, 0.06),
			"size": _rng.randf_range(1.0, 3.2),
			"phase": _rng.randf_range(0.0, TAU),
		}
		_particles.append(p)
	for i in range(18):
		_distant.append({
			"x": _rng.randf_range(0.0, 1.0),
			"y": _rng.randf_range(0.15, 0.85),
			"r": _rng.randf_range(0.6, 2.0),
			"phase": _rng.randf_range(0.0, TAU),
		})


func _process(delta: float) -> void:
	if not _ready_for_draw:
		return
	_time += delta
	_acc += delta
	if _acc >= 0.033:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	if not _ready_for_draw:
		return
	var w: float = maxf(size.x, 1280.0)
	var h: float = maxf(size.y, 720.0)
	_draw_sky(w, h)
	_draw_celestial(w, h)
	match style:
		"lava": _draw_lava(w, h)
		"ocean": _draw_ocean(w, h)
		"sky": _draw_sky_islands(w, h)
		"forest": _draw_forest(w, h)
		"storm": _draw_storm(w, h)
		"desert": _draw_desert(w, h)
		"temple": _draw_temple(w, h)
		"night": _draw_night(w, h)
		"void": _draw_void(w, h)
		"throne": _draw_throne(w, h)
		_: _draw_sky_islands(w, h)
	_draw_particles(w, h)
	_draw_vignette(w, h)


func _draw_sky(w: float, h: float) -> void:
	var bands := 48
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var c := sky_top.lerp(sky_bottom, pow(t, 0.85))
		draw_rect(Rect2(0, h * float(i) / float(bands), w, h / float(bands) + 1.0), c)
	# haze near the horizon
	var haze := accent
	haze.a = 0.06
	draw_rect(Rect2(0, h * 0.48, w, h * 0.30), haze)


func _draw_celestial(w: float, h: float) -> void:
	var cx := w * (0.72 if style in ["lava", "desert", "throne"] else 0.24)
	var cy := h * (0.22 if style in ["lava", "desert", "throne"] else 0.18)
	var radius := h * (0.075 if style == "desert" else 0.055)
	for i in range(6):
		var rr := radius * (2.6 - float(i) * 0.3)
		var c := accent
		c.a = 0.035 + float(i) * 0.006
		draw_circle(Vector2(cx, cy), rr, c)
	draw_circle(Vector2(cx, cy), radius, Color(accent.r, accent.g, accent.b, 0.55))
	draw_circle(Vector2(cx, cy), radius * 0.72, Color(1, 0.95, 0.8, 0.55))
	if style in ["night", "void", "temple"]:
		for d in _distant:
			var tw := 0.35 + 0.35 * sin(_time * 1.5 + float(d["phase"]))
			draw_circle(Vector2(float(d["x"]) * w, float(d["y"]) * h), float(d["r"]), Color(1, 1, 1, tw))


func _mountain_layer(w: float, h: float, base_y: float, amp: float, color: Color, peaks: int, seed_off: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(map_id)) + seed_off + 7
	var pts := PackedVector2Array()
	pts.append(Vector2(-20, h))
	pts.append(Vector2(-20, base_y))
	var step := (w + 40.0) / float(peaks)
	for i in range(peaks + 1):
		var x := -20.0 + step * float(i)
		var y := base_y - rng.randf_range(0.25, 1.0) * amp
		pts.append(Vector2(x, y))
		if i < peaks:
			pts.append(Vector2(x + step * 0.5, base_y - rng.randf_range(0.05, 0.28) * amp))
	pts.append(Vector2(w + 20, base_y))
	pts.append(Vector2(w + 20, h))
	draw_colored_polygon(pts, color)


func _draw_lava(w: float, h: float) -> void:
	_mountain_layer(w, h, h * 0.66, h * 0.30, Color(0.12, 0.05, 0.07, 1), 7, 1)
	_mountain_layer(w, h, h * 0.76, h * 0.20, Color(0.07, 0.03, 0.05, 1), 9, 2)
	# lava river
	var pts := PackedVector2Array()
	for i in range(33):
		var t := float(i) / 32.0
		pts.append(Vector2(t * w, h * 0.86 + sin(t * 14.0 + _time * 0.4) * 6.0))
	pts.append(Vector2(w, h))
	pts.append(Vector2(0, h))
	draw_colored_polygon(pts, Color(1.0, 0.34, 0.12, 0.55))
	for i in range(7):
		var t := float(i) / 6.0
		var y := h * 0.90 + sin(t * 10.0 + _time) * 4.0
		draw_line(Vector2(w * (0.05 + t * 0.9), y), Vector2(w * (0.12 + t * 0.9), y), Color(1, 0.75, 0.4, 0.30), 2.0, true)
	# rock spires
	for i in range(5):
		var x := w * (0.08 + float(i) * 0.19)
		var pts2 := PackedVector2Array([
			Vector2(x - 22, h * 0.88), Vector2(x, h * (0.60 + 0.04 * (i % 3))), Vector2(x + 26, h * 0.88),
		])
		draw_colored_polygon(pts2, Color(0.08, 0.035, 0.05, 0.9))


func _draw_ocean(w: float, h: float) -> void:
	for layer in range(4):
		var base_y := h * (0.62 + 0.08 * layer)
		var col := Color(0.05 + 0.02 * layer, 0.22 + 0.04 * layer, 0.35 + 0.05 * layer, 0.85)
		var pts := PackedVector2Array()
		pts.append(Vector2(0, h))
		for i in range(49):
			var t := float(i) / 48.0
			var y := base_y + sin(t * (8.0 + layer * 2.0) + _time * (0.3 + layer * 0.12)) * (8.0 + layer * 3.0)
			pts.append(Vector2(t * w, y))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, col)
	# coral silhouettes
	for i in range(7):
		var x := w * (0.06 + i * 0.14)
		var y := h * 0.95
		draw_line(Vector2(x, y), Vector2(x, y - h * (0.05 + 0.02 * (i % 3))), Color(0.12, 0.32, 0.35, 0.75), 5.0, true)
		draw_line(Vector2(x, y - h * 0.04), Vector2(x + 18, y - h * 0.08), Color(0.12, 0.32, 0.35, 0.75), 4.0, true)
		draw_line(Vector2(x, y - h * 0.06), Vector2(x - 15, y - h * 0.10), Color(0.12, 0.32, 0.35, 0.75), 4.0, true)
	# light shafts
	for i in range(4):
		var x := w * (0.2 + i * 0.2)
		var c := Color(0.4, 0.8, 1.0, 0.035)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0), Vector2(x + 80, 0), Vector2(x + 180, h * 0.75), Vector2(x + 60, h * 0.75),
		]), c)


func _draw_sky_islands(w: float, h: float) -> void:
	# floating islands
	for i in range(4):
		var x := w * (0.12 + i * 0.25)
		var y := h * (0.40 + 0.09 * (i % 2)) + sin(_time * 0.5 + i) * 5.0
		var pts := PackedVector2Array([
			Vector2(x - 70, y), Vector2(x + 70, y), Vector2(x + 40, y + 26), Vector2(x, y + 40), Vector2(x - 45, y + 22),
		])
		draw_colored_polygon(pts, Color(0.14, 0.20, 0.24, 0.85))
		draw_line(Vector2(x - 50, y), Vector2(x + 55, y), Color(0.35, 0.55, 0.52, 0.5), 2.0, true)
	# clouds
	for i in range(8):
		var x := w * (0.05 + i * 0.145) + sin(_time * 0.2 + i) * 12.0
		var y := h * (0.18 + 0.07 * (i % 3))
		_ellipse(Vector2(x, y), 70, 16, Color(1, 1, 1, 0.055))
		_ellipse(Vector2(x + 34, y - 8), 44, 12, Color(1, 1, 1, 0.045))
	# distant mountains below
	_mountain_layer(w, h, h * 0.92, h * 0.24, Color(0.07, 0.10, 0.12, 0.9), 7, 4)


func _draw_forest(w: float, h: float) -> void:
	_mountain_layer(w, h, h * 0.80, h * 0.18, Color(0.05, 0.12, 0.08, 0.9), 6, 3)
	for layer in range(3):
		var col := Color(0.03 + 0.015 * layer, 0.10 + 0.03 * layer, 0.05 + 0.02 * layer, 1.0)
		for i in range(9):
			var x := w * (0.03 + i * 0.12) + layer * 14
			var base := h * (0.98 - layer * 0.02)
			var top := h * (0.40 + layer * 0.06) + (i % 3) * 12
			draw_rect(Rect2(x - 5, top, 10, base - top), col)
			_ellipse(Vector2(x, top + 8), 46 - layer * 6, 30 - layer * 4, col)
			_ellipse(Vector2(x - 26, top + 24), 30 - layer * 4, 20, col)
			_ellipse(Vector2(x + 26, top + 24), 30 - layer * 4, 20, col)
	# fireflies
	for i in range(14):
		var p: Dictionary = _particles[i % _particles.size()]
		var x := float(p["x"]) * w + sin(_time * 0.7 + float(p["phase"])) * 18.0
		var y := float(p["y"]) * h + cos(_time * 0.5 + float(p["phase"])) * 12.0
		var a := 0.25 + 0.35 * (0.5 + 0.5 * sin(_time * 2.0 + float(p["phase"])))
		draw_circle(Vector2(x, y), float(p["size"]) + 1.0, Color(1.0, 0.9, 0.4, a))


func _draw_storm(w: float, h: float) -> void:
	_mountain_layer(w, h, h * 0.72, h * 0.28, Color(0.08, 0.06, 0.14, 0.95), 8, 5)
	_mountain_layer(w, h, h * 0.84, h * 0.16, Color(0.05, 0.04, 0.09, 1.0), 10, 6)
	# clouds
	for i in range(9):
		var x := w * (0.02 + i * 0.125)
		var y := h * (0.10 + 0.05 * (i % 3))
		_ellipse(Vector2(x, y), 90, 22, Color(0.16, 0.12, 0.22, 0.55))
	# lightning
	if fmod(_time, 5.0) < 0.22:
		var lx := w * 0.63
		var pts := PackedVector2Array([
			Vector2(lx, h * 0.12), Vector2(lx - 14, h * 0.28), Vector2(lx + 6, h * 0.30),
			Vector2(lx - 18, h * 0.48), Vector2(lx + 10, h * 0.44), Vector2(lx - 6, h * 0.62),
		])
		draw_polyline(pts, Color(0.85, 0.9, 1.0, 0.85), 2.5, true)
	# rain
	for p in _particles:
		var x := fmod(float(p["x"]) * w + _time * 24.0, w + 40.0) - 20.0
		var y := fmod(float(p["y"]) * h + _time * 360.0 * float(p["speed"]) + float(p["phase"]) * 30.0, h + 60.0) - 30.0
		draw_line(Vector2(x, y), Vector2(x - 4, y + 14), Color(0.65, 0.72, 0.95, 0.22), 1.2, true)


func _draw_desert(w: float, h: float) -> void:
	for layer in range(4):
		var base_y := h * (0.64 + layer * 0.08)
		var col := Color(0.24 + 0.05 * layer, 0.16 + 0.035 * layer, 0.07 + 0.02 * layer, 1.0)
		var pts := PackedVector2Array()
		pts.append(Vector2(0, h))
		for i in range(41):
			var t := float(i) / 40.0
			var y := base_y + sin(t * (3.0 + layer * 0.6) + layer * 1.7) * (18.0 + layer * 5.0)
			pts.append(Vector2(t * w, y))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, col)
	# ruins
	for i in range(3):
		var x := w * (0.22 + i * 0.28)
		var y := h * 0.72
		draw_rect(Rect2(x, y - 60, 18, 60), Color(0.18, 0.12, 0.06, 0.9))
		draw_rect(Rect2(x - 10, y - 68, 38, 10), Color(0.18, 0.12, 0.06, 0.9))


func _draw_temple(w: float, h: float) -> void:
	# pillars
	for i in range(6):
		var x := w * (0.08 + i * 0.17)
		var ww := 26.0 if i % 2 == 0 else 18.0
		draw_rect(Rect2(x, h * 0.24, ww, h * 0.62), Color(0.13, 0.16, 0.27, 0.85))
		draw_rect(Rect2(x - 8, h * 0.22, ww + 16, 12), Color(0.20, 0.24, 0.36, 0.9))
		draw_rect(Rect2(x - 6, h * 0.84, ww + 12, 12), Color(0.20, 0.24, 0.36, 0.9))
	# floor glow
	var glow := Color(1, 0.85, 0.42, 0.08)
	draw_rect(Rect2(0, h * 0.84, w, h * 0.16), glow)
	# rays
	for i in range(6):
		var x := w * (0.15 + i * 0.14)
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.5, h * 0.08), Vector2(x, h * 0.95), Vector2(x + 50, h * 0.95),
		]), Color(1, 0.86, 0.5, 0.025))


func _draw_night(w: float, h: float) -> void:
	# gothic arches
	for i in range(5):
		var x := w * (0.10 + i * 0.20)
		var top := h * 0.30
		var radius := 62.0
		draw_arc(Vector2(x, top), radius, PI, TAU, 24, Color(0.16, 0.09, 0.24, 0.9), 8.0, true)
		draw_rect(Rect2(x - radius, top, 8, h * 0.55), Color(0.10, 0.06, 0.15, 0.95))
		draw_rect(Rect2(x + radius - 8, top, 8, h * 0.55), Color(0.10, 0.06, 0.15, 0.95))
		draw_line(Vector2(x - radius, h * 0.85), Vector2(x + radius, h * 0.85), Color(0.13, 0.08, 0.18, 0.9), 6.0, true)
	# fog
	for i in range(5):
		var y := h * (0.55 + i * 0.08)
		var c := Color(0.5, 0.3, 0.7, 0.035)
		_ellipse(Vector2(w * (0.3 + 0.12 * i) + sin(_time * 0.2 + i) * 30.0, y), w * 0.35, 28.0, c)
	# candle flames
	for i in range(6):
		var x := w * (0.14 + i * 0.14)
		var y := h * 0.62 + sin(_time + i) * 2.0
		draw_circle(Vector2(x, y), 3.5, Color(0.8, 0.5, 1.0, 0.55))
		draw_circle(Vector2(x, y), 8.0, Color(0.6, 0.3, 1.0, 0.07))


func _draw_void(w: float, h: float) -> void:
	# crystal shards
	for i in range(10):
		var x := w * (0.04 + i * 0.10)
		var y := h * (0.55 + 0.18 * ((i * 7) % 5) / 5.0)
		var sz := 26.0 + float((i * 13) % 40)
		var pts := PackedVector2Array([
			Vector2(x, y - sz), Vector2(x + sz * 0.45, y), Vector2(x, y + sz * 0.65), Vector2(x - sz * 0.42, y),
		])
		draw_colored_polygon(pts, Color(0.55, 0.18, 0.6, 0.22))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.95, 0.4, 0.95, 0.35), 1.2, true)
	# cracks
	for i in range(4):
		var x := w * (0.15 + i * 0.22)
		var pts := PackedVector2Array([Vector2(x, 0), Vector2(x + 20, h * 0.2), Vector2(x - 10, h * 0.35), Vector2(x + 14, h * 0.52)])
		draw_polyline(pts, Color(1, 0.45, 0.95, 0.16), 1.4, true)
	# floating motes handled by particles


func _draw_throne(w: float, h: float) -> void:
	# grand stair
	for i in range(5):
		var y := h * (0.72 + i * 0.055)
		draw_rect(Rect2(w * (0.20 - i * 0.035), y, w * (0.60 + i * 0.07), h * 0.05), Color(0.07, 0.05, 0.10, 0.95))
	# throne
	var cx := w * 0.5
	draw_rect(Rect2(cx - 92, h * 0.38, 184, h * 0.38), Color(0.08, 0.05, 0.11, 0.98))
	draw_rect(Rect2(cx - 120, h * 0.30, 240, 30), Color(0.11, 0.07, 0.15, 0.98))
	for side in [-1.0, 1.0]:
		var x: float = cx + float(side) * 108.0
		draw_rect(Rect2(x - 13, h * 0.22, 26, h * 0.56), Color(0.10, 0.06, 0.14, 0.98))
		draw_circle(Vector2(x, h * 0.22), 16.0, Color(0.75, 0.45, 0.9, 0.25))
	# crown hovering
	var cy := h * 0.17 + sin(_time * 0.8) * 5.0
	var pts := PackedVector2Array([
		Vector2(cx - 48, cy + 16), Vector2(cx - 30, cy - 16), Vector2(cx - 12, cy + 6),
		Vector2(cx, cy - 28), Vector2(cx + 12, cy + 6), Vector2(cx + 30, cy - 16), Vector2(cx + 48, cy + 16),
	])
	draw_colored_polygon(pts, Color(1.0, 0.72, 0.25, 0.8))
	draw_circle(Vector2(cx, cy + 2), 70.0, Color(1.0, 0.55, 0.25, 0.05))
	# pillars of light
	for side in [-1.0, 1.0]:
		var x: float = cx + float(side) * 210.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 30, 0), Vector2(x + 30, 0), Vector2(x + 70, h), Vector2(x - 70, h),
		]), Color(1, 0.5, 0.3, 0.03))


func _draw_particles(w: float, h: float) -> void:
	if style in ["storm"]:
		return
	for p in _particles:
		var x := float(p["x"]) * w
		var speed := float(p["speed"]) * h
		var y := 0.0
		if style in ["lava", "throne"]:
			y = h - fmod(float(p["y"]) * h + _time * speed, h + 40.0)
		elif style in ["ocean"]:
			y = h - fmod(float(p["y"]) * h + _time * speed * 0.5, h + 40.0)
			x += sin(_time * 0.8 + float(p["phase"])) * 10.0
		elif style in ["void", "temple", "night"]:
			y = fmod(float(p["y"]) * h + _time * speed * 0.25, h + 40.0)
			x += sin(_time * 0.4 + float(p["phase"])) * 14.0
		else:
			y = fmod(float(p["y"]) * h + _time * speed * 0.3, h + 40.0)
		var col := accent
		if style == "temple":
			col = Color(1, 0.85, 0.45, 0.35)
		elif style == "void":
			col = Color(1, 0.4, 0.9, 0.35)
		else:
			col = Color(accent.r, accent.g, accent.b, 0.28)
		draw_circle(Vector2(x, y), float(p["size"]), col)


func _draw_vignette(w: float, h: float) -> void:
	var steps := 10
	for i in range(steps):
		var a := 0.06 * (1.0 - float(i) / float(steps))
		draw_rect(Rect2(0, float(i) * 6.0, w, 6.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, h - float(i + 1) * 6.0, w, 6.0), Color(0, 0, 0, a))
		draw_rect(Rect2(float(i) * 8.0, 0, 8.0, h), Color(0, 0, 0, a * 0.7))
		draw_rect(Rect2(w - float(i + 1) * 8.0, 0, 8.0, h), Color(0, 0, 0, a * 0.7))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / max(rx, 0.001)))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
