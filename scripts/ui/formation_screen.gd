extends "res://scripts/ui/screen_base.gd"
## 3x3 formation editor.

var placements: Array = []
var selected_uid: int = -1
var grid_host: GridContainer
var roster_host: VBoxContainer
var count_label: Label
var tip_label: Label


func _ready() -> void:
	placements = GameState.deployed.duplicate(true)
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.45)
	_build_static()
	_refresh()


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
	count_label = UI.label("上阵 0 / 5", 14, UI.GOOD)
	top.add_child(count_label)
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
	preset_row.add_child(UI.grow())
	preset_row.add_child(UI.label("切换时会自动保存当前阵型", 11, UI.FAINT))
	root.add_child(preset_row)
	tip_label = UI.label("点击精灵，再点击格子放置。再次点击已选精灵可下阵。", 13, UI.MUTED)
	root.add_child(tip_label)

	var main := UI.hbox(24)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(610, 0)
	main.add_child(left)
	var col_labels := UI.hbox(8)
	col_labels.add_theme_constant_override("separation", 8)
	for col in range(2, -1, -1):
		var cap_text: String = ["前排 · 伤害 +20%", "中排 · 无加成", "后排 · 伤害 -15%"][col]
		var cap := UI.label(cap_text, 12, UI.GOLD if col == 0 else UI.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.custom_minimum_size = Vector2(194, 0)
		col_labels.add_child(cap)
	left.add_child(col_labels)
	grid_host = GridContainer.new()
	grid_host.columns = 3
	grid_host.add_theme_constant_override("h_separation", 8)
	grid_host.add_theme_constant_override("v_separation", 8)
	left.add_child(grid_host)
	var legend := UI.hbox(8)
	legend.add_child(UI.pill("前排伤害 +20%", UI.GOLD, 11))
	legend.add_child(UI.pill("中排无加成", UI.MUTED, 11))
	legend.add_child(UI.pill("后排伤害 -15%", UI.BLUE, 11))
	legend.add_child(UI.grow())
	legend.add_child(UI.label("靠近敌方的列是前排", 11, UI.FAINT))
	left.add_child(legend)

	var right := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 16, 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var rv := UI.vbox(8)
	right.add_child(rv)
	var rh := UI.hbox(8)
	rh.add_child(UI.label("精灵仓库", 19, UI.TEXT))
	rh.add_child(UI.label("共 %d 只" % GameState.roster.size(), 12, UI.MUTED))
	rh.add_child(UI.grow())
	rh.add_child(UI.label("上阵上限 5", 11, UI.FAINT))
	rv.add_child(rh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	roster_host = UI.vbox(6)
	roster_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(roster_host)

	var bottom := UI.hbox(10)
	var auto := UI.button("自动布阵", Color.TRANSPARENT, 15)
	auto.custom_minimum_size = Vector2(132, 48)
	auto.pressed.connect(_auto_deploy)
	bottom.add_child(auto)
	var clear := UI.ghost_button("全部下阵", 14)
	clear.custom_minimum_size = Vector2(110, 40)
	clear.pressed.connect(func():
		placements.clear()
		selected_uid = -1
		_refresh())
	bottom.add_child(clear)
	bottom.add_child(UI.grow())
	var save := UI.button("保存并返回", Color.TRANSPARENT, 15)
	save.custom_minimum_size = Vector2(150, 48)
	save.pressed.connect(_save_and_back)
	bottom.add_child(save)
	var fight := UI.button("保存并挑战", UI.ACCENT, 17)
	fight.custom_minimum_size = Vector2(190, 48)
	fight.pressed.connect(_save_and_fight)
	bottom.add_child(fight)
	root.add_child(bottom)


func _refresh() -> void:
	UI.clear_children(grid_host)
	UI.clear_children(roster_host)
	count_label.text = "上阵 %d / 5" % placements.size()
	for row in range(3):
		for col in range(2, -1, -1):
			grid_host.add_child(_cell(row, col))
	for entry in GameState.roster:
		roster_host.add_child(_roster_row(entry))


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
	panel.custom_minimum_size = Vector2(194, 124)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_cell_clicked(row, col))
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
		make_click_overlay(panel, func(): _on_cell_clicked(row, col))
		return panel
	var entry := GameState.get_roster_entry(int(placement["uid"]))
	if entry.is_empty():
		return panel
	var p: Dictionary = ContentDB.pet(str(entry["species"]))
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var h := UI.hbox(8)
	panel.add_child(h)
	var av := UI.avatar(str(entry["species"]), 62, int(entry["level"]))
	h.add_child(av)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UI.label(GameState.pet_name(entry), 14, UI.TEXT))
	info.add_child(UI.label("Lv.%d" % int(entry["level"]), 11, UI.MUTED))
	var tags := UI.hbox(4)
	tags.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 9))
	tags.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 9))
	info.add_child(tags)
	info.add_child(UI.label("词条 %d/6" % GameState.total_affixes(entry), 10, UI.FAINT))
	make_click_overlay(panel, func(): _on_cell_clicked(row, col))
	return panel


