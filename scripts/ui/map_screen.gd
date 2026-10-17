extends "res://scripts/ui/screen_base.gd"
## Between-floor map: enemy intel, team snapshot and run actions.

var floor_num: int = 1
var f: Dictionary = {}
var enc: Dictionary = {}


func _ready() -> void:
	floor_num = GameState.current_floor
	f = ContentDB.floor(floor_num)
	enc = GameState.encounter
	if enc.is_empty():
		enc = GameState.generate_encounter(floor_num)
	add_background(str(f.get("map", "lava")))
	add_dim(0.38)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var root := UI.vbox(14)
	margin.add_child(root)

	root.add_child(_top_bar())
	var main := UI.hbox(20)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	main.add_child(_enemy_panel())
	main.add_child(_team_panel())
	root.add_child(_bottom_bar())


func _top_bar() -> Control:
	var bar := UI.hbox(12)
	bar.add_child(UI.label(str(f.get("name", "第 %d 层" % floor_num)), 29, UI.TEXT))
	var pips := progress_pips(floor_num)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(pips)
	bar.add_child(UI.grow())
	bar.add_child(UI.pill("种子 #%d" % GameState.run_seed, UI.MUTED, 12))
	bar.add_child(UI.pill(str(GameState.trainer.get("name", "")), UI.GOLD, 12))
	bar.add_child(UI.pill("图鉴 %d / 50" % GameState.owned_species.size(), UI.BLUE, 12))
	var details := UI.ghost_button("队伍详情", 14)
	details.custom_minimum_size = Vector2(100, 34)
	details.pressed.connect(_show_team_details)
	bar.add_child(details)
	var abandon := UI.ghost_button("放弃远征", 14)
	abandon.custom_minimum_size = Vector2(100, 34)
	abandon.pressed.connect(_confirm_abandon)
	bar.add_child(abandon)
	return bar


func _enemy_panel() -> Control:
	var panel := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 18, 18)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(10)
	panel.add_child(v)

	var head := UI.hbox(10)
	head.add_child(UI.label("前方敌情", 20, UI.ACCENT))
	var is_boss := str(f.get("kind", "normal")) == "boss"
	if is_boss:
		head.add_child(UI.pill("首领层", UI.GOLD, 12))
	else:
		head.add_child(UI.pill("普通层", UI.MUTED, 12))
	head.add_child(UI.grow())
	var enemies: Array = enc.get("enemies", [])
	head.add_child(UI.label("等级 %d · %d 名敌人" % [int(f.get("level", 10)), enemies.size()], 13, UI.MUTED))
	v.add_child(head)

	if is_boss:
		var boss_name := ""
		var buff_names: Array = []
		for bid in enc.get("boss_buffs", []):
			var b: Dictionary = ContentDB.boss_buff(str(bid))
			if not b.is_empty():
				buff_names.append(str(b["name"]))
		for e in enemies:
			if bool(e.get("is_boss", false)):
				boss_name = str(e["name"])
		var boss_row := UI.hbox(8)
		boss_row.add_child(UI.label("首领：" + boss_name, 15, UI.GOLD))
		for bn in buff_names:
			boss_row.add_child(UI.pill("增益 · " + str(bn), UI.DANGER, 11))
		boss_row.add_child(UI.grow())
		boss_row.add_child(UI.label("大 Boss 在 70% / 40% 生命进入新阶段" if floor_num == 10 else "小 Boss 携带 1 条随机增益", 12, UI.FAINT))
		v.add_child(boss_row)
	else:
		var rule := "敌人从本层精灵池按属性与职业抽取。"
		if floor_num <= 4:
			rule += " 本层敌人数量：%d。" % enemies.size()
		v.add_child(UI.label(rule, 12, UI.FAINT))

	var grid_wrap := CenterContainer.new()
	grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid_wrap)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid_wrap.add_child(grid)
	for e in enemies:
		grid.add_child(_enemy_card(e))

	var reward_hint := UI.hbox(8)
	reward_hint.add_child(UI.pill("宝箱：精灵 100%", UI.GOOD, 11))
	reward_hint.add_child(UI.pill("道具 50%", UI.BLUE, 11))
	reward_hint.add_child(UI.pill("技能词条 25%", UI.PURPLE, 11))
	reward_hint.add_child(UI.grow())
	if floor_num >= 10:
		reward_hint.add_child(UI.label("塔顶：击败星蚀龙皇即可登顶", 12, UI.GOLD))
	v.add_child(reward_hint)
	return panel


