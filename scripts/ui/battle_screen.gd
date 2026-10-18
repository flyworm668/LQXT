extends "res://scripts/ui/screen_base.gd"
## Battle screen: simulates the fight, then plays back the event stream.

const BattleEngineScript = preload("res://scripts/core/battle_engine.gd")
const UnitCardScript = preload("res://scripts/ui/unit_card.gd")
const BattleFxScript = preload("res://scripts/ui/battle_fx.gd")

const CARD_W := 172.0
const CARD_H := 128.0
const ROW_GAP := 140.0

var events: Array = []
var cards: Dictionary = {}
var hp_by_uid: Dictionary = {}
var status_by_uid: Dictionary = {}
var speed: float = 0.5
var skipping: bool = false
var finished: bool = false
var winner: String = ""
var field: Control
var fx: Control
var _silent: bool = false
var round_label: Label
var alive_player: Label
var alive_enemy: Label
var log_label: RichTextLabel
var log_lines: Array = []
var speed_buttons: Array = []
var skip_button: Button
var skill_label: Label
var callout_tween: Tween
var victory_applied: bool = false


func _ready() -> void:
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.55)
	_build_hud()
	_build_field()
	_build_log()
	_prepare_battle()
	_append_log("战斗开始。", UI.FAINT)
	var enc: Dictionary = GameState.encounter
	if str(enc.get("kind", "")) == "boss":
		var names: Array = []
		for bid in enc.get("boss_buffs", []):
			var b: Dictionary = ContentDB.boss_buff(str(bid))
			if not b.is_empty():
				names.append(str(b["name"]))
		if not names.is_empty():
			_append_log("首领增益：%s" % "、".join(names), UI.DANGER)
	_update_alive_labels()
	await get_tree().create_timer(0.55).timeout
	_play()


func _build_hud() -> void:
	var bar := UI.panel(Color(0.03, 0.05, 0.09, 0.9), UI.BORDER, 12, 10)
	bar.position = Vector2(16, 10)
	bar.size = Vector2(1248, 58)
	add_child(bar)
	var h := UI.hbox(12)
	bar.add_child(h)
	var f: Dictionary = ContentDB.floor(GameState.current_floor)
	h.add_child(UI.label(str(f.get("name", "战斗")), 22, UI.TEXT))
	h.add_child(UI.pill("自动战斗", UI.BLUE, 11))
	round_label = UI.label("回合 1", 15, UI.GOLD)
	h.add_child(round_label)
	var enc: Dictionary = GameState.encounter
	if str(enc.get("kind", "")) == "boss":
		for bid in enc.get("boss_buffs", []):
			var b: Dictionary = ContentDB.boss_buff(str(bid))
			if not b.is_empty():
				h.add_child(UI.pill("首领·" + str(b["name"]), UI.DANGER, 10))
	h.add_child(UI.grow())
	h.add_child(UI.label("速度", 12, UI.MUTED))
	for mult in [0.5, 1.0, 2.0, 4.0]:
		var b := UI.ghost_button(_speed_text(mult), 13)
		b.custom_minimum_size = Vector2(52, 30)
		b.pressed.connect(_set_speed.bind(mult))
		speed_buttons.append([mult, b])
		h.add_child(b)
	skip_button = UI.ghost_button("跳过", 13)
	skip_button.custom_minimum_size = Vector2(64, 30)
	skip_button.pressed.connect(_skip)
	h.add_child(skip_button)
	_set_speed(0.5)

	skill_label = UI.label("", 20, UI.GOLD)
	skill_label.position = Vector2(0, 68)
	skill_label.size = Vector2(1280, 30)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.modulate.a = 0.0
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_label)


