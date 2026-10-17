extends "res://scripts/ui/screen_base.gd"
## Title screen.


func _ready() -> void:
	add_background("temple")
	add_dim(0.26)
	_build_top_right()
	_build_main()
	_build_footer()


func _build_top_right() -> void:
	var rec := UI.panel(Color(0.03, 0.05, 0.09, 0.72), UI.BORDER, 12, 14)
	rec.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	rec.position = Vector2(1280 - 360, 24)
	rec.custom_minimum_size = Vector2(336, 0)
	var v := UI.vbox(3)
	rec.add_child(v)
	var title := UI.label("远征记录", 13, UI.FAINT)
	v.add_child(title)
	var text := "最佳抵达：第 %d 层    远征 %d 次    登顶 %d 次" % [
		GameState.best_floor, GameState.total_runs, GameState.total_wins]
	v.add_child(UI.label(text, 14, UI.TEXT))
	add_child(rec)


func _build_main() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 76)
	margin.add_theme_constant_override("margin_right", 76)
	margin.add_theme_constant_override("margin_top", 130)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)
	var row := UI.hbox(40)
	margin.add_child(row)

	var left := UI.vbox(14)
	left.custom_minimum_size = Vector2(560, 0)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)

	left.add_child(UI.label("ROGUELIKE · TOWER CLIMB · 2010s NOSTALGIA", 12, UI.FAINT))
	var title := UI.label("灵契 · 星塔远征", 56, UI.GOLD)
	title.add_theme_constant_override("outline_size", 0)
	left.add_child(title)
	var sub := UI.label("轻量化怀旧肉鸽爬塔 · 单机版", 22, UI.TEXT)
	left.add_child(sub)
	var desc := UI.label("契约 50 只可进化精灵，在九宫格中排兵布阵，\n攀上十层星塔，收集宝箱、道具与技能词条。", 16, UI.MUTED, true)
	desc.custom_minimum_size = Vector2(520, 0)
	left.add_child(desc)
	left.add_child(UI.spacer(0, 14))

	var start := UI.button("开 始 远 征", UI.ACCENT, 20)
	start.custom_minimum_size = Vector2(320, 56)
	start.pressed.connect(func(): goto_screen("res://scripts/ui/trainer_screen.gd"))
	left.add_child(start)
	var help := UI.button("玩 法 说 明", Color.TRANSPARENT, 17)
	help.custom_minimum_size = Vector2(320, 46)
	help.pressed.connect(_show_help)
	left.add_child(help)
	var quit := UI.ghost_button("退出游戏", 15)
	quit.custom_minimum_size = Vector2(320, 38)
	quit.pressed.connect(func(): get_tree().quit())
	left.add_child(quit)

	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_build_starter_art(right)


func _build_starter_art(host: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(center)
	var plate := UI.panel(Color(0.025, 0.04, 0.07, 0.55), Color(0.3, 0.45, 0.7, 0.35), 24, 20)
	plate.custom_minimum_size = Vector2(440, 300)
	center.add_child(plate)
	var v := UI.vbox(8)
	plate.add_child(v)
	v.add_child(UI.label("三主宠 · 契约候选", 15, UI.MUTED))
	var avatars := UI.hbox(14)
	v.add_child(avatars)
	var starters: Array = ContentDB.data.get("starters", [])
	var idx := 0
	for s in starters:
		var pid := str(s["id"])
		var p: Dictionary = ContentDB.pet(pid)
		var col := UI.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(126, 130)
		col.add_child(holder)
		var av := UI.avatar(pid, 112, 10)
		holder.add_child(av)
		var nm := UI.label(ContentDB.pet_display_name(pid, 10), 18, UI.TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		var tags := UI.hbox(5)
		tags.alignment = BoxContainer.ALIGNMENT_CENTER
		tags.add_child(UI.pill(ContentDB.element_name(str(p.get("element", ""))), ContentDB.element_color(str(p.get("element", ""))), 11))
		tags.add_child(UI.pill(ContentDB.class_name_for(str(p.get("class", ""))), ContentDB.class_color(str(p.get("class", ""))), 11))
		col.add_child(tags)
		avatars.add_child(col)
		var t := create_tween().set_loops()
		var delay := 0.4 * float(idx)
		t.tween_interval(delay)
		t.tween_property(av, "rotation", 0.035, 1.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(av, "rotation", -0.035, 1.6).set_trans(Tween.TRANS_SINE)
		idx += 1
	var note := UI.label("未选择的主宠仍会出现在宝箱候选池中", 12, UI.FAINT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)


func _build_footer() -> void:
	var foot := UI.label("原创矢量美术 · 纯单机 · 无内购 · 无联网", 12, UI.FAINT)
	foot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	foot.position = Vector2(76, 682)
	add_child(foot)
	var keys := UI.label("F11 全屏", 12, UI.FAINT)
	keys.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	keys.position = Vector2(1160, 682)
	add_child(keys)


func _show_help() -> void:
	var body := UI.vbox(10)
	body.custom_minimum_size.x = 700
	var text := """[color=#ffd166][font_size=19]远征目标[/font_size][/color]
从第一层攀至第十层，击败第四、第八层的首领与塔顶的星蚀龙皇。

[color=#ffd166][font_size=17]开局[/font_size][/color]
· 三选一训练家，获得不同增益。
· 三选一主宠，初始队伍只有这一只精灵。
· 每层胜利后全员等级 +10，精灵在 30 / 60 级时进化。

[color=#ffd166][font_size=17]战斗[/font_size][/color]
· 九宫格 3×3，最多上阵 5 只。前排伤害 +20%，中排无加成，后排伤害 -15%。
· 自动战斗，按速度决定行动顺序。
· 普攻与受击都会积攒气势；气势达到 2 点后，下一次行动释放大招。
· 属性克制造成 125% 伤害，被克制造成 80% 伤害；光暗互克。
· 职业：坦克 / 战士 / 法师 / 射手 / 辅助。

[color=#ffd166][font_size=17]宝箱：三次独立判定[/font_size][/color]
· 100%：获得本层精灵。重复精灵转化为共鸣，永久增强该精灵。
· 50%：获得随机道具。
· 25%：获得技能词条，三选一后附着到某只精灵的某个技能上。
· 每个技能最多 3 条词条，每只精灵最多 6 条。满上限时可替换，或转化为随机道具。

[color=#ffd166][font_size=17]首领[/font_size][/color]
· 小 Boss 随机 1 条增益，大 Boss 随机 2 条。
· 大 Boss 在 70% / 40% 生命时进入更强阶段。

[color=#8894aa]每次远征使用独立随机种子；种子显示在地图上，可用于复盘。[/color]"""
	var r := UI.rich(text, 15, UI.TEXT)
	r.custom_minimum_size = Vector2(700, 0)
	body.add_child(r)
	show_modal("玩法说明", body, 760, 500)
