extends "res://scripts/ui/screen_base.gd"
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
const SpiritPool = preload("res://scripts/core/spirit_pool.gd")
## Step 2/2 — starter selection.

var trainer_id: String = ""
var selected_id: String = ""
var cards: Dictionary = {}
var confirm: Button


func _ready() -> void:
	trainer_id = str(params.get("trainer", ""))
	if trainer_id.is_empty():
		var trainers: Array = ContentDB.data.get("trainers", [])
		if not trainers.is_empty():
			trainer_id = str(trainers[0]["id"])
	add_background("forest")
	add_dim(0.46)
	_build()
	var first: Array = _starter_options(bool(ContentDB.trainers_by_id.get(trainer_id, {}).get("hero_starter", false)))
	if not first.is_empty():
		_select(str(first[0]["id"]))


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var root := UI.vbox(12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top := UI.hbox(10)
	var back := UI.ghost_button("← 上一步", 14)
	back.custom_minimum_size = Vector2(100, 34)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/trainer_screen.gd"))
	top.add_child(back)
	top.add_child(UI.grow())
	var trainer: Dictionary = ContentDB.trainers_by_id.get(trainer_id, {})
	top.add_child(UI.pill(str(trainer.get("name", "训练家")) + " · " + str(trainer.get("title", "")), UI.GOLD, 13))
	var picks := int(trainer.get("pick_items", 0))
	top.add_child(UI.pill("第 2 / %d 步" % (3 if picks > 0 else 2), UI.ACCENT, 13))
	root.add_child(top)

	var hero_start := bool(trainer.get("hero_starter", false))
	var head := UI.hbox(14)
	head.add_child(UI.label("契约你的第一只英雄" if hero_start else "契约你的第一只精灵", 32, UI.TEXT))
	head.add_child(UI.grow())
	var hint := "未选择的英雄仍会进入宝箱" if hero_start else "未选择的两位伙伴会进入宝箱候选池"
	head.add_child(UI.label(hint, 14, UI.MUTED))
	root.add_child(head)
	root.add_child(UI.label("这只主宠没有等级上限，技能词条也可以一直叠加。", 13, UI.GOLD))

	var slot: Array = ScreenFit.scroll_slot(true)
	root.add_child(slot[0])
	var scroll: ScrollContainer = slot[1]
	# The row itself must not grow. A tall card scrolls inside itself so the
	# confirm button under the row stays on screen.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var options := _starter_options(hero_start)
	var box := ScreenFit.card_box(self, options.size(), 20.0, 56.0, 230.0)
	var row := UI.hbox(20)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	for s in options:
		row.add_child(_starter_card(s, box))

	var bottom := UI.hbox(10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm = UI.button(_confirm_caption(""), UI.ACCENT, 19)
	confirm.custom_minimum_size = Vector2(380, 52)
	confirm.pressed.connect(_confirm)
	bottom.add_child(confirm)
	root.add_child(bottom)


func _starter_card(s: Dictionary, box: Vector2) -> Control:
	var pid := str(s["id"])
	var p: Dictionary = ContentDB.pet(pid)
	var element := str(p.get("element", "fire"))
	var cls := str(p.get("class", "warrior"))
	var el_color := ContentDB.element_color(element)
	var stats: Dictionary = ContentDB.pet_stats(pid, 10)
	var card := UI.panel(Color(0.05, 0.07, 0.11, 0.92), UI.BORDER, 18, 20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(box.x, 0)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(pid))
	var v := UI.vbox(8)
	# Let clicks on the portrait and stats fall through to the card. The skill
	# scroller below keeps its own mouse events so it can scroll.
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 136)
	v.add_child(holder)
	var av := UI.avatar(pid, 126, 10)
	holder.add_child(av)

	var name_label := UI.label(ContentDB.pet_display_name(pid, 10), 25, UI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var tags := UI.hbox(6)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(UI.pill(ContentDB.element_name(element), el_color, 12))
	tags.add_child(UI.pill(ContentDB.class_name_for(cls), ContentDB.class_color(cls), 12))
	v.add_child(tags)

	var role := UI.label(str(ContentDB.data["classes"].get(cls, {}).get("role", "")), 13, UI.MUTED)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(role)
	v.add_child(UI.hline(Color(el_color.r, el_color.g, el_color.b, 0.28), 1))

	var stat_row := UI.hbox(6)
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["生命", "hp", UI.GOOD], ["攻击", "atk", UI.ACCENT], ["防御", "def", UI.BLUE], ["速度", "spd", UI.GOLD]]:
		var cell := UI.vbox(1)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap := UI.label(str(pair[0]), 11, UI.FAINT)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cap)
		var val := UI.label(ContentDB.fmt(int(stats[pair[1]])), 15, pair[2])
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(val)
		stat_row.add_child(cell)
	v.add_child(stat_row)
	v.add_child(UI.hline(UI.BORDER, 1))

	# Head and stats stay fixed. Skill lines and the note scroll inside the
	# card, and the card itself stays inside the row so "下一步" is not pushed off.
	var scroll := ScreenFit.scrolling_body()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 64)
	var body := UI.vbox(6)
	body.custom_minimum_size = Vector2(maxf(160.0, box.x - 48.0), 0)
	for raw in SpiritPool.starter_arts(p):
		var art: Dictionary = raw
		var line := UI.label(SpiritPool.art_text(art), 12, UI.TEXT, true)
		body.add_child(line)
	var note := UI.label(str(s.get("note", "")), 12, UI.GOLD, true)
	body.add_child(note)
	scroll.add_child(body)
	v.add_child(scroll)
	_pass_clicks(v, scroll)
	cards[pid] = card
	return card


