extends "res://scripts/ui/screen_base.gd"
## Run summary — victory or defeat.

var won: bool = false


func _ready() -> void:
	won = bool(params.get("win", GameState.run_won))
	add_background("throne" if won else "night")
	add_dim(0.52)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 54)
	add_child(margin)
	var root := UI.vbox(16)
	margin.add_child(root)

	var kicker := UI.label("RUN COMPLETE · 星塔远征" if won else "RUN OVER · 远征终止", 12, UI.FAINT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(kicker)
	var title := UI.label("登 顶 成 功" if won else "远 征 结 束", 56, UI.GOLD if won else UI.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := UI.label(
		"你与契约精灵一起征服了十层星塔。" if won else "星塔仍在等待下一次挑战。",
		17, UI.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	root.add_child(UI.spacer(0, 10))

	var stats_panel := UI.panel(Color(0.04, 0.06, 0.10, 0.9), UI.BORDER, 18, 20)
	stats_panel.custom_minimum_size = Vector2(0, 0)
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_panel.custom_minimum_size.x = 720
	root.add_child(stats_panel)
	var stats_row := UI.hbox(10)
	stats_panel.add_child(stats_row)
	var summary: Dictionary = GameState.run_summary()
	var cells := [
		["抵达层数", "第 %d 层" % int(summary["floor"]), UI.GOLD],
		["通过层数", "%d / 10" % int(summary["floors_cleared"]), UI.GOOD],
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
	roster_flow.custom_minimum_size = Vector2(0, 0)
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

	root.add_child(UI.grow())
	var record := UI.label("历史最佳：第 %d 层 · 远征 %d 次 · 登顶 %d 次" % [
		GameState.best_floor, GameState.total_runs, GameState.total_wins], 13, UI.FAINT)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(record)
	var buttons := UI.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UI.button("再 来 一 局", UI.ACCENT, 18)
	again.custom_minimum_size = Vector2(240, 52)
	again.pressed.connect(func(): goto_screen("res://scripts/ui/trainer_screen.gd"))
	buttons.add_child(again)
	var back := UI.button("返回标题", Color.TRANSPARENT, 16)
	back.custom_minimum_size = Vector2(180, 52)
	back.pressed.connect(func(): goto_screen("res://scripts/ui/title_screen.gd"))
	buttons.add_child(back)
	var quit := UI.ghost_button("退出游戏", 14)
	quit.custom_minimum_size = Vector2(120, 52)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	root.add_child(buttons)
