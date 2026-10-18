extends "res://scripts/ui/screen_base.gd"
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
	var starters: Array = ContentDB.data.get("starters", [])
	if not starters.is_empty():
		_select(str(starters[0]["id"]))


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var root := UI.vbox(12)
	margin.add_child(root)

	var top := UI.hbox(10)
	var back := UI.ghost_button("← 上一步", 14)
	back.custom_minimum_size = Vector2(100, 34)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/trainer_screen.gd"))
	top.add_child(back)
	top.add_child(UI.grow())
	var trainer: Dictionary = ContentDB.trainers_by_id.get(trainer_id, {})
	top.add_child(UI.pill(str(trainer.get("name", "训练家")) + " · " + str(trainer.get("title", "")), UI.GOLD, 13))
	top.add_child(UI.pill("第 2 / 2 步", UI.ACCENT, 13))
	root.add_child(top)

	var head := UI.hbox(14)
	head.add_child(UI.label("契约你的第一只精灵", 32, UI.TEXT))
	head.add_child(UI.grow())
	head.add_child(UI.label("未选择的两位伙伴会进入宝箱候选池", 14, UI.MUTED))
	root.add_child(head)

	var row := UI.hbox(20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var starters: Array = ContentDB.data.get("starters", [])
	for s in starters:
		row.add_child(_starter_card(s))

	var bottom := UI.hbox(10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm = UI.button("契约成立，进入星塔", UI.ACCENT, 19)
	confirm.custom_minimum_size = Vector2(380, 52)
	confirm.pressed.connect(_confirm)
	bottom.add_child(confirm)
	root.add_child(bottom)


func _starter_card(s: Dictionary) -> Control:
	var pid := str(s["id"])
	var p: Dictionary = ContentDB.pet(pid)
	var element := str(p.get("element", "fire"))
	var cls := str(p.get("class", "warrior"))
	var el_color := ContentDB.element_color(element)
	var stats: Dictionary = ContentDB.pet_stats(pid, 10)
	var card := UI.panel(Color(0.05, 0.07, 0.11, 0.92), UI.BORDER, 18, 20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(pid))
	var v := UI.vbox(8)
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

	var normal: Dictionary = p["skills"]["normal"]
	var ult: Dictionary = p["skills"]["ultimate"]
	v.add_child(UI.label("普攻 · " + str(normal["name"]), 14, UI.TEXT))
	v.add_child(UI.label(str(normal.get("desc", "")), 12, UI.MUTED, true))
	v.add_child(UI.label("大招 · " + str(ult["name"]), 14, el_color))
	v.add_child(UI.label(str(ult.get("desc", "")), 12, UI.MUTED, true))
	var note := UI.label(str(s.get("note", "")), 12, UI.GOLD, true)
	v.add_child(note)
	make_click_overlay(card, func(): _select(pid))
	cards[pid] = card
	return card


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
		confirm.text = "契约「%s」并进入星塔" % ContentDB.pet_display_name(pid, 10)


func _confirm() -> void:
	if selected_id.is_empty():
		return
	GameState.start_run(trainer_id, selected_id)
	goto_screen("res://scripts/ui/formation_screen.gd", {"first": true})