func _pass_clicks(root: Node, keep: Node) -> void:
	if root == keep:
		return
	if root is Control:
		(root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		_pass_clicks(child, keep)


func _select(pid: String) -> void:
	selected_id = pid
	for id in cards.keys():
		var card: PanelContainer = cards[id]
		var p: Dictionary = ContentDB.pet(id)
		var color := ContentDB.element_color(str(p.get("element", "fire")))
		if id == pid:
			card.add_theme_stylebox_override("panel", UI.soft_style(Color(0.08, 0.10, 0.15, 0.97), color, 2, 18, 20))
		else:
			card.add_theme_stylebox_override("panel", UI.soft_style(Color(0.05, 0.07, 0.11, 0.9), UI.BORDER, 1, 18, 20))
	if confirm != null:
		confirm.text = _confirm_caption(pid)


func _starter_options(hero_start: bool) -> Array:
	if not hero_start:
		return ContentDB.data.get("starters", [])
	var out: Array = []
	for p in ContentDB.data.get("pets", []):
		if str(p.get("rarity", "")) != "hero":
			continue
		out.append({
			"id": str(p["id"]),
			"note": "英雄精灵。开局即为英雄，可以升星，也能打碎魔王屏障。",
		})
	return out


func _confirm_caption(pid: String) -> String:
	var picks := int(ContentDB.trainers_by_id.get(trainer_id, {}).get("pick_items", 0))
	if pid.is_empty():
		return "下一步 · 选择开局道具" if picks > 0 else "下一步 · 进入星塔"
	var name := ContentDB.pet_display_name(pid, 10)
	if picks > 0:
		return "下一步 · 为「%s」选道具" % name
	return "下一步 · 契约「%s」" % name


func _confirm() -> void:
	if selected_id.is_empty():
		return
	var trainer: Dictionary = ContentDB.trainers_by_id.get(trainer_id, {})
	if int(trainer.get("pick_items", 0)) > 0:
		goto_screen("res://scripts/ui/item_pick_screen.gd", {"trainer": trainer_id, "starter": selected_id})
		return
	GameState.start_run(trainer_id, selected_id)
	goto_screen("res://scripts/ui/formation_screen.gd", {"first": true})