func _build_field() -> void:
	field = Control.new()
	field.position = Vector2(0, 80)
	field.size = Vector2(1280, 470)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.06)
	divider.position = Vector2(639, 24)
	divider.size = Vector2(2, 420)
	field.add_child(divider)
	var center := UI.vbox(0)
	center.position = Vector2(560, 160)
	center.size = Vector2(160, 120)
	field.add_child(center)
	var vs := UI.label("VS", 40, Color(1, 1, 1, 0.22))
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(vs)
	var auto_label := UI.label("自动战斗中", 11, UI.FAINT)
	auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(auto_label)
	alive_player = UI.label("我方 5", 12, UI.GOOD)
	alive_player.position = Vector2(20, 6)
	field.add_child(alive_player)
	alive_enemy = UI.label("敌方 5", 12, UI.DANGER)
	alive_enemy.position = Vector2(1084, 6)
	alive_enemy.size = Vector2(176, 18)
	alive_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field.add_child(alive_enemy)
	_add_column_labels()
	fx = BattleFxScript.new()
	fx.z_index = 50
	field.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_log() -> void:
	var panel := UI.panel(Color(0.03, 0.05, 0.09, 0.92), UI.BORDER, 12, 10)
	panel.position = Vector2(16, 558)
	panel.size = Vector2(1248, 148)
	add_child(panel)
	var v := UI.vbox(4)
	panel.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label("战斗记录", 13, UI.MUTED))
	head.add_child(UI.grow())
	head.add_child(UI.label("种子 #%d" % GameState.run_seed, 10, UI.FAINT))
	v.add_child(head)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.fit_content = false
	log_label.custom_minimum_size = Vector2(0, 106)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_color_override("default_color", UI.TEXT)
	v.add_child(log_label)


func _prepare_battle() -> void:
	var player_units := GameState.build_player_units()
	var enemy_units := GameState.build_enemy_units()
	var battle = BattleEngineScript.new()
	var result: Dictionary = battle.simulate(player_units, enemy_units, GameState.next_battle_seed())
	events = result.get("events", [])
	var start: Array = result.get("start", [])
	for u in start:
		var card = UnitCardScript.new()
		card.setup(u, str(u["side"]) == "enemy")
		var pos := _slot_position(u)
		field.add_child(card)
		if bool(u.get("is_boss", false)):
			card.scale = Vector2(1.12, 1.12)
			card.pivot_offset = card.size * 0.5
			pos += Vector2(-12, -8)
		card.position = pos
		card.set_meta("base_pos", pos)
		cards[int(u["uid"])] = card
		hp_by_uid[int(u["uid"])] = int(u.get("hp", 0))
		status_by_uid[int(u["uid"])] = (u.get("statuses", {}) as Dictionary).duplicate(true)


