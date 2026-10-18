extends Node
## Headless verification: data integrity, affix caps, reward odds, encounters
## and full-run balance.  Run with:
##   Godot --headless --path . -- --test

const BattleEngineScript = preload("res://scripts/core/battle_engine.gd")

const SCREEN_SCRIPTS := [
	"res://scripts/main.gd",
	"res://scripts/autoload/content_db.gd",
	"res://scripts/autoload/game_state.gd",
	"res://scripts/autoload/ui.gd",
	"res://scripts/core/battle_engine.gd",
	"res://scripts/ui/screen_base.gd",
	"res://scripts/ui/pet_avatar.gd",
	"res://scripts/ui/backdrop.gd",
	"res://scripts/ui/unit_card.gd",
	"res://scripts/ui/title_screen.gd",
	"res://scripts/ui/trainer_screen.gd",
	"res://scripts/ui/starter_screen.gd",
	"res://scripts/ui/map_screen.gd",
	"res://scripts/ui/formation_screen.gd",
	"res://scripts/ui/battle_screen.gd",
	"res://scripts/ui/reward_screen.gd",
	"res://scripts/ui/affix_screen.gd",
	"res://scripts/ui/result_screen.gd",
]

var failures: Array = []
var checks: int = 0
var floor_attempts: Dictionary = {}
var floor_wins: Dictionary = {}
var run_count: int = 0
var run_wins: int = 0
var battles: int = 0
var total_rounds: int = 0
var _validated_runs: int = 0


func _ready() -> void:
	await get_tree().process_frame
	GameState.persist_enabled = false
	print("== 灵契·星塔远征 — headless verification ==")
	_test_content()
	_test_scripts_load()
	_test_affix_caps()
	_test_reward_odds()
	_test_encounters()
	_test_full_runs(96)
	await _test_ui_flow()
	GameState.persist_enabled = true
	_print_balance()
	_print_summary()
	get_tree().quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)


func _test_content() -> void:
	print("-- content integrity")
	check(ContentDB.pets_by_id.size() == 50, "50 pets")
	check(ContentDB.data.get("starters", []).size() == 3, "3 starters")
	check(ContentDB.trainers_by_id.size() == 3, "3 trainers")
	check(ContentDB.affixes_by_id.size() == 18, "18 affixes")
	check(ContentDB.items_by_id.size() == 20, "20 items")
	check(ContentDB.bosses_by_id.size() == 3, "3 bosses")
	check(ContentDB.floors_by_num.size() == 10, "10 floors")
	check(GameState.MAX_DEPLOY == 5, "autoload constant accessible")
	for p in ContentDB.data["pets"]:
		check((p["names"] as Array).size() == 3, "three evolution names: " + str(p["id"]))
		check(ContentDB.pets_by_id.has(p["id"]), "pet id indexed")
		for slot in ["normal", "ultimate"]:
			var sk: Dictionary = p["skills"][slot]
			check(not str(sk.get("id", "")).is_empty(), "%s %s skill id" % [p["id"], slot])
			check(float(sk.get("mult", -1)) >= 0.0, "%s %s multiplier" % [p["id"], slot])
	for f in ContentDB.data["floors"]:
		for pid in f["pool"]:
			check(ContentDB.pets_by_id.has(pid), "floor pool reference " + str(pid))
		if str(f["kind"]) == "boss":
			check(ContentDB.bosses_by_id.has(f["boss"]), "boss reference " + str(f["boss"]))
	check(ContentDB.stage_for_level(10) == 0, "stage 1 at lv10")
	check(ContentDB.stage_for_level(30) == 1, "stage 2 at lv30")
	check(ContentDB.stage_for_level(59) == 1, "stage 2 at lv59")
	check(ContentDB.stage_for_level(60) == 2, "stage 3 at lv60")
	check(ContentDB.stage_for_level(100) == 2, "stage 3 at lv100")
	check(is_equal_approx(ContentDB.element_multiplier("fire", "wind"), 1.25), "fire beats wind")
	check(is_equal_approx(ContentDB.element_multiplier("fire", "water"), 0.80), "fire loses to water")
	check(is_equal_approx(ContentDB.element_multiplier("light", "dark"), 1.25), "light/dark mutual")
	var lv10: Dictionary = ContentDB.pet_stats("p01", 10)
	var lv100: Dictionary = ContentDB.pet_stats("p01", 100)
	check(int(lv100["hp"]) > int(lv10["hp"]), "hp scales with level")
	check(int(lv100["atk"]) > int(lv10["atk"]), "atk scales with level")
	var raw := FileAccess.get_file_as_string("res://data/content.json")
	check(not raw.to_lower().contains("mirror"), "no mirror rule in data")
	check(not raw.to_lower().contains("higheststat"), "no highestStat rule in data")


