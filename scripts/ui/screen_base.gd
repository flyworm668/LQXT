extends Control
## Base helper for all full-screen views.

var params: Dictionary = {}


func goto_screen(path: String, p: Dictionary = {}) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("goto"):
		main.goto(path, p)


func add_background(map_id: String) -> void:
	var bg := UI.backdrop(map_id)
	add_child(bg)
	move_child(bg, 0)


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
	var panel := UI.panel(UI.PANEL, UI.BORDER, 18, 22)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	var head := UI.hbox(12)
	head.add_child(UI.label(title_text, 24, UI.GOLD))
	var grow := UI.grow()
	head.add_child(grow)
	var close := UI.ghost_button("关闭", 15)
	close.custom_minimum_size = Vector2(76, 34)
	close.pressed.connect(func(): overlay.queue_free())
	head.add_child(close)
	v.add_child(head)
	v.add_child(UI.hline(UI.BORDER, 1))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 44, height)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	v.add_child(scroll)
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
	hit.pressed.connect(callback)
	return hit


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


func progress_pips(current: int, total: int = 10) -> HBoxContainer:
	var row := UI.hbox(5)
	for i in range(1, total + 1):
		var color := UI.FAINT
		if i < current:
			color = UI.GOOD
		elif i == current:
			color = UI.ACCENT
		if i == 4 or i == 8 or i == 10:
			color = color.lerp(UI.GOLD, 0.55) if i != current else UI.GOLD
		var pip := ColorRect.new()
		pip.color = color
		pip.custom_minimum_size = Vector2(22, 6)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return row
