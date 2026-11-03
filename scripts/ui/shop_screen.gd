extends "res://scripts/ui/screen_base.gd"
## Gold shop on a chosen route floor. Leaving the shop skips the fight.

var gold_label: Label
var host: VBoxContainer
var stock: Array = []


func _ready() -> void:
	GameState.note_screen("shop")
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.5)
	_build()
	_roll_stock()
	_fill()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := UI.vbox(10)
	margin.add_child(root)
	var top := UI.hbox(10)
	top.add_child(UI.label("行商", 30, UI.GOLD))
	top.add_child(UI.grow())
	gold_label = UI.label("", 16, UI.GOLD)
	top.add_child(gold_label)
	root.add_child(top)
	root.add_child(UI.label("买完离开后进入下一层，这一层不再战斗。词条上限每次 80 金币，最高 9。", 13, UI.MUTED, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	host = UI.vbox(8)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(host)
	var leave := UI.button("离开行商", UI.ACCENT, 16)
	leave.custom_minimum_size = Vector2(220, 46)
	leave.pressed.connect(_leave)
	root.add_child(leave)


func _fill() -> void:
	gold_label.text = "金币 %d" % GameState.gold
	UI.clear_children(host)
	for offer in stock:
		var kind := str(offer.get("kind", ""))
		var iid := str(offer.get("id", ""))
		var price := int(offer.get("price", 0))
		if kind == "item":
			_row(str(offer.get("name", "")), price, _buy_item.bind(iid, price))
		else:
			_row("词条 · " + str(offer.get("name", "")), price, _buy_affix.bind(iid, price))
	_row("灵契球", 28, _buy_item.bind("pokeball", 28))
	for entry in GameState.roster_view():
		if bool(entry.get("uncapped", false)):
			continue
		var cap := GameState.pet_affix_cap(entry)
		var uid := int(entry["uid"])
		_row("%s 词条上限 %d → %d" % [GameState.pet_name(entry), cap, mini(9, cap + 1)], 80, _raise_cap.bind(uid))


func _row(title: String, price: int, action: Callable) -> void:
	var row := UI.hbox(8)
	var name := UI.label(title, 15, UI.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name)
	var b := UI.button("%d 金币" % price, UI.GOLD, 13)
	b.custom_minimum_size = Vector2(120, 36)
	b.pressed.connect(action)
	row.add_child(b)
	host.add_child(row)


func _roll_stock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed + GameState.current_floor * 17
	stock = []
	for i in range(3):
		var it: Dictionary = ContentDB.random_item(rng, 0.2, ["barrier_blade", "pokeball"])
		if it.is_empty():
			continue
		stock.append({"kind": "item", "id": str(it.get("id", "")), "name": str(it.get("name", "")),
			"price": _price(str(it.get("rarity", "common")))})
	for i in range(2):
		var a: Dictionary = ContentDB.random_affix(rng)
		if a.is_empty():
			continue
		stock.append({"kind": "affix", "id": str(a.get("id", "")), "name": str(a.get("name", "")),
			"price": _price(str(a.get("rarity", "common")))})


func _take_stock(iid: String) -> void:
	for i in range(stock.size()):
		if str(stock[i].get("id", "")) == iid:
			stock.remove_at(i)
			return


func _price(rarity: String) -> int:
	return {"common": 36, "rare": 64, "epic": 100}.get(rarity, 64)


func _spend(price: int) -> bool:
	if GameState.gold < price:
		toast("金币不够", UI.DANGER)
		return false
	GameState.gold -= price
	return true


func _buy_item(iid: String, price: int) -> void:
	if iid == "" or not _spend(price):
		return
	if not GameState.add_item(iid):
		GameState.gold += price
		toast("这件道具已经拿满了", UI.DANGER)
		return
	if iid != "pokeball":
		_take_stock(iid)
	toast("已放入行囊", UI.GOOD)
	_fill()


func _buy_affix(aid: String, price: int) -> void:
	if aid == "" or not _spend(price):
		return
	GameState.affix_bag.append(aid)
	_take_stock(aid)
	toast("词条已放入背包", UI.GOOD)
	_fill()


func _raise_cap(uid: int) -> void:
	toast(GameState.raise_affix_cap(uid), UI.GOLD)
	_fill()


func _leave() -> void:
	GameState.leave_shop()
	var where := GameState.destination_after_floor()
	if where == "route":
		goto_screen("res://scripts/ui/route_screen.gd")
	elif where == "event":
		goto_screen("res://scripts/ui/event_screen.gd")
	else:
		goto_screen("res://scripts/ui/map_screen.gd")
