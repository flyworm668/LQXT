extends RefCounted
## In-run pause menu: continue, manual save/load, return home, abandon.


static func screen_path(screen: String) -> String:
	match screen:
		"reward":
			return "res://scripts/ui/reward_screen.gd"
		"event":
			return "res://scripts/ui/event_screen.gd"
		"route":
			return "res://scripts/ui/route_screen.gd"
		"shop":
			return "res://scripts/ui/shop_screen.gd"
		"formation":
			return "res://scripts/ui/formation_screen.gd"
		_:
			return "res://scripts/ui/map_screen.gd"


static func is_open(screen: Control) -> bool:
	return screen != null and screen.has_meta("run_menu") and is_instance_valid(screen.get_meta("run_menu"))


static func close(screen: Control) -> void:
	if screen == null:
		return
	if is_open(screen):
		(screen.get_meta("run_menu") as Node).queue_free()
	screen.remove_meta("run_menu")
	_set_paused(screen, false)


static func toggle(screen: Control) -> void:
	if screen == null or not GameState.run_active:
		return
	if is_open(screen):
		close(screen)
	else:
		open(screen)


static func open(screen: Control) -> void:
	if screen == null or not GameState.run_active or is_open(screen):
		return
	_set_paused(screen, true)
	var overlay := _overlay(screen)
	screen.set_meta("run_menu", overlay)
	_show_main(screen, overlay)


static func open_load_only(screen: Control) -> void:
	if screen == null or is_open(screen):
		return
	var overlay := _overlay(screen)
	screen.set_meta("run_menu", overlay)
	_show_slots(screen, overlay, false)


static func _overlay(screen: Control) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "RunMenu"
	overlay.color = Color(0.01, 0.015, 0.03, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 180
	screen.add_child(overlay)
	return overlay


static func _set_paused(screen: Control, paused: bool) -> void:
	if screen != null and screen.has_method("set_menu_paused"):
		screen.set_menu_paused(paused)


static func _panel(overlay: ColorRect) -> VBoxContainer:
	for child in overlay.get_children():
		child.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.98), UI.GOLD, 18, 22)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	return v


