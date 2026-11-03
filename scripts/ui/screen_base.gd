extends Control
## Base helper for all full-screen views.

var params: Dictionary = {}


const RunMenuScript = preload("res://scripts/ui/run_menu.gd")


func goto_screen(path: String, p: Dictionary = {}) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("goto"):
		main.goto(path, p)


func add_background(map_id: String) -> void:
	var bg := UI.backdrop(map_id)
	add_child(bg)
	move_child(bg, 0)


func open_run_menu() -> void:
	RunMenuScript.toggle(self)


func open_load_menu() -> void:
	RunMenuScript.open_load_only(self)


func add_menu_button() -> void:
	if not GameState.run_active:
		return
	var b := UI.ghost_button("菜单", 13)
	b.custom_minimum_size = Vector2(64, 30)
	b.position = Vector2(1196, 14)
	b.z_index = 40
	b.pressed.connect(open_run_menu)
	add_child(b)


func add_dim(alpha: float = 0.35) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func show_modal(title_text: String, body: Control, width: float = 760.0, height: float = 420.0) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.015, 0.03, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var view := get_viewport_rect().size
	width = minf(width, maxf(360.0, view.x - 48.0))
	var panel := UI.panel(UI.PANEL, UI.BORDER, 18, 22)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	var head := UI.hbox(12)
	head.add_child(UI.label(title_text, 24, UI.GOLD))
	var grow := UI.grow()
	head.add_child(grow)
	var close := UI.button("返回", UI.ACCENT, 16)
	close.clip_text = false
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(128, 46)
	close.pressed.connect(func(): overlay.queue_free())
	head.add_child(close)
	v.add_child(head)
	v.add_child(UI.hline(UI.BORDER, 1))
	var view_h := view.y
	var scroll_h := minf(height, maxf(160.0, view_h - 220.0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 44, scroll_h)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	v.add_child(scroll)
	var back := UI.button("返回", UI.ACCENT, 18)
	back.clip_text = false
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(220, 48)
	back.pressed.connect(func(): overlay.queue_free())
	v.add_child(back)
	return overlay


func make_click_overlay(panel: Control, callback: Callable) -> Button:
	var hit := Button.new()
	hit.flat = true
	hit.text = ""
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	panel.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(callback)
	return hit


func close_modals() -> void:
	for child in get_children():
		if child is ColorRect and int(child.z_index) >= 100 and int(child.z_index) < 200:
			child.queue_free()


func toast(text: String, color: Color = UI.TEXT) -> void:
	var p := UI.panel(Color(0.04, 0.06, 0.10, 0.96), color, 10, 12)
	var l := UI.label(text, 15, color)
	p.add_child(l)
	p.z_index = 200
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	await get_tree().process_frame
	var vp := get_viewport_rect().size
	p.position = Vector2(vp.x * 0.5 - p.size.x * 0.5, vp.y - 150.0)
	p.modulate.a = 0.0
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.15)
	t.tween_interval(1.2)
	t.tween_property(p, "modulate:a", 0.0, 0.35)
	t.tween_callback(p.queue_free)


func banner(text: String, color: Color = UI.GOLD, duration: float = 1.2) -> void:
	var p := UI.panel(Color(0.03, 0.04, 0.07, 0.9), color, 12, 16)
	var l := UI.label(text, 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.z_index = 150
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	await get_tree().process_frame
	var vp := get_viewport_rect().size
	p.position = Vector2(vp.x * 0.5 - p.size.x * 0.5, 118.0)
	p.modulate.a = 0.0
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.15)
	t.tween_interval(duration)
	t.tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)


func progress_pips(current: int, total: int = 0) -> HBoxContainer:
	if total <= 0:
		total = ContentDB.total_floors()
	var row := UI.hbox(3)
	var width := 22.0 if total <= 12 else (8.0 if total > 24 else 14.0)
	for i in range(1, total + 1):
		var color := UI.FAINT
		if i < current:
			color = UI.GOOD
		elif i == current:
			color = UI.ACCENT
		if str(ContentDB.floor(i).get("kind", "")) == "boss":
			color = UI.GOLD if i == current else color.lerp(UI.GOLD, 0.55)
		var pip := ColorRect.new()
		pip.color = color
		pip.custom_minimum_size = Vector2(width, 6)
		pip.tooltip_text = "第 %d 层" % i
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return row