func _roster_row(entry: Dictionary) -> Control:
	var uid := int(entry["uid"])
	var pid := str(entry["species"])
	var p: Dictionary = ContentDB.pet(pid)
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var deployed := _placement_of(uid)
	var is_selected := uid == selected_uid
	var border := UI.GOLD if is_selected else (Color(0.35, 0.55, 0.45, 0.7) if not deployed.is_empty() else UI.BORDER)
	var panel := UI.panel(Color(0.07, 0.09, 0.14, 0.9), border, 10, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_roster_clicked(uid))
	var h := UI.hbox(8)
	panel.add_child(h)
	var av := UI.avatar(pid, 50, int(entry["level"]))
	h.add_child(av)
	var info := UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var line1 := UI.hbox(6)
	line1.add_child(UI.label(GameState.pet_name(entry), 14, UI.TEXT))
	line1.add_child(UI.label("Lv.%d" % int(entry["level"]), 11, UI.MUTED))
	if int(entry.get("resonance", 0)) > 0:
		line1.add_child(UI.pill("共鸣×%d" % int(entry["resonance"]), UI.PURPLE, 9))
	info.add_child(line1)
	var line2 := UI.hbox(4)
	line2.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 9))
	line2.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 9))
	line2.add_child(UI.label("词条 %d/6" % GameState.total_affixes(entry), 10, UI.FAINT))
	info.add_child(line2)
	var state := UI.pill("已上阵" if not deployed.is_empty() else "待命", UI.GOOD if not deployed.is_empty() else UI.MUTED, 9)
	h.add_child(state)
	make_click_overlay(panel, func(): _on_roster_clicked(uid))
	return panel


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
	tip_label.text = "布阵已更新。"
	_refresh()


func _name_for_uid(uid: int) -> String:
	var e := GameState.get_roster_entry(uid)
	return GameState.pet_name(e) if not e.is_empty() else "精灵"


func _switch_preset(index: int) -> void:
	GameState.save_preset(int(GameState.active_preset), placements)
	GameState.active_preset = index
	var loaded: Array = GameState.load_preset(index)
	selected_uid = -1
	if loaded.is_empty():
		_auto_deploy()
		tip_label.text = "阵型 %d 为空，已按推荐阵型填充。" % (index + 1)
	else:
		placements = loaded
		tip_label.text = "已切换到阵型 %d。" % (index + 1)
		_refresh()


func _auto_deploy() -> void:
	placements.clear()
	selected_uid = -1
	var count := mini(GameState.roster.size(), GameState.MAX_DEPLOY)
	var templates: Dictionary = ContentDB.data["formation"].get("player_templates", {})
	var positions: Array = templates.get(str(count), [])
	for i in range(mini(count, positions.size())):
		placements.append({
			"uid": int(GameState.roster[i]["uid"]),
			"row": int(positions[i][0]),
			"col": int(positions[i][1]),
		})
	tip_label.text = "已按推荐阵型自动布阵。"
	_refresh()


func _save() -> bool:
	if placements.is_empty():
		toast("至少需要上阵一只精灵", UI.DANGER)
		return false
	GameState.save_preset(int(GameState.active_preset), placements)
	return GameState.set_deployment(placements)


func _save_and_back() -> void:
	if _save():
		goto_screen("res://scripts/ui/map_screen.gd")


func _save_and_fight() -> void:
	if _save():
		goto_screen("res://scripts/ui/battle_screen.gd")
