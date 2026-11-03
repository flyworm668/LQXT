extends "res://scripts/ui/screen_base.gd"
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
## Post-battle chest: pet, item and affix are guaranteed. Pet rarity is rolled.

var evolutions: Array = []
var cards_host: HBoxContainer
var continue_button: Button


func _ready() -> void:
	GameState.note_screen("reward")
	evolutions = params.get("evolutions", [])
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.5)
	_build_static()
	_refresh()
	if bool(GameState.pending_rewards.get("forged", false)):
		_show_forge_card()


func _build_static() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := UI.vbox(8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top := UI.hbox(10)
	var loot_title := "战利品 · 第 %d 层" % GameState.current_floor
	if GameState.run_mode != "conquest":
		loot_title = "战利品 · 第 %d / %d 层" % [GameState.current_floor, ContentDB.total_floors()]
	top.add_child(UI.label(loot_title, 27, UI.GOLD))
	top.add_child(UI.pill("全员等级 +%d" % GameState._growth_step(), UI.GOOD, 12))
	top.add_child(UI.pill("当前队伍 Lv.%d" % GameState.party_level(), UI.BLUE, 12))
	if bool(GameState.encounter.get("curse", false)):
		top.add_child(UI.pill("精英试炼", UI.DANGER, 12))
	top.add_child(UI.grow())
	var menu := UI.ghost_button("菜单", 13)
	menu.custom_minimum_size = Vector2(64, 30)
	menu.pressed.connect(open_run_menu)
	top.add_child(menu)
	top.add_child(UI.label("精灵 / 道具 / 词条必出", 12, UI.MUTED))
	root.add_child(top)
	var notice := str(GameState.pending_rewards.get("notice", ""))
	if notice != "":
		root.add_child(UI.label(notice, 14, UI.GOLD))

	var progress := UI.hbox(8)
	progress.add_child(UI.pill("精灵 100%", UI.GOOD, 11))
	progress.add_child(UI.pill("道具 100%", UI.BLUE, 11))
	progress.add_child(UI.pill("词条 100%", UI.PURPLE, 11))
	progress.add_child(UI.pill("英雄 5%", Color(1.0, 0.85, 0.45), 11))
	var bonus_items: Array = GameState.pending_rewards.get("bonus_items", [])
	if not bonus_items.is_empty():
		progress.add_child(UI.pill("精英奖励 +%d 道具" % bonus_items.size(), UI.DANGER, 11))
	progress.add_child(UI.grow())
	if not evolutions.is_empty():
		var names: Array = []
		for e in evolutions:
			names.append("%s → %s" % [e.get("from", ""), e.get("to", "")])
		var evo := UI.label("进化：" + "、".join(names), 12, UI.PURPLE)
		evo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		evo.custom_minimum_size = Vector2(280, 0)
		evo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.add_child(evo)
	root.add_child(progress)

	var slot: Array = ScreenFit.scroll_slot(true)
	root.add_child(slot[0])
	var scroll: ScrollContainer = slot[1]
	cards_host = UI.hbox(14)
	cards_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards_host.alignment = BoxContainer.ALIGNMENT_BEGIN
	scroll.add_child(cards_host)

	var bottom := UI.hbox(12)
	bottom.add_child(UI.label("未领取的精灵 / 道具会在继续时自动收取；未处理的词条视为放弃。", 11, UI.FAINT))
	bottom.add_child(UI.grow())
	continue_button = UI.button("继续前进", UI.ACCENT, 17)
	continue_button.custom_minimum_size = Vector2(250, 46)
	continue_button.pressed.connect(_continue)
	bottom.add_child(continue_button)
	root.add_child(bottom)


func _refresh() -> void:
	if cards_host == null:
		return
	UI.clear_children(cards_host)
	var pr: Dictionary = GameState.pending_rewards
	if pr.is_empty():
		var note := UI.panel(Color(0.05, 0.07, 0.11, 0.9), UI.BORDER, 16, 20)
		note.add_child(UI.label("没有待领取的奖励。", 16, UI.MUTED))
		cards_host.add_child(note)
		return
	cards_host.add_child(_pet_card(pr))
	cards_host.add_child(_item_card(pr))
	cards_host.add_child(_affix_card(pr))
	if str(pr.get("hero", {}).get("kind", "none")) == "hero":
		cards_host.add_child(_hero_card(pr))
	if str(pr.get("king", {}).get("kind", "none")) == "king":
		cards_host.add_child(_king_card(pr))
	if continue_button != null:
		if GameState.run_won:
			continue_button.text = "登顶 · 查看结算"
		elif GameState.is_route_floor(GameState.current_floor + 1):
			continue_button.text = "选择道路"
		elif GameState.is_event_floor(GameState.current_floor + 1):
			continue_button.text = "前往奇遇"
		else:
			continue_button.text = "继续前进"


func _card_shell(title: String, chance: String, accent: Color) -> Array:
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.94), UI.BORDER, 16, 12)
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	panel.add_child(v)
	var head := UI.hbox(6)
	head.add_child(UI.label(title, 17, accent))
	head.add_child(UI.grow())
	head.add_child(UI.pill(chance, accent, 10))
	v.add_child(head)
	v.add_child(UI.hline(UI.BORDER, 1))
	return [panel, v]


