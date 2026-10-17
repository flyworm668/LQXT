extends "res://scripts/ui/screen_base.gd"
## Post-battle chest: three independent reward rolls.

var evolutions: Array = []
var cards_host: HBoxContainer
var continue_button: Button


func _ready() -> void:
	evolutions = params.get("evolutions", [])
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.5)
	_build_static()
	_refresh()


func _build_static() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var root := UI.vbox(10)
	margin.add_child(root)

	var top := UI.hbox(12)
	top.add_child(UI.label("战利品 · 第 %d 层" % GameState.current_floor, 31, UI.GOLD))
	top.add_child(UI.pill("全员等级 +10", UI.GOOD, 13))
	top.add_child(UI.pill("当前队伍 Lv.%d" % GameState.party_level(), UI.BLUE, 12))
	top.add_child(UI.grow())
	top.add_child(UI.label("宝箱三次独立判定", 13, UI.MUTED))
	root.add_child(top)

	if not evolutions.is_empty():
		var evo_row := UI.hbox(10)
		evo_row.add_child(UI.pill("进化", UI.PURPLE, 12))
		for e in evolutions:
			evo_row.add_child(UI.label("%s → %s" % [e.get("from", ""), e.get("to", "")], 14, UI.PURPLE))
		root.add_child(evo_row)
	else:
		root.add_child(UI.label("精灵在 30 / 60 级时进化，进化后名称与属性都会提升。", 12, UI.FAINT))

	cards_host = UI.hbox(18)
	cards_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cards_host)

	var bottom := UI.hbox(12)
	bottom.add_child(UI.label("未领取的道具会在继续时自动收取；未处理的词条视为放弃。", 12, UI.FAINT))
	bottom.add_child(UI.grow())
	continue_button = UI.button("继续前进", UI.ACCENT, 18)
	continue_button.custom_minimum_size = Vector2(260, 50)
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
	if continue_button != null:
		continue_button.text = "登顶 · 查看结算" if GameState.current_floor >= 10 else "继续前进"


func _card_shell(title: String, chance: String, accent: Color) -> Array:
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.94), UI.BORDER, 18, 18)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(10)
	panel.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label(title, 19, accent))
	head.add_child(UI.grow())
	head.add_child(UI.pill(chance, accent, 11))
	v.add_child(head)
	v.add_child(UI.hline(UI.BORDER, 1))
	v.add_child(UI.spacer(0, 6))
	return [panel, v]


func _pet_card(pr: Dictionary) -> Control:
	var shell := _card_shell("精灵伙伴", "100%", UI.GOOD)
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("pet", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("pet", false))
	if r.is_empty():
		v.add_child(UI.label("本层没有精灵线索。", 14, UI.MUTED))
		return panel
	var pid := str(r.get("species", "p01"))
	var level := GameState.party_level()
	var p: Dictionary = ContentDB.pet(pid)
	var color := ContentDB.element_color(str(p.get("element", "fire")))
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 112)
	v.add_child(holder)
	holder.add_child(UI.avatar(pid, 104, level))
	var name_label := UI.label(ContentDB.pet_display_name(pid, level), 21, UI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var tags := UI.hbox(6)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), color, 11))
	tags.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 11))
	tags.add_child(UI.pill("Lv.%d" % level, UI.MUTED, 11))
	v.add_child(tags)
	var kind := str(r.get("kind", "new"))
	if kind == "new":
		v.add_child(UI.label("新的伙伴！加入仓库，可编入阵型。", 13, UI.MUTED, true))
	else:
		v.add_child(UI.label("重复精灵，转化为共鸣：该精灵全属性永久 +8%。", 13, UI.PURPLE, true))
	var grow := UI.grow()
	v.add_child(grow)
	if claimed:
		v.add_child(UI.label("✓ 已收入队伍", 15, UI.GOOD))
	else:
		var b := UI.button("收入队伍", UI.GOOD, 16)
		b.pressed.connect(func():
			GameState.claim_pet_reward()
			_refresh())
		v.add_child(b)
	return panel


func _item_card(pr: Dictionary) -> Control:
	var shell := _card_shell("随机道具", "50%", UI.BLUE)
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("item", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("item", false))
	v.add_child(UI.spacer(0, 30))
	if str(r.get("kind", "none")) != "item":
		var mark := UI.label("—", 64, Color(1, 1, 1, 0.12))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mark)
		var miss := UI.label("这次没有发现道具", 16, UI.MUTED)
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(miss)
		v.add_child(UI.label("道具判定 50%，可被训练家与幸运金币提升。", 12, UI.FAINT, true))
		return panel
	var item: Dictionary = ContentDB.item(str(r["id"]))
	var rarity := str(item.get("rarity", "common"))
	var rcolor := ContentDB.rarity_color(rarity)
	var icon := CenterContainer.new()
	icon.custom_minimum_size = Vector2(0, 94)
	v.add_child(icon)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.soft_style(Color(rcolor.r, rcolor.g, rcolor.b, 0.14), rcolor, 2, 44, 0))
	badge.custom_minimum_size = Vector2(88, 88)
	icon.add_child(badge)
	var glyph := UI.label("◆", 38, rcolor)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)
	var name_label := UI.label(str(item.get("name", "道具")), 21, rcolor)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var rarity_label := UI.label(ContentDB.rarity_name(rarity), 12, rcolor)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rarity_label)
	var desc := UI.label(str(item.get("desc", "")), 13, UI.MUTED, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var grow := UI.grow()
	v.add_child(grow)
	if claimed:
		v.add_child(UI.label("✓ 已收入行囊", 15, UI.GOOD))
	else:
		var b := UI.button("收入行囊", UI.BLUE, 16)
		b.pressed.connect(func():
			GameState.claim_item_reward()
			_refresh())
		v.add_child(b)
	return panel


func _affix_card(pr: Dictionary) -> Control:
	var shell := _card_shell("技能词条", "25%", UI.PURPLE)
	var panel: PanelContainer = shell[0]
	var v: VBoxContainer = shell[1]
	var r: Dictionary = pr.get("affix", {})
	var claimed: bool = bool(pr.get("claimed", {}).get("affix", false))
	v.add_child(UI.spacer(0, 16))
	if str(r.get("kind", "none")) != "affix":
		var mark := UI.label("—", 64, Color(1, 1, 1, 0.12))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mark)
		var miss := UI.label("这次没有发现词条", 16, UI.MUTED)
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(miss)
		v.add_child(UI.label("词条判定 25%，可在本次远征中持续成长。", 12, UI.FAINT, true))
		return panel
	v.add_child(UI.label("本次发现 3 条候选词条：", 13, UI.MUTED))
	for a in r.get("candidates", []):
		var acolor := ContentDB.rarity_color(str(a.get("rarity", "common")))
		var row := UI.hbox(6)
		row.add_child(UI.pill(str(a.get("name", "")), acolor, 11))
		var desc := UI.label(str(a.get("desc", "")), 11, UI.MUTED, true)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		v.add_child(row)
	var grow := UI.grow()
	v.add_child(grow)
	if claimed:
		v.add_child(UI.label("✓ 本次词条已处理", 15, UI.PURPLE))
	else:
		var b := UI.button("挑选词条", UI.PURPLE, 16)
		b.pressed.connect(func(): goto_screen("res://scripts/ui/affix_screen.gd"))
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
	if GameState.current_floor >= 10:
		goto_screen("res://scripts/ui/result_screen.gd", {"win": true})
		return
	GameState.advance_floor()
	goto_screen("res://scripts/ui/map_screen.gd")
