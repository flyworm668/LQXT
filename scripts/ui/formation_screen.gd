extends "res://scripts/ui/screen_base.gd"
const PetDetailScript = preload("res://scripts/ui/pet_detail.gd")
## 3x3 formation editor.

var placements: Array = []
var selected_uid: int = -1
var grid_host: GridContainer
var roster_host: VBoxContainer
var roster_scroll: ScrollContainer
var count_label: Label
var tip_label: Label
var resonance_row: HFlowContainer
var preset_buttons: Array = []
var roster_panel: Control
var drag_armed := false
var drag_uid := -1
var drag_from_cell := false
var drag_row := -1
var drag_col := -1
var drag_origin := Vector2.ZERO
var dragging := false
var drag_ghost: Control


func _ready() -> void:
	placements = GameState.deployed.duplicate(true)
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.45)
	_build_static()
	_refresh()
	GameState.note_screen("formation")
	if placements.is_empty():
		tip_label.text = "从仓库拖到格子上阵，格子之间拖动可交换。点一下再点格子也可以。"


func _build_static() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := UI.vbox(12)
	margin.add_child(root)

	var top := UI.hbox(12)
	var back := UI.ghost_button("← 返回地图", 14)
	back.custom_minimum_size = Vector2(112, 34)
	back.pressed.connect(_save_and_back)
	top.add_child(back)
	top.add_child(UI.label("阵型编排", 30, UI.TEXT))
	top.add_child(UI.grow())
	count_label = UI.label("上阵 0 / 6", 14, UI.GOOD)
	top.add_child(count_label)
	var menu := UI.ghost_button("菜单", 14)
	menu.custom_minimum_size = Vector2(72, 34)
	menu.pressed.connect(open_run_menu)
	top.add_child(menu)
	root.add_child(top)

	var preset_row := UI.hbox(8)
	preset_row.add_child(UI.label("阵型预设", 13, UI.MUTED))
	for i in range(3):
		var pb := UI.ghost_button("阵型 %d" % (i + 1), 13)
		pb.custom_minimum_size = Vector2(96, 32)
		if int(GameState.active_preset) == i:
			pb.add_theme_color_override("font_color", UI.GOLD)
		pb.pressed.connect(_switch_preset.bind(i))
		preset_row.add_child(pb)
		preset_buttons.append(pb)
	preset_row.add_child(UI.grow())
	preset_row.add_child(UI.label("切换时会自动保存当前阵型", 11, UI.FAINT))
	root.add_child(preset_row)
	tip_label = UI.label("拖到格子上阵，拖回仓库下阵。点一下再点格子同样有效。点「详情」查看技能。", 13, UI.MUTED)
	root.add_child(tip_label)
	resonance_row = HFlowContainer.new()
	resonance_row.add_theme_constant_override("h_separation", 8)
	resonance_row.add_theme_constant_override("v_separation", 4)
	root.add_child(resonance_row)

	var main := UI.hbox(24)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(548, 0)
	main.add_child(left)
	var col_labels := UI.hbox(8)
	col_labels.add_theme_constant_override("separation", 8)
	for col in range(2, -1, -1):
		var cap_text: String = ["前排", "中排", "后排"][col]
		var cap := UI.label(cap_text, 12, UI.GOLD if col == 0 else UI.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.custom_minimum_size = Vector2(176, 0)
		col_labels.add_child(cap)
	left.add_child(col_labels)
	grid_host = GridContainer.new()
	grid_host.columns = 3
	grid_host.add_theme_constant_override("h_separation", 8)
	grid_host.add_theme_constant_override("v_separation", 8)
	left.add_child(grid_host)
	var legend := UI.hbox(8)
	legend.add_child(UI.label("坦克嘲讽单体。相邻职业有连携。同排坦克会挡下身后 30% 伤害。", 11, UI.MUTED))
	legend.add_child(UI.grow())
	legend.add_child(UI.label("靠近敌方的列是前排", 11, UI.FAINT))
	left.add_child(legend)

	var right := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 16, 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_panel = right
	main.add_child(right)
	var rv := UI.vbox(8)
	right.add_child(rv)
	var rh := UI.hbox(8)
	rh.add_child(UI.label("精灵仓库", 19, UI.TEXT))
	rh.add_child(UI.label("共 %d 只" % GameState.roster.size(), 12, UI.MUTED))
	rh.add_child(UI.grow())
	rh.add_child(UI.label("上阵上限 6", 11, UI.FAINT))
	rv.add_child(rh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	roster_scroll = scroll
	roster_host = UI.vbox(6)
	roster_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(roster_host)

	var bottom := UI.hbox(10)
	var clear := UI.ghost_button("全部下阵", 14)
	clear.custom_minimum_size = Vector2(110, 40)
	clear.pressed.connect(func():
		placements.clear()
		selected_uid = -1
		_persist()
		_refresh())
	bottom.add_child(clear)
	bottom.add_child(UI.grow())
	var save := UI.button("保存并返回", Color.TRANSPARENT, 15)
	save.custom_minimum_size = Vector2(150, 48)
	save.pressed.connect(_save_and_back)
	bottom.add_child(save)
	var fight := UI.button("保存并开战", UI.ACCENT, 17)
	fight.custom_minimum_size = Vector2(190, 48)
	fight.pressed.connect(_save_and_fight)
	bottom.add_child(fight)
	root.add_child(bottom)


func _refresh() -> void:
	var kept_scroll := 0
	if roster_scroll != null:
		kept_scroll = roster_scroll.scroll_vertical
	UI.clear_children(grid_host)
	UI.clear_children(roster_host)
	count_label.text = "上阵 %d / 6" % placements.size()
	_refresh_resonance()
	for row in range(3):
		for col in range(2, -1, -1):
			grid_host.add_child(_cell(row, col))
	# Display order only. Deploying does not rewrite GameState.roster.
	for entry in GameState.roster_view():
		roster_host.add_child(_roster_row(entry))
	_restore_roster_scroll(kept_scroll)


func _restore_roster_scroll(y: int) -> void:
	if roster_scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(roster_scroll):
		roster_scroll.scroll_vertical = y


func _refresh_resonance() -> void:
	UI.clear_children(resonance_row)
	resonance_row.add_child(UI.label("元素共鸣", 12, UI.GOLD))
	var counts := {}
	for p in placements:
		var entry := GameState.get_roster_entry(int(p["uid"]))
		if entry.is_empty():
			continue
		var eid := str(ContentDB.pet(str(entry["species"])).get("element", ""))
		if eid.is_empty():
			continue
		counts[eid] = int(counts.get(eid, 0)) + 1
	if counts.is_empty():
		resonance_row.add_child(UI.label("同元素上阵 2 只激活一阶、3 只激活二阶团队加成。", 11, UI.FAINT))
		return
	for eid in counts.keys():
		var cfg: Dictionary = ContentDB.resonance(str(eid))
		var tier: Dictionary = ContentDB.resonance_tier(str(eid), int(counts[eid]))
		var color := Color(str(cfg.get("color", "#ffffff")))
		var text := "%s ×%d" % [str(cfg.get("name", eid)), int(counts[eid])]
		if tier.is_empty():
			var need := 2
			for t in cfg.get("tiers", []):
				if int(t.get("count", 99)) > int(counts[eid]):
					need = int(t["count"])
					break
			text += "（还需 %d 只）" % maxi(1, need - int(counts[eid]))
		else:
			var parts: Array = []
			for key in (tier.get("mods", {}) as Dictionary).keys():
				parts.append("%s+%d%%" % [{"hp": "生命", "atk": "攻击", "def": "防御", "spd": "速度", "crit": "暴击"}.get(key, key),
					int(round(float(tier["mods"][key]) * 100.0))])
			text += " · " + " ".join(parts)
		resonance_row.add_child(UI.pill(text, color, 10))
	resonance_row.add_child(UI.grow())


func _fit_label(text: String, size: int, color: Color) -> Label:
	var l := UI.label(text, size, color)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(36, 0)
	return l


func _placement_at(row: int, col: int) -> Dictionary:
	for p in placements:
		if int(p["row"]) == row and int(p["col"]) == col:
			return p
	return {}


func _placement_of(uid: int) -> Dictionary:
	for p in placements:
		if int(p["uid"]) == uid:
			return p
	return {}


func _cell(row: int, col: int) -> Control:
	var placement := _placement_at(row, col)
	var is_selected_cell := not placement.is_empty() and int(placement["uid"]) == selected_uid
	var border := UI.BORDER
	if is_selected_cell:
		border = UI.GOLD
	elif not placement.is_empty():
		border = Color(0.35, 0.55, 0.45, 0.8)
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.88), border, 14, 10)
	panel.custom_minimum_size = Vector2(176, 118)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("row", row)
	panel.set_meta("col", col)
	var cell_uid := -1 if placement.is_empty() else int(placement["uid"])
	if placement.is_empty():
		var v := UI.vbox(4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(v)
		var plus := UI.label("+", 34, Color(1, 1, 1, 0.16))
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(plus)
		var name: String = ["前排", "中排", "后排"][col]
		var l := UI.label(name, 12, Color(1, 1, 1, 0.22))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		_bind_pick(panel, cell_uid, true, row, col)
		return panel
	var entry := GameState.get_roster_entry(int(placement["uid"]))
	if entry.is_empty():
		return panel
	var h := UI.hbox(8)
	panel.add_child(h)
	var av := UI.avatar(str(entry["species"]), 48, int(entry["level"]))
	h.add_child(av)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_contents = true
	h.add_child(info)
	info.add_child(_fit_label(GameState.pet_name(entry), 13, UI.TEXT))
	info.add_child(UI.label("Lv.%d" % int(entry["level"]), 11, UI.MUTED))
	if bool(entry.get("hero", false)):
		info.add_child(UI.pill("英雄 %d★" % int(entry.get("hero_star", 0)), Color(1.0, 0.85, 0.45), 9))
	var cap_text := "不封顶" if bool(entry.get("uncapped", false)) else str(GameState.pet_affix_cap(entry))
	info.add_child(UI.label("词条 %d/%s" % [GameState.total_affixes(entry), cap_text], 10, UI.FAINT))
	_bind_pick(panel, cell_uid, true, row, col)
	return panel


func _roster_row(entry: Dictionary) -> Control:
	var uid := int(entry["uid"])
	var pid := str(entry["species"])
	var deployed := _placement_of(uid)
	var is_selected := uid == selected_uid
	var border := UI.GOLD if is_selected else (Color(0.35, 0.55, 0.45, 0.7) if not deployed.is_empty() else UI.BORDER)
	var panel := UI.panel(Color(0.07, 0.09, 0.14, 0.9), border, 10, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(8)
	panel.add_child(h)
	var av := UI.avatar(pid, 46, int(entry["level"]))
	h.add_child(av)
	var info := UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_contents = true
	h.add_child(info)
	var line1 := UI.hbox(6)
	var name := _fit_label(GameState.pet_name(entry), 14, UI.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line1.add_child(name)
	line1.add_child(UI.label("Lv.%d" % int(entry["level"]), 11, UI.MUTED))
	info.add_child(line1)
	var line2 := HFlowContainer.new()
	line2.add_theme_constant_override("h_separation", 4)
	line2.add_theme_constant_override("v_separation", 2)
	if bool(entry.get("hero", false)):
		line2.add_child(UI.pill("英雄 %d★" % int(entry.get("hero_star", 0)), Color(1.0, 0.85, 0.45), 9))
	if int(entry.get("resonance", 0)) > 0:
		line2.add_child(UI.pill("共鸣×%d" % int(entry["resonance"]), UI.PURPLE, 9))
	var cap_text := "不封顶" if bool(entry.get("uncapped", false)) else str(GameState.pet_affix_cap(entry))
	line2.add_child(UI.label("词条 %d/%s" % [GameState.total_affixes(entry), cap_text], 10, UI.FAINT))
	info.add_child(line2)
	var state := UI.pill("已上阵" if not deployed.is_empty() else "待命", UI.GOOD if not deployed.is_empty() else UI.MUTED, 9)
	h.add_child(state)
	var detail := UI.ghost_button("详情", 12)
	detail.custom_minimum_size = Vector2(56, 30)
	detail.pressed.connect(func(): PetDetailScript.open_roster(self, entry))
	h.add_child(detail)
	_bind_pick(panel, uid, false, -1, -1)
	return panel


func _pass_clicks(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not (child is Button):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_clicks(child)


func _bind_pick(panel: Control, uid: int, from_cell: bool, row: int, col: int) -> void:
	_pass_clicks(panel)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_arm_drag(uid, from_cell, row, col))


func _arm_drag(uid: int, from_cell: bool, row: int, col: int) -> void:
	drag_armed = true
	drag_uid = uid
	drag_from_cell = from_cell
	drag_row = row
	drag_col = col
	drag_origin = get_viewport().get_mouse_position()
	dragging = false


func _input(event: InputEvent) -> void:
	if not drag_armed:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if drag_uid >= 0 and not dragging and motion.position.distance_to(drag_origin) >= 8.0:
			dragging = true
			_show_ghost()
		if dragging and drag_ghost != null:
			drag_ghost.global_position = motion.position + Vector2(12, 12)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
			return
		var uid := drag_uid
		var from_cell := drag_from_cell
		var row := drag_row
		var col := drag_col
		var was_drag := dragging
		var pos := button.position
		_clear_drag()
		if was_drag:
			_drop_at(uid, from_cell, pos)
			get_viewport().set_input_as_handled()
		elif from_cell:
			_on_cell_clicked(row, col)
		else:
			_on_roster_clicked(uid)


func _show_ghost() -> void:
	_clear_ghost()
	var entry := GameState.get_roster_entry(drag_uid)
	if entry.is_empty():
		return
	drag_ghost = UI.panel(Color(0.08, 0.1, 0.16, 0.94), UI.GOLD, 10, 8)
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.z_index = 90
	drag_ghost.add_child(UI.label(GameState.pet_name(entry), 14, UI.TEXT))
	add_child(drag_ghost)
	drag_ghost.global_position = get_viewport().get_mouse_position() + Vector2(12, 12)


func _clear_ghost() -> void:
	if drag_ghost != null and is_instance_valid(drag_ghost):
		drag_ghost.queue_free()
	drag_ghost = null


func _clear_drag() -> void:
	drag_armed = false
	drag_uid = -1
	dragging = false
	_clear_ghost()


func _drop_at(uid: int, from_cell: bool, pos: Vector2) -> void:
	for child in grid_host.get_children():
		if child is Control and (child as Control).get_global_rect().has_point(pos):
			selected_uid = uid
			_on_cell_clicked(int(child.get_meta("row")), int(child.get_meta("col")))
			return
	if from_cell and roster_panel != null and roster_panel.get_global_rect().has_point(pos):
		var old := _placement_of(uid)
		if not old.is_empty():
			placements.erase(old)
			selected_uid = -1
			tip_label.text = "已拖回仓库。"
			_persist()
			_refresh()
			return
	tip_label.text = "已取消拖动。"
	_refresh()


func _on_roster_clicked(uid: int) -> void:
	if selected_uid == uid:
		selected_uid = -1
	else:
		selected_uid = uid
		if _placement_of(uid).is_empty() and placements.size() >= GameState.MAX_DEPLOY:
			tip_label.text = "上阵已满。先点击一个已上阵精灵将其下阵，或直接点击格子交换。"
	_refresh()


func _on_cell_clicked(row: int, col: int) -> void:
	var here := _placement_at(row, col)
	if selected_uid < 0:
		if not here.is_empty():
			selected_uid = int(here["uid"])
			tip_label.text = "已选择「%s」。点击其他格子移动，或再次点击自身下阵。" % _name_for_uid(selected_uid)
		_refresh()
		return
	var old := _placement_of(selected_uid)
	if not here.is_empty() and int(here["uid"]) == selected_uid:
		placements.erase(old)
		selected_uid = -1
		tip_label.text = "已下阵。点击精灵后选择格子重新上阵。"
		_persist()
		_refresh()
		return
	if old.is_empty() and placements.size() >= GameState.MAX_DEPLOY:
		tip_label.text = "上阵已满（5/5）。点击已上阵精灵可下阵。"
		_refresh()
		return
	if not old.is_empty():
		# move / swap
		if not here.is_empty():
			var old_row := int(old["row"])
			var old_col := int(old["col"])
			old["row"] = row
			old["col"] = col
			here["row"] = old_row
			here["col"] = old_col
		else:
			old["row"] = row
			old["col"] = col
	else:
		if not here.is_empty():
			placements.erase(here)
		placements.append({"uid": selected_uid, "row": row, "col": col})
	selected_uid = -1
	tip_label.text = "布阵已更新并保存。"
	_persist()
	_refresh()


func _name_for_uid(uid: int) -> String:
	var e := GameState.get_roster_entry(uid)
	return GameState.pet_name(e) if not e.is_empty() else "精灵"


func _switch_preset(index: int) -> void:
	GameState.save_preset(int(GameState.active_preset), placements)
	GameState.active_preset = index
	selected_uid = -1
	placements = GameState.load_preset(index)
	if placements.is_empty():
		tip_label.text = "阵型 %d 为空，请手动布阵。" % (index + 1)
	else:
		tip_label.text = "已切换到阵型 %d。" % (index + 1)
	_persist()
	_update_preset_buttons()
	_refresh()


func _update_preset_buttons() -> void:
	for i in range(preset_buttons.size()):
		var b: Button = preset_buttons[i]
		b.add_theme_color_override("font_color", UI.GOLD if i == int(GameState.active_preset) else UI.MUTED)
		b.add_theme_color_override("font_hover_color", UI.GOLD if i == int(GameState.active_preset) else UI.TEXT)


func _persist() -> void:
	GameState.save_preset(int(GameState.active_preset), placements)
	GameState.set_deployment(placements)


func _save_and_back() -> void:
	_persist()
	goto_screen("res://scripts/ui/map_screen.gd")


func _save_and_fight() -> void:
	if placements.is_empty():
		toast("至少需要上阵一只精灵", UI.DANGER)
		return
	_persist()
	goto_screen("res://scripts/ui/battle_screen.gd")
