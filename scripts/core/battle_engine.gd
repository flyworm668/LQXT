extends RefCounted
## Deterministic 5v5 auto-battle simulation.
## The engine mutates internal copies only and returns an event stream for the
## battle screen, so playback can be fast-forwarded or skipped at any time.

const STATUS_NAMES := {
	"burn": "灼烧", "stun": "眩晕", "slow": "减速", "haste": "急速",
	"atk_up": "攻击提升", "atk_down": "攻击降低", "def_down": "破甲",
	"vulnerable": "易伤", "thorns": "反伤", "vamp": "吸血",
}

var rng := RandomNumberGenerator.new()
var units: Array = []
var by_uid: Dictionary = {}
var events: Array = []
var combat: Dictionary = {}
var rage_max: int = 2
var rounds: int = 0
var winner: String = ""
var _end_emitted := false
var _reported_dead: Dictionary = {}


static func status_name(key: String) -> String:
	return str(STATUS_NAMES.get(key, key))


func simulate(player_units: Array, enemy_units: Array, seed_value: int) -> Dictionary:
	combat = ContentDB.combat()
	rage_max = int(combat.get("rage_max", 2))
	rng.seed = seed_value
	units.clear()
	by_uid.clear()
	events.clear()
	winner = ""
	rounds = 0
	_end_emitted = false
	_reported_dead.clear()
	for u in player_units:
		_add_unit(u)
	for u in enemy_units:
		_add_unit(u)
	var start_snapshot: Array = []
	for u in units:
		start_snapshot.append(_snapshot(u))
	_battle_start()
	var max_rounds := int(combat.get("max_rounds", 60))
	for r in range(1, max_rounds + 1):
		rounds = r
		events.append({"t": "round", "round": r})
		_round_start()
		if _check_end():
			break
		var order := _turn_order()
		for u in order:
			if u["hp"] <= 0:
				continue
			if _check_end():
				break
			if _has_status(u, "stun"):
				u["statuses"].erase("stun")
				events.append({"t": "stunned", "uid": int(u["uid"]),
					"text": "%s 被冰封，无法行动！" % u["name"]})
				continue
			_take_turn(u)
		if winner != "":
			break
		if _check_end():
			break
		_round_end()
	if winner == "":
		winner = _judge_by_hp()
		if not _end_emitted:
			events.append({"t": "log", "text": "战斗超时，按剩余生命比例判定。"})
	_end_emitted = true
	_flush_deaths()
	events.append({"t": "end", "winner": winner, "rounds": rounds})
	return {
		"events": events,
		"winner": winner,
		"rounds": rounds,
		"start": start_snapshot,
		"final": _final_snapshot(),
	}


func _add_unit(source: Dictionary) -> void:
	var u: Dictionary = source.duplicate(true)
	if not u.has("hooks"):
		u["hooks"] = {}
	if not u.has("statuses"):
		u["statuses"] = {}
	units.append(u)
	by_uid[int(u["uid"])] = u


func _snapshot(u: Dictionary) -> Dictionary:
	return {
		"uid": int(u["uid"]), "side": u["side"], "species": u["species"], "name": u["name"],
		"element": u["element"], "class": u["class"], "level": int(u["level"]),
		"stage": int(u.get("stage", 0)), "max_hp": int(u["max_hp"]), "hp": int(u["hp"]),
		"atk": int(u["atk"]), "def": int(u["def"]), "spd": int(u["spd"]),
		"rage": int(u.get("rage", 0)), "shield": int(u.get("shield", 0)),
		"row": int(u["row"]), "col": int(u["col"]), "is_boss": bool(u.get("is_boss", false)),
		"buff_ids": (u.get("buff_ids", []) as Array).duplicate(),
		"skills": (u.get("skills", {}) as Dictionary).duplicate(true),
		"affixes": (u.get("affixes", {}) as Dictionary).duplicate(true),
		"statuses": (u.get("statuses", {}) as Dictionary).duplicate(true),
	}


func _final_snapshot() -> Array:
	var out: Array = []
	for u in units:
		out.append(_snapshot(u))
	return out


func _alive_units(side: String) -> Array:
	var out: Array = []
	for u in units:
		if u["hp"] > 0 and str(u["side"]) == side:
			out.append(u)
	return out


func _opponents(side: String) -> Array:
	return _alive_units("enemy" if side == "player" else "player")


func _team_dead(side: String) -> bool:
	return _alive_units(side).is_empty()


func _has_status(u: Dictionary, key: String) -> bool:
	return (u["statuses"] as Dictionary).has(key)


func _status_pct(u: Dictionary, key: String) -> float:
	var st: Dictionary = u["statuses"].get(key, {})
	return float(st.get("pct", 0.0))