func _enemy_card(e: Dictionary) -> Control:
	var is_boss := bool(e.get("is_boss", false))
	var element := str(e.get("element", "fire"))
	var color := ContentDB.element_color(element)
	var card := UI.panel(Color(0.06, 0.08, 0.13, 0.92), UI.GOLD if is_boss else UI.BORDER, 12, 10)
	card.custom_minimum_size = Vector2(208, 106 if not is_boss else 128)
	var h := UI.hbox(8)
	card.add_child(h)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(60, 0)
	h.add_child(holder)
	var av: Control
	if is_boss:
		var boss_data: Dictionary = ContentDB.boss(str(e.get("species", "")))
		if boss_data.is_empty():
			av = UI.avatar("p01", 60, int(e.get("level", 10)), false, true)
		else:
			var a_script = preload("res://scripts/ui/pet_avatar.gd")
			av = a_script.new()
			av.setup_boss(boss_data, 64)
	else:
		av = UI.avatar(str(e.get("species", "p01")), 58, int(e.get("level", 10)), false, true)
	holder.add_child(av)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var name_text := str(e.get("name", "?"))
	var nm := UI.label(name_text, 15 if is_boss else 14, UI.GOLD if is_boss else UI.TEXT)
	info.add_child(nm)
	info.add_child(UI.label("Lv.%d" % int(e.get("level", 1)), 12, UI.MUTED))
	var tags := UI.hbox(4)
	tags.add_child(UI.pill(ContentDB.element_name(element), color, 10))
	tags.add_child(UI.pill(ContentDB.class_name_for(str(e.get("class", ""))), ContentDB.class_color(str(e.get("class", ""))), 10))
	info.add_child(tags)
	if is_boss:
		info.add_child(UI.label("首领 · 强力增益", 11, UI.DANGER))
	return card


func _team_panel() -> Control:
	var panel := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 18, 18)
	panel.custom_minimum_size = Vector2(452, 0)
	var v := UI.vbox(8)
	panel.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label("我方队伍", 20, UI.GOOD))
	head.add_child(UI.pill("上阵 %d / 5" % GameState.deployed.size(), UI.GOOD, 11))
	head.add_child(UI.grow())
	var adjust := UI.ghost_button("调整阵型", 13)
	adjust.custom_minimum_size = Vector2(96, 30)
	adjust.pressed.connect(func(): goto_screen("res://scripts/ui/formation_screen.gd"))
	head.add_child(adjust)
	v.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rows := UI.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for d in GameState.deployed:
		var entry := GameState.get_roster_entry(int(d["uid"]))
		if entry.is_empty():
			continue
		rows.add_child(_team_row(entry, int(d["row"]), int(d["col"])))

	if GameState.roster.size() > GameState.deployed.size():
		rows.add_child(UI.label("仓库中还有 %d 只精灵待命" % (GameState.roster.size() - GameState.deployed.size()), 12, UI.FAINT))

	var items_head := UI.hbox(8)
	items_head.add_child(UI.label("行囊", 14, UI.GOLD))
	items_head.add_child(UI.label("%d 件道具" % GameState.items.size(), 12, UI.MUTED))
	items_head.add_child(UI.grow())
	items_head.add_child(UI.label("词条 %d 条" % _total_affixes(), 12, UI.PURPLE))
	v.add_child(UI.hline(UI.BORDER, 1))
	v.add_child(items_head)
	var item_flow := HFlowContainer.new()
	item_flow.add_theme_constant_override("h_separation", 6)
	item_flow.add_theme_constant_override("v_separation", 6)
	v.add_child(item_flow)
	var counts := GameState.item_counts()
	var shown := 0
	for iid in counts.keys():
		var item: Dictionary = ContentDB.item(str(iid))
		if item.is_empty():
			continue
		var suffix := " ×%d" % int(counts[iid]) if int(counts[iid]) > 1 else ""
		var tag := UI.pill(str(item["name"]) + suffix, ContentDB.rarity_color(str(item.get("rarity", "common"))), 10)
		tag.tooltip_text = str(item.get("desc", ""))
		item_flow.add_child(tag)
		shown += 1
		if shown >= 8:
			break
	if counts.is_empty():
		item_flow.add_child(UI.label("还没有道具，宝箱里有机会获得。", 12, UI.FAINT))
	return panel


func _team_row(entry: Dictionary, row: int, col: int) -> Control:
	var pid := str(entry["species"])
	var p: Dictionary = ContentDB.pet(pid)
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var row_panel := UI.panel(Color(0.07, 0.09, 0.14, 0.85), UI.BORDER, 10, 8)
	var h := UI.hbox(8)
	row_panel.add_child(h)
	var av := UI.avatar(pid, 46, int(entry["level"]))
	av.custom_minimum_size = Vector2(46, 46)
	h.add_child(av)
	var info := UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var line1 := UI.hbox(6)
	line1.add_child(UI.label(GameState.pet_name(entry), 14, UI.TEXT))
	line1.add_child(UI.label("Lv.%d" % int(entry["level"]), 11, UI.MUTED))
	if int(entry.get("resonance", 0)) > 0:
		line1.add_child(UI.pill("共鸣 ×%d" % int(entry["resonance"]), UI.PURPLE, 10))
	info.add_child(line1)
	var line2 := UI.hbox(5)
	line2.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 9))
	line2.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 9))
	line2.add_child(UI.label("词条 %d/6" % GameState.total_affixes(entry), 10, UI.FAINT))
	info.add_child(line2)
	var pos := UI.vbox(0)
	var pos_name: String = ["前排", "中排", "后排"][col]
	pos.add_child(UI.label(pos_name, 11, UI.GOLD if col == 0 else UI.MUTED))
	pos.add_child(UI.label("第%d位" % (row + 1), 10, UI.FAINT))
	h.add_child(pos)
	return row_panel


