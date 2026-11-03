extends "res://scripts/ui/screen_base.gd"
const SpiritPool = preload("res://scripts/core/spirit_pool.gd")
## Attach a drafted affix to a pet skill, respecting per-skill and per-pet caps.

var candidates: Array = []
var selected_affix_id: String = ""
var selected_uid: int = -1
var step: int = 1
var content_host: VBoxContainer
var next_button: Button
var bag_button: Button
var pet_scroll: ScrollContainer
var pet_rows_host: VBoxContainer
var detail_host: PanelContainer


func _ready() -> void:
	if not GameState.pending_rewards.is_empty():
		candidates = GameState.pending_rewards.get("affix", {}).get("candidates", [])
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.52)
	_build_static()
	_refresh()


func _build_static() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var root := UI.vbox(10)
	margin.add_child(root)

	var top := UI.hbox(12)
	var back := UI.ghost_button("← 返回宝箱", 14)
	back.custom_minimum_size = Vector2(112, 34)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/reward_screen.gd"))
	top.add_child(back)
	top.add_child(UI.label("技能词条", 29, UI.PURPLE))
	top.add_child(UI.pill("三招都能贴 · 每招最多 3 条", UI.PURPLE, 12))
	top.add_child(UI.grow())
	var abandon := UI.ghost_button("放弃本次词条", 13)
	abandon.custom_minimum_size = Vector2(130, 34)
	abandon.pressed.connect(func():
		GameState.skip_affix_reward()
		goto_screen("res://scripts/ui/reward_screen.gd"))
	top.add_child(abandon)
	root.add_child(top)
	root.add_child(UI.label("词条贴在普通、辅助或大招上，不增加灵力。技能效果是培养时另加的，两套不是一回事。", 13, UI.MUTED))

	content_host = UI.vbox(12)
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_host)

	var bottom := UI.hbox(10)
	bottom.add_child(UI.grow())
	bag_button = UI.button("放入背包", UI.GOLD, 17)
	bag_button.custom_minimum_size = Vector2(180, 46)
	bag_button.pressed.connect(_stash)
	bottom.add_child(bag_button)
	next_button = UI.button("下 一 步", UI.PURPLE, 17)
	next_button.custom_minimum_size = Vector2(220, 46)
	next_button.pressed.connect(_go_step_two)
	bottom.add_child(next_button)
	root.add_child(bottom)


func _refresh() -> void:
	UI.clear_children(content_host)
	next_button.visible = step == 1
	bag_button.visible = step == 1
	if step == 1:
		next_button.disabled = selected_affix_id.is_empty()
		bag_button.disabled = selected_affix_id.is_empty()
		_build_step_one()
	else:
		_build_step_two()


func _build_step_one() -> void:
	var head := UI.hbox(10)
	head.add_child(UI.label("第 1 步 · 三选一词条", 19, UI.TEXT))
	head.add_child(UI.grow())
	head.add_child(UI.label("词条稀有度：普通 60% · 稀有 30% · 史诗 10%", 12, UI.FAINT))
	content_host.add_child(head)
	var row := UI.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.add_child(row)
	for a in candidates:
		row.add_child(_affix_choice(a))


