extends Control
## Root router.  Screens are instantiated from scripts and cross-faded.

var current_screen: Control = null
var _busy: bool = false
var _fade: ColorRect = null


func _ready() -> void:
	theme = UI.theme
	RenderingServer.set_default_clear_color(UI.BG)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_fade.move_to_front()
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.22)
	await t2.finished
	if is_instance_valid(_fade):
		_fade.queue_free()
	_fade = null
	_busy = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
