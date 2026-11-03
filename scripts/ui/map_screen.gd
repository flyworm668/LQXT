extends "res://scripts/ui/screen_base.gd"
const PetDetailScript = preload("res://scripts/ui/pet_detail.gd")
const SpiritPool = preload("res://scripts/core/spirit_pool.gd")
const TypeChartScript = preload("res://scripts/ui/type_chart.gd")
## Between-floor map: enemy intel, team snapshot and run actions.

var floor_num: int = 1
var f: Dictionary = {}
var enc: Dictionary = {}


func _ready() -> void:
	GameState.note_screen("map")
	floor_num = GameState.current_floor
	var where := GameState.destination_after_floor()
	if where == "route":
		goto_screen("res://scripts/ui/route_screen.gd")
		return
	if where == "event":
		goto_screen("res://scripts/ui/event_screen.gd")
		return
	if GameState.run_mode == "conquest":
		if GameState.encounter.is_empty():
			GameState.generate_conquest_encounter()
		enc = GameState.encounter
		f = ContentDB.floor(mini(maxi(floor_num, 1), ContentDB.total_floors())).duplicate(true)
		f["name"] = str(enc.get("name", "第 %d 层" % floor_num))
		f["kind"] = str(enc.get("kind", "normal"))
		f["level"] = int(enc.get("level", f.get("level", 10)))
		var kids: Array = enc.get("king_ids", [])
		f["boss"] = str(kids[0]) if not kids.is_empty() else ""
	else:
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
	var bar := UI.hbox(8)
	var title := UI.label(str(f.get("name", "第 %d 层" % floor_num)), 26, UI.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(title)
	if GameState.run_mode == "conquest":
		bar.add_child(UI.pill("征服战", UI.GOLD, 12))
	bar.add_child(UI.pill("种子 #%d" % GameState.run_seed, UI.MUTED, 12))
	bar.add_child(UI.pill(str(GameState.trainer.get("name", "")), UI.GOLD, 12))
	bar.add_child(UI.pill("图鉴 %d / %d" % [GameState.owned_species.size(), ContentDB.pets_by_id.size()], UI.BLUE, 12))
	bar.add_child(UI.pill("金币 %d" % GameState.gold, UI.GOLD, 12))
	var bag := UI.ghost_button("词条背包", 13)
	bag.custom_minimum_size = Vector2(88, 34)
	bag.pressed.connect(_show_affix_bag)
	bar.add_child(bag)
	var details := UI.ghost_button("队伍详情", 13)
	details.custom_minimum_size = Vector2(88, 34)
	details.pressed.connect(_show_team_details)
	bar.add_child(details)
	var menu := UI.ghost_button("菜单", 14)
	menu.custom_minimum_size = Vector2(72, 34)
	menu.pressed.connect(open_run_menu)
	bar.add_child(menu)
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
	if bool(enc.get("curse", false)):
		head.add_child(UI.pill("精英试炼 · 敌人 +25%", UI.DANGER, 12))
	if int(f.get("minion_affix_count", 0)) > 0:
		head.add_child(UI.pill("敌方词条 ×%d" % int(f.get("minion_affix_count", 0)), UI.PURPLE, 11))
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
		var phase_count := 0
		for e in enemies:
			if bool(e.get("is_boss", false)):
				boss_name = str(e["name"])
				phase_count = (e.get("phases", []) as Array).size()
		var boss_row := UI.hbox(8)
		boss_row.add_child(UI.label("首领：" + boss_name, 15, UI.GOLD))
		for bn in buff_names:
			boss_row.add_child(UI.pill("增益 · " + str(bn), UI.DANGER, 11))
		boss_row.add_child(UI.grow())
		var phase_hint := "%d 个阶段：血量阈值时回满气势并获得护盾" % phase_count if phase_count > 0 else "无阶段增益"
		boss_row.add_child(UI.label(phase_hint, 12, UI.FAINT))
		v.add_child(boss_row)
	else:
		var rule := "敌人从本层精灵池按属性与职业抽取。"
		if int(f.get("minion_affix_count", 0)) > 0:
			rule += " 随层数成长，敌人会携带技能词条。"
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
	reward_hint.add_child(UI.pill("道具 100%", UI.BLUE, 11))
	reward_hint.add_child(UI.pill("词条 100%", UI.PURPLE, 11))
	reward_hint.add_child(UI.pill("英雄 5%", Color(1.0, 0.85, 0.45), 11))
	reward_hint.add_child(UI.grow())
	if GameState.run_won:
		reward_hint.add_child(UI.label("本层打赢即可结束远征", 12, UI.GOLD))
	elif int(GameState.blade_trial_floor) == floor_num:
		reward_hint.add_child(UI.label("本层是圣剑试炼", 12, UI.GOLD))
	elif GameState.is_route_floor(floor_num + 1):
		reward_hint.add_child(UI.label("下一层要选择道路", 12, UI.ACCENT))
	elif GameState.is_event_floor(floor_num + 1):
		reward_hint.add_child(UI.label("下一层是奇遇关", 12, UI.ACCENT))
	elif GameState.run_mode != "conquest" and floor_num >= ContentDB.total_floors():
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
	var nm := UI.label(name_text, 14 if is_boss else 13, UI.GOLD if is_boss else UI.TEXT, true)
	nm.custom_minimum_size = Vector2(96, 0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(nm)
	info.add_child(UI.label("Lv.%d" % int(e.get("level", 1)), 12, UI.MUTED))
	var tags := UI.hbox(4)
	tags.add_child(UI.pill(ContentDB.element_name(element), color, 10))
	tags.add_child(UI.pill(ContentDB.class_name_for(str(e.get("class", ""))), ContentDB.class_color(str(e.get("class", ""))), 10))
	info.add_child(tags)
	if is_boss:
		info.add_child(UI.label("首领 · 强力增益", 11, UI.DANGER))
	elif bool(e.get("curse", false)):
		info.add_child(UI.label("精英强化 · +25%", 11, UI.DANGER))
	elif int(f.get("minion_affix_count", 0)) > 0:
		info.add_child(UI.label("技能词条 ×%d" % int(f.get("minion_affix_count", 0)), 11, UI.PURPLE))
	make_click_overlay(card, func(): PetDetailScript.open_unit(self, e))
	return card


func _team_panel() -> Control:
	var panel := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 18, 18)
	panel.custom_minimum_size = Vector2(452, 0)
	var v := UI.vbox(8)
	panel.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label("我方队伍", 20, UI.GOOD))
	head.add_child(UI.pill("上阵 %d / 6" % GameState.deployed.size(), UI.GOOD, 11))
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

	if GameState.deployed.is_empty():
		rows.add_child(UI.label("尚未布阵。点击「调整阵型」把精灵放入九宫格。", 13, UI.DANGER, true))
	elif GameState.roster.size() > GameState.deployed.size():
		rows.add_child(UI.label("仓库中还有 %d 只精灵待命" % (GameState.roster.size() - GameState.deployed.size()), 12, UI.FAINT))

	var resonance_list: Array = GameState.resonance_records()
	if not resonance_list.is_empty():
		var res_row := UI.hbox(6)
		res_row.add_child(UI.label("元素共鸣", 12, UI.GOLD))
		for r in resonance_list:
			var mods_text: Array = []
			for key in (r["tier"].get("mods", {}) as Dictionary).keys():
				var mod_value := float(r["tier"]["mods"][key])
				mods_text.append("%s+%d%%" % [{"hp": "生命", "atk": "攻击", "def": "防御", "spd": "速度", "crit": "暴击"}.get(key, key), int(round(mod_value * 100.0))])
			var tag := UI.pill("%s ×%d · %s" % [str(r["name"]), int(r["count"]), " ".join(mods_text)],
				Color(str(r["color"])), 10)
			res_row.add_child(tag)
		res_row.add_child(UI.grow())
		v.add_child(res_row)

	var items_head := UI.hbox(8)
	items_head.add_child(UI.label("行囊", 14, UI.GOLD))
	items_head.add_child(UI.label("%d 件未携带" % GameState.items.size(), 12, UI.MUTED))
	items_head.add_child(UI.grow())
	items_head.add_child(UI.label("词条 %d 条" % _total_affixes(), 12, UI.PURPLE))
	v.add_child(UI.hline(UI.BORDER, 1))
	v.add_child(items_head)
	var item_flow := HFlowContainer.new()
	item_flow.add_theme_constant_override("h_separation", 6)
	item_flow.add_theme_constant_override("v_separation", 6)
	v.add_child(item_flow)
	var shown := 0
	var bag_seen := {}
	for iid in GameState.items:
		if bag_seen.has(iid):
			continue
		bag_seen[iid] = true
		var item: Dictionary = ContentDB.item(str(iid))
		if item.is_empty():
			continue
		var count := 0
		for one in GameState.items:
			if str(one) == str(iid):
				count += 1
		var suffix := " ×%d" % count if count > 1 else ""
		var tag := UI.button(str(item["name"]) + suffix + " · 携带", ContentDB.rarity_color(str(item.get("rarity", "common"))), 11)
		tag.tooltip_text = str(item.get("desc", ""))
		tag.pressed.connect(_pick_carry_target.bind(str(iid)))
		item_flow.add_child(tag)
		shown += 1
		if shown >= 8:
			break
	if GameState.items.is_empty():
		item_flow.add_child(UI.label("行囊是空的。获得道具后点「携带」，交给一只精灵。每只最多 3 件，无限不限。", 12, UI.FAINT, true))
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
	if bool(entry.get("hero", false)):
		line1.add_child(UI.pill("英雄 %d★" % int(entry.get("hero_star", 0)), Color(1.0, 0.85, 0.45), 10))
	if int(entry.get("resonance", 0)) > 0:
		line1.add_child(UI.pill("共鸣 ×%d" % int(entry["resonance"]), UI.PURPLE, 10))
	info.add_child(line1)
	var line2 := UI.hbox(5)
	line2.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 9))
	line2.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 9))
	var cap_text := "不封顶" if bool(entry.get("uncapped", false)) else str(GameState.pet_affix_cap(entry))
	line2.add_child(UI.label("词条 %d/%s" % [GameState.total_affixes(entry), cap_text], 10, UI.FAINT))
	info.add_child(line2)
	var pos := UI.vbox(0)
	var pos_name: String = ["前排", "中排", "后排"][col]
	pos.add_child(UI.label(pos_name, 11, UI.GOLD if col == 0 else UI.MUTED))
	pos.add_child(UI.label("第%d位" % (row + 1), 10, UI.FAINT))
	h.add_child(pos)
	var detail := UI.ghost_button("详情", 12)
	detail.custom_minimum_size = Vector2(52, 28)
	detail.pressed.connect(func(): PetDetailScript.open_roster(self, entry))
	h.add_child(detail)
	return row_panel


