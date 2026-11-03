extends "res://scripts/ui/screen_base.gd"
## Every third tower floor: pick a fight, an elite, a shop or an event.


func _ready() -> void:
	GameState.note_screen("route")
	if GameState.pending_route.is_empty() or int(GameState.pending_route.get("floor", -1)) != GameState.current_floor:
		GameState.roll_route()
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.45)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var root := UI.vbox(14)
	margin.add_child(root)
	var top := UI.hbox(12)
	top.add_child(UI.label("选择道路", 32, UI.GOLD))
	top.add_child(UI.pill("第 %d 层" % GameState.current_floor, UI.BLUE, 12))
	top.add_child(UI.grow())
	top.add_child(UI.pill("金币 %d" % GameState.gold, UI.GOLD, 13))
	root.add_child(top)
	root.add_child(UI.label("三条路里选一条。魔王层不绕路。", 15, UI.MUTED))
	var row := UI.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for opt in GameState.pending_route.get("options", []):
		row.add_child(_card(opt))


func _card(opt: Dictionary) -> Control:
	var accent := Color(str(opt.get("color", "#ffffff")))
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.95), accent, 3, 18)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(10)
	panel.add_child(v)
	var title := UI.label(str(opt.get("title", "道路")), 24, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var desc := UI.label(str(opt.get("desc", "")), 14, UI.TEXT, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	v.add_child(UI.grow())
	var pick := UI.button("选 择", accent, 16)
	pick.custom_minimum_size = Vector2(0, 46)
	pick.pressed.connect(func(): _choose(str(opt.get("kind", "fight"))))
	v.add_child(pick)
	return panel


func _choose(kind: String) -> void:
	var where := GameState.apply_route(kind)
	_open(where)


func _open(where: String) -> void:
	match where:
		"shop":
			goto_screen("res://scripts/ui/shop_screen.gd")
		"event":
			goto_screen("res://scripts/ui/event_screen.gd")
		_:
			goto_screen("res://scripts/ui/map_screen.gd")