static func _show_main(screen: Control, overlay: ColorRect) -> void:
	var v := _panel(overlay)
	var title := UI.label("远 征 菜 单", 28, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var place := "星塔征服战" if GameState.run_mode == "conquest" else "第 %d 层" % GameState.current_floor
	v.add_child(UI.label("%s · %s · 自动存档已开启" % [
		place, str(GameState.trainer.get("name", ""))], 13, UI.MUTED))
	v.add_child(UI.hline(UI.BORDER, 1))
	v.add_child(_action(screen, "继续游戏", UI.ACCENT, func(): close(screen)))
	v.add_child(_action(screen, "保存进度", UI.BLUE, func(): _show_slots(screen, overlay, true)))
	v.add_child(_action(screen, "读取存档", UI.PURPLE, func(): _show_slots(screen, overlay, false)))
	v.add_child(_action(screen, "保存并返回主页面", UI.GOLD, func(): _save_and_home(screen)))
	v.add_child(_action(screen, "画面设置", UI.BLUE, func(): _show_display(screen, overlay)))
	v.add_child(UI.label("战斗中的存档会回到本层开战前。Esc 关闭菜单。", 11, UI.FAINT))


static func _action(screen: Control, text: String, color: Color, callback: Callable) -> Button:
	var b := UI.button(text, color, 16)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(callback)
	return b


static func _show_slots(screen: Control, overlay: ColorRect, saving: bool) -> void:
	var v := _panel(overlay)
	var title := UI.label("保存进度" if saving else "读取存档", 26, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UI.label("自动存档每次推进都会更新。下面三个是手动存档。", 12, UI.MUTED, true))
	if not saving:
		v.add_child(_slot_row(screen, overlay, -1, false))
	for i in range(GameState.SLOT_COUNT):
		v.add_child(_slot_row(screen, overlay, i, saving))
	var back := UI.ghost_button("返回", 14)
	back.custom_minimum_size = Vector2(0, 36)
	back.pressed.connect(func():
		if GameState.run_active:
			_show_main(screen, overlay)
		else:
			close(screen))
	v.add_child(back)


static func _slot_row(screen: Control, overlay: ColorRect, index: int, saving: bool) -> Control:
	var summary: Dictionary = GameState.autosave_summary() if index < 0 else GameState.slot_summary(index)
	var row := UI.panel(Color(0.07, 0.09, 0.14, 0.95), UI.BORDER, 10, 10)
	var h := UI.hbox(8)
	row.add_child(h)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var name := "自动存档" if index < 0 else "存档 %d" % (index + 1)
	info.add_child(UI.label(name, 15, UI.TEXT))
	if summary.is_empty():
		info.add_child(UI.label("空", 12, UI.FAINT))
	else:
		var when := _when(int(summary.get("saved_at", 0)))
		var where := "星塔征服战" if str(summary.get("mode", "")) == "conquest" else "第 %d 层" % int(summary.get("floor", 1))
		info.add_child(UI.label("%s · %s · %s%s" % [
			where,
			str(summary.get("trainer", "")),
			GameState.screen_label(str(summary.get("screen", "map"))),
			(" · " + when) if when != "" else ""], 12, UI.MUTED))
	if saving:
		var save := UI.button("保存", UI.BLUE, 13)
		save.custom_minimum_size = Vector2(72, 34)
		save.pressed.connect(func(): _write_slot(screen, overlay, index))
		h.add_child(save)
	else:
		var load := UI.button("读取", UI.PURPLE, 13)
		load.custom_minimum_size = Vector2(72, 34)
		load.disabled = summary.is_empty()
		load.pressed.connect(func(): _read_slot(screen, index))
		h.add_child(load)
		if index >= 0:
			var wipe := UI.ghost_button("删除", 12)
			wipe.custom_minimum_size = Vector2(60, 34)
			wipe.disabled = summary.is_empty()
			wipe.pressed.connect(func():
				GameState.delete_slot(index)
				_show_slots(screen, overlay, false))
			h.add_child(wipe)
	return row


static func _when(unix: int) -> String:
	if unix <= 0:
		return ""
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
	return "%02d-%02d %02d:%02d" % [int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]


static func _write_slot(screen: Control, overlay: ColorRect, index: int) -> void:
	if GameState.save_slot(index) and screen.has_method("toast"):
		screen.toast("已写入存档 %d" % (index + 1), UI.GOOD)
	elif screen.has_method("toast"):
		screen.toast("保存失败", UI.DANGER)
	_show_slots(screen, overlay, true)


static func _read_slot(screen: Control, index: int) -> void:
	var where := GameState.resume_run() if index < 0 else GameState.load_slot(index)
	if where == "":
		if screen.has_method("toast"):
			screen.toast("这个存档是空的", UI.DANGER)
		return
	close(screen)
	if screen.has_method("goto_screen"):
		screen.goto_screen(screen_path(where))


static func _save_and_home(screen: Control) -> void:
	GameState.save_run()
	close(screen)
	if screen.has_method("goto_screen"):
		screen.goto_screen("res://scripts/ui/title_screen.gd")


static func open_display(screen: Control) -> void:
	if screen == null or is_open(screen):
		return
	var overlay := _overlay(screen)
	screen.set_meta("run_menu", overlay)
	_show_display(screen, overlay)


static func _show_display(screen: Control, overlay: ColorRect) -> void:
	var v := _panel(overlay)
	var title := UI.label("画面设置", 26, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UI.label("拖动边距，躲开刘海和圆角。只在手机上生效。", 13, UI.MUTED, true))
	var safe := CheckBox.new()
	safe.text = "跟随系统安全区"
	safe.button_pressed = GameState.screen_safe
	safe.add_theme_font_size_override("font_size", 15)
	safe.toggled.connect(func(on: bool):
		GameState.set_screen_safe(on)
		_refit(screen))
	v.add_child(safe)
	v.add_child(_pad_slider(screen, "左", "left"))
	v.add_child(_pad_slider(screen, "右", "right"))
	v.add_child(_pad_slider(screen, "上", "top"))
	v.add_child(_pad_slider(screen, "下", "bottom"))
	var reset := UI.ghost_button("恢复默认", 14)
	reset.custom_minimum_size = Vector2(0, 36)
	reset.pressed.connect(func():
		GameState.set_screen_safe(true)
		for side in ["left", "right", "top", "bottom"]:
			GameState.screen_pad[side] = 0
		GameState.save_display()
		_refit(screen)
		_show_display(screen, overlay))
	v.add_child(reset)
	var back := UI.button("返回", UI.ACCENT, 15)
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func():
		if GameState.run_active:
			_show_main(screen, overlay)
		else:
			close(screen))
	v.add_child(back)


static func _pad_slider(screen: Control, title: String, side: String) -> Control:
	var row := UI.hbox(8)
	var label := UI.label("%s %d" % [title, int(GameState.screen_pad.get(side, 0))], 15, UI.TEXT)
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 160
	slider.step = 4
	slider.value = int(GameState.screen_pad.get(side, 0))
	slider.custom_minimum_size = Vector2(240, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float):
		GameState.set_screen_pad(side, int(value))
		label.text = "%s %d" % [title, int(value)]
		_refit(screen))
	row.add_child(slider)
	return row


static func _refit(screen: Control) -> void:
	var root: Node = screen.get_parent()
	if root != null and root.has_method("_fit_phone_screen"):
		root.call("_fit_phone_screen")