func _bottom_bar() -> Control:
	var bar := UI.hbox(12)
	var info := UI.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	var is_boss := str(f.get("kind", "normal")) == "boss"
	var line1 := ""
	var boss_name := ""
	for e in enc.get("enemies", []):
		if bool(e.get("is_boss", false)):
			boss_name = str(e.get("name", ""))
	if GameState.run_mode == "conquest" and not (enc.get("king_ids", []) as Array).is_empty():
		line1 = "关底魔王：%d 位魔王" % (enc.get("king_ids", []) as Array).size()
	elif is_boss:
		line1 = "首领战：%s + %d 只随从" % [boss_name, maxi(0, enc.get("enemies", []).size() - 1)]
	else:
		line1 = "普通战：%d 名敌人" % enc.get("enemies", []).size()
	var line1_label := UI.label(line1, 14, UI.TEXT)
	line1_label.clip_text = true
	line1_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(line1_label)
	var line2 := "每层胜利后全员等级 +%d。当前队伍等级 Lv.%d。" % [GameState._growth_step(), GameState.party_level()]
	if not GameState.curse_floors.is_empty() and GameState.curse_floors.has(floor_num):
		line2 += " 本层为精英试炼。"
	var line2_label := UI.label(line2, 12, UI.MUTED)
	line2_label.clip_text = true
	line2_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(line2_label)
	var king_note := _king_warning()
	if not king_note.is_empty():
		info.add_child(UI.label(king_note, 12, UI.DANGER))
	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var chart := UI.ghost_button("属性克制", 14)
	chart.custom_minimum_size = Vector2(110, 50)
	chart.pressed.connect(func(): TypeChartScript.open(self))
	buttons.add_child(chart)
	var train := UI.button("精灵培养", Color.TRANSPARENT, 15)
	train.custom_minimum_size = Vector2(132, 50)
	train.pressed.connect(_open_train)
	buttons.add_child(train)
	var formation := UI.button("调整阵型", Color.TRANSPARENT, 15)
	formation.custom_minimum_size = Vector2(132, 50)
	formation.pressed.connect(func(): goto_screen("res://scripts/ui/formation_screen.gd"))
	buttons.add_child(formation)
	var fight_label := "请先布阵"
	if not GameState.deployed.is_empty():
		fight_label = "开战"
	var fight := UI.button(fight_label, UI.ACCENT, 18)
	fight.custom_minimum_size = Vector2(168, 50)
	fight.pressed.connect(_start_battle)
	buttons.add_child(fight)
	bar.add_child(buttons)
	return bar


