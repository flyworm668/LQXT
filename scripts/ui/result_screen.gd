extends "res://scripts/ui/screen_base.gd"
## Run summary — victory scrolls up like credits; defeat stays a static card.

var won: bool = false
var summit_scroll: ScrollContainer
var summit_reel: VBoxContainer
var summit_lead: Control
var summit_tail: Control
var summit_body: Control
var skip_button: Button
var fast_hint: Label
var summit_corner: Control
var scroll_px := 0.0
var summit_ready := false
var summit_done := false
var summit_fast := false
var settle_now := false

const SCROLL_SPEED := 72.0
const FAST_SPEED := 460.0


func _ready() -> void:
	won = bool(params.get("win", GameState.run_won))
	add_background("throne" if won else "night")
	add_dim(0.52)
	if won:
		_build_summit()
	else:
		_build_defeat()


func _build_defeat() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 54)
	add_child(margin)
	var root := UI.vbox(16)
	margin.add_child(root)
	_fill_summary(root, false)
	root.add_child(UI.grow())
	root.add_child(_record_label())
	root.add_child(_action_buttons(false))


func _build_summit() -> void:
	summit_scroll = ScrollContainer.new()
	summit_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(summit_scroll)
	summit_reel = UI.vbox(0)
	summit_reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summit_scroll.add_child(summit_reel)
	summit_lead = UI.spacer(0, 720)
	summit_reel.add_child(summit_lead)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summit_reel.add_child(center)
	summit_body = UI.vbox(16)
	summit_body.custom_minimum_size.x = 880
	center.add_child(summit_body)
	_fill_summary(summit_body, true)
	summit_body.add_child(_record_label())
	summit_body.add_child(_action_buttons(true))
	summit_body.add_child(UI.spacer(0, 28))
	summit_tail = UI.spacer(0, 720)
	summit_reel.add_child(summit_tail)

	summit_corner = UI.hbox(8)
	summit_corner.z_index = 40
	summit_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(summit_corner)
	skip_button = UI.ghost_button("跳过", 14)
	skip_button.custom_minimum_size = Vector2(88, 34)
	skip_button.pressed.connect(finish_scroll)
	summit_corner.add_child(skip_button)
	var home := UI.ghost_button("返回主页", 14)
	home.custom_minimum_size = Vector2(108, 34)
	home.pressed.connect(func(): goto_screen("res://scripts/ui/title_screen.gd"))
	summit_corner.add_child(home)

	fast_hint = UI.label("点击屏幕快进", 13, UI.FAINT)
	fast_hint.z_index = 40
	fast_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fast_hint)


