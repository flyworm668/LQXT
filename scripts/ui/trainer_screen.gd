extends "res://scripts/ui/screen_base.gd"
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
## Step 1/2 — trainer selection.

var selected_id: String = ""
var cards: Dictionary = {}
var confirm: Button


func _ready() -> void:
	add_background("temple")
	add_dim(0.42)
	_build()
	var trainers: Array = ContentDB.data.get("trainers", [])
	if not trainers.is_empty():
		_select(str(trainers[0]["id"]))


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var root := UI.vbox(18)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top := UI.hbox(12)
	var back := UI.ghost_button("← 返回", 14)
	back.custom_minimum_size = Vector2(92, 34)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/title_screen.gd"))
	top.add_child(back)
	top.add_child(UI.grow())
	top.add_child(UI.pill("第 1 / 2 步", UI.ACCENT, 13))
	root.add_child(top)

	root.add_child(UI.label("选择训练家", 34, UI.TEXT))
	root.add_child(UI.label("不同的启程方式，会改变整局远征的节奏。", 15, UI.MUTED))

	var slot: Array = ScreenFit.scroll_slot(true)
	root.add_child(slot[0])
	var row := UI.hbox(22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(slot[1] as ScrollContainer).add_child(row)
	var trainers: Array = ContentDB.data.get("trainers", [])
	var box := ScreenFit.card_box(self, trainers.size(), 22.0, 70.0, 250.0)
	for t in trainers:
		row.add_child(_trainer_card(t, box))

	var bottom := UI.hbox(12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm = UI.button("确认训练家", UI.ACCENT, 19)
	confirm.custom_minimum_size = Vector2(340, 54)
	confirm.pressed.connect(_confirm)
	bottom.add_child(confirm)
	root.add_child(bottom)


func _trainer_card(t: Dictionary, box: Vector2) -> Control:
	var color := Color.from_string(str(t.get("color", "#ff8a4c")), UI.ACCENT)
	var p := UI.panel(Color(0.05, 0.07, 0.11, 0.88), UI.BORDER, 18, 22)
	p.custom_minimum_size = Vector2(box.x, 0)
	p.clip_contents = false
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(str(t["id"])))
	var v := UI.vbox(12)
	p.add_child(v)

	var badge_center := CenterContainer.new()
	badge_center.custom_minimum_size = Vector2(0, 94)
	v.add_child(badge_center)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.soft_style(Color(color.r, color.g, color.b, 0.16), color, 2, 46, 0))
	badge.custom_minimum_size = Vector2(92, 92)
	badge_center.add_child(badge)
	var glyph := UI.label(str(t["name"]).substr(0, 1), 42, color)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)

	var name_label := UI.label(str(t["name"]), 24, UI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var title_label := UI.label(str(t.get("title", "")), 14, color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)
	v.add_child(UI.hline(Color(color.r, color.g, color.b, 0.35), 1))
	var scroll := ScreenFit.scrolling_body()
	scroll.custom_minimum_size = Vector2(0, maxf(72.0, box.y - 280.0))
	var body := UI.vbox(8)
	body.custom_minimum_size = Vector2(maxf(160.0, box.x - 56.0), 0)
	var desc := UI.label(str(t.get("desc", "")), 14, UI.MUTED, true)
	body.add_child(desc)
	var chips := UI.hbox(6)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	var mods: Dictionary = t.get("mods", {})
	var all_stat := float(mods.get("hp_mult", 0))
	if all_stat > 0.0 and is_equal_approx(all_stat, float(mods.get("atk_mult", 0))) \
			and is_equal_approx(all_stat, float(mods.get("def_mult", 0))) \
			and is_equal_approx(all_stat, float(mods.get("spd_mult", 0))):
		chips.add_child(UI.pill("全属性 +%d%%" % int(all_stat * 100), UI.GOLD, 11))
	else:
		if float(mods.get("hp_mult", 0)) > 0:
			chips.add_child(UI.pill("生命 +%d%%" % int(float(mods["hp_mult"]) * 100), UI.GOOD, 11))
		if float(mods.get("atk_mult", 0)) > 0:
			chips.add_child(UI.pill("攻击 +%d%%" % int(float(mods["atk_mult"]) * 100), UI.ACCENT, 11))
		if float(mods.get("def_mult", 0)) > 0:
			chips.add_child(UI.pill("防御 +%d%%" % int(float(mods["def_mult"]) * 100), UI.BLUE, 11))
		if float(mods.get("spd_mult", 0)) > 0:
			chips.add_child(UI.pill("速度 +%d%%" % int(float(mods["spd_mult"]) * 100), UI.BLUE, 11))
		if float(mods.get("crit", 0)) > 0:
			chips.add_child(UI.pill("暴击 +%d%%" % int(float(mods["crit"]) * 100), UI.GOLD, 11))
	body.add_child(chips)
	var extra := UI.vbox(3)
	if str(t.get("starter_affix", "")) == "miracle":
		extra.add_child(UI.label("· 主宠普通技能上的词条：2% 概率造成 99999 伤害", 12, UI.MUTED))
	if int(t.get("pick_items", 0)) > 0:
		extra.add_child(UI.label("· 开局自选 %d 件道具" % int(t["pick_items"]), 12, UI.MUTED))
	if bool(t.get("hero_starter", false)):
		extra.add_child(UI.label("· 初始精灵从英雄中选择", 12, UI.MUTED))
	if int(t.get("start_items", 0)) > 0:
		extra.add_child(UI.label("· 开局获得 %d 件随机道具" % int(t["start_items"]), 12, UI.MUTED))
	extra.add_child(UI.label("· 选中的主宠不封顶，词条可无限叠加", 12, UI.GOLD))
	body.add_child(extra)
	scroll.add_child(body)
	v.add_child(scroll)
	make_click_overlay(p, func(): _select(str(t["id"])))
	cards[str(t["id"])] = p
	return p


func _select(tid: String) -> void:
	selected_id = tid
	for id in cards.keys():
		var card: PanelContainer = cards[id]
		var t: Dictionary = ContentDB.trainers_by_id.get(id, {})
		var color := Color.from_string(str(t.get("color", "#ff8a4c")), UI.ACCENT)
		if id == tid:
			card.add_theme_stylebox_override("panel", UI.soft_style(Color(0.08, 0.10, 0.15, 0.95), color, 2, 18, 22))
			card.scale = Vector2(1.0, 1.0)
		else:
			card.add_theme_stylebox_override("panel", UI.soft_style(Color(0.05, 0.07, 0.11, 0.86), UI.BORDER, 1, 18, 22))
	if confirm != null:
		var t: Dictionary = ContentDB.trainers_by_id.get(tid, {})
		confirm.text = "以「%s」开始远征" % t.get("name", "")


func _confirm() -> void:
	if selected_id.is_empty():
		return
	goto_screen("res://scripts/ui/starter_screen.gd", {"trainer": selected_id})
