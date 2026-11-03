extends RefCounted
const SpiritPool = preload("res://scripts/core/spirit_pool.gd")
## Shared pet / unit inspector. Preload this script and call open_roster / open_unit.


static func open_roster(screen: Control, entry: Dictionary) -> Control:
	if entry.is_empty():
		return null
	GameState.ensure_arts(entry)
	var pid := str(entry["species"])
	var level := int(entry["level"])
	var stats: Dictionary = GameState.effective_stats(entry)
	return open(screen, {
		"species": pid,
		"level": level,
		"name": GameState.pet_name(entry),
		"element": str(ContentDB.pet(pid).get("element", "")),
		"class": str(ContentDB.pet(pid).get("class", "")),
		"rarity": str(ContentDB.pet(pid).get("rarity", "common")),
		"hero": bool(entry.get("hero", false)),
		"hero_star": int(entry.get("hero_star", 0)),
		"uncapped": bool(entry.get("uncapped", false)),
		"max_level": GameState.pet_max_level(entry),
		"resonance": int(entry.get("resonance", 0)),
		"stats": stats,
		"skills": ContentDB.pet(pid).get("skills", {}),
		"arts": entry.get("arts", []),
		"mark": ContentDB.pet(pid).get("mark", {}),
		"affixes": entry.get("affixes", {}),
		"boss": false,
	})


static func open_unit(screen: Control, unit: Dictionary) -> Control:
	if unit.is_empty():
		return null
	var pid := str(unit.get("species", ""))
	var boss := bool(unit.get("is_boss", false))
	var source: Dictionary = ContentDB.boss(pid) if boss else ContentDB.pet(pid)
	return open(screen, {
		"species": pid,
		"level": int(unit.get("level", 1)),
		"name": str(unit.get("name", "?")),
		"element": str(unit.get("element", source.get("element", ""))),
		"class": str(unit.get("class", source.get("class", ""))),
		"rarity": "boss" if boss else str(unit.get("rarity", source.get("rarity", "common"))),
		"hero": bool(unit.get("is_hero", false)),
		"hero_star": int(unit.get("hero_star", 0)),
		"resonance": 0,
		"stats": {
			"hp": int(unit.get("max_hp", 1)),
			"atk": int(unit.get("atk", 0)),
			"def": int(unit.get("def", 0)),
			"spd": int(unit.get("spd", 0)),
		},
		"hp_now": int(unit.get("hp", 0)),
		"shield": int(unit.get("shield", 0)),
		"rage": int(unit.get("rage", 0)),
		"skills": unit.get("skills", source.get("skills", {})),
		"arts": unit.get("arts", []),
		"uses_spirit": bool(unit.get("uses_spirit", false)),
		"mark": unit.get("mark", source.get("mark", {})),
		"stacks": unit.get("marks", {}),
		"statuses": unit.get("statuses", {}),
		"affixes": unit.get("affixes", {}),
		"boss": boss,
	})