func _fill_summary(root: VBoxContainer, victory: bool) -> void:
	var in_conquest := GameState.run_mode == "conquest"
	var conquest := victory and (GameState.conquest_clear or in_conquest)
	var kicker := UI.label("RUN COMPLETE · 星塔征服" if conquest else ("RUN COMPLETE · 星塔远征" if victory else ("RUN OVER · 征服终止" if in_conquest else "RUN OVER · 远征终止")), 12, UI.FAINT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(kicker)
	var title := UI.label("征 服 星 塔" if conquest else ("登 顶 成 功" if victory else ("征 服 中 断" if in_conquest else "远 征 结 束")), 56, UI.GOLD if victory else UI.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := UI.label(
		"五位魔王同时倒下，星塔被征服了。" if conquest else ("你与契约精灵一起征服了四十层星塔。" if victory else ("这一次没有打穿五魔王阵。" if in_conquest else "星塔仍在等待下一次挑战。")),
		17, UI.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	if GameState.wonder_line:
		var wonder := UI.label("神奇的力量触发了", 16, UI.GOLD)
		wonder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(wonder)
		GameState.wonder_line = false
		GameState.save_record()
	root.add_child(UI.spacer(0, 10))

	var stats_panel := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 18, 20)
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(stats_panel)
	var stats_row := UI.hbox(10)
	stats_panel.add_child(stats_row)
	var summary: Dictionary = GameState.run_summary()
	var cells := [
		["抵达", "星塔征服战" if in_conquest else "第 %d 层" % int(summary["floor"]), UI.GOLD],
		["通过", "征服星塔" if conquest else ("未征服" if in_conquest else "%d / %d" % [int(summary["floors_cleared"]), ContentDB.total_floors()]), UI.GOOD],
		["收集精灵", "%d 只" % int(summary["roster"]), UI.BLUE],
		["道具 / 词条", "%d / %d" % [int(summary["items"]), int(summary["affixes"])], UI.PURPLE],
		["训练家", str(summary["trainer"]), UI.TEXT],
		["随机种子", "#%d" % int(summary["seed"]), UI.MUTED],
	]
	for c in cells:
		var cell := UI.vbox(3)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.x = 96
		var cap := UI.label(str(c[0]), 11, UI.FAINT)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cap)
		var val := UI.label(str(c[1]), 18, c[2])
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(val)
		stats_row.add_child(cell)

	var team_cap := UI.label("最终队伍", 13, UI.MUTED)
	team_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(team_cap)
	var roster_wrap := CenterContainer.new()
	root.add_child(roster_wrap)
	var roster_flow := HFlowContainer.new()
	roster_flow.add_theme_constant_override("h_separation", 10)
	roster_flow.add_theme_constant_override("v_separation", 8)
	roster_flow.custom_minimum_size = Vector2(860, 0)
	roster_wrap.add_child(roster_flow)
	for entry in GameState.roster:
		var pid := str(entry["species"])
		var cell := UI.vbox(1)
		cell.custom_minimum_size = Vector2(82, 0)
		var holder := CenterContainer.new()
		holder.add_child(UI.avatar(pid, 54, int(entry["level"])))
		cell.add_child(holder)
		var nm := UI.label(GameState.pet_name(entry), 10, UI.MUTED)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(nm)
		roster_flow.add_child(cell)


func _record_label() -> Label:
	var record := UI.label("历史最佳：第 %d 层 · 远征 %d 次 · 登顶 %d 次" % [
		GameState.best_floor, GameState.total_runs, GameState.total_wins], 13, UI.FAINT)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return record


func _action_buttons(victory: bool) -> HBoxContainer:
	var buttons := UI.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UI.button("再 来 一 局", UI.ACCENT, 18)
	again.custom_minimum_size = Vector2(240, 52)
	again.pressed.connect(func(): goto_screen("res://scripts/ui/trainer_screen.gd"))
	buttons.add_child(again)
	var back := UI.button("返回主页" if victory else "返回标题", Color.TRANSPARENT, 16)
	back.custom_minimum_size = Vector2(180, 52)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/title_screen.gd"))
	buttons.add_child(back)
	var quit := UI.ghost_button("退出游戏", 14)
	quit.custom_minimum_size = Vector2(120, 52)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	return buttons


func _process(delta: float) -> void:
	if not won or summit_scroll == null:
		return
	var vp := summit_scroll.size.y
	if vp < 32.0 or summit_body == null:
		return
	summit_lead.custom_minimum_size.y = vp
	summit_tail.custom_minimum_size.y = vp
	if summit_corner != null:
		var corner_size := summit_corner.size
		if corner_size.x < 8.0:
			corner_size = summit_corner.get_combined_minimum_size()
		summit_corner.position = Vector2(get_viewport_rect().size.x - corner_size.x - 28.0, 22.0)
	if fast_hint != null and not summit_done:
		var hint_size := fast_hint.size
		if hint_size.x < 8.0:
			hint_size = fast_hint.get_combined_minimum_size()
		fast_hint.position = Vector2(get_viewport_rect().size.x * 0.5 - hint_size.x * 0.5, vp - 42.0)
	var summary_h := summit_body.size.y
	if summary_h < 8.0:
		return
	if summit_done:
		return
	var max_scroll := maxf(0.0, summit_lead.size.y + summary_h + summit_tail.size.y - vp)
	var target := _rest_scroll(vp, summary_h, max_scroll)
	if settle_now:
		scroll_px = target
		summit_scroll.scroll_vertical = int(target)
		_finish_scroll()
		return
	if not summit_ready:
		summit_ready = true
		scroll_px = 0.0
	var speed := FAST_SPEED if summit_fast else SCROLL_SPEED
	if scroll_px < target:
		scroll_px = minf(target, scroll_px + speed * delta)
	summit_scroll.scroll_vertical = int(scroll_px)
	if scroll_px >= target - 0.5:
		summit_scroll.scroll_vertical = int(target)
		_finish_scroll()


func _rest_scroll(vp: float, summary_h: float, max_scroll: float) -> float:
	var target: float
	if summary_h + 120.0 <= vp:
		var top_on_screen := maxf(78.0, (vp - summary_h) * 0.5)
		target = vp - top_on_screen
	else:
		target = summary_h + 48.0
	return clampf(target, 0.0, max_scroll)


func _finish_scroll() -> void:
	summit_done = true
	summit_fast = false
	settle_now = false
	if skip_button != null:
		skip_button.visible = false
	if fast_hint != null:
		fast_hint.visible = false
	if summit_scroll != null:
		summit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func finish_scroll() -> void:
	settle_now = true


func _input(event: InputEvent) -> void:
	if not won or summit_done or not summit_ready:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hovered := get_viewport().gui_get_hovered_control()
		var node: Node = hovered
		while node != null:
			if node is BaseButton:
				return
			node = node.get_parent()
		summit_fast = true
		if fast_hint != null:
			fast_hint.text = "快进中"
		get_viewport().set_input_as_handled()