func _affix_choice(a: Dictionary) -> Control:
	var aid := str(a["id"])
	var rarity := str(a.get("rarity", "common"))
	var color := ContentDB.rarity_color(rarity)
	var selected := aid == selected_affix_id
	var panel := UI.panel_with(UI.soft_style(Color(0.06, 0.08, 0.12, 0.95), color if selected else UI.BORDER, 2 if selected else 1, 20, 22))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			selected_affix_id = aid
			next_button.disabled = false
			_refresh())
	var v := UI.vbox(12)
	panel.add_child(v)
	var top := UI.hbox(8)
	top.add_child(UI.pill(ContentDB.rarity_name(rarity), color, 11))
	top.add_child(UI.grow())
	top.add_child(UI.label("词条", 11, UI.FAINT))
	v.add_child(top)
	var name_label := UI.label(str(a.get("name", "")), 30, color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	v.add_child(UI.hline(Color(color.r, color.g, color.b, 0.35), 1))
	var desc := UI.label(str(a.get("desc", "")), 15, UI.TEXT, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var grow := UI.grow()
	v.add_child(grow)
	var hint := UI.label("点击选择" if not selected else "✓ 已选择", 13, color if selected else UI.FAINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	make_click_overlay(panel, func():
		selected_affix_id = aid
		next_button.disabled = false
		_refresh())
	return panel


func _stash() -> void:
	if selected_affix_id.is_empty():
		toast("请先选择一条词条", UI.DANGER)
		return
	var a := _selected_affix()
	if not GameState.stash_affix_reward(selected_affix_id):
		toast("无法放入背包", UI.DANGER)
		return
	toast("「%s」已放入词条背包" % str(a.get("name", "")), UI.GOOD)
	await get_tree().create_timer(0.55).timeout
	goto_screen("res://scripts/ui/reward_screen.gd")


func _go_step_two() -> void:
	if selected_affix_id.is_empty():
		toast("请先选择一条词条", UI.DANGER)
		return
	step = 2
	for entry in GameState.roster:
		GameState.ensure_arts(entry)
	var ordered := GameState.roster_for_affix()
	# preselect first eligible pet in rarity order
	if selected_uid < 0:
		for e in ordered:
			var uid := int(e["uid"])
			if GameState.can_attach(uid, "basic")["ok"] or GameState.can_attach(uid, "aid")["ok"] or GameState.can_attach(uid, "ult")["ok"]:
				selected_uid = int(e["uid"])
				break
		if selected_uid < 0 and not ordered.is_empty():
			selected_uid = int(ordered[0]["uid"])
	_refresh()


func _build_step_two() -> void:
	var kept_scroll := 0
	if pet_scroll != null and is_instance_valid(pet_scroll):
		kept_scroll = pet_scroll.scroll_vertical
	var head := UI.hbox(10)
	head.add_child(UI.label("第 2 步 · 选择精灵与技能", 19, UI.TEXT))
	head.add_child(UI.grow())
	var a: Dictionary = _selected_affix()
	head.add_child(UI.pill("已选词条：" + str(a.get("name", "")), ContentDB.rarity_color(str(a.get("rarity", "common"))), 12))
	var back := UI.ghost_button("← 重选词条", 12)
	back.pressed.connect(func():
		step = 1
		_refresh())
	head.add_child(back)
	content_host.add_child(head)

	var body := UI.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.add_child(body)
	var left := UI.panel(Color(0.04, 0.06, 0.10, 0.92), UI.BORDER, 14, 14)
	left.custom_minimum_size = Vector2(470, 0)
	body.add_child(left)
	var lv := UI.vbox(8)
	left.add_child(lv)
	var lh := UI.hbox(8)
	lh.add_child(UI.label("选择精灵", 15, UI.MUTED))
	lh.add_child(UI.label("词条多的在前 · 数量相同按稀有度", 11, UI.FAINT))
	lv.add_child(lh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	pet_scroll = scroll
	var rows := UI.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	pet_rows_host = rows
	for e in GameState.roster_for_affix():
		rows.add_child(_pet_row(e))

	var right := UI.panel(Color(0.04, 0.06, 0.10, 0.92), UI.BORDER, 14, 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	detail_host = right
	_build_pet_detail(right)
	_restore_pet_scroll(kept_scroll)


func _restore_pet_scroll(y: int) -> void:
	if pet_scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if pet_scroll != null and is_instance_valid(pet_scroll):
		pet_scroll.scroll_vertical = y


func _select_pet(uid: int) -> void:
	if selected_uid == uid:
		return
	var kept_scroll := 0
	if pet_scroll != null and is_instance_valid(pet_scroll):
		kept_scroll = pet_scroll.scroll_vertical
	selected_uid = uid
	if pet_rows_host != null and is_instance_valid(pet_rows_host) and detail_host != null and is_instance_valid(detail_host):
		UI.clear_children(pet_rows_host)
		for e in GameState.roster_for_affix():
			pet_rows_host.add_child(_pet_row(e))
		UI.clear_children(detail_host)
		_build_pet_detail(detail_host)
		_restore_pet_scroll(kept_scroll)
	else:
		_refresh()


func _pet_row(entry: Dictionary) -> Control:
	var uid := int(entry["uid"])
	var pid := str(entry["species"])
	var p: Dictionary = ContentDB.pet(pid)
	var rarity := str(p.get("rarity", "common"))
	var rcolor := ContentDB.rarity_color(rarity)
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var total := GameState.total_affixes(entry)
	var uncapped := bool(entry.get("uncapped", false))
	var full := (not uncapped) and total >= GameState.pet_affix_cap(entry)
	var selected := uid == selected_uid
	var border := UI.PURPLE if selected else (UI.DANGER.darkened(0.4) if full else UI.BORDER)
	var panel := UI.panel_with(UI.soft_style(Color(0.07, 0.09, 0.14, 0.92), border, 2 if selected else 1, 10, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_pet(uid))
	var h := UI.hbox(8)
	panel.add_child(h)
	h.add_child(UI.avatar(pid, 46, int(entry["level"])))
	var info := UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var l1 := UI.hbox(5)
	l1.add_child(UI.label(GameState.pet_name(entry), 14, UI.TEXT))
	l1.add_child(UI.label("Lv.%d" % int(entry["level"]), 10, UI.MUTED))
	l1.add_child(UI.pill(ContentDB.rarity_name(rarity), rcolor, 9))
	info.add_child(l1)
	var l2 := UI.hbox(4)
	l2.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 9))
	l2.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 9))
	if uncapped:
		l2.add_child(UI.label("词条 %d · 不封顶" % total, 10, UI.GOLD))
	else:
		l2.add_child(UI.label("词条 %d/%d" % [total, GameState.pet_affix_cap(entry)], 10, UI.DANGER if full else UI.FAINT))
	info.add_child(l2)
	h.add_child(UI.pill("已满" if full else "可附着", UI.DANGER if full else UI.GOOD, 9))
	make_click_overlay(panel, func():
		_select_pet(uid))
	return panel


func _build_pet_detail(host: PanelContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var entry := GameState.get_roster_entry(selected_uid)
	if not entry.is_empty():
		GameState.ensure_arts(entry)
	if entry.is_empty():
		v.add_child(UI.label("请选择一只精灵。", 15, UI.MUTED))
		return
	var pid := str(entry["species"])
	var p: Dictionary = ContentDB.pet(pid)
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var head := UI.hbox(10)
	head.add_child(UI.avatar(pid, 58, int(entry["level"])))
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(UI.label(GameState.pet_name(entry), 21, UI.TEXT))
	info.add_child(UI.label("Lv.%d · %s · %s" % [int(entry["level"]), ContentDB.element_name(str(p.get("element", ""))), ContentDB.class_name_for(str(p.get("class", "")))], 12, UI.MUTED))
	v.add_child(head)
	var total := GameState.total_affixes(entry)
	var uncapped := bool(entry.get("uncapped", false))
	if uncapped:
		v.add_child(UI.label("主宠词条 %d · 无限叠加" % total, 13, UI.GOLD))
	else:
		var cap := GameState.pet_affix_cap(entry)
		v.add_child(UI.label("该精灵词条 %d / %d" % [total, cap], 13, UI.DANGER if total >= cap else UI.GOOD))
	if not uncapped and total >= GameState.pet_affix_cap(entry):
		var warn := UI.panel(Color(0.18, 0.06, 0.09, 0.7), UI.DANGER.darkened(0.2), 10, 12)
		var wv := UI.vbox(6)
		warn.add_child(wv)
		wv.add_child(UI.label("该精灵的词条已满。", 14, UI.DANGER))
		wv.add_child(UI.label("可以替换某个已满技能中的词条，或把这条词条转化为随机道具。", 12, UI.MUTED, true))
		var convert := UI.button("转化为随机道具", UI.PURPLE, 14)
		convert.pressed.connect(_convert_reward)
		wv.add_child(convert)
		v.add_child(warn)
	v.add_child(UI.hline(UI.BORDER, 1))
	for slot in ["basic", "aid", "ult"]:
		v.add_child(_slot_panel(entry, slot))
	var grow := UI.grow()
	v.add_child(grow)
	var back := UI.button("返回宝箱", Color.TRANSPARENT, 14)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/reward_screen.gd"))
	v.add_child(back)


func _art_for(entry: Dictionary, role: String) -> Dictionary:
	for raw in entry.get("arts", []):
		var art: Dictionary = raw
		if str(art.get("role", "")) == role:
			return art
	return {"name": SpiritPool.role_name(role), "effects": ["hit"]}


func _slot_panel(entry: Dictionary, slot: String) -> Control:
	var uid := int(entry["uid"])
	var pid := str(entry["species"])
	var p: Dictionary = ContentDB.pet(pid)
	var skill := _art_for(entry, slot)
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var panel := UI.panel(Color(0.07, 0.09, 0.14, 0.9), UI.BORDER, 12, 12)
	var v := UI.vbox(6)
	panel.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label("词条·" + SpiritPool.role_name(slot) + " · " + str(skill.get("name", "技能")), 15, color))
	head.add_child(UI.grow())
	var list: Array = entry["affixes"].get(slot, [])
	var uncapped := bool(entry.get("uncapped", false))
	if uncapped:
		head.add_child(UI.label("技能词条 %d · 不封顶" % list.size(), 11, UI.GOLD))
	else:
		head.add_child(UI.label("技能词条 %d/3" % list.size(), 11, UI.DANGER if list.size() >= 3 else UI.FAINT))
	v.add_child(head)
	v.add_child(UI.label(SpiritPool.art_text(skill), 12, UI.MUTED, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 5)
	v.add_child(chips)
	if list.is_empty():
		chips.add_child(UI.label("暂无词条", 11, UI.FAINT))
	for aid in list:
		var a: Dictionary = ContentDB.affix(str(aid))
		var tag := UI.pill(str(a.get("name", "")), ContentDB.rarity_color(str(a.get("rarity", "common"))), 10)
		tag.tooltip_text = str(a.get("desc", ""))
		chips.add_child(tag)
	var duplicate := selected_affix_id in list
	var max_slot := int(ContentDB.combat().get("affix_max_per_skill", 3))
	if uncapped or list.size() < max_slot:
		if not uncapped and GameState.total_affixes(entry) >= int(ContentDB.combat().get("affix_max_per_pet", 6)):
			v.add_child(UI.label("精灵词条已满，无法新增；请在已满技能中替换，或转化为道具。", 11, UI.DANGER, true))
		else:
			var attach := UI.button("再叠一层" if duplicate and uncapped else "附着到此技能", UI.PURPLE, 13)
			attach.disabled = duplicate and not uncapped
			if duplicate and not uncapped:
				attach.text = "该技能已有此词条"
			attach.pressed.connect(func(): _try_attach(uid, slot))
			v.add_child(attach)
	else:
		v.add_child(UI.label("该技能已满 3/3，选择一条替换：", 11, UI.FAINT))
		var replace_row := HFlowContainer.new()
		replace_row.add_theme_constant_override("h_separation", 5)
		replace_row.add_theme_constant_override("v_separation", 5)
		for i in range(list.size()):
			var old: Dictionary = ContentDB.affix(str(list[i]))
			var b := UI.ghost_button("替换：「%s」" % str(old.get("name", "")), 11)
			b.pressed.connect(func(): _try_attach(uid, slot, i))
			replace_row.add_child(b)
		v.add_child(replace_row)
	return panel


func _selected_affix() -> Dictionary:
	for a in candidates:
		if str(a.get("id", "")) == selected_affix_id:
			return a
	return {}


func _try_attach(uid: int, slot: String, replace_index: int = -1) -> void:
	var a := _selected_affix()
	if a.is_empty():
		toast("词条数据缺失", UI.DANGER)
		return
	var ok := GameState.claim_affix_reward(uid, slot, selected_affix_id, replace_index)
	if not ok:
		var entry := GameState.get_roster_entry(uid)
		if selected_affix_id in entry["affixes"].get(slot, []):
			toast("同一技能不能重复附着相同词条", UI.DANGER)
		elif GameState.total_affixes(entry) >= int(ContentDB.combat().get("affix_max_per_pet", 6)):
			toast("该精灵词条已满，请替换或转化", UI.DANGER)
		else:
			toast("无法附着该词条", UI.DANGER)
		return
	toast("「%s」已附着到技能上" % str(a.get("name", "")), UI.GOOD)
	await get_tree().create_timer(0.65).timeout
	goto_screen("res://scripts/ui/reward_screen.gd")


func _convert_reward() -> void:
	var it := GameState.convert_affix_reward()
	var msg := "词条已转化为道具" if it.is_empty() else "词条已转化为「%s」" % str(it.get("name", ""))
	toast(msg, UI.GOLD)
	await get_tree().create_timer(0.65).timeout
	goto_screen("res://scripts/ui/reward_screen.gd")