func _bottom_bar() -> Control:
	var bar := UI.hbox(12)
	var info := UI.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	var is_boss := str(f.get("kind", "normal")) == "boss"
	var line1 := ""
	if is_boss:
		var boss_title := "星蚀龙皇" if floor_num == 10 else "小 Boss"
		line1 = "首领战：%s + 4 只随从" % boss_title
	else:
		line1 = "普通战：%d 名敌人" % int(f.get("enemy_count", 1))
	info.add_child(UI.label(line1, 14, UI.TEXT))
	var line2 := "每层胜利后全员等级 +10。当前队伍等级 Lv.%d。" % GameState.party_level()
	info.add_child(UI.label(line2, 12, UI.MUTED))
	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var formation := UI.button("调整阵型", Color.TRANSPARENT, 15)
	formation.custom_minimum_size = Vector2(132, 50)
	formation.pressed.connect(func(): goto_screen("res://scripts/ui/formation_screen.gd"))
	buttons.add_child(formation)
	var fight := UI.button("挑战本层" if floor_num < 10 else "挑战塔顶", UI.ACCENT, 19)
	fight.custom_minimum_size = Vector2(236, 50)
	fight.pressed.connect(_start_battle)
	buttons.add_child(fight)
	bar.add_child(buttons)
	return bar


func _start_battle() -> void:
	if GameState.deployed.is_empty():
		toast("至少需要上阵一只精灵", UI.DANGER)
		return
	goto_screen("res://scripts/ui/battle_screen.gd")


func _total_affixes() -> int:
	var total := 0
	for e in GameState.roster:
		total += GameState.total_affixes(e)
	return total


func _show_team_details() -> void:
	var body := UI.vbox(10)
	body.custom_minimum_size.x = 760
	for entry in GameState.roster:
		var pid := str(entry["species"])
		var p: Dictionary = ContentDB.pet(pid)
		var color := ContentDB.element_color(str(p.get("element", "fire")))
		var card := UI.panel(Color(0.06, 0.08, 0.12, 0.95), UI.BORDER, 12, 12)
		var h := UI.hbox(12)
		card.add_child(h)
		var av := UI.avatar(pid, 62, int(entry["level"]))
		h.add_child(av)
		var info := UI.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var top := UI.hbox(8)
		top.add_child(UI.label(GameState.pet_name(entry), 18, UI.TEXT))
		top.add_child(UI.label("Lv.%d" % int(entry["level"]), 13, UI.MUTED))
		top.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 10))
		top.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 10))
		if int(entry.get("resonance", 0)) > 0:
			top.add_child(UI.pill("共鸣 ×%d（全属性 +%d%%）" % [int(entry["resonance"]), int(entry["resonance"]) * 8], UI.PURPLE, 10))
		info.add_child(top)
		var st: Dictionary = GameState.effective_stats(entry)
		info.add_child(UI.label("生命 %s   攻击 %s   防御 %s   速度 %s" % [
			ContentDB.fmt(int(st["hp"])), ContentDB.fmt(int(st["atk"])),
			ContentDB.fmt(int(st["def"])), ContentDB.fmt(int(st["spd"]))], 12, UI.MUTED))
		for slot in ["normal", "ultimate"]:
			var skill: Dictionary = p["skills"][slot]
			var line := UI.hbox(6)
			line.add_child(UI.label(("普攻" if slot == "normal" else "大招") + " · " + str(skill["name"]), 12, UI.TEXT))
			var list: Array = entry["affixes"].get(slot, [])
			if list.is_empty():
				line.add_child(UI.label("无词条", 11, UI.FAINT))
			for aid in list:
				var a: Dictionary = ContentDB.affix(str(aid))
				var tag := UI.pill(str(a["name"]), ContentDB.rarity_color(str(a.get("rarity", "common"))), 10)
				tag.tooltip_text = str(a.get("desc", ""))
				line.add_child(tag)
			info.add_child(line)
		body.add_child(card)
	show_modal("队伍详情", body, 820, 460)


func _confirm_abandon() -> void:
	var body := UI.vbox(12)
	body.add_child(UI.label("放弃本次远征？当前进度与战利品都会丢失。", 15, UI.MUTED, true))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var overlay_holder: Array = [null]
	var keep := UI.button("继续爬塔", Color.TRANSPARENT, 15)
	keep.pressed.connect(func():
		if overlay_holder[0] != null:
			overlay_holder[0].queue_free())
	row.add_child(keep)
	var quit := UI.button("放弃远征", UI.DANGER, 15)
	quit.pressed.connect(func():
		if overlay_holder[0] != null:
			overlay_holder[0].queue_free()
		GameState.end_run_defeat()
		goto_screen("res://scripts/ui/title_screen.gd"))
	row.add_child(quit)
	body.add_child(row)
	overlay_holder[0] = show_modal("确认放弃", body, 520, 190)
