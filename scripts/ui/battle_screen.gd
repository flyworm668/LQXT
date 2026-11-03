extends "res://scripts/ui/screen_base.gd"
## Battle screen: simulates the fight, then plays back the event stream.

const BattleEngineScript = preload("res://scripts/core/battle_engine.gd")
const UnitCardScript = preload("res://scripts/ui/unit_card.gd")
const BattleFxScript = preload("res://scripts/ui/battle_fx.gd")
const PetDetailScript = preload("res://scripts/ui/pet_detail.gd")

const CARD_W := 172.0
const CARD_H := 156.0
const ROW_GAP := 162.0

var events: Array = []
var engine = null
var manual: bool = true
var play_i: int = 0
var playing: bool = false
var pending_slot: String = ""
var command: Control
var command_text: Label
var mode_button: Button
var ult_button: Button
var normal_button: Button
var ball_button: Button
var skill_buttons: Array = []
var spirit_now: int = 0
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
var inspect_paused: bool = false
var menu_paused: bool = false
var _trauma: float = 0.0
var _shake_t: float = 0.0
var _field_home := Vector2(0, 72)
var _hit_stop_id: int = 0


func _ready() -> void:
	add_background(str(ContentDB.floor(GameState.current_floor).get("map", "lava")))
	add_dim(0.55)
	_build_hud()
	_build_field()
	_build_log()
	_build_command()
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
	var battle_name := str(GameState.encounter.get("name", f.get("name", "战斗"))) if GameState.run_mode == "conquest" else str(f.get("name", "战斗"))
	h.add_child(UI.label(battle_name, 26 if _phone() else 22, UI.TEXT))
	if GameState.run_mode == "conquest":
		h.add_child(UI.pill("星塔征服战", UI.GOLD, 11))
	else:
		h.add_child(UI.pill("第 %d / %d 层" % [GameState.current_floor, ContentDB.total_floors()], UI.GOLD, 11))
	mode_button = UI.ghost_button("手动", 13)
	mode_button.custom_minimum_size = Vector2(64, 30)
	mode_button.pressed.connect(_toggle_manual)
	h.add_child(mode_button)
	round_label = UI.label("回合 1", 20 if _phone() else 15, UI.GOLD)
	h.add_child(round_label)
	var enc: Dictionary = GameState.encounter
	if bool(enc.get("curse", false)):
		h.add_child(UI.pill("精英试炼", UI.DANGER, 10))
	if str(enc.get("kind", "")) == "boss":
		for bid in enc.get("boss_buffs", []):
			var b: Dictionary = ContentDB.boss_buff(str(bid))
			if not b.is_empty():
				h.add_child(UI.pill("首领·" + str(b["name"]), UI.DANGER, 10))
	var hero_count := 0
	for d in GameState.deployed:
		var e := GameState.get_roster_entry(int(d["uid"]))
		if not e.is_empty() and bool(e.get("hero", false)):
			hero_count += 1
	if hero_count > 0:
		h.add_child(UI.pill("英雄 ×%d" % hero_count, UI.GOLD, 10))
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
	var menu := UI.ghost_button("菜单", 13)
	menu.custom_minimum_size = Vector2(64, 30)
	menu.pressed.connect(open_run_menu)
	h.add_child(menu)
	_set_speed(0.5)

	skill_label = UI.label("", 30 if _phone() else 20, UI.GOLD)
	skill_label.position = Vector2(0, 68)
	skill_label.size = Vector2(1280, 40 if _phone() else 30)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.modulate.a = 0.0
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_label)


