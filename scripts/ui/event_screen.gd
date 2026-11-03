extends "res://scripts/ui/screen_base.gd"
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
## Between-floor event: pick one of three random boons before climbing on.

var option_host: HBoxContainer
var chosen: bool = false


func _ready() -> void:
	GameState.note_screen("event")
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.45)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var root := UI.vbox(16)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top := UI.hbox(12)
	top.add_child(UI.label("层 间 奇 遇", 34, UI.GOLD))
	if GameState.run_mode == "conquest":
		top.add_child(UI.pill("星塔征服战 · 第 %d 层" % GameState.current_floor, UI.BLUE, 12))
	else:
		top.add_child(UI.pill("第 %d 层奇遇" % GameState.current_floor, UI.BLUE, 12))
	top.add_child(UI.grow())
	var menu := UI.ghost_button("菜单", 13)
	menu.custom_minimum_size = Vector2(64, 30)
	menu.pressed.connect(open_run_menu)
	top.add_child(menu)
	top.add_child(UI.label("三选一 · 效果立即生效", 13, UI.MUTED))
	root.add_child(top)
	root.add_child(UI.label("这一层是奇遇。选择一项祝福，或跳过本层。试炼会立刻在本层开战。", 15, UI.MUTED, true))
	root.add_child(UI.hline(UI.BORDER, 1))

	var slot: Array = ScreenFit.scroll_slot(true)
	root.add_child(slot[0])
	option_host = UI.hbox(20)
	option_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(slot[1] as ScrollContainer).add_child(option_host)
	var pending: Dictionary = GameState.pending_event
	var options: Array = pending.get("options", [])
	var box := ScreenFit.card_box(self, options.size(), 20.0, 56.0, 250.0)
	for opt in options:
		option_host.add_child(_option_card(opt, box))

	var bottom := UI.hbox(12)
	bottom.add_child(UI.label("跳过奇遇不会得到任何奖励，但也不会带来风险。", 12, UI.FAINT))
	bottom.add_child(UI.grow())
	var skip := UI.ghost_button("跳过奇遇", 15)
	skip.custom_minimum_size = Vector2(140, 44)
	skip.pressed.connect(_skip)
	bottom.add_child(skip)
	root.add_child(bottom)


func _option_card(opt: Dictionary, box: Vector2) -> Control:
	var accent := Color(str(opt.get("color", "#ffffff")))
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.95), accent, 3, 22)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(box.x, 0)
	panel.clip_contents = false
	var v := UI.vbox(12)
	panel.add_child(v)
	var title := UI.label(str(opt.get("title", "奇遇")), 25, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UI.hline(Color(accent.r, accent.g, accent.b, 0.35), 1))
	var scroll := ScreenFit.scrolling_body()
	scroll.custom_minimum_size = Vector2(0, maxf(80.0, box.y - 160.0))
	var desc := UI.label(str(opt.get("desc", "")), 14, UI.TEXT, true)
	desc.custom_minimum_size = Vector2(maxf(160.0, box.x - 56.0), 0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.add_child(desc)
	v.add_child(scroll)
	var pick := UI.button("选 择", accent, 17)
	pick.custom_minimum_size = Vector2(0, 50)
	pick.pressed.connect(func(): _choose(opt))
	v.add_child(pick)
	return panel


func _choose(opt: Dictionary) -> void:
	if chosen:
		return
	chosen = true
	for c in option_host.get_children():
		for node in c.find_children("*", "Button", true, false):
			(node as Button).disabled = true
	var text := GameState.apply_event(opt)
	_show_result(text)


func _skip() -> void:
	if chosen:
		return
	chosen = true
	GameState.skip_event()
	_advance()


func _show_result(text: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.015, 0.03, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.98), UI.GOLD, 20, 28)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	var title := UI.label("奇 遇 结 算", 28, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := UI.label(text, 16, UI.TEXT, true)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	v.add_child(UI.hline(UI.BORDER, 1))
	var go_label := "进入试炼" if GameState.event_battle else "继续前进"
	var go := UI.button(go_label, UI.ACCENT, 18)
	go.custom_minimum_size = Vector2(0, 50)
	go.pressed.connect(_advance)
	v.add_child(go)


func _advance() -> void:
	if GameState.event_battle:
		GameState.event_battle = false
		goto_screen("res://scripts/ui/map_screen.gd")
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