func _status_value(u: Dictionary, key: String) -> float:
	var st: Dictionary = u["statuses"].get(key, {})
	return float(st.get("value", 0.0))


func _atk_eff(u: Dictionary) -> float:
	return float(u["atk"]) * maxf(0.05, 1.0 + _status_pct(u, "atk_up") - _status_pct(u, "atk_down"))


func _def_eff(u: Dictionary) -> float:
	return float(u["def"]) * maxf(0.0, 1.0 - _status_pct(u, "def_down"))


func _spd_eff(u: Dictionary) -> float:
	return float(u["spd"]) * maxf(0.1, 1.0 + _status_pct(u, "haste") - _status_pct(u, "slow"))


func _hp_ratio(u: Dictionary) -> float:
	return float(u["hp"]) / maxf(1.0, float(u["max_hp"]))


# ---------------------------------------------------------------- setup

func _battle_start() -> void:
	for u in units:
		var hooks: Dictionary = u.get("hooks", {})
		var start_rage := int(hooks.get("start_rage", 0))
		if start_rage > 0:
			u["rage"] = mini(rage_max, int(u.get("rage", 0)) + start_rage)
		var start_shield := float(hooks.get("start_shield", 0.0))
		if start_shield > 0.0:
			u["shield"] = int(float(u["max_hp"]) * start_shield)
	# boss "oppress" aura
	for u in units:
		var hooks: Dictionary = u.get("hooks", {})
		var pct := float(hooks.get("oppress", 0.0))
		if pct <= 0.0:
			continue
		for foe in _opponents(str(u["side"])):
			_apply_status(foe, "atk_down", 99, pct)
			events.append({"t": "status", "uid": int(foe["uid"]), "status": "atk_down",
				"dur": 99, "pct": pct, "text": "%s 受到威压，攻击降低！" % foe["name"]})


func _round_start() -> void:
	var tick_entries: Array = []
	var heal_entries: Array = []
	var deaths: Array = []
	for u in units:
		if u["hp"] <= 0:
			continue
		# regeneration from items / boss buffs
		var regen := float((u.get("hooks", {}) as Dictionary).get("regen", 0.0))
		if regen > 0.0:
			var h := _heal(u, int(float(u["max_hp"]) * regen))
			if int(h["amount"]) > 0:
				heal_entries.append(h)
		# burn damage
		if _has_status(u, "burn"):
			var dmg := maxi(1, int(_status_value(u, "burn")))
			var entry := _deal_damage({}, u, dmg, false, 1.0, false)
			tick_entries.append(entry)
			if entry["dead"]:
				deaths.append({"t": "death", "uid": int(u["uid"]), "side": u["side"],
					"text": "%s 被灼烧击倒。" % u["name"]})
	if not tick_entries.is_empty() or not heal_entries.is_empty():
		events.append({"t": "tick", "targets": tick_entries, "heals": heal_entries,
			"text": "回合开始结算。"})
	_flush_deaths()


func _turn_order() -> Array:
	var alive: Array = []
	for u in units:
		if u["hp"] > 0:
			alive.append(u)
	var scores := {}
	for u in alive:
		scores[int(u["uid"])] = _spd_eff(u) * rng.randf_range(0.94, 1.06)
	alive.sort_custom(func(a, b):
		var sa := float(scores[int(a["uid"])])
		var sb := float(scores[int(b["uid"])])
		if is_equal_approx(sa, sb):
			return int(a["uid"]) < int(b["uid"])
		return sa > sb)
	return alive


func _round_end() -> void:
	for u in units:
		if u["hp"] <= 0:
			continue
		var keys: Array = (u["statuses"] as Dictionary).keys()
		for key in keys:
			if key == "stun":
				continue
			var st: Dictionary = u["statuses"][key]
			if int(st.get("applied_round", 0)) == rounds:
				continue
			st["dur"] = int(st.get("dur", 1)) - 1
			if int(st["dur"]) <= 0:
				u["statuses"].erase(key)
			else:
				u["statuses"][key] = st


func _check_end() -> bool:
	if winner != "":
		return true
	if _team_dead("player"):
		winner = "enemy"
		return true
	if _team_dead("enemy"):
		winner = "player"
		return true
	return false


func _judge_by_hp() -> String:
	var player_hp := 0.0
	var player_max := 1.0
	var enemy_hp := 0.0
	var enemy_max := 1.0
	for u in units:
		if str(u["side"]) == "player":
			player_hp += float(maxi(0, int(u["hp"])))
			player_max += float(u["max_hp"])
		else:
			enemy_hp += float(maxi(0, int(u["hp"])))
			enemy_max += float(u["max_hp"])
	return "player" if player_hp / player_max >= enemy_hp / enemy_max else "enemy"


