extends "res://scripts/ui/screen_base.gd"
const TypeChartScript = preload("res://scripts/ui/type_chart.gd")
## Title screen.


func _ready() -> void:
	add_background("temple")
	_add_key_art()
	add_dim(0.5)
	_build_main()
	_build_top_right()
	_build_footer()


func _add_key_art() -> void:
	var path := "res://art/title_key.png"
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var view := TextureRect.new()
	view.texture = tex
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	move_child(view, 1)


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

	var left := UI.vbox(16)
	left.custom_minimum_size = Vector2(420, 0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)

	var title := UI.label("灵契 · 星塔远征", 56, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	left.add_child(UI.spacer(0, 18))
	var start := UI.button("星塔远征", UI.ACCENT, 20)
	start.custom_minimum_size = Vector2(360, 56)
	start.pressed.connect(func():
		GameState.pending_mode = "tower"
		goto_screen("res://scripts/ui/trainer_screen.gd"))
	left.add_child(start)
	start.grab_focus()
	if GameState.tower_cleared:
		var conquest := UI.button("星塔征服", UI.DANGER, 20)
		conquest.custom_minimum_size = Vector2(360, 56)
		conquest.pressed.connect(func():
			GameState.pending_mode = "conquest"
			goto_screen("res://scripts/ui/trainer_screen.gd"))
		left.add_child(conquest)
	else:
		var locked := UI.label("星塔征服 · 登顶一次后开启", 16, UI.FAINT)
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(locked)
	if OS.get_name() == "Android":
		var display := UI.button("画面设置", UI.BLUE, 18)
		display.custom_minimum_size = Vector2(360, 52)
		display.pressed.connect(func():
			preload("res://scripts/ui/run_menu.gd").open_display(self))
		left.add_child(display)
	var load_save := UI.button("读取存档", UI.PURPLE, 18)
	load_save.custom_minimum_size = Vector2(360, 52)
	load_save.pressed.connect(open_load_menu)
	left.add_child(load_save)
	var quit := UI.button("退出游戏", Color.TRANSPARENT, 18)
	quit.custom_minimum_size = Vector2(360, 52)
	quit.pressed.connect(func(): get_tree().quit())
	left.add_child(quit)

	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(520, 420)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func open_run_menu() -> void:
	pass


func _continue_run() -> void:
	var screen := GameState.resume_run()
	if screen == "":
		toast("没有可继续的远征", UI.DANGER)
		return
	match screen:
		"reward":
			goto_screen("res://scripts/ui/reward_screen.gd")
		"event":
			goto_screen("res://scripts/ui/event_screen.gd")
		"route":
			goto_screen("res://scripts/ui/route_screen.gd")
		"shop":
			goto_screen("res://scripts/ui/shop_screen.gd")
		"formation":
			goto_screen("res://scripts/ui/formation_screen.gd")
		_:
			goto_screen("res://scripts/ui/map_screen.gd")


func _show_help() -> void:
	var body := UI.vbox(10)
	body.custom_minimum_size.x = 700
	var text := """[color=#ffd166][font_size=19]远征目标[/font_size][/color]
星塔远征从第一层攀至第四十层。第 5 / 15 / 25 / 35 层是旧首领，第 10 / 20 / 30 / 40 层是四代魔王。
魔王有无敌屏障：英雄、魔人或携带破魔圣剑的精灵打中一次才破碎，这一下不造成伤害，之后谁都能打。
魔王会复活倒下的魔人并强化。大招每两回合才能尝试封印，每只精灵 50% 概率被封印 1 回合、无法释放大招。生命上限被削减会触发警报，魔王立即再行动一次，这次伤害另加魔王自身生命上限 10% 的真实伤害。
星塔每 3 层选一次路：普通战斗、精英战斗、行商或奇遇。第 10、20、30、40 层的魔王不绕路。没有破魔圣剑时，三条路里必有「圣剑试炼」。四次试炼分别是 1、2、3、4 名英雄精灵，合成后试炼关闭。征服战仍是连战，个位数为 4 或 9 的层保留圣剑试炼。

[color=#ffd166][font_size=17]开局[/font_size][/color]
· 新手：词条「天命」放进背包，自己决定贴给谁。2% 概率造成 99999 伤害。
· 高级：全属性 +10%，开局自选 3 件道具。
· 老练：全属性 +20%，初始精灵从英雄中选择。
· 每局背包里有一张「无限」，只能赋予开局选定的那只精灵：没有等级上限，词条可以无限叠加。
· 其余精灵按稀有度封顶：普通 60 / 稀有 70 / 史诗 80 / 传说 90 / 英雄 100 / 魔人 180。四位征服魔王的契约魔人是 195、215、220、230。另外三位契约魔王是 280、350、500，不会变成额外的征服首领。
· 每层胜利后全员等级 +5，精灵在 30 / 60 级时进化。

[color=#ffd166][font_size=17]战斗[/font_size][/color]
· 九宫格 3×3，最多上阵 6 只，其余留在仓库。战斗中不能换人。布阵会自动保存。
· 坦克存活时，敌方单体攻击必须打坦克。同排、站在坦克身后的精灵，有 30% 伤害由坦克承担。
· 上下左右相邻的不同职业会触发连携，例如坦克+射手减伤、法师+辅助强化治疗。
· 默认每回合手动选择技能和目标，可切回自动。敌人始终自动行动。丢出灵契球占一次行动。
· 我方共用一条灵力。每回合开始回复 6 点，最多存 30 点。费用等于该招的技能效果数减 1，0 费就能放。灵力不够就不能放那一招。
· 每只精灵开局三招：普通、辅助、大招。普通只造成伤害。辅助职业的辅助招回复 3 点灵力，大招回复 4 点并治疗、护盾、加攻。其他职业不能回灵。史诗、传说、英雄辅助回灵时再额外 +1、+2、+3。
· 每只精灵每一层可以培养一次：从技能池抽五个技能效果，加到普通、辅助或大招上。同一个效果最多叠三次，叠上去会更强，也多耗 1 点灵力。普通技能最多再加 1 个；辅助精灵的普通技能从 2 个起，稀有度每高一档再 +1。辅助技能最多再加 2 个。大招总数上限是普通 3、稀有 4、史诗 6、传说 7、英雄 9、魔人 10。只有辅助能回灵。
· 敌方仍用气势，攒满 4 点后放他们自己的大招。
· 十七系克制：克制 2 倍，被克制 0.5 倍，无效为 0。没有妖精系。
· 职业：坦克 / 战士 / 法师 / 射手 / 辅助。敌方坦克和战士优先站前排。
· 同元素上阵 2 只激活一阶共鸣，3 只激活二阶共鸣，全队获得属性加成。
· 稀有及以上命中会叠加专属印记。史诗及以上还有一条常驻专属，不占技能，也不耗灵力。

[color=#ffd166][font_size=17]宝箱：关键奖励必出[/font_size][/color]
· 100%：获得一只精灵。稀有度：普通 45% / 稀有 25% / 史诗 15% / 传说 10% / 英雄 5%。宝箱不出首领，也不出魔人。
· 重复精灵转化为共鸣，永久增强该精灵。
· 100%：获得随机道具。战意项链最多持有 2 件，每件让战斗开始时灵力 +1。
· 100%：获得词条，三选一后贴到某只精灵的普通、辅助或大招上。词条不增加灵力，和培养里的技能效果不是一回事。
· 词条三选一时，有 10% 概率出现稀有词条：反震、齐射、无伤、断势。
· 奇遇不能获得魔人。打败魔王有 15% 概率契约魔人，优先是这一世代的魔人。
· 每个技能最多 3 条词条。每只精灵默认 6 条，行商可以把上限买到 9。贴了「无限」的开局精灵不封顶。英雄最多 6 星，升星消耗一件史诗道具。

[color=#ffd166][font_size=17]星塔征服战[/font_size][/color]
· 不显示总层数。每十层一个关底魔王。
· 先轮流打四位魔王，打完后再按不重复组合成对、三人、四人，最后五位魔王同时上场。
· 打赢五魔王阵即征服星塔。破魔圣剑要靠四次圣剑试炼：每次得到一块碎片，集齐后自动合成。碎片可以先给精灵携带。
· 携带者的每次攻击都能击碎屏障，暴击率 +20%，暴击伤害 +80%，对魔王和魔人伤害翻倍，并免疫 10 次致命伤害。
· 魔王战里，携带者每有 1 名队友倒下就升一档，最高四档：附带 9999 真实伤害；再削减 10% 生命上限；再改为削减 15% 并斩杀生命上限低于原始 20% 的敌人；最后削减 20%、斩杀低于 30%，并且不会被控制。
· 征服战敌方等级与玩家相同。每层有一只「无限」敌人，词条和道具可以重复叠加，数量随层数增加。
· 征服战和普通层一样，每胜一层全员升 5 级。第 6 层起敌方固定五只，魔王不够时由魔人和传说精灵补满。

[color=#ffd166][font_size=17]首领与成长[/font_size][/color]
· 小 Boss 随机 2 到 3 条增益。最终魔王更强，并随机 4 条。
· 打败魔王有 15% 概率契约魔人。魔人不会出现在宝箱或奇遇里。
· 所有首领都有阶段：血量阈值时回满气势、获得护盾并强化。
· 每层小怪都会变强，并逐层获得技能词条。
· 凡个位数为 4 或 9 的关卡都是奇遇关：祝福、道具、共鸣、契约，或本层圣剑试炼。

[color=#8894aa]每次远征使用独立随机种子；种子显示在地图上，可用于复盘。[/color]"""
	var r := UI.rich(text, 15, UI.TEXT)
	r.custom_minimum_size = Vector2(700, 0)
	body.add_child(r)
	show_modal("玩法说明", body, 760, 500)