func _pet_card(pr: Dictionary) -> Control:
	var shell := _card_shell("精灵伙伴", "必出", UI.GOOD)
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("pet", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("pet", false))
	if r.is_empty():
		v.add_child(UI.label("本层没有精灵线索。", 13, UI.MUTED))
		return panel
	var pid := str(r.get("species", "p01"))
	var p: Dictionary = ContentDB.pet(pid)
	var rarity := str(p.get("rarity", "common"))
	var level := GameState.party_level_for(pid, rarity == "hero" or rarity == "demon")
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 84)
	v.add_child(holder)
	holder.add_child(UI.avatar(pid, 78, level))
	var name_label := UI.label(ContentDB.pet_display_name(pid, level), 15, UI.TEXT, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var tags := UI.hbox(5)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 10))
	tags.add_child(UI.pill(ContentDB.rarity_name(str(p.get("rarity", "common"))), ContentDB.rarity_color(str(p.get("rarity", "common"))), 10))
	tags.add_child(UI.pill("Lv.%d" % level, UI.MUTED, 10))
	v.add_child(tags)
	var kind := str(r.get("kind", "new"))
	if kind == "new":
		v.add_child(UI.label("新的伙伴，可编入阵型。", 11, UI.MUTED, true))
	else:
		v.add_child(UI.label("重复精灵 → 共鸣，全属性 +8%。", 11, UI.PURPLE, true))
	v.add_child(UI.grow())
	if claimed:
		v.add_child(UI.label("✓ 已收入队伍", 13, UI.GOOD))
	else:
		var b := UI.button("收入队伍", UI.GOOD, 14)
		b.pressed.connect(func():
			GameState.claim_pet_reward()
			_refresh())
		v.add_child(b)
	return panel