func _build_field() -> void:
	field = Control.new()
	field.position = Vector2(0, 72)
	field.size = Vector2(1280, 528)
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
	alive_player = UI.label("我方 6", 16 if _phone() else 12, UI.GOOD)
	alive_player.position = Vector2(20, 6)
	field.add_child(alive_player)
	alive_enemy = UI.label("敌方 5", 16 if _phone() else 12, UI.DANGER)
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
	panel.position = Vector2(16, 604)
	panel.size = Vector2(1248, 108)
	add_child(panel)
	var v := UI.vbox(4)
	panel.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label("战斗记录", 18 if _phone() else 13, UI.MUTED))
	head.add_child(UI.grow())
	head.add_child(UI.label("种子 #%d" % GameState.run_seed, 10, UI.FAINT))
	v.add_child(head)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.fit_content = false
	log_label.custom_minimum_size = Vector2(0, 72)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 22 if _phone() else 16)
	log_label.add_theme_color_override("default_color", UI.TEXT)
	v.add_child(log_label)


func _prepare_battle() -> void:
	var player_units := GameState.build_player_units()
	var enemy_units := GameState.build_enemy_units()
	engine = BattleEngineScript.new()
	engine.begin(player_units, enemy_units, GameState.next_battle_seed(), true)
	events = engine.events
	var start: Array = engine.start_snapshot
	for u in start:
		var card = UnitCardScript.new()
		card.phone_battle = _phone()
		card.setup(u, str(u["side"]) == "enemy")
		var pos := _slot_position(u)
		field.add_child(card)
		card.scale = Vector2.ONE
		card.position = pos
		card.set_meta("base_pos", pos)
		card.inspect_requested.connect(_inspect_unit)
		card.selected.connect(_pick_target)
		cards[int(u["uid"])] = card
		hp_by_uid[int(u["uid"])] = int(u.get("hp", 0))
		status_by_uid[int(u["uid"])] = (u.get("statuses", {}) as Dictionary).duplicate(true)