func _test_scripts_load() -> void:
	print("-- script compilation")
	for path in SCREEN_SCRIPTS:
		var script = load(path)
		check(script != null, "loads " + path)


func _test_affix_caps() -> void:
	print("-- affix caps and replacement")
	GameState.start_run("novice", "p01", 12345)
	var entry: Dictionary = GameState.roster[0]
	var uid := int(entry["uid"])
	var ids: Array = []
	for a in ContentDB.data["affixes"]:
		ids.append(str(a["id"]))
	check(GameState.attach_affix(uid, "normal", ids[0]), "attach affix 1")
	check(GameState.attach_affix(uid, "normal", ids[1]), "attach affix 2")
	check(GameState.attach_affix(uid, "normal", ids[2]), "attach affix 3")
	check(not GameState.attach_affix(uid, "normal", ids[3]), "4th affix on one skill rejected")
	check(GameState.attach_affix(uid, "ultimate", ids[3]), "attach ultimate 1")
	check(GameState.attach_affix(uid, "ultimate", ids[4]), "attach ultimate 2")
	check(GameState.attach_affix(uid, "ultimate", ids[5]), "attach ultimate 3")
	check(GameState.total_affixes(entry) == 6, "pet reaches 6 affixes")
	check(not GameState.attach_affix(uid, "normal", ids[6]), "7th affix on pet rejected")
	check(GameState.attach_affix(uid, "normal", ids[7], 0), "replace affix at index 0")
	check(GameState.total_affixes(entry) == 6, "replacement keeps total at 6")
	check(not GameState.attach_affix(uid, "normal", ids[7]), "duplicate affix on same skill rejected")
	check(GameState.can_replace(uid, "normal"), "can_replace reports true")
	var can: Dictionary = GameState.can_attach(uid, "ultimate")
	check(not bool(can["ok"]) and bool(can.get("full_skill", false)), "full skill reported")


func _test_reward_odds() -> void:
	print("-- chest odds (4000 rolls)")
	GameState.start_run("novice", "p01", 98765)
	var trials := 4000
	var item_hits := 0
	var affix_hits := 0
	var pet_hits := 0
	for i in range(trials):
		GameState.roll_rewards()
		var pr: Dictionary = GameState.pending_rewards
		if not pr.is_empty():
			if str(pr.get("pet", {}).get("kind", "")) != "":
				pet_hits += 1
			if str(pr.get("item", {}).get("kind", "none")) == "item":
				item_hits += 1
			if str(pr.get("affix", {}).get("kind", "none")) == "affix":
				affix_hits += 1
	var item_rate := float(item_hits) / float(trials)
	var affix_rate := float(affix_hits) / float(trials)
	print("   pet %.1f%%  item %.1f%%  affix %.1f%%" % [
		float(pet_hits) * 100.0 / float(trials), item_rate * 100.0, affix_rate * 100.0])
	check(pet_hits == trials, "pet reward is guaranteed")
	check(absf(item_rate - 0.50) < 0.035, "item reward ~50%")
	check(absf(affix_rate - 0.25) < 0.030, "affix reward ~25%")
	check(GameState.pending_rewards["affix"].get("candidates", []).size() == 3 or
		str(GameState.pending_rewards["affix"].get("kind", "")) == "none",
		"affix draft has three candidates when rolled")


func _test_encounters() -> void:
	print("-- encounter generation")
	GameState.start_run("novice", "p01", 424242)
	var expected_counts := {1: 1, 2: 2, 3: 3, 4: 5, 5: 5, 6: 5, 7: 5, 8: 5, 9: 5, 10: 5}
	for trial in range(12):
		for f in range(1, 11):
			GameState.current_floor = f
			var enc: Dictionary = GameState.generate_encounter(f)
			var enemies: Array = enc["enemies"]
			check(enemies.size() == int(expected_counts[f]), "floor %d enemy count %d" % [f, enemies.size()])
			var floor_data: Dictionary = ContentDB.floor(f)
			var boss_seen := false
			var minions := 0
			for e in enemies:
				if bool(e.get("is_boss", false)):
					boss_seen = true
				else:
					minions += 1
					check(str(e["species"]) in floor_data["pool"], "floor %d enemy from pool" % f)
			if str(floor_data["kind"]) == "boss":
				check(boss_seen, "floor %d has boss" % f)
				check(minions == int(floor_data["minion_count"]), "floor %d minion count" % f)
			else:
				check(not boss_seen, "floor %d no boss" % f)


