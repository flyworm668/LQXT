extends Control
## Root router.  Screens are instantiated from scripts and cross-faded.

var current_screen: Control = null
var _busy: bool = false
var _fade: ColorRect = null


func _ready() -> void:
	theme = UI.theme
	RenderingServer.set_default_clear_color(UI.BG)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	get_tree().root.size_changed.connect(_fit_phone_screen)
	var args := OS.get_cmdline_user_args()
	if "--test" in args:
		add_child(load("res://tests/test_runner.gd").new())
		return
	if "--shots" in args:
		_show_initial("res://scripts/ui/title_screen.gd")
		add_child(load("res://tests/shot_runner.gd").new())
		return
	_show_initial("res://scripts/ui/title_screen.gd")


func _show_initial(path: String) -> void:
	var scr: Control = load(path).new()
	scr.name = "Screen"
	scr.set("params", {})
	add_child(scr)
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scr.set_meta("screen_path", path)
	current_screen = scr
	_fit_phone_screen()


func goto(path: String, p: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.015, 0.03, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.z_index = 500
	add_child(_fade)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.16)
	await t.finished
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
		current_screen = null
	var scr: Control = load(path).new()
	scr.name = "Screen"
	scr.set("params", p)
	scr.set_meta("screen_path", path)
	add_child(scr)
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_screen = scr
	_fit_phone_screen()
	_fade.move_to_front()
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.22)
	await t2.finished
	if is_instance_valid(_fade):
		_fade.queue_free()
	_fade = null
	_busy = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_android_back()


func _android_back() -> void:
	if GameState.run_active and current_screen != null and current_screen.has_method("open_run_menu"):
		current_screen.open_run_menu()
		return
	get_tree().quit()


func _fit_phone_screen() -> void:
	if current_screen == null or not is_instance_valid(current_screen):
		return
	if not OS.has_feature("mobile"):
		return
	var window_px := Vector2(DisplayServer.window_get_size())
	if window_px.x < 2.0 or window_px.y < 2.0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var safe_pos := Vector2(safe.position)
	var safe_end := safe_pos + Vector2(safe.size)
	var win_pos := Vector2(DisplayServer.window_get_position())
	var vis_pos := (safe_pos - win_pos).clamp(Vector2.ZERO, window_px)
	var vis_end := (safe_end - win_pos).clamp(Vector2.ZERO, window_px)
	var vis := vis_end - vis_pos
	if vis.x < 2.0 or vis.y < 2.0:
		vis_pos = Vector2.ZERO
		vis = window_px
	var canvas := Vector2(1280, 720)
	var map_scale := minf(window_px.x / canvas.x, window_px.y / canvas.y)
	var letter := (window_px - canvas * map_scale) * 0.5
	var canvas_pos := ((vis_pos - letter) / map_scale).clamp(Vector2.ZERO, canvas)
	var canvas_end := ((vis_end - letter) / map_scale).clamp(Vector2.ZERO, canvas)
	if not GameState.screen_safe:
		canvas_pos = Vector2.ZERO
		canvas_end = canvas
	var pad: Dictionary = GameState.screen_pad
	canvas_pos.x = clampf(canvas_pos.x + float(pad.get("left", 0)), 0.0, canvas.x)
	canvas_pos.y = clampf(canvas_pos.y + float(pad.get("top", 0)), 0.0, canvas.y)
	canvas_end.x = clampf(canvas_end.x - float(pad.get("right", 0)), 0.0, canvas.x)
	canvas_end.y = clampf(canvas_end.y - float(pad.get("bottom", 0)), 0.0, canvas.y)
	var room := canvas_end - canvas_pos
	if room.x < 2.0 or room.y < 2.0:
		return
	var fit := minf(1.0, minf(room.x / canvas.x, room.y / canvas.y))
	var center := canvas_pos + room * 0.5
	var scr := current_screen
	scr.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scr.offset_left = 0.0
	scr.offset_top = 0.0
	scr.offset_right = canvas.x
	scr.offset_bottom = canvas.y
	scr.pivot_offset = canvas * 0.5
	scr.scale = Vector2(fit, fit)
	scr.position = center - canvas * 0.5
	scr.clip_contents = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if current_screen != null and current_screen.has_method("open_run_menu"):
				current_screen.open_run_menu()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