# ---------------------------------------------------------------- turn

func _take_turn(u: Dictionary) -> void:
	var use_ult := int(u.get("rage", 0)) >= rage_max and (u["skills"] as Dictionary).has("ultimate")
	if use_ult:
		u["rage"] = 0
		_use_ultimate(u)
		if _slot_has_affix(u, "ultimate", "rage_fuel"):
			u["rage"] = mini(rage_max, int(u["rage"]) + 1)
	else:
		_use_normal(u)
		u["rage"] = mini(rage_max, int(u.get("rage", 0)) + 1)
		if _slot_has_affix(u, "normal", "rage_fuel"):
			u["rage"] = mini(rage_max, int(u["rage"]) + 1)
	events.append({"t": "rage", "uid": int(u["uid"]), "rage": int(u.get("rage", 0))})


func _slot_has_affix(u: Dictionary, slot: String, affix_id: String) -> bool:
	var list: Array = (u.get("affixes", {}) as Dictionary).get(slot, [])
	return affix_id in list


func _front_target(u: Dictionary) -> Dictionary:
	var foes := _opponents(str(u["side"]))
	if foes.is_empty():
		return {}
	foes.sort_custom(func(a, b):
		var ca := int(a["col"])
		var cb := int(b["col"])
		if ca != cb:
			return ca < cb
		var da := absi(int(a["row"]) - int(u["row"]))
		var db := absi(int(b["row"]) - int(u["row"]))
		if da != db:
			return da < db
		return _hp_ratio(a) < _hp_ratio(b))
	return foes[0]


func _back_target(u: Dictionary) -> Dictionary:
	var foes := _opponents(str(u["side"]))
	if foes.is_empty():
		return {}
	foes.sort_custom(func(a, b):
		var ca := int(a["col"])
		var cb := int(b["col"])
		if ca != cb:
			return ca > cb
		return _hp_ratio(a) < _hp_ratio(b))
	return foes[0]


func _lowest_target(u: Dictionary) -> Dictionary:
	var foes := _opponents(str(u["side"]))
	if foes.is_empty():
		return {}
	var best: Dictionary = foes[0]
	for f in foes:
		if _hp_ratio(f) < _hp_ratio(best):
			best = f
	return best


func _aoe_targets(u: Dictionary, count: int) -> Array:
	var foes := _opponents(str(u["side"]))
	foes.sort_custom(func(a, b):
		var ca := int(a["col"])
		var cb := int(b["col"])
		if ca != cb:
			return ca > cb
		return _hp_ratio(a) < _hp_ratio(b))
	return foes.slice(0, mini(count, foes.size()))


func _lowest_ally(u: Dictionary) -> Dictionary:
	var allies := _alive_units(str(u["side"]))
	if allies.is_empty():
		return {}
	var best: Dictionary = allies[0]
	for a in allies:
		if _hp_ratio(a) < _hp_ratio(best):
			best = a
	return best


func _normal_target(u: Dictionary) -> Dictionary:
	var skill: Dictionary = (u["skills"] as Dictionary).get("normal", {})
	match str(skill.get("target", "front")):
		"back":
			return _back_target(u)
		"lowest":
			return _lowest_target(u)
		_:
			return _front_target(u)


# ---------------------------------------------------------------- skills

func _use_normal(u: Dictionary) -> void:
	var skill: Dictionary = (u["skills"] as Dictionary).get("normal", {})
	var action := _new_action(u, "normal", str(skill.get("name", "普通攻击")))
	var target := _normal_target(u)
	if target.is_empty():
		return
	var dmg_info := _calc_damage(u, target, float(skill.get("mult", 1.0)), "normal")
	var entry := _deal_damage(u, target, int(dmg_info["amount"]), bool(dmg_info["crit"]), float(dmg_info["element"]), true)
	action["targets"].append(entry)
	var deaths: Array = []
	if entry["dead"]:
		deaths.append(entry["uid"])
	# support normal attack also mends the weakest ally
	if str(u["class"]) == "support":
		var ally := _lowest_ally(u)
		if not ally.is_empty():
			var h := _heal(ally, int(float(ally["max_hp"]) * 0.05))
			if int(h["amount"]) > 0:
				action["heals"].append(h)
	elif str(u["class"]) == "guardian":
		var guard_shield := _add_shield(u, int(float(u["max_hp"]) * 0.03))
		action["shields"].append(guard_shield)
	_apply_on_hit_affixes(u, target, "normal", int(entry["damage"]), action, true, deaths)
	_apply_item_on_hit(u, target, "normal", action, true)
	if bool(u.get("is_boss", false)) and int(target["hp"]) > 0:
		_apply_boss_normal_element(u, target, action)
	action["text"] = "%s 使用【%s】攻击 %s，造成 %d 伤害。" % [
		u["name"], action["skill_name"], target["name"], int(entry["damage"])]
	_emit_action(action, deaths, [])
	_check_phase_after(target)