static func open(screen: Control, info: Dictionary) -> Control:
	if not screen.has_method("show_modal"):
		return null
	var body := UI.vbox(8)
	body.custom_minimum_size.x = 640
	var head := UI.hbox(12)
	var av: Control
	if bool(info.get("boss", false)):
		var script = load("res://scripts/ui/pet_avatar.gd")
		av = script.new()
		var boss_data: Dictionary = ContentDB.boss(str(info.get("species", "")))
		if boss_data.is_empty():
			boss_data = {"id": "boss", "element": info.get("element", "dark"), "class": info.get("class", "warrior")}
		av.setup_boss(boss_data, 84)
	else:
		av = UI.avatar(str(info.get("species", "")), 84, int(info.get("level", 1)))
	head.add_child(av)
	var col := UI.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	col.add_child(UI.label(str(info.get("name", "?")), 22, UI.TEXT))
	var tags := UI.hbox(5)
	var element := str(info.get("element", ""))
	var cls := str(info.get("class", ""))
	var rarity := str(info.get("rarity", "common"))
	tags.add_child(UI.pill(ContentDB.element_name(element), ContentDB.element_color(element), 11))
	tags.add_child(UI.pill(ContentDB.class_name_for(cls), ContentDB.class_color(cls), 11))
	if rarity == "boss":
		tags.add_child(UI.pill("首领", UI.GOLD, 11))
	else:
		tags.add_child(UI.pill(ContentDB.rarity_name(rarity), ContentDB.rarity_color(rarity), 11))
	var lv_val := int(info.get("level", 1))
	var max_lv := int(info.get("max_level", 0))
	if bool(info.get("uncapped", false)):
		tags.add_child(UI.pill("Lv.%d · 无上限" % lv_val, UI.GOLD, 11))
	elif max_lv > 0:
		tags.add_child(UI.pill("Lv.%d / %d" % [lv_val, max_lv], UI.MUTED, 11))
	else:
		tags.add_child(UI.pill("Lv.%d" % lv_val, UI.MUTED, 11))
	if bool(info.get("hero", false)):
		tags.add_child(UI.pill("英雄 %d★" % int(info.get("hero_star", 0)), Color(1.0, 0.85, 0.45), 11))
	if int(info.get("resonance", 0)) > 0:
		tags.add_child(UI.pill("共鸣 ×%d" % int(info["resonance"]), UI.PURPLE, 11))
	col.add_child(tags)
	var stats: Dictionary = info.get("stats", {})
	var stat_line := "生命 %s    攻击 %s    防御 %s    速度 %s" % [
		ContentDB.fmt(int(stats.get("hp", 0))), ContentDB.fmt(int(stats.get("atk", 0))),
		ContentDB.fmt(int(stats.get("def", 0))), ContentDB.fmt(int(stats.get("spd", 0)))]
	if info.has("hp_now"):
		var resource := "" if bool(info.get("uses_spirit", false)) else "气势 %d    " % int(info.get("rage", 0))
		stat_line = "当前生命 %s / %s    护盾 %s    %s" % [
			ContentDB.fmt(int(info["hp_now"])), ContentDB.fmt(int(stats.get("hp", 0))),
			ContentDB.fmt(int(info.get("shield", 0))), resource] + stat_line
	col.add_child(UI.label(stat_line, 13, UI.MUTED, true))
	body.add_child(head)
	body.add_child(UI.hline(UI.BORDER, 1))
	var arts: Array = info.get("arts", [])
	if arts.is_empty():
		var skills: Dictionary = info.get("skills", {})
		_skill_block(body, "普攻", skills.get("normal", {}))
		_skill_block(body, "大招", skills.get("ultimate", {}))
	else:
		body.add_child(UI.label("技能", 15, UI.GOLD))
		for raw in arts:
			var art: Dictionary = raw
			body.add_child(UI.label(SpiritPool.art_text(art), 13, UI.TEXT, true))
	var mark: Dictionary = info.get("mark", {})
	if not mark.is_empty():
		body.add_child(UI.label("专属印记", 15, UI.GOLD))
		var stacks: Dictionary = info.get("stacks", {})
		var n := 0
		var mid := str(mark.get("id", ""))
		if stacks.has(mid) and typeof(stacks[mid]) == TYPE_DICTIONARY:
			n = int(stacks[mid].get("n", 0))
		var line := "%s · 最多 %d 层" % [str(mark.get("name", "印记")), int(mark.get("max", 3))]
		if n > 0:
			line += " · 当前 %d 层" % n
		body.add_child(UI.label(line, 13, UI.TEXT))
		body.add_child(UI.label(_mark_text(mark), 12, UI.MUTED, true))
	var statuses: Dictionary = info.get("statuses", {})
	if not statuses.is_empty():
		body.add_child(UI.label("当前状态", 15, UI.PURPLE))
		var parts: Array = []
		var engine = load("res://scripts/core/battle_engine.gd")
		for key in statuses.keys():
			var st: Dictionary = statuses[key]
			parts.append("%s %d 回合" % [engine.status_name(str(key)), int(st.get("dur", 0))])
		body.add_child(UI.label("、".join(parts), 12, UI.MUTED, true))
	var affixes: Dictionary = info.get("affixes", {})
	var listed := false
	var slots: Array = ["basic", "aid", "ult"] if affixes.has("basic") else ["normal", "ultimate"]
	for slot in slots:
		for aid in affixes.get(slot, []):
			if not listed:
				body.add_child(UI.label("已附着词条", 15, UI.PURPLE))
				listed = true
			var a: Dictionary = ContentDB.affix(str(aid))
			var where := "词条·" + ("普通" if slot == "normal" or slot == "basic" else ("辅助" if slot == "aid" else "大招"))
			body.add_child(UI.label("%s · %s：%s" % [where, str(a.get("name", aid)), str(a.get("desc", ""))], 12, UI.MUTED, true))
	return screen.show_modal(str(info.get("name", "精灵")), body, 700, 420)


static func _skill_block(body: VBoxContainer, title: String, skill: Variant) -> void:
	var sk: Dictionary = skill if typeof(skill) == TYPE_DICTIONARY else {}
	if sk.is_empty():
		return
	var row := UI.hbox(8)
	row.add_child(UI.label(title, 15, UI.GOLD))
	row.add_child(UI.label(str(sk.get("name", "")), 15, UI.TEXT))
	var mult := float(sk.get("mult", 0.0))
	if mult > 0.0:
		row.add_child(UI.pill("%.0f%%" % (mult * 100.0), UI.MUTED, 10))
	body.add_child(row)
	body.add_child(UI.label(str(sk.get("desc", "")), 13, UI.MUTED, true))


static func _mark_text(mark: Dictionary) -> String:
	var fx := {
		"elem_taken": "受到该属性伤害提高", "slow": "速度降低", "self_crit": "自身暴击提高",
		"def_down": "防御降低", "self_atk": "自身攻击提高", "poison": "中毒",
		"antiheal": "治疗降低", "self_heal": "自身治疗提高", "crit_taken": "受到暴击伤害提高",
		"atk_down": "攻击降低", "self_skill": "自身技能伤害提高", "self_thorns": "自身反伤提高",
		"self_spd": "自身速度提高", "self_def": "自身防御提高", "vuln": "受到伤害提高",
		"ward": "分摊伤害", "tick_adj": "相邻单位受到持续伤害", "true_hp": "额外真实伤害",
		"self_vamp": "自身吸血", "self_ult": "自身大招伤害提高", "self_elem": "自身属性伤害提高",
		"dealt_down": "造成伤害降低", "ignore_def": "无视防御",
	}
	var text := str(fx.get(str(mark.get("fx", "")), "特殊效果"))
	text += " %.0f%%" % (float(mark.get("per", 0.0)) * 100.0)
	if str(mark.get("fx2", "")) != "":
		text += "，另有 " + str(fx.get(str(mark.get("fx2", "")), "附加")) + " %.0f%%" % (float(mark.get("per2", 0.0)) * 100.0)
	if str(mark.get("full", "")) != "":
		text += "。叠满后触发一次强效。"
	return text