func _king_warning() -> String:
	var here: Dictionary = ContentDB.boss(str(f.get("boss", "")))
	var king_here := bool(here.get("demon_king", false)) or not (enc.get("king_ids", []) as Array).is_empty()
	if king_here:
		if GameState.deployed_breaker():
			return "魔王有无敌屏障。英雄、魔人或破魔圣剑打中一次后破碎，这一下不造成伤害。"
		if GameState.owns_breaker():
			return "魔王有无敌屏障，但能打破它的精灵还没上阵。"
		if GameState.holds_sword():
			return "破魔圣剑还在背包里。先让一只精灵携带，再开战。"
		return "魔王有无敌屏障。没有英雄、魔人或破魔圣剑，这一层打不穿。"
	var nxt := GameState.next_king_floor()
	if nxt == floor_num + 1:
		if GameState.run_mode == "conquest":
			return "下一层是关底魔王。"
		if not GameState.owns_breaker() and not GameState.holds_sword():
			return "下一层是魔王。先在奇遇里接受圣剑试炼，打赢后让一只精灵携带破魔圣剑。"
	return ""


func _start_battle() -> void:
	if GameState.deployed.is_empty():
		toast("请先布阵：从仓库选择精灵放入九宫格", UI.DANGER)
		goto_screen("res://scripts/ui/formation_screen.gd")
		return
	goto_screen("res://scripts/ui/battle_screen.gd")