func _add_column_labels() -> void:
	var cols := [
		[20.0, "后排", UI.MUTED],
		[200.0, "中排", UI.MUTED],
		[380.0, "前排", UI.GOLD],
	]
	for c in cols:
		var l := UI.label(str(c[1]), 10, c[2])
		l.position = Vector2(float(c[0]), 450)
		l.size = Vector2(172, 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.add_child(l)
	var ecols := [
		[728.0, "前排", UI.GOLD],
		[908.0, "中排", UI.MUTED],
		[1088.0, "后排", UI.MUTED],
	]
	for c in ecols:
		var l := UI.label(str(c[1]), 10, c[2])
		l.position = Vector2(float(c[0]), 450)
		l.size = Vector2(172, 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.add_child(l)


func _slot_position(u: Dictionary) -> Vector2:
	var col := int(u.get("col", 0))
	var row := int(u.get("row", 0))
	var x := (20.0 + float(2 - col) * 180.0) if str(u.get("side")) == "player" else (728.0 + float(col) * 180.0)
	var y := 40.0 + float(row) * ROW_GAP
	return Vector2(x, y)


func _speed_text(value: float) -> String:
	return "0.5×" if value < 1.0 else "%d×" % int(value)


func _set_speed(value: float) -> void:
	speed = value
	for pair in speed_buttons:
		var b: Button = pair[1]
		var on := is_equal_approx(float(pair[0]), value)
		b.add_theme_color_override("font_color", UI.GOLD if on else UI.MUTED)
		b.add_theme_color_override("font_hover_color", UI.GOLD if on else UI.TEXT)


func _skip() -> void:
	skipping = true
	skip_button.text = "跳过中"
	skip_button.disabled = true
	if fx != null:
		fx.clear()


func _play() -> void:
	for i in range(events.size()):
		if not is_inside_tree():
			return
		if skipping:
			_silent = true
			for j in range(i, events.size()):
				_apply_event(events[j], false)
			_silent = false
			break
		_apply_event(events[i], true)
		var d := _delay_for(events[i]) / maxf(0.25, speed)
		if d > 0.002:
			await get_tree().create_timer(d).timeout
	_finish()


func _delay_for(ev: Dictionary) -> float:
	match str(ev.get("t", "")):
		"round":
			return 0.12
		"action":
			return 0.75 if str(ev.get("slot", "")) == "ultimate" else 0.5
		"tick":
			return 0.4
		"stun":
			return 0.25
		"death":
			return 0.25
		"phase":
			return 0.8
		"end":
			return 0.2
		_:
			return 0.1


func _apply_event(ev: Dictionary, visual: bool = true) -> void:
	match str(ev.get("t", "")):
		"round":
			round_label.text = "回合 %d" % int(ev.get("round", 1))
			_append_log("── 第 %d 回合 ──" % int(ev.get("round", 1)), UI.FAINT)
		"rage":
			var c = cards.get(int(ev.get("uid", 0)))
			if c != null:
				c.set_rage(int(ev.get("rage", 0)))
		"action":
			_apply_action(ev, visual)
		"tick":
			_apply_tick(ev, visual)
		"status":
			_apply_single_status(ev)
		"stunned":
			_append_log(str(ev.get("text", "")), UI.BLUE)
			var c = cards.get(int(ev.get("uid", 0)))
			if c != null and visual:
				_float_on(c, "眩晕", UI.BLUE, 20)
		"death":
			_handle_death(ev)
		"phase":
			_append_log(str(ev.get("text", "")), UI.DANGER)
			if visual:
				_flash(Color(1, 0.2, 0.2, 0.12))
				banner(str(ev.get("text", "首领进入新阶段！")), UI.DANGER, 1.6)
		"log":
			_append_log(str(ev.get("text", "")), UI.MUTED)
		"end":
			winner = str(ev.get("winner", ""))
			_append_log("战斗结束。" if winner == "player" else "我们败下阵来……",
				UI.GOOD if winner == "player" else UI.DANGER)
		_:
			pass


func _apply_action(ev: Dictionary, visual: bool = true) -> void:
	var actor_uid := int(ev.get("actor", 0))
	for uid in cards.keys():
		cards[uid].set_active(uid == actor_uid)
	var actor = cards.get(actor_uid)
	var is_ult := str(ev.get("slot", "")) == "ultimate"
	var skill_name := str(ev.get("skill_name", ""))
	if visual:
		_skill_callout(("【%s】" % skill_name), UI.GOLD if is_ult else UI.TEXT)
	_append_log(str(ev.get("text", "")), UI.GOOD if str(ev.get("side", "")) == "player" else UI.DANGER)
	if actor != null:
		actor.set_active(true)
		if visual:
			_play_attack_fx(actor, ev, is_ult)

	for t in ev.get("targets", []):
		var uid := int(t.get("uid", 0))
		var card = cards.get(uid)
		hp_by_uid[uid] = int(t.get("hp", 0))
		if card != null:
			card.refresh_hp(int(t.get("hp", 0)), int(t.get("max_hp", 1)))
			card.set_shield(int(t.get("shield", 0)))
			if t.has("rage"):
				card.set_rage(int(t["rage"]))
			if t.has("statuses"):
				status_by_uid[uid] = (t["statuses"] as Dictionary).duplicate(true)
				card.set_statuses(status_by_uid[uid])
			var dmg := int(t.get("damage", 0))
			var absorbed := int(t.get("absorbed", 0))
			var crit := bool(t.get("crit", false))
			var elem := float(t.get("element", 1.0))
			var col := UI.TEXT
			var size := 26
			var text := ""
			if crit:
				col = UI.GOLD
				size = 36
				text = "暴击 -%s" % ContentDB.fmt(dmg)
			elif elem > 1.05:
				col = UI.ACCENT
				size = 30
				text = "克制 -%s" % ContentDB.fmt(dmg)
			elif elem < 0.95:
				col = UI.BLUE
				size = 22
				text = "弱效 -%s" % ContentDB.fmt(dmg)
			else:
				col = UI.TEXT
				size = 26
				text = "-%s" % ContentDB.fmt(dmg)
			if dmg > 0 and visual:
				_float_on(card, text, col, size, crit)
				if fx != null:
					fx.add_hit(_card_center(card), col, crit, 1.25 if crit else 1.0)
			if absorbed > 0 and visual:
				_float_on(card, "格挡 %s" % ContentDB.fmt(absorbed), UI.BLUE, 18)
			if bool(t.get("saved", false)) and visual:
				_float_on(card, "不屈!", UI.GOLD, 24)
			if bool(t.get("dead", false)):
				card.die()
	for h in ev.get("heals", []):
		var uid := int(h.get("uid", 0))
		var card = cards.get(uid)
		hp_by_uid[uid] = int(h.get("hp", 0))
		if card != null:
			card.refresh_hp(int(h.get("hp", 0)), int(h.get("max_hp", 1)))
			if int(h.get("amount", 0)) > 0 and visual:
				_float_on(card, "+%s" % ContentDB.fmt(int(h["amount"])), UI.GOOD, 26)
				if fx != null:
					fx.add_heal(_card_center(card), UI.GOOD)
	for sh in ev.get("shields", []):
		var card = cards.get(int(sh.get("uid", 0)))
		if card != null:
			card.set_shield(int(sh.get("shield", 0)))
			if visual and fx != null:
				fx.add_burst(_card_center(card), UI.BLUE, 34.0)
	for st in ev.get("statuses", []):
		var uid := int(st.get("uid", 0))
		var card = cards.get(uid)
		if card == null:
			continue
		var map: Dictionary = status_by_uid.get(uid, {})
		var key := str(st.get("status", ""))
		var prev: Dictionary = map.get(key, {"dur": 0, "pct": 0.0, "value": 0.0})
		prev["dur"] = maxi(int(prev.get("dur", 0)), int(st.get("dur", 1)))
		if st.has("pct"):
			prev["pct"] = maxf(float(prev.get("pct", 0.0)), float(st["pct"]))
		if st.has("value"):
			prev["value"] = maxf(float(prev.get("value", 0.0)), float(st["value"]))
		map[key] = prev
		status_by_uid[uid] = map
		card.set_statuses(map)
	_update_alive_labels()


func _apply_tick(ev: Dictionary, visual: bool = true) -> void:
	for t in ev.get("targets", []):
		var uid := int(t.get("uid", 0))
		var card = cards.get(uid)
		hp_by_uid[uid] = int(t.get("hp", 0))
		if card != null:
			card.refresh_hp(int(t.get("hp", 0)), int(t.get("max_hp", 1)))
			card.set_shield(int(t.get("shield", 0)))
			if int(t.get("damage", 0)) > 0 and visual:
				_float_on(card, "-%s" % ContentDB.fmt(int(t["damage"])), UI.ACCENT, 21)
				if fx != null:
					fx.add_hit(_card_center(card), UI.ACCENT, false, 0.8)
			if bool(t.get("dead", false)):
				card.die()
	for h in ev.get("heals", []):
		var uid := int(h.get("uid", 0))
		var card = cards.get(uid)
		hp_by_uid[uid] = int(h.get("hp", 0))
		if card != null:
			card.refresh_hp(int(h.get("hp", 0)), int(h.get("max_hp", 1)))
			if int(h.get("amount", 0)) > 0 and visual:
				_float_on(card, "+%s" % ContentDB.fmt(int(h["amount"])), UI.GOOD, 20)
				if fx != null:
					fx.add_heal(_card_center(card), UI.GOOD)
	_append_log(str(ev.get("text", "回合结算")), UI.MUTED)
	_update_alive_labels()


func _apply_single_status(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", 0))
	var card = cards.get(uid)
	if card == null:
		return
	var key := str(ev.get("status", ""))
	var map: Dictionary = status_by_uid.get(uid, {})
	map[key] = {"dur": int(ev.get("dur", 1)), "pct": float(ev.get("pct", 0.0))}
	status_by_uid[uid] = map
	card.set_statuses(map)
	if ev.has("text"):
		_append_log(str(ev.get("text", "")), UI.PURPLE)


func _handle_death(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", 0))
	hp_by_uid[uid] = 0
	var card = cards.get(uid)
	if card != null:
		card.die()
	_append_log(str(ev.get("text", "")), UI.FAINT)
	_update_alive_labels()


func _update_alive_labels() -> void:
	var player_alive := 0
	var enemy_alive := 0
	for uid in cards.keys():
		var card = cards[uid]
		if int(hp_by_uid.get(uid, 0)) > 0:
			if str(card.unit_data.get("side", "")) == "player":
				player_alive += 1
			else:
				enemy_alive += 1
	alive_player.text = "我方 %d" % player_alive
	alive_enemy.text = "敌方 %d" % enemy_alive


func _append_log(text: String, color: Color) -> void:
	if text.is_empty() or _silent:
		return
	var esc := text.replace("[", "［").replace("]", "］")
	log_lines.append("[color=#%s]%s[/color]" % [color.to_html(false), esc])
	while log_lines.size() > 7:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


func _skill_callout(text: String, color: Color) -> void:
	if callout_tween != null and callout_tween.is_valid():
		callout_tween.kill()
	skill_label.text = text
	skill_label.add_theme_color_override("font_color", color)
	skill_label.modulate.a = 0.0
	callout_tween = create_tween()
	callout_tween.tween_property(skill_label, "modulate:a", 1.0, 0.08)
	callout_tween.tween_interval(0.5)
	callout_tween.tween_property(skill_label, "modulate:a", 0.0, 0.25)


func _float_on(card: Control, text: String, color: Color, size: int = 26, crit: bool = false) -> void:
	if fx == null:
		return
	var center: Vector2 = card.position + Vector2(card.size.x * card.scale.x * 0.5, -14.0)
	fx.add_text(text, center, color, size, crit)


func _card_center(card: Control) -> Vector2:
	return card.position + card.size * card.scale * 0.5


func _play_attack_fx(actor: Control, ev: Dictionary, is_ult: bool) -> void:
	if fx == null:
		return
	var actor_center := _card_center(actor)
	var element := str(actor.unit_data.get("element", "fire"))
	var color := ContentDB.element_color(element)
	if is_ult:
		fx.add_charge(actor_center, color)
		fx.add_burst(actor_center, color, 46.0)
		_flash(Color(color.r, color.g, color.b, 0.07))
		for t in ev.get("targets", []):
			var tc = cards.get(int(t.get("uid", 0)))
			if tc != null:
				fx.add_burst(_card_center(tc), color, 76.0)
		return
	var target_card = null
	for t in ev.get("targets", []):
		var c = cards.get(int(t.get("uid", 0)))
		if c != null:
			target_card = c
			break
	if target_card == null:
		return
	var target_center := _card_center(target_card)
	var ranged := str(actor.unit_data.get("class", "")) in ["mage", "archer", "support"]
	if ranged:
		fx.add_projectile(actor_center, target_center, color, 0.28)
	else:
		var base: Vector2 = actor.get_meta("base_pos", actor.position)
		var dir := (target_center - actor_center).normalized()
		var tw := create_tween()
		tw.tween_property(actor, "position", base + dir * 24.0, 0.08)
		tw.tween_property(actor, "position", base, 0.13)
	fx.add_slash(target_center, color)


func _flash(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 90
	add_child(rect)
	var t := create_tween()
	t.tween_property(rect, "color:a", 0.0, 0.45)
	t.tween_callback(rect.queue_free)


func _finish() -> void:
	if finished:
		return
	finished = true
	await get_tree().create_timer(0.55).timeout
	if fx != null:
		fx.clear()
	_show_result()


func _show_result() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.015, 0.03, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := UI.panel(Color(0.05, 0.07, 0.11, 0.98), UI.GOLD if winner == "player" else UI.DANGER, 20, 28)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(v)
	var title_text := "战 斗 胜 利" if winner == "player" else "战 斗 失 败"
	var title := UI.label(title_text, 36, UI.GOLD if winner == "player" else UI.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub_text := "全员等级 +10，精灵在 30 / 60 级时进化。" if winner == "player" else "远征止步于第 %d 层。" % GameState.current_floor
	var sub := UI.label(sub_text, 15, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UI.hline(UI.BORDER, 1))
	var stats := UI.hbox(12)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(UI.pill("回合 %d" % _last_round(), UI.BLUE, 12))
	stats.add_child(UI.pill("存活 %d" % _alive_count(winner), UI.GOOD if winner == "player" else UI.MUTED, 12))
	stats.add_child(UI.pill("种子 #%d" % GameState.run_seed, UI.FAINT, 12))
	v.add_child(stats)
	v.add_child(UI.spacer(0, 6))
	if winner == "player":
		var go := UI.button("开 启 宝 箱", UI.ACCENT, 19)
		go.custom_minimum_size = Vector2(0, 54)
		go.pressed.connect(_claim_victory)
		v.add_child(go)
	else:
		var go := UI.button("查 看 结 算", UI.DANGER, 19)
		go.custom_minimum_size = Vector2(0, 54)
		go.pressed.connect(_go_defeat)
		v.add_child(go)


func _last_round() -> int:
	for i in range(events.size() - 1, -1, -1):
		if str(events[i].get("t", "")) == "round":
			return int(events[i].get("round", 1))
	return 0


func _alive_count(side: String) -> int:
	var count := 0
	for uid in cards.keys():
		if int(hp_by_uid.get(uid, 0)) > 0 and str(cards[uid].unit_data.get("side", "")) == side:
			count += 1
	return count


func _claim_victory() -> void:
	if victory_applied:
		return
	victory_applied = true
	var res: Dictionary = GameState.apply_victory()
	goto_screen("res://scripts/ui/reward_screen.gd", {"evolutions": res.get("evolutions", [])})


func _go_defeat() -> void:
	GameState.end_run_defeat()
	goto_screen("res://scripts/ui/result_screen.gd", {"win": false})
