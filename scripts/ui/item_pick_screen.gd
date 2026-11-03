extends "res://scripts/ui/screen_base.gd"
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
## Step 3/3 — advanced trainer picks three starting items.

var trainer_id: String = ""
var starter_id: String = ""
var picked: Array = []
var confirm: Button
var chosen_row: HBoxContainer


func _ready() -> void:
	trainer_id = str(params.get("trainer", ""))
	starter_id = str(params.get("starter", ""))
	add_background("forest")
	add_dim(0.46)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := UI.vbox(10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top := UI.hbox(10)
	var back := UI.ghost_button("← 上一步", 14)
	back.custom_minimum_size = Vector2(100, 34)
	back.pressed.connect(func():
		goto_screen("res://scripts/ui/starter_screen.gd", {"trainer": trainer_id}))
	top.add_child(back)
	top.add_child(UI.grow())
	top.add_child(UI.pill("第 3 / 3 步", UI.ACCENT, 13))
	root.add_child(top)

	var head := UI.hbox(12)
	head.add_child(UI.label("选 %d 件开局道具" % _need(), 30, UI.TEXT))
	head.add_child(UI.grow())
	head.add_child(UI.label("同一件可以重复选，但不能超过它的持有上限", 14, UI.MUTED))
	root.add_child(head)

	var slot: Array = ScreenFit.scroll_slot(false)
	root.add_child(slot[0])
	var scroll: ScrollContainer = slot[1]
	var grid := GridContainer.new()
	var usable := ScreenFit.usable(self)
	grid.columns = maxi(2, int((usable.x - 96.0) / 270.0))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for item in ContentDB.data.get("items", []):
		if item.get("pool", true) == false:
			continue
		grid.add_child(_item_card(item))

	chosen_row = UI.hbox(8)
	chosen_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(chosen_row)

	var bottom := UI.hbox(10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm = UI.button("再选 %d 件" % _need(), UI.ACCENT, 18)
	confirm.custom_minimum_size = Vector2(360, 50)
	confirm.disabled = true
	confirm.pressed.connect(_confirm)
	bottom.add_child(confirm)
	root.add_child(bottom)
	_refresh()


func _item_card(item: Dictionary) -> Control:
	var iid := str(item["id"])
	var color := ContentDB.rarity_color(str(item.get("rarity", "common")))
	var card := UI.panel(Color(0.05, 0.07, 0.11, 0.92), color, 12, 12)
	card.custom_minimum_size = Vector2(248, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UI.vbox(4)
	card.add_child(v)
	var name_label := UI.label(str(item.get("name", iid)), 15, color)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_label)
	var desc := UI.label(str(item.get("desc", "")), 12, UI.MUTED, true)
	desc.custom_minimum_size = Vector2(200, 0)
	v.add_child(desc)
	var cap := ContentDB.max_stack_for(iid)
	if cap > 0:
		v.add_child(UI.label("最多持有 %d 件" % cap, 11, UI.FAINT))
	make_click_overlay(card, func(): _add(iid))
	return card


func _add(iid: String) -> void:
	if picked.size() >= _need():
		toast("已经选了 %d 件" % _need(), UI.DANGER)
		return
	var cap := ContentDB.max_stack_for(iid)
	if cap > 0 and picked.count(iid) >= cap:
		toast("这件道具最多带 %d 件" % cap, UI.DANGER)
		return
	picked.append(iid)
	_refresh()


func _remove_one(iid: String) -> void:
	var index := picked.find(iid)
	if index >= 0:
		picked.remove_at(index)
	_refresh()


func _refresh() -> void:
	for child in chosen_row.get_children():
		child.queue_free()
	if picked.is_empty():
		chosen_row.add_child(UI.label("还没有选择道具", 13, UI.FAINT))
	else:
		var seen := {}
		for iid in picked:
			if seen.has(iid):
				continue
			seen[iid] = true
			var item: Dictionary = ContentDB.item(str(iid))
			var n := picked.count(iid)
			var label := str(item.get("name", iid))
			if n > 1:
				label += " ×%d" % n
			var b := UI.ghost_button(label + "  ×", 13)
			b.pressed.connect(_remove_one.bind(str(iid)))
			chosen_row.add_child(b)
	var left := _need() - picked.size()
	confirm.disabled = left != 0
	confirm.text = "带着这 %d 件出发" % _need() if left == 0 else "再选 %d 件" % left


func _confirm() -> void:
	if picked.size() != _need() or starter_id.is_empty():
		return
	GameState.start_run(trainer_id, starter_id, 0, picked)
	goto_screen("res://scripts/ui/formation_screen.gd", {"first": true})


func _need() -> int:
	return maxi(1, GameState.item_pick_count(trainer_id))