func _total_affixes() -> int:
	var total := 0
	for e in GameState.roster:
		total += GameState.total_affixes(e)
	return total


var team_scroll: ScrollContainer
var team_overlay: Control


func _show_team_details() -> void:
	var kept_scroll := 0
	if team_scroll != null and is_instance_valid(team_scroll):
		kept_scroll = team_scroll.scroll_vertical
	if team_overlay != null and is_instance_valid(team_overlay):
		team_overlay.queue_free()
		team_overlay = null
		team_scroll = null
	var body := UI.vbox(10)
	body.custom_minimum_size.x = 760
	body.add_child(UI.label("按稀有度排列。同一稀有度保持获得顺序，升星不会换位。", 12, UI.MUTED))
	for entry in GameState.roster_view():
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
		var max_lv := GameState.pet_max_level(entry)
		var lv_str := ("Lv.%d（主宠·无上限）" % int(entry["level"])) if bool(entry.get("uncapped", false)) else ("Lv.%d / %d" % [int(entry["level"]), max_lv])
		top.add_child(UI.label(lv_str, 13, UI.GOLD if bool(entry.get("uncapped", false)) else UI.MUTED))
		top.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 10))
		top.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 10))
		if bool(entry.get("hero", false)):
			top.add_child(UI.pill("英雄 %d★" % int(entry.get("hero_star", 0)), Color(1.0, 0.85, 0.45), 10))
		if int(entry.get("resonance", 0)) > 0:
			top.add_child(UI.pill("共鸣 ×%d（全属性 +%d%%）" % [int(entry["resonance"]), int(entry["resonance"]) * 8], UI.PURPLE, 10))
		info.add_child(top)
		var st: Dictionary = GameState.effective_stats(entry)
		var carried: Array = entry.get("carried", [])
		var carry_line := UI.hbox(6)
		var cap := GameState.carry_cap(entry)
		carry_line.add_child(UI.label("携带 %d%s" % [carried.size(), "" if cap == 0 else (" / %d" % cap)], 12, UI.GOLD))
		if carried.is_empty():
			carry_line.add_child(UI.label("没有道具", 11, UI.FAINT))
		for i in range(carried.size()):
			var it: Dictionary = ContentDB.item(str(carried[i]))
			var drop := UI.button(str(it.get("name", carried[i])) + " · 卸下", ContentDB.rarity_color(str(it.get("rarity", "common"))), 11)
			drop.tooltip_text = str(it.get("desc", ""))
			drop.pressed.connect(_unequip_at.bind(int(entry["uid"]), i))
			carry_line.add_child(drop)
		info.add_child(carry_line)
		info.add_child(UI.label("生命 %s   攻击 %s   防御 %s   速度 %s" % [
			ContentDB.fmt(int(st["hp"])), ContentDB.fmt(int(st["atk"])),
			ContentDB.fmt(int(st["def"])), ContentDB.fmt(int(st["spd"]))], 12, UI.MUTED))
		GameState.ensure_arts(entry)
		for slot in ["basic", "aid", "ult"]:
			var skill := _art_named(entry, slot)
			var line := UI.hbox(6)
			line.add_child(UI.label("词条·" + SpiritPool.role_name(slot) + " · " + skill, 12, UI.TEXT))
			var list: Array = entry["affixes"].get(slot, [])
			if list.is_empty():
				line.add_child(UI.label("无词条", 11, UI.FAINT))
			for aid in list:
				var a: Dictionary = ContentDB.affix(str(aid))
				var tag := UI.pill(str(a["name"]), ContentDB.rarity_color(str(a.get("rarity", "common"))), 10)
				tag.tooltip_text = str(a.get("desc", ""))
				line.add_child(tag)
			info.add_child(line)
		if bool(entry.get("hero", false)):
			var up := UI.hbox(8)
			var star := int(entry.get("hero_star", 0))
			var max_star := ContentDB.hero_max_star()
			up.add_child(UI.label("英雄觉醒 %d / %d 星 · 每星全属性 +%d%%" % [
				star, max_star, int(round(float(ContentDB.combat().get("hero_star_bonus", 0.06)) * 100.0))], 12, Color(1.0, 0.85, 0.45)))
			var check := GameState.can_upgrade_hero(int(entry["uid"]))
			var up_btn := UI.button("升星（消耗 1 道具）", Color(1.0, 0.8, 0.36), 12)
			up_btn.custom_minimum_size = Vector2(170, 30)
			up_btn.disabled = not bool(check["ok"])
			up_btn.tooltip_text = str(check["reason"])
			var target_uid := int(entry["uid"])
			up_btn.pressed.connect(func():
				var res := GameState.upgrade_hero(target_uid)
				if bool(res.get("ok", false)):
					toast("升星成功 → %d★" % int(res.get("star", 0)), UI.GOLD)
					_show_team_details()
				else:
					toast(str(res.get("reason", "无法升星")), UI.DANGER))
			up.add_child(up_btn)
			info.add_child(up)
		body.add_child(card)
	var overlay := show_modal("队伍详情", body, 820, 460)
	team_overlay = overlay
	team_scroll = _find_scroll(overlay)
	_restore_team_scroll(kept_scroll)


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