func _item_card(pr: Dictionary) -> Control:
	var shell := _card_shell("随机道具", "必出", UI.BLUE)
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("item", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("item", false))
	if str(r.get("kind", "none")) != "item":
		v.add_child(UI.label("行囊里该道具已达上限。", 13, UI.MUTED))
		return panel
	var item: Dictionary = ContentDB.item(str(r["id"]))
	var rarity := str(item.get("rarity", "common"))
	var rcolor := ContentDB.rarity_color(rarity)
	var icon := CenterContainer.new()
	icon.custom_minimum_size = Vector2(0, 66)
	v.add_child(icon)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.soft_style(Color(rcolor.r, rcolor.g, rcolor.b, 0.14), rcolor, 2, 32, 0))
	badge.custom_minimum_size = Vector2(64, 64)
	icon.add_child(badge)
	var glyph := UI.label("◆", 30, rcolor)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)
	var name_label := UI.label(str(item.get("name", "道具")), 15, rcolor, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var rarity_label := UI.label(ContentDB.rarity_name(rarity), 10, rcolor)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rarity_label)
	var desc := UI.label(str(item.get("desc", "")), 11, UI.MUTED, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	v.add_child(UI.grow())
	if claimed:
		v.add_child(UI.label("✓ 已收入行囊", 13, UI.GOOD))
	else:
		var b := UI.button("收入行囊", UI.BLUE, 14)
		b.pressed.connect(func():
			GameState.claim_item_reward()
			_refresh())
		v.add_child(b)
	return panel


func _affix_card(pr: Dictionary) -> Control:
	var shell := _card_shell("技能词条", "必出", UI.PURPLE)
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("affix", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("affix", false))
	if str(r.get("kind", "none")) != "affix":
		v.add_child(UI.label("没有可用的词条。", 13, UI.MUTED))
		return panel
	v.add_child(UI.label("3 条候选词条，挑选 1 条：", 11, UI.MUTED))
	for a in r.get("candidates", []):
		var acolor := ContentDB.rarity_color(str(a.get("rarity", "common")))
		var row := UI.hbox(5)
		row.add_child(UI.pill(str(a.get("name", "")), acolor, 10))
		var desc := UI.label(str(a.get("desc", "")), 10, UI.MUTED, true)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		v.add_child(row)
	v.add_child(UI.grow())
	if claimed:
		v.add_child(UI.label("✓ 本次词条已处理", 13, UI.PURPLE))
	else:
		var b := UI.button("挑选词条", UI.PURPLE, 14)
		b.pressed.connect(func(): goto_screen("res://scripts/ui/affix_screen.gd"))
		v.add_child(b)
	return panel


func _hero_card(pr: Dictionary) -> Control:
	var shell := _card_shell("英雄精灵", "15%", Color(1.0, 0.85, 0.45))
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("hero", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("hero", false))
	if str(r.get("kind", "none")) != "hero":
		v.add_child(UI.spacer(0, 14))
		var mark := UI.label("—", 40, Color(1, 1, 1, 0.14))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mark)
		var miss := UI.label("星辉沉寂", 14, UI.MUTED)
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(miss)
		var hint := UI.label("每次开箱独立 15% 概率唤醒英雄精灵。", 11, UI.FAINT, true)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
		return panel
	var pid := str(r.get("species", "p01"))
	var level := GameState.party_level_for(pid, true)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 78)
	var av := UI.avatar(pid, 74, level)
	holder.add_child(av)
	v.add_child(holder)
	var name_label := UI.label("英雄·" + ContentDB.pet_display_name(pid, level), 15, Color(1.0, 0.86, 0.48))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var buff: Dictionary = ContentDB.boss_buff(str(r.get("buff", "")))
	var buff_name := str(buff.get("name", "英雄之力"))
	var tags := UI.hbox(5)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(UI.pill(buff_name, Color(1.0, 0.85, 0.45), 10))
	tags.add_child(UI.pill("阶段觉醒", UI.DANGER, 10))
	v.add_child(tags)
	var desc := UI.label("与首领相同的机制，数值低于首领；可用道具升星。", 11, UI.MUTED, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	v.add_child(UI.grow())
	if claimed:
		v.add_child(UI.label("✓ 英雄已加入队伍", 13, UI.GOOD))
	else:
		var b := UI.button("缔结英雄契约", Color(1.0, 0.78, 0.35), 14)
		b.pressed.connect(func():
			GameState.claim_hero_reward()
			_refresh())
		v.add_child(b)
	return panel


func _king_card(pr: Dictionary) -> Control:
	var r: Dictionary = pr.get("king", {})
	var claimed: Dictionary = pr.get("claimed", {})
	var shell := _card_shell("魔王契约", "15%", Color(1.0, 0.45, 0.5))
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var names: Array = r.get("species_list", [])
	var pid := str(r.get("species", ""))
	var level := GameState.party_level_for(pid, true)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 78)
	holder.add_child(UI.avatar(pid, 74, level))
	v.add_child(holder)
	var name_label := UI.label(ContentDB.pet_display_name(pid, level), 15, Color(1.0, 0.55, 0.62))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var extra := ""
	if names.size() > 1:
		var shown: Array = []
		for species in names:
			shown.append(ContentDB.pet_display_name(str(species), level))
		extra = "本场还契约到：" + "、".join(shown)
	var desc := UI.label("打败魔王后有 15% 概率契约魔人。" + extra, 11, UI.MUTED, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	v.add_child(UI.grow())
	if bool(claimed.get("king", false)):
		v.add_child(UI.label("✓ 魔人已加入队伍", 13, UI.GOOD))
	else:
		var b := UI.button("契约魔人", Color(1.0, 0.45, 0.5), 14)
		b.pressed.connect(func():
			GameState.claim_king_reward()
			_refresh())
		v.add_child(b)
	return panel


func _continue() -> void:
	var pr: Dictionary = GameState.pending_rewards
	if not pr.is_empty():
		var claimed: Dictionary = pr.get("claimed", {})
		if not bool(claimed.get("pet", false)):
			GameState.claim_pet_reward()
		if not bool(claimed.get("item", false)) and str(pr.get("item", {}).get("kind", "none")) == "item":
			GameState.claim_item_reward()
		if not bool(claimed.get("affix", false)) and str(pr.get("affix", {}).get("kind", "none")) == "affix":
			GameState.skip_affix_reward()
		if not bool(claimed.get("hero", false)):
			GameState.claim_hero_reward()
		if not bool(claimed.get("king", false)):
			GameState.claim_king_reward()
	GameState.claim_bonus_items()
	if GameState.run_won:
		goto_screen("res://scripts/ui/result_screen.gd", {"win": true})
		return
	GameState.advance_floor()
	_open_next()


func _open_next() -> void:
	match GameState.destination_after_floor():
		"route":
			goto_screen("res://scripts/ui/route_screen.gd")
		"event":
			goto_screen("res://scripts/ui/event_screen.gd")
		_:
			goto_screen("res://scripts/ui/map_screen.gd")


func _show_forge_card() -> void:
	var body := UI.vbox(8)
	body.custom_minimum_size = Vector2(520, 0)
	body.add_child(UI.label("四块碎片汇聚成一把剑。", 14, UI.MUTED))
	for iid in ["blade_shard_1", "blade_shard_2", "blade_shard_3", "blade_shard_4"]:
		var shard: Dictionary = ContentDB.item(iid)
		body.add_child(UI.label(str(shard.get("name", iid)) + "  →  汇入", 13, UI.TEXT))
	body.add_child(UI.hline(UI.BORDER, 1))
	var sword: Dictionary = ContentDB.item("barrier_blade")
	body.add_child(UI.label(str(sword.get("name", "破魔圣剑")), 20, UI.GOLD))
	var desc := UI.label(str(sword.get("desc", "")), 13, UI.MUTED, true)
	desc.custom_minimum_size = Vector2(480, 0)
	body.add_child(desc)
	body.add_child(UI.label("圣剑已放入道具背包，让一只精灵携带后，完整效果才会生效。", 13, UI.GOLD, true))
	show_modal("破魔圣剑合成", body, 620, 360)