func _add_column_labels() -> void:
	var phone := _phone()
	var w := 196.0 if phone else 172.0
	var y := 458.0 if phone else 508.0
	var px := 14 if phone else 10
	var cols := [
		[8.0 if phone else 20.0, "后排", UI.MUTED],
		[212.0 if phone else 200.0, "中排", UI.MUTED],
		[416.0 if phone else 380.0, "前排", UI.GOLD],
	]
	for c in cols:
		var l := UI.label(str(c[1]), px, c[2])
		l.position = Vector2(float(c[0]), y)
		l.size = Vector2(w, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.add_child(l)
	var ecols := [
		[668.0 if phone else 728.0, "前排", UI.GOLD],
		[872.0 if phone else 908.0, "中排", UI.MUTED],
		[1076.0 if phone else 1088.0, "后排", UI.MUTED],
	]
	for c in ecols:
		var l := UI.label(str(c[1]), px, c[2])
		l.position = Vector2(float(c[0]), y)
		l.size = Vector2(w, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.add_child(l)


func _phone() -> bool:
	return OS.get_name() == "Android"


func _slot_position(u: Dictionary) -> Vector2:
	var col := int(u.get("col", 0))
	var row := int(u.get("row", 0))
	var x: float
	var y: float
	if _phone():
		x = (8.0 + float(2 - col) * 204.0) if str(u.get("side")) == "player" else (668.0 + float(col) * 204.0)
		y = 24.0 + float(row) * 218.0
	else:
		x = (20.0 + float(2 - col) * 180.0) if str(u.get("side")) == "player" else (728.0 + float(col) * 180.0)
		y = 18.0 + float(row) * ROW_GAP
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
	_clear_targets()
	if command != null:
		command.visible = false
	if engine != null and str(engine._phase) != "done":
		engine.resume_auto()
	if not playing:
		_play()


func set_menu_paused(paused: bool) -> void:
	menu_paused = paused


func _inspect_unit(unit: Dictionary) -> void:
	inspect_paused = true
	var overlay := PetDetailScript.open_unit(self, unit)
	if overlay == null:
		inspect_paused = false
		return
	overlay.tree_exiting.connect(func(): inspect_paused = false)


func _play() -> void:
	if playing:
		return
	playing = true
	while is_inside_tree():
		while (inspect_paused or menu_paused) and is_inside_tree():
			await get_tree().process_frame
		if play_i >= events.size():
			if engine == null or str(engine._phase) == "done":
				_finish()
			playing = false
			return
		if skipping:
			_silent = true
			while play_i < events.size():
				_apply_event(events[play_i], false)
				play_i += 1
			_silent = false
			if engine != null and str(engine._phase) != "done":
				playing = false
				return
			break
		var ev: Dictionary = events[play_i]
		play_i += 1
		if str(ev.get("t", "")) == "choose":
			if manual:
				_show_command(ev)
				playing = false
				return
			if engine != null:
				engine.auto_choose()
			continue
		_apply_event(ev, true)
		var d := _delay_for(ev) / maxf(0.25, speed)
		if d > 0.002:
			await get_tree().create_timer(d, true, false, true).timeout
	playing = false
	_finish()


func _delay_for(ev: Dictionary) -> float:
	match str(ev.get("t", "")):
		"round":
			return 0.12
		"action":
			return 1.15 if str(ev.get("slot", "")) == "ultimate" else 0.5
		"tick":
			return 0.4
		"stun":
			return 0.25
		"death":
			return 0.25
		"phase":
			return 0.9
		"end":
			return 0.2
		_:
			return 0.1


func _apply_event(ev: Dictionary, visual: bool = true) -> void:
	match str(ev.get("t", "")):
		"round":
			round_label.text = "回合 %d" % int(ev.get("round", 1))
			_append_log("── 第 %d 回合 ──" % int(ev.get("round", 1)), UI.FAINT)
		"spirit":
			spirit_now = int(ev.get("spirit", spirit_now))
			round_label.text = "%s · 灵力 %d" % [round_label.text.split(" · ")[0], spirit_now]
			_append_log(str(ev.get("text", "")), UI.BLUE)
			for h in ev.get("heals", []):
				var card = cards.get(int(h.get("uid", 0)))
				hp_by_uid[int(h.get("uid", 0))] = int(h.get("hp", 0))
				if card != null:
					card.refresh_hp(int(h.get("hp", 0)), int(h.get("max_hp", 1)))
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
		"revive":
			_handle_revive(ev)
		"phase":
			_append_log(str(ev.get("text", "")), UI.DANGER)
			var phase_card = cards.get(int(ev.get("uid", 0)))
			if phase_card != null and ev.has("shield"):
				phase_card.set_shield(int(ev["shield"]))
			if visual:
				_flash(Color(1, 0.2, 0.2, 0.12))
				_shake(4.5)
				_hit_stop(0.08, 0.05)
				if phase_card != null and fx != null:
					fx.add_burst(_card_center(phase_card), UI.DANGER, 78.0)
					fx.add_shockwave(_card_center(phase_card), UI.GOLD, 110.0)
				banner(str(ev.get("text", "首领进入新阶段！")), UI.DANGER, 1.6)
		"auras":
			_apply_auras(ev)
		"log":
			_append_log(str(ev.get("text", "")), UI.MUTED)
		"caught":
			var added := GameState.catch_enemy(str(ev.get("species", "")), int(ev.get("level", 1)))
			var joined := "加入了队伍" if str(added.get("kind", "")) == "new" else "转化为共鸣"
			_append_log("%s 被收服，%s。" % [str(ev.get("name", "")), joined], UI.GOLD)
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
	var hero_actor := actor != null and bool(actor.unit_data.get("is_hero", false))
	if visual:
		if is_ult:
			var cast_color := Color(1.0, 0.84, 0.45) if hero_actor else ContentDB.element_color(str(actor.unit_data.get("element", "fire")) if actor != null else "fire")
			_skill_callout(("【%s】" % skill_name), cast_color)
		else:
			_skill_callout(("【%s】" % skill_name), UI.TEXT)
	_append_log(str(ev.get("text", "")), UI.GOOD if str(ev.get("side", "")) == "player" else UI.DANGER)
	if actor != null:
		actor.set_active(true)
		if visual:
			_play_attack_fx(actor, ev, is_ult)

	var punched := false
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
			var barrier := str(t.get("barrier", ""))
			if barrier == "break":
				card.unit_data["king_barrier"] = false
				card.refresh_hp(int(t.get("hp", 0)), int(t.get("max_hp", 1)))
				if visual:
					_float_on(card, "屏障破碎", UI.GOLD, 24)
			elif barrier == "hold" and visual:
				_float_on(card, "屏障", UI.MUTED, 22)
			var dmg := int(t.get("damage", 0))
			var absorbed := int(t.get("absorbed", 0))
			var crit := bool(t.get("crit", false))
			var elem := float(t.get("element", 1.0))
			var col := UI.TEXT
			var size := 26
			var text := ""
			if dmg >= 99999:
				col = UI.GOLD
				size = 40
				text = "天命 -%s" % ContentDB.fmt(dmg)
			elif crit:
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
				if not punched and (crit or dmg >= 99999):
					punched = true
					_shake(5.5 if dmg >= 99999 else 2.6)
					_hit_stop(0.07 if dmg >= 99999 else 0.04, 0.06 if dmg >= 99999 else 0.14)
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
		if key == "mark":
			card.set_mark(str(st.get("name", "")), int(st.get("n", 0)))
			continue
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
	if key == "mark":
		card.set_mark(str(ev.get("name", "")), int(ev.get("n", 0)))
		return
	var map: Dictionary = status_by_uid.get(uid, {})
	map[key] = {"dur": int(ev.get("dur", 1)), "pct": float(ev.get("pct", 0.0))}
	status_by_uid[uid] = map
	card.set_statuses(map)
	if ev.has("text"):
		_append_log(str(ev.get("text", "")), UI.PURPLE)


func _apply_auras(ev: Dictionary) -> void:
	for row in ev.get("units", []):
		var uid := int(row.get("uid", 0))
		var card = cards.get(uid)
		if card == null:
			continue
		var statuses: Dictionary = row.get("statuses", {})
		status_by_uid[uid] = statuses.duplicate(true)
		card.set_statuses(statuses)
		card.set_marks(row.get("marks", []))


func _handle_revive(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", 0))
	hp_by_uid[uid] = int(ev.get("hp", 1))
	var card = cards.get(uid)
	if card != null:
		card.revive()
		card.refresh_hp(int(ev.get("hp", 1)), int(ev.get("max_hp", 1)))
	_append_log(str(ev.get("text", "")), UI.GOLD)
	_update_alive_labels()


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
	skill_label.pivot_offset = Vector2(640, 16)
	skill_label.scale = Vector2(1.32, 1.32)
	skill_label.modulate.a = 0.0
	callout_tween = create_tween()
	callout_tween.set_parallel(true)
	callout_tween.tween_property(skill_label, "modulate:a", 1.0, 0.08)
	callout_tween.tween_property(skill_label, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	callout_tween.set_parallel(false)
	callout_tween.tween_interval(0.45)
	callout_tween.tween_property(skill_label, "modulate:a", 0.0, 0.25)


func _process(delta: float) -> void:
	if field == null or _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - 1.8 * delta, 0.0)
	_shake_t += delta * 30.0
	if _trauma <= 0.0:
		field.position = _field_home
		return
	var kick := _trauma * _trauma
	field.position = _field_home + Vector2(12.0 * kick * sin(_shake_t * 1.7), 7.0 * kick * sin(_shake_t * 2.3))


func _shake(strength: float) -> void:
	if field == null:
		return
	_trauma = clampf(_trauma + clampf(strength / 8.0, 0.12, 0.85), 0.0, 1.0)


func _hit_stop(duration: float = 0.05, slow: float = 0.1) -> void:
	if skipping or _silent or not is_inside_tree():
		return
	_hit_stop_id += 1
	var my_id := _hit_stop_id
	Engine.time_scale = slow
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _hit_stop_id and is_inside_tree():
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _float_on(card: Control, text: String, color: Color, size: int = 26, crit: bool = false) -> void:
	if fx == null:
		return
	if _phone():
		size = int(round(float(size) * 1.35))
	var center: Vector2 = card.position + Vector2(card.size.x * card.scale.x * 0.5, -14.0)
	fx.add_text(text, center, color, size, crit)


func _card_center(card: Control) -> Vector2:
	return card.position + card.size * card.scale * 0.5


func _motion(node: Control, delta: Vector2) -> void:
	var old: Variant = node.get_meta("motion", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var base: Vector2 = node.get_meta("base_pos", node.position)
	node.position = base
	var tw := create_tween()
	node.set_meta("motion", tw)
	tw.tween_property(node, "position", base + delta, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", base, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _play_attack_fx(actor: Control, ev: Dictionary, is_ult: bool) -> void:
	if fx == null:
		return
	var actor_center := _card_center(actor)
	var element := str(actor.unit_data.get("element", "fire"))
	var color := ContentDB.element_color(element)
	var first = null
	var hit_cards: Array = []
	for t in ev.get("targets", []):
		var tc = cards.get(int(t.get("uid", 0)))
		if tc != null:
			hit_cards.append(tc)
			if first == null:
				first = tc
	if is_ult:
		var target_points: Array = []
		for item in hit_cards:
			var hit: Control = item
			target_points.append(_card_center(hit))
		var hero_cast := bool(actor.unit_data.get("is_hero", false))
		var cast_color := Color(1.0, 0.84, 0.45) if hero_cast else color
		fx.add_ultimate_cast(actor_center, target_points, element, cast_color, hero_cast)
		_flash(Color(cast_color.r, cast_color.g, cast_color.b, 0.13 if hero_cast else 0.08))
		_shake(5.0 if hero_cast else 3.2)
		_hit_stop(0.06, 0.08)
	if first == null:
		return
	var lead: Control = first
	var target_center := _card_center(lead)
	var dir := (target_center - actor_center).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if str(actor.unit_data.get("side", "")) == "player" else Vector2.LEFT
	var ranged := str(actor.unit_data.get("class", "")) in ["mage", "archer", "support"]
	var step := 46.0 if is_ult else (36.0 if ranged else 78.0)
	var recoil := 20.0 if is_ult else (16.0 if ranged else 26.0)
	if ranged and not is_ult:
		fx.add_projectile(actor_center, target_center, color, 0.28)
	_motion(actor, dir * step)
	if actor.has_method("play_strike"):
		actor.call("play_strike", dir.x >= 0.0)
	for item in hit_cards:
		var tc: Control = item
		_motion(tc, dir * recoil)
		if tc.has_method("play_flinch"):
			tc.call("play_flinch", dir.x >= 0.0)
		fx.add_slash(_card_center(tc), color)


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


func _build_command() -> void:
	command = UI.panel(Color(0.04, 0.06, 0.1, 0.94), UI.GOLD, 12, 8)
	command.position = Vector2(16, 544)
	command.size = Vector2(1248, 52)
	command.visible = false
	command.z_index = 40
	add_child(command)
	var row := UI.hbox(8)
	command.add_child(row)
	command_text = UI.label("选择行动", 15, UI.TEXT)
	command_text.custom_minimum_size = Vector2(220, 0)
	row.add_child(command_text)
	normal_button = UI.button("普攻", UI.ACCENT, 14)
	normal_button.custom_minimum_size = Vector2(110, 36)
	normal_button.pressed.connect(_arm_slot.bind("normal"))
	row.add_child(normal_button)
	ult_button = UI.button("大招", UI.PURPLE, 14)
	ult_button.custom_minimum_size = Vector2(110, 36)
	ult_button.pressed.connect(_arm_slot.bind("ultimate"))
	row.add_child(ult_button)
	ball_button = UI.button("灵契球", UI.GOLD, 14)
	ball_button.custom_minimum_size = Vector2(140, 36)
	ball_button.pressed.connect(_arm_slot.bind("ball"))
	row.add_child(ball_button)


func _toggle_manual() -> void:
	manual = not manual
	mode_button.text = "手动" if manual else "自动"
	if engine == null:
		return
	engine.manual = true
	if manual:
		return
	_clear_targets()
	if command != null:
		command.visible = false
	if engine.waiting:
		engine.auto_choose()
		if not playing:
			_play()


func _clear_skill_buttons() -> void:
	for b in skill_buttons:
		if is_instance_valid(b):
			b.queue_free()
	skill_buttons.clear()


func _show_command(ev: Dictionary) -> void:
	if command == null:
		return
	command.visible = true
	_clear_skill_buttons()
	ball_button.disabled = GameState.ball_count() <= 0 or engine.ball_target_ids().is_empty()
	ball_button.text = "灵契球 %d" % GameState.ball_count()
	var arts: Array = ev.get("arts", [])
	if not arts.is_empty():
		normal_button.visible = false
		ult_button.visible = false
		spirit_now = int(ev.get("spirit", spirit_now))
		var row := command.get_child(0)
		for art in arts:
			var slot := str(art.get("slot", "a0"))
			var button := UI.button("%s %d" % [str(art.get("name", "技能")), int(art.get("cost", 0))], UI.PURPLE if int(art.get("cost", 0)) > 0 else UI.ACCENT, 13)
			button.custom_minimum_size = Vector2(132, 36)
			button.disabled = not bool(art.get("ready", false))
			button.tooltip_text = str(art.get("text", ""))
			button.pressed.connect(_arm_slot.bind(slot))
			row.add_child(button)
			row.move_child(button, row.get_child_count() - 2)
			skill_buttons.append(button)
		command_text.text = "%s · 灵力 %d" % [str(ev.get("name", "")), spirit_now]
		pending_slot = ""
		_clear_targets()
		_focus_command()
		return
	normal_button.visible = true
	ult_button.visible = true
	ult_button.disabled = not bool(ev.get("can_ult", false))
	if engine.needs_target("normal"):
		pending_slot = "normal"
		command_text.text = "%s：点发亮的敌人就是普攻" % str(ev.get("name", ""))
		_mark_targets(engine.legal_target_ids())
	else:
		pending_slot = ""
		command_text.text = "%s：这次普攻打全体，点普攻放出" % str(ev.get("name", ""))
		_clear_targets()
	_focus_command()


func _focus_command() -> void:
	if command == null or command.get_child_count() == 0:
		return
	for child in command.get_child(0).get_children():
		if child is Button and child.visible and not (child as Button).disabled:
			(child as Button).grab_focus()
			return


func _arm_slot(slot: String) -> void:
	if engine == null or not engine.waiting:
		return
	pending_slot = slot
	if engine.needs_target(slot):
		var ids: Array = engine.ball_target_ids() if slot == "ball" else engine.legal_target_ids()
		command_text.text = "点击一个目标"
		_mark_targets(ids)
		return
	_submit(slot, -1)


func _pick_target(uid: int) -> void:
	if pending_slot == "":
		return
	_submit(pending_slot, uid)


func _submit(slot: String, uid: int) -> void:
	_clear_targets()
	if command != null:
		command.visible = false
	pending_slot = ""
	if slot == "ball":
		if not GameState.use_ball():
			toast("没有灵契球", UI.DANGER)
			return
		if engine == null or not engine.throw_ball(uid):
			GameState.items.append("pokeball")
			toast("这个目标不能丢球", UI.DANGER)
			return
	elif engine != null:
		engine.choose(slot, uid)
	_play()


func _mark_targets(ids: Array) -> void:
	for key in cards.keys():
		var card = cards[key]
		var on := ids.has(int(key))
		card.select_mode = on
		card.modulate = Color(1, 1, 0.72) if on else Color.WHITE


func _clear_targets() -> void:
	_mark_targets([])


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
	var step := GameState._growth_step()
	var sub_text := "全员等级 +%d，精灵在 30 / 60 级时进化。" % step if winner == "player" else ("征服战到此为止。" if GameState.run_mode == "conquest" else "远征止步于第 %d 层。" % GameState.current_floor)
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
		go.grab_focus()
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