func _restore_team_scroll(y: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if team_scroll != null and is_instance_valid(team_scroll):
		team_scroll.scroll_vertical = y


func _show_affix_bag() -> void:
	var body := UI.vbox(8)
	body.custom_minimum_size = Vector2(560, 0)
	if GameState.affix_bag.is_empty():
		body.add_child(UI.label("背包是空的。圣剑试炼、开局的无限和天命会放在这里。", 14, UI.MUTED, true))
		show_modal("词条背包", body, 620, 180)
		return
	for aid in GameState.affix_bag:
		var affix: Dictionary = ContentDB.affix(str(aid))
		var row := UI.hbox(8)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(str(affix.get("name", aid)), 16, UI.GOLD))
		var desc := UI.label(str(affix.get("desc", "")), 12, UI.MUTED, true)
		desc.custom_minimum_size = Vector2(360, 32)
		info.add_child(desc)
		row.add_child(info)
		var give := UI.button("赋予", UI.ACCENT, 14)
		give.custom_minimum_size = Vector2(88, 40)
		give.pressed.connect(_pick_bag_target.bind(str(aid)))
		row.add_child(give)
		body.add_child(row)
	show_modal("词条背包", body, 640, 420)


func _pick_carry_target(iid: String) -> void:
	var body := UI.vbox(6)
	body.custom_minimum_size = Vector2(560, 0)
	var item: Dictionary = ContentDB.item(iid)
	body.add_child(UI.label(str(item.get("desc", "")), 13, UI.MUTED, true))
	var carry_rows: Array = []
	var order := 0
	for entry in GameState.roster_view():
		carry_rows.append({"entry": entry, "order": order, "count": (entry.get("carried", []) as Array).size()})
		order += 1
	carry_rows.sort_custom(func(a, b):
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return int(a["order"]) < int(b["order"]))
	for row_info in carry_rows:
		var entry: Dictionary = row_info["entry"]
		var uid := int(entry["uid"])
		var carried: Array = entry.get("carried", [])
		var cap := GameState.carry_cap(entry)
		var ok := cap == 0 or carried.size() < cap
		var row := UI.hbox(8)
		var cap_text := "不限" if cap == 0 else ("%d/%d" % [carried.size(), cap])
		row.add_child(UI.label("%s · %s" % [GameState.pet_name(entry), cap_text], 15, UI.TEXT))
		row.add_child(UI.grow())
		var b := UI.button("携带" if ok else "已满", UI.GOLD if ok else UI.MUTED, 13)
		b.custom_minimum_size = Vector2(88, 34)
		b.disabled = not ok
		b.pressed.connect(_give_carry.bind(uid, iid))
		row.add_child(b)
		body.add_child(row)
	show_modal("交给哪只精灵", body, 640, 420)