func _simulate_run(trainer_id: String, starter_id: String, seed_value: int) -> Dictionary:
	GameState.start_run(trainer_id, starter_id, seed_value)
	for f in range(1, 11):
		_place_test_formation()
		var engine = BattleEngineScript.new()
		var result: Dictionary = engine.simulate(
			GameState.build_player_units(), GameState.build_enemy_units(),
			GameState.next_battle_seed())
		battles += 1
		total_rounds += int(result.get("rounds", 0))
		floor_attempts[f] = int(floor_attempts.get(f, 0)) + 1
		if _validated_runs < 12:
			var evs: Array = result.get("events", [])
			check(not evs.is_empty() and str(evs.back().get("t", "")) == "end", "event stream ends with end")
			for u in result.get("final", []):
				check(int(u["hp"]) >= 0 and int(u["hp"]) <= int(u["max_hp"]), "hp in range")
				check(int(u.get("rage", 0)) >= 0 and int(u.get("rage", 0)) <= 2, "rage in range")
		if str(result.get("winner", "")) != "player":
			GameState.end_run_defeat()
			return {"won": false, "floor": f, "rounds": int(result.get("rounds", 0))}
		floor_wins[f] = int(floor_wins.get(f, 0)) + 1
		GameState.apply_victory()
		GameState.claim_pet_reward()
		GameState.claim_item_reward()
		var ar: Dictionary = GameState.pending_rewards.get("affix", {})
		if str(ar.get("kind", "none")) == "affix":
			var candidates: Array = ar.get("candidates", [])
			var done := false
			for entry in GameState.roster:
				for slot in ["normal", "ultimate"]:
					if done:
						break
					var can: Dictionary = GameState.can_attach(int(entry["uid"]), str(slot))
					if not bool(can.get("ok", false)):
						continue
					var aid := str(candidates[0]["id"])
					if aid in (entry["affixes"] as Dictionary).get(slot, []):
						continue
					if GameState.claim_affix_reward(int(entry["uid"]), str(slot), aid):
						done = true
			if not done:
				GameState.convert_affix_reward()
		if f >= 10:
			return {"won": true, "floor": 10, "rounds": int(result.get("rounds", 0))}
		GameState.advance_floor()
	return {"won": false, "floor": 10, "rounds": 0}


func _place_test_formation() -> void:
	var count := mini(GameState.roster.size(), 5)
	var templates: Dictionary = ContentDB.data["formation"].get("player_templates", {})
	var positions: Array = templates.get(str(count), [])
	var placements: Array = []
	for i in range(mini(count, positions.size())):
		placements.append({
			"uid": int(GameState.roster[i]["uid"]),
			"row": int(positions[i][0]),
			"col": int(positions[i][1]),
		})
	GameState.set_deployment(placements)


func _test_full_runs(count: int) -> void:
	print("-- full run simulations (%d runs)" % count)
	var trainer_ids: Array = []
	for t in ContentDB.data["trainers"]:
		trainer_ids.append(str(t["id"]))
	var starter_ids: Array = []
	for s in ContentDB.data["starters"]:
		starter_ids.append(str(s["id"]))
	run_count = count
	for i in range(count):
		var tid := str(trainer_ids[i % trainer_ids.size()])
		var sid := str(starter_ids[i % starter_ids.size()])
		var res := _simulate_run(tid, sid, 10007 + i * 7919)
		if bool(res["won"]):
			run_wins += 1
		_validated_runs += 1
	check(battles >= count, "battles executed")
	check(run_wins > 0, "at least one full ten-floor clear in simulation")