func _use_ultimate(u: Dictionary) -> void:
	var skill: Dictionary = (u["skills"] as Dictionary).get("ultimate", {})
	if skill.is_empty():
		_use_normal(u)
		return
	var action := _new_action(u, "ultimate", str(skill.get("name", "大招")))
	var kind := str(skill.get("kind", "ult_warrior"))
	var deaths: Array = []
	var primary_damage := 0
	match kind:
		"ult_guardian":
			var t := _front_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 1.8)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", primary_damage, action, true, deaths)
				_apply_item_on_hit(u, t, "ultimate", action, true)
			var sh := _add_shield(u, int(float(u["max_hp"]) * 0.12))
			action["shields"].append(sh)
		"ult_warrior":
			var t := _front_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 2.6)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", primary_damage, action, true, deaths)
				_apply_item_on_hit(u, t, "ultimate", action, true)
				var others := _other_targets(u, t)
				if not others.is_empty():
					var splash_amount := int(float(primary_damage) * float(skill.get("splash", 0.3)))
					var se := _deal_damage(u, others[0], maxi(1, splash_amount), false, float(info["element"]), false)
					se["splash"] = true
					action["targets"].append(se)
					if se["dead"]:
						deaths.append(se["uid"])
		"ult_mage":
			var targets := _aoe_targets(u, 3)
			for t in targets:
				var info := _calc_damage(u, t, float(skill.get("mult", 1.35)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				if primary_damage == 0:
					primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", int(e["damage"]), action, false, deaths)
			if not targets.is_empty():
				_apply_item_on_hit(u, targets[0], "ultimate", action, false)
		"ult_archer":
			var t := _lowest_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 2.0)), "ultimate", 0.25)
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", primary_damage, action, true, deaths)
				_apply_item_on_hit(u, t, "ultimate", action, true)
		"ult_support":
			for ally in _alive_units(str(u["side"])):
				var h := _heal(ally, int(float(ally["max_hp"]) * 0.15))
				action["heals"].append(h)
				_apply_status(ally, "atk_up", 2, 0.10)
				action["statuses"].append({"uid": int(ally["uid"]), "status": "atk_up",
					"dur": 2, "pct": 0.10})
		"ult_boss_aoe":
			var targets := _aoe_targets(u, 3)
			for t in targets:
				var info := _calc_damage(u, t, float(skill.get("mult", 1.5)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				if primary_damage == 0:
					primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
		_:
			var t := _front_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 1.5)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
	if kind != "ult_support":
		_apply_ultimate_element(u, action["targets"], action, kind)
	else:
		_apply_support_element(u, action)
	action["text"] = "%s 释放【%s】！" % [u["name"], action["skill_name"]]
	if not action["targets"].is_empty():
		var total := 0
		for t in action["targets"]:
			total += int(t.get("damage", 0))
		action["text"] += " 共造成 %d 伤害。" % total
	if not action["heals"].is_empty():
		var healed := 0
		for h in action["heals"]:
			healed += int(h.get("amount", 0))
		action["text"] += " 治疗 %d 生命。" % healed
	_emit_action(action, deaths, [])
	for t in action["targets"]:
		var tu = by_uid.get(int(t["uid"]))
		if tu != null:
			_check_phase_after(tu)


func _new_action(u: Dictionary, slot: String, skill_name: String) -> Dictionary:
	return {
		"t": "action", "actor": int(u["uid"]), "side": u["side"], "slot": slot,
		"skill_name": skill_name, "targets": [], "heals": [], "shields": [],
		"statuses": [], "text": "",
	}


func _emit_action(action: Dictionary, deaths: Array, phases: Array) -> void:
	events.append(action)
	_flush_deaths()
	for p in phases:
		events.append(p)


func _flush_deaths() -> void:
	for u in units:
		if int(u["hp"]) > 0:
			continue
		var uid := int(u["uid"])
		if _reported_dead.has(uid):
			continue
		_reported_dead[uid] = true
		events.append({"t": "death", "uid": uid, "side": u.get("side", ""),
			"text": "%s 倒下了。" % u.get("name", "")})


func _other_targets(u: Dictionary, except: Dictionary) -> Array:
	var out: Array = []
	for f in _opponents(str(u["side"])):
		if int(f["uid"]) != int(except["uid"]):
			out.append(f)
	out.sort_custom(func(a, b): return int(a["col"]) < int(b["col"]))
	return out


func _apply_ultimate_element(u: Dictionary, targets: Array, action: Dictionary, kind: String) -> void:
	var element := str(u["element"])
	match element:
		"fire":
			for t in targets:
				if not t["dead"]:
					var tu: Dictionary = by_uid[int(t["uid"])]
					var burn := maxi(1, int(float(u["atk"]) * 0.06))
					_apply_status(tu, "burn", 2, 0.0, burn)
					action["statuses"].append({"uid": int(tu["uid"]), "status": "burn", "dur": 2, "value": burn})
		"water":
			for t in targets:
				if not t["dead"]:
					var tu: Dictionary = by_uid[int(t["uid"])]
					_apply_status(tu, "slow", 2, 0.15)
					action["statuses"].append({"uid": int(tu["uid"]), "status": "slow", "dur": 2, "pct": 0.15})
		"wind":
			_apply_status(u, "haste", 2, 0.20)
			action["statuses"].append({"uid": int(u["uid"]), "status": "haste", "dur": 2, "pct": 0.20})
		"earth":
			for t in targets:
				if not t["dead"]:
					var tu: Dictionary = by_uid[int(t["uid"])]
					_apply_status(tu, "def_down", 2, 0.20)
					action["statuses"].append({"uid": int(tu["uid"]), "status": "def_down", "dur": 2, "pct": 0.20})
		"light":
			for ally in _alive_units(str(u["side"])):
				var amt := int(float(ally["max_hp"]) * 0.08)
				var sh := _add_shield(ally, amt)
				action["shields"].append(sh)
		"dark":
			for t in targets:
				if not t["dead"]:
					var tu: Dictionary = by_uid[int(t["uid"])]
					if bool(u.get("is_boss", false)) and int(u.get("tier", 0)) >= 2:
						_apply_status(tu, "vulnerable", 2, 0.15)
						action["statuses"].append({"uid": int(tu["uid"]), "status": "vulnerable", "dur": 2, "pct": 0.15})
					else:
						_apply_status(tu, "atk_down", 2, 0.15)
						action["statuses"].append({"uid": int(tu["uid"]), "status": "atk_down", "dur": 2, "pct": 0.15})


func _apply_boss_normal_element(u: Dictionary, target: Dictionary, action: Dictionary) -> void:
	var element := str(u["element"])
	match element:
		"fire":
			var burn := maxi(1, int(float(u["atk"]) * 0.06))
			_apply_status(target, "burn", 2, 0.0, burn)
			action["statuses"].append({"uid": int(target["uid"]), "status": "burn", "dur": 2, "value": burn})
		"water":
			_apply_status(target, "slow", 2, 0.15)
			action["statuses"].append({"uid": int(target["uid"]), "status": "slow", "dur": 2, "pct": 0.15})
		"wind":
			_apply_status(u, "haste", 2, 0.20)
			action["statuses"].append({"uid": int(u["uid"]), "status": "haste", "dur": 2, "pct": 0.20})
		"earth":
			_apply_status(target, "def_down", 2, 0.20)
			action["statuses"].append({"uid": int(target["uid"]), "status": "def_down", "dur": 2, "pct": 0.20})
		"light":
			var sh := _add_shield(u, int(float(u["max_hp"]) * 0.06))
			action["shields"].append(sh)
		"dark":
			if int(u.get("tier", 0)) >= 2:
				_apply_status(target, "vulnerable", 2, 0.15)
				action["statuses"].append({"uid": int(target["uid"]), "status": "vulnerable", "dur": 2, "pct": 0.15})
			else:
				_apply_status(target, "atk_down", 2, 0.15)
				action["statuses"].append({"uid": int(target["uid"]), "status": "atk_down", "dur": 2, "pct": 0.15})


func _apply_support_element(u: Dictionary, action: Dictionary) -> void:
	var element := str(u["element"])
	match element:
		"wind":
			for ally in _alive_units(str(u["side"])):
				_apply_status(ally, "haste", 2, 0.15)
				action["statuses"].append({"uid": int(ally["uid"]), "status": "haste", "dur": 2, "pct": 0.15})
		"light":
			for ally in _alive_units(str(u["side"])):
				var sh := _add_shield(ally, int(float(ally["max_hp"]) * 0.08))
				action["shields"].append(sh)
		_:
			var t := _front_target(u)
			if t.is_empty():
				return
			var key := "atk_down"
			if element == "fire":
				key = "burn"
			elif element == "water":
				key = "slow"
			elif element == "earth":
				key = "def_down"
			if key == "burn":
				var burn := maxi(1, int(float(u["atk"]) * 0.06))
				_apply_status(t, "burn", 2, 0.0, burn)
				action["statuses"].append({"uid": int(t["uid"]), "status": "burn", "dur": 2, "value": burn})
			else:
				_apply_status(t, key, 2, 0.15)
				action["statuses"].append({"uid": int(t["uid"]), "status": key, "dur": 2, "pct": 0.15})


# ---------------------------------------------------------------- damage

func _calc_damage(src: Dictionary, tgt: Dictionary, mult: float, slot: String,
		extra_crit: float = 0.0) -> Dictionary:
	var atk := _atk_eff(src)
	var defense := _def_eff(tgt)
	var def_coeff := float(combat.get("def_coefficient", 0.4))
	var damage := atk * mult * 100.0 / (100.0 + defense * def_coeff)
	# Formation position affects targeting only; it no longer changes damage.
	var row_mult := 1.0
	var elem_mult := ContentDB.element_multiplier(str(src["element"]), str(tgt["element"]))
	damage *= elem_mult
	# affix: sharp / execute
	if _slot_has_affix(src, slot, "sharp"):
		damage *= 1.15
	if _slot_has_affix(src, slot, "execute") and _hp_ratio(tgt) < 0.35:
		damage *= 1.35
	# status: vulnerable
	if _has_status(tgt, "vulnerable"):
		damage *= 1.0 + _status_pct(tgt, "vulnerable")
	# item hooks
	var hooks: Dictionary = src.get("hooks", {})
	if float(hooks.get("execute", 0.0)) > 0.0 and _hp_ratio(tgt) < 0.40:
		damage *= 1.0 + float(hooks["execute"])
	if bool(tgt.get("is_boss", false)) and float(hooks.get("vs_boss", 0.0)) > 0.0:
		damage *= 1.0 + float(hooks["vs_boss"])
	if slot == "ultimate" and float(hooks.get("ult_damage", 0.0)) > 0.0:
		damage *= 1.0 + float(hooks["ult_damage"])
	# crit
	var crit_chance := clampf(float(src.get("crit", 0.05)) + extra_crit, 0.0, 1.0)
	if _slot_has_affix(src, slot, "crit"):
		crit_chance = clampf(crit_chance + 0.20, 0.0, 1.0)
	var crit := rng.randf() < crit_chance
	if crit:
		damage *= float(combat.get("crit_mult", 1.6))
	damage *= rng.randf_range(0.94, 1.06)
	return {"amount": maxi(1, int(round(damage))), "crit": crit, "element": elem_mult, "row": row_mult}


func _deal_damage(src: Dictionary, tgt: Dictionary, amount: int, crit: bool,
		element_mult: float, allow_reflect: bool = true) -> Dictionary:
	var incoming := maxi(0, amount)
	var warded := float((tgt.get("hooks", {}) as Dictionary).get("warded", 1.0))
	incoming = int(round(float(incoming) * warded))
	var absorbed := 0
	if int(tgt.get("shield", 0)) > 0 and incoming > 0:
		absorbed = mini(int(tgt["shield"]), incoming)
		tgt["shield"] = int(tgt["shield"]) - absorbed
		incoming -= absorbed
	var hp_before := int(tgt["hp"])
	tgt["hp"] = maxi(0, hp_before - incoming)
	var saved := false
	if int(tgt["hp"]) <= 0:
		var hooks: Dictionary = tgt.get("hooks", {})
		if float(hooks.get("last_stand", 0.0)) > 0.0 and not bool(tgt.get("last_stand_used", false)):
			tgt["hp"] = 1
			tgt["last_stand_used"] = true
			saved = true
	var dead := int(tgt["hp"]) <= 0
	if not dead:
		tgt["rage"] = mini(rage_max, int(tgt.get("rage", 0)) + 1)
	# lifesteal
	var lifesteal := float((src.get("hooks", {}) as Dictionary).get("lifesteal", 0.0)) if not src.is_empty() else 0.0
	if not src.is_empty():
		lifesteal += _status_pct(src, "vamp")
	if lifesteal > 0.0 and not dead and not src.is_empty():
		var heal_amt := int(float(hp_before - int(tgt["hp"])) * lifesteal)
		if heal_amt > 0:
			_heal(src, heal_amt)
	# reflect
	if allow_reflect and not src.is_empty() and int(src.get("hp", 0)) > 0:
		var reflect_pct := float((tgt.get("hooks", {}) as Dictionary).get("reflect", 0.0))
		if _has_status(tgt, "thorns"):
			reflect_pct += _status_pct(tgt, "thorns")
		if reflect_pct > 0.0 and incoming > 0:
			var reflected := maxi(1, int(float(incoming) * reflect_pct))
			var rs := int(src.get("shield", 0))
			var absorbed2 := mini(rs, reflected)
			src["shield"] = rs - absorbed2
			src["hp"] = maxi(0, int(src["hp"]) - (reflected - absorbed2))
	return {
		"uid": int(tgt["uid"]), "damage": int(hp_before - int(tgt["hp"])),
		"absorbed": absorbed, "crit": crit, "element": element_mult,
		"hp": int(tgt["hp"]), "max_hp": int(tgt["max_hp"]), "shield": int(tgt.get("shield", 0)),
		"dead": dead, "saved": saved, "rage": int(tgt.get("rage", 0)),
	}


func _heal(u: Dictionary, amount: int) -> Dictionary:
	var before := int(u["hp"])
	u["hp"] = mini(int(u["max_hp"]), before + maxi(0, amount))
	return {"uid": int(u["uid"]), "amount": int(u["hp"]) - before,
		"hp": int(u["hp"]), "max_hp": int(u["max_hp"])}


func _add_shield(u: Dictionary, amount: int) -> Dictionary:
	u["shield"] = int(u.get("shield", 0)) + maxi(0, amount)
	return {"uid": int(u["uid"]), "amount": amount, "shield": int(u["shield"])}


func _apply_status(u: Dictionary, key: String, dur: int, pct: float = 0.0, value: float = 0.0) -> void:
	var statuses: Dictionary = u["statuses"]
	var st: Dictionary = statuses.get(key, {"dur": 0, "pct": 0.0, "value": 0.0})
	st["dur"] = maxi(int(st.get("dur", 0)), dur)
	if pct > 0.0:
		st["pct"] = maxf(float(st.get("pct", 0.0)), pct)
	if value > 0.0:
		st["value"] = maxf(float(st.get("value", 0.0)), value)
	st["applied_round"] = rounds
	statuses[key] = st


func _cleanse_one(u: Dictionary) -> String:
	for key in ["stun", "burn", "slow", "atk_down", "def_down", "vulnerable"]:
		if (u["statuses"] as Dictionary).has(key):
			u["statuses"].erase(key)
			return key
	return ""


func _apply_on_hit_affixes(actor: Dictionary, target: Dictionary, slot: String, primary_damage: int,
		action: Dictionary, allow_extra: bool, deaths: Array) -> void:
	var list: Array = (actor.get("affixes", {}) as Dictionary).get(slot, [])
	if list.is_empty():
		return
	for aid in list:
		var affix: Dictionary = ContentDB.affix(str(aid))
		if affix.is_empty():
			continue
		match str(aid):
			"burn":
				var burn := maxi(1, int(float(actor["atk"]) * 0.06))
				_apply_status(target, "burn", 2, 0.0, burn)
				action["statuses"].append({"uid": int(target["uid"]), "status": "burn", "dur": 2, "value": burn})
			"frost":
				if rng.randf() < 0.20:
					_apply_status(target, "stun", 1)
					action["statuses"].append({"uid": int(target["uid"]), "status": "stun", "dur": 1})
			"drain":
				var h := _heal(actor, int(float(primary_damage) * 0.25))
				if int(h["amount"]) > 0:
					action["heals"].append(h)
			"armor_break":
				_apply_status(target, "def_down", 2, 0.15)
				action["statuses"].append({"uid": int(target["uid"]), "status": "def_down", "dur": 2, "pct": 0.15})
			"double":
				if allow_extra and not target.is_empty() and int(target["hp"]) > 0 and rng.randf() < 0.25:
					var info := _calc_damage(actor, target, 0.5, slot)
					var e := _deal_damage(actor, target, int(info["amount"]), bool(info["crit"]), float(info["element"]), false)
					e["extra"] = true
					action["targets"].append(e)
					if e["dead"]:
						deaths.append(e["uid"])
			"splash":
				if allow_extra:
					var others := _other_targets(actor, target)
					if not others.is_empty():
						var amount := maxi(1, int(float(primary_damage) * 0.30))
						var e := _deal_damage(actor, others[0], amount, false, 1.0, false)
						e["splash"] = true
						action["targets"].append(e)
						if e["dead"]:
							deaths.append(e["uid"])
			"haste":
				_apply_status(actor, "haste", 2, 0.20)
				action["statuses"].append({"uid": int(actor["uid"]), "status": "haste", "dur": 2, "pct": 0.20})
			"shield":
				var sh := _add_shield(actor, int(float(actor["max_hp"]) * 0.08))
				action["shields"].append(sh)
			"cleanse":
				_cleanse_one(actor)
			"heal_ally":
				var ally := _lowest_ally(actor)
				if not ally.is_empty():
					var h2 := _heal(ally, int(float(ally["max_hp"]) * 0.06))
					if int(h2["amount"]) > 0:
						action["heals"].append(h2)
			"thorns":
				_apply_status(actor, "thorns", 2, 0.15)
				action["statuses"].append({"uid": int(actor["uid"]), "status": "thorns", "dur": 2, "pct": 0.15})
			"war_cry":
				for ally in _alive_units(str(actor["side"])):
					_apply_status(ally, "atk_up", 2, 0.10)
					action["statuses"].append({"uid": int(ally["uid"]), "status": "atk_up", "dur": 2, "pct": 0.10})
			"vamp_aura":
				for ally in _alive_units(str(actor["side"])):
					_apply_status(ally, "vamp", 2, 0.08)
					action["statuses"].append({"uid": int(ally["uid"]), "status": "vamp", "dur": 2, "pct": 0.08})
			"vulnerability":
				_apply_status(target, "vulnerable", 2, 0.15)
				action["statuses"].append({"uid": int(target["uid"]), "status": "vulnerable", "dur": 2, "pct": 0.15})


func _apply_item_on_hit(actor: Dictionary, target: Dictionary, slot: String,
		action: Dictionary, allow_extra: bool) -> void:
	var hooks: Dictionary = actor.get("hooks", {})
	var burn_rate := float(hooks.get("burn_on_hit", 0.0))
	if burn_rate > 0.0 and int(target["hp"]) > 0:
		var burn := maxi(1, int(float(actor["atk"]) * burn_rate))
		_apply_status(target, "burn", 2, 0.0, burn)
		action["statuses"].append({"uid": int(target["uid"]), "status": "burn", "dur": 2, "value": burn})
	var slow_rate := float(hooks.get("slow_on_hit", 0.0))
	if slow_rate > 0.0 and int(target["hp"]) > 0:
		_apply_status(target, "slow", 2, slow_rate)
		action["statuses"].append({"uid": int(target["uid"]), "status": "slow", "dur": 2, "pct": slow_rate})
	var double_chance := float(hooks.get("double_normal", 0.0))
	if allow_extra and slot == "normal" and double_chance > 0.0 and int(target["hp"]) > 0:
		if rng.randf() < double_chance:
			var info := _calc_damage(actor, target, 0.5, slot)
			var e := _deal_damage(actor, target, int(info["amount"]), bool(info["crit"]), float(info["element"]), false)
			e["extra"] = true
			action["targets"].append(e)


func _check_phase_after(u: Dictionary) -> void:
	if int(u.get("hp", 0)) <= 0:
		return
	if not bool(u.get("is_boss", false)) or int(u.get("tier", 0)) < 2:
		return
	var phases: Array = u.get("phases", [])
	while int(u.get("phase_index", 0)) < phases.size():
		var ph: Dictionary = phases[int(u["phase_index"])]
		if _hp_ratio(u) <= float(ph.get("hp_pct", 0.0)):
			u["phase_index"] = int(u["phase_index"]) + 1
			var buff_id := str(ph.get("buff", ""))
			_apply_single_boss_buff(u, buff_id)
			u["rage"] = rage_max
			events.append({"t": "phase", "uid": int(u["uid"]), "text": str(ph.get("text", "首领进入新阶段！"))})
		else:
			break


func _apply_single_boss_buff(u: Dictionary, bid: String) -> void:
	var hooks: Dictionary = u.get("hooks", {})
	match bid:
		"frenzy":
			u["atk"] = int(float(u["atk"]) * 1.25)
		"undying":
			u["max_hp"] = int(float(u["max_hp"]) * 1.30)
			u["hp"] = int(u["max_hp"])
		"bedrock":
			u["def"] = int(float(u["def"]) * 1.25)
		"swift":
			u["spd"] = int(float(u["spd"]) * 1.20)
		"bloodthirst":
			hooks["lifesteal"] = float(hooks.get("lifesteal", 0.0)) + 0.20
		"barbed":
			hooks["reflect"] = float(hooks.get("reflect", 0.0)) + 0.12
		"renewal":
			hooks["regen"] = float(hooks.get("regen", 0.0)) + 0.05
		"oppress":
			hooks["oppress"] = float(hooks.get("oppress", 0.0)) + 0.10
		"warded":
			hooks["warded"] = 0.90
		"surge":
			hooks["ult_damage"] = float(hooks.get("ult_damage", 0.0)) + 0.30
	u["hooks"] = hooks