func _give_carry(uid: int, iid: String) -> void:
	var msg := GameState.carry_item(uid, iid)
	close_modals()
	call_deferred("_refresh_after", msg)


func _unequip_at(uid: int, index: int) -> void:
	var msg := GameState.unequip_item(uid, index)
	close_modals()
	call_deferred("_refresh_after", msg)


func _refresh_after(msg: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ready()
	toast(msg, UI.GOOD)


func _pick_bag_target(affix_id: String) -> void:
	var body := UI.vbox(6)
	body.custom_minimum_size = Vector2(560, 0)
	var unbound := affix_id == "unbound"
	for entry in GameState.roster_for_affix():
		var uid := int(entry["uid"])
		var row := UI.hbox(8)
		var name := GameState.pet_name(entry)
		if bool(entry.get("chosen", false)):
			name += " · 开局选定"
		row.add_child(UI.label(name, 15, UI.TEXT))
		row.add_child(UI.grow())
		if unbound:
			var ok := bool(entry.get("chosen", false)) and not bool(entry.get("uncapped", false))
			var b := UI.button("赋予无限" if ok else "不可用", UI.GOLD if ok else UI.MUTED, 13)
			b.custom_minimum_size = Vector2(110, 34)
			b.disabled = not ok
			b.pressed.connect(_give_bag.bind(uid, "normal", affix_id))
			row.add_child(b)
		else:
			GameState.ensure_arts(entry)
			for pair in [["basic", "普通"], ["aid", "辅助"], ["ult", "大招"]]:
				var b := UI.button(str(pair[1]), UI.ACCENT, 13)
				b.custom_minimum_size = Vector2(72, 34)
				b.pressed.connect(_give_bag.bind(uid, str(pair[0]), affix_id))
				row.add_child(b)
		body.add_child(row)
	show_modal("选择精灵", body, 640, 460)


func _give_bag(uid: int, slot: String, affix_id: String) -> void:
	var msg := GameState.attach_from_bag(uid, slot, affix_id)
	close_modals()
	call_deferred("_after_bag", msg)


func _after_bag(msg: String) -> void:
	toast(msg, UI.GOOD)
	if not GameState.affix_bag.is_empty():
		_show_affix_bag()


func _art_named(entry: Dictionary, role: String) -> String:
	for raw in entry.get("arts", []):
		var art: Dictionary = raw
		if str(art.get("role", "")) == role:
			return str(art.get("name", "技能"))
	return SpiritPool.role_name(role)


func _open_train() -> void:
	if not GameState.can_train():
		toast("这一层的精灵都培养过了。", UI.MUTED)
		return
	var body := UI.vbox(8)
	body.add_child(UI.label("普通技能最多再加 1 个，辅助精灵的普通技能从 2 个起、稀有度每高一档 +1。辅助技能最多再加 2 个。大招按稀有度封顶。同一个效果最多叠三次。", 13, UI.MUTED, true))
	for entry in GameState.roster:
		GameState.ensure_arts(entry)
		var done := not GameState.can_train_pet(entry)
		var b := UI.button(GameState.pet_name(entry) + (" · 本层已培养" if done else ""), UI.MUTED if done else UI.ACCENT, 14)
		b.custom_minimum_size = Vector2(0, 36)
		b.disabled = done
		if not done:
			b.pressed.connect(_train_pet.bind(int(entry["uid"])))
		body.add_child(b)
	show_modal("精灵培养", body, 640, 480)


func _train_pet(uid: int) -> void:
	close_modals()
	call_deferred("_show_train_pet", uid)


func _show_train_pet(uid: int) -> void:
	var entry := GameState.get_roster_entry(uid)
	if entry.is_empty():
		return
	var body := UI.vbox(8)
	var passive: Dictionary = entry.get("passive", {})
	if not passive.is_empty():
		body.add_child(UI.label("专属：%s · %s" % [str(passive.get("name", "")), str(passive.get("text", ""))], 13, UI.GOLD))
	for art in entry.get("arts", []):
		body.add_child(UI.label(SpiritPool.art_text(art), 13, UI.TEXT))
	body.add_child(UI.label("从技能池里抽五个。效果只改这一招：打法、目标或留下一个状态。词条不会出现在这里。只有辅助能回灵。", 13, UI.MUTED, true))
	for offer in GameState.train_offers(uid):
		var eid := str(offer.get("id", ""))
		var b := UI.button("%s · %s" % [SpiritPool.effect_name(eid), SpiritPool.effect_text(eid)], UI.PURPLE, 13)
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(_train_effect.bind(uid, eid))
		body.add_child(b)
	show_modal("挑选效果", body, 680, 520)


func _train_effect(uid: int, eid: String) -> void:
	close_modals()
	call_deferred("_show_train_slots", uid, eid)


func _show_train_slots(uid: int, eid: String) -> void:
	var entry := GameState.get_roster_entry(uid)
	if entry.is_empty():
		return
	var body := UI.vbox(8)
	var arts: Array = entry.get("arts", [])
	for i in arts.size():
		var art: Dictionary = arts[i]
		var b := UI.button("加到【%s】" % str(art.get("name", "技能")), UI.ACCENT, 14)
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(_train_commit.bind(uid, eid, i))
		body.add_child(b)
	show_modal(SpiritPool.effect_name(eid), body, 560, 360)


func _train_commit(uid: int, eid: String, index: int) -> void:
	var msg := GameState.train_apply(uid, eid, index)
	close_modals()
	toast("培养完成。" if msg == "" else msg, UI.GOOD if msg == "" else UI.DANGER)