func _test_ui_flow() -> void:
	print("-- UI flow smoke test")
	var main = get_tree().current_scene
	await main.goto("res://scripts/ui/title_screen.gd")
	await get_tree().create_timer(0.5).timeout
	var title = main.current_screen
	var start_btn = _find_button(title, "开 始 远 征")
	check(start_btn != null, "title start button wired")
	if start_btn == null:
		return
	start_btn.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	var trainer = main.current_screen
	check(trainer != null and trainer.has_method("_confirm"), "trainer screen loaded")
	if trainer == null:
		return
	trainer.call("_select", "veteran")
	var trainer_btn = _find_button(trainer, "以「")
	check(trainer_btn != null, "trainer confirm button wired")
	if trainer_btn == null:
		return
	trainer_btn.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	var starter = main.current_screen
	check(starter != null and starter.has_method("_select"), "starter screen loaded")
	if starter == null:
		return
	starter.call("_select", "p01")
	var starter_btn = _find_button(starter, "契约「")
	check(starter_btn != null, "starter confirm button wired")
	if starter_btn == null:
		return
	starter_btn.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	var first_formation = main.current_screen
	check(first_formation != null and first_formation.has_method("_save_and_fight"), "first formation screen loaded")
	check(GameState.deployed.is_empty(), "formation starts empty")
	if first_formation == null:
		return
	first_formation.placements = [{"uid": int(GameState.roster[0]["uid"]), "row": 1, "col": 0}]
	first_formation.call("_persist")
	var begin_btn = _find_button(first_formation, "保存并挑战")
	check(begin_btn != null, "manual formation challenge button wired")
	if begin_btn == null:
		return
	begin_btn.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	var battle = main.current_screen
	check(battle != null and battle.has_method("_claim_victory"), "battle screen loaded")
	if battle == null:
		return
	check((battle.events as Array).size() > 0, "battle produced events")
	battle.call("_skip")
	await get_tree().create_timer(0.5).timeout
	battle.call("_claim_victory")
	await get_tree().create_timer(0.75).timeout
	var reward = main.current_screen
	check(reward != null and reward.has_method("_continue"), "reward screen loaded")
	check(not GameState.pending_rewards.is_empty(), "rewards rolled")
	check(GameState.roster[0]["level"] == 20, "victory levels the roster")
	var continue_btn = _find_button(reward, "继续前进")
	check(continue_btn != null, "reward continue button wired")
	if continue_btn == null:
		return
	continue_btn.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	check(GameState.current_floor == 2, "continue advances the floor")
	check(GameState.deployed.size() == 1, "formation is preserved across floors")
	await main.goto("res://scripts/ui/formation_screen.gd")
	await get_tree().create_timer(0.5).timeout
	var formation = main.current_screen
	check(formation != null and formation.has_method("_save_and_back"), "formation screen loaded")
	if formation != null:
		var saved: Array = GameState.deployed.duplicate(true)
		saved.append({"uid": int(GameState.roster[1]["uid"]), "row": 2, "col": 0})
		formation.placements = saved
		formation.call("_persist")
		formation.call("_switch_preset", 1)
		check(GameState.active_preset == 1, "formation preset switch")
		check((formation.placements as Array).is_empty(), "empty preset stays empty")
		formation.call("_switch_preset", 0)
		check(GameState.active_preset == 0, "formation preset switch back")
		check((formation.placements as Array).size() > 0, "saved preset restores deployment")
		var save_btn = _find_button(formation, "保存并返回")
		check(save_btn != null, "formation save button wired")
		if save_btn != null:
			save_btn.pressed.emit()
			await get_tree().create_timer(0.65).timeout
			check(main.current_screen != null and main.current_screen.has_method("_start_battle"), "formation returns to map")


func _find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and str(child.text).begins_with(prefix):
			return child
		var found := _find_button(child, prefix)
		if found != null:
			return found
	return null


func _print_balance() -> void:
	print("-- balance report")
	for f in range(1, 11):
		var attempts := int(floor_attempts.get(f, 0))
		var wins := int(floor_wins.get(f, 0))
		var rate := 0.0 if attempts == 0 else float(wins) * 100.0 / float(attempts)
		var tag := "BOSS" if f in [4, 8, 10] else "    "
		print("   floor %2d %s  attempt %3d  win %3d  rate %5.1f%%" % [f, tag, attempts, wins, rate])
	var avg_rounds := 0.0 if battles == 0 else float(total_rounds) / float(battles)
	print("   full clears: %d / %d (%.1f%%)  battles %d  avg rounds %.1f" % [
		run_wins, run_count, 100.0 * float(run_wins) / float(maxi(1, run_count)), battles, avg_rounds])
	check(avg_rounds < 45.0, "average battle length under 45 rounds")
	check(int(floor_wins.get(1, 0)) * 2 >= int(floor_attempts.get(1, 1)), "floor 1 win rate >= 50%")
	check(run_wins > 0, "balance: at least one clear")


func _print_summary() -> void:
	print("-- summary")
	print("   checks: %d   failures: %d" % [checks, failures.size()])
	if failures.is_empty():
		print("   RESULT: PASS")
	else:
		for f in failures:
			print("   FAIL: ", f)
		print("   RESULT: FAIL")
