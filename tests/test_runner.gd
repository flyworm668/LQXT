extends Node
## Headless verification: data integrity, affix caps, reward odds, encounters,
## resonance, events, hero spirits and full-run balance.  Run with:
##   Godot --headless --path . -- --test

const BattleEngineScript = preload("res://scripts/core/battle_engine.gd")
const TypeChartScript = preload("res://scripts/ui/type_chart.gd")

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
	"res://scripts/ui/item_pick_screen.gd",
	"res://scripts/ui/map_screen.gd",
	"res://scripts/ui/formation_screen.gd",
	"res://scripts/ui/battle_screen.gd",
	"res://scripts/ui/reward_screen.gd",
	"res://scripts/ui/affix_screen.gd",
	"res://scripts/ui/event_screen.gd",
	"res://scripts/ui/result_screen.gd",
	"res://scripts/ui/pet_detail.gd",
	"res://scripts/ui/type_chart.gd",
	"res://scripts/ui/run_menu.gd",
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
	_test_trainers()
	_test_reward_odds()
	_test_item_cap()
	_test_resonance()
	_test_encounters()
	_test_events()
	_test_curse()
	_test_hero()
	_test_kings()
	_test_conquest()
	_test_roster_view()
	_test_run_snapshot()
	_test_save_slots()
	_test_full_runs(48)
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
	check(ContentDB.affixes_by_id.size() == 25, "25 affixes")
	check(not bool(ContentDB.affix("miracle").get("pool", true)), "miracle stays out of the chest")
	check(ContentDB.items_by_id.size() == 20, "20 items")
	check(ContentDB.bosses_by_id.size() == 8, "8 bosses")
	check(ContentDB.floors_by_num.size() == 40, "40 floors")
	check(ContentDB.total_floors() == 40, "total_floors reports 40")
	check(GameState.MAX_DEPLOY == 5, "autoload constant accessible")
	check(ContentDB.resonance_data.size() == 17, "17 resonance elements")
	check(ContentDB.data.get("elements", {}).size() == 17, "17 elements")
	check(ContentDB.data.get("demons", []).size() == 8, "8 demons")
	var formation: Dictionary = ContentDB.data.get("formation", {})
	var links: Array = formation.get("links", [])
	check(links.size() == 10, "10 formation links")
	var starters: Array = ContentDB.data.get("starters", [])
	var starter_ids: Array = []
	for s in starters:
		var row: Dictionary = s
		starter_ids.append(str(row.get("id", "")))
	check(starter_ids == ["p01", "p10", "p25"], "starters are fire water grass")
	var combat: Dictionary = ContentDB.combat()
	check(int(combat.get("max_level", 0)) == 150, "max level 150")
	var caps: Dictionary = combat.get("rarity_max_level", {})
	check(int(caps.get("common", 0)) == 60, "common cap 60")
	check(int(caps.get("rare", 0)) == 70, "rare cap 70")
	check(int(caps.get("epic", 0)) == 80, "epic cap 80")
	check(int(caps.get("legend", 0)) == 90, "legend cap 90")
	check(int(caps.get("hero", 0)) == 100, "hero cap 100")
	check(int(caps.get("demon_king", 0)) == 150, "demon king cap 150")
	check(int(combat.get("level_up_per_floor", 0)) == 5, "+5 levels per floor")
	check(is_equal_approx(float(combat.get("chest_item_chance", 0.0)), 1.0), "item chest chance 100%")
	check(is_equal_approx(float(combat.get("chest_affix_chance", 0.0)), 1.0), "affix chest chance 100%")
	check(is_equal_approx(float(combat.get("chest_hero_chance", 0.0)), 0.0), "no separate hero chest roll")
	var weights: Dictionary = combat.get("chest_rarity_weights", {})
	check(int(weights.get("common", 0)) == 45, "common weight 45")
	check(int(weights.get("rare", 0)) == 25, "rare weight 25")
	check(int(weights.get("epic", 0)) == 15, "epic weight 15")
	check(int(weights.get("legend", 0)) == 10, "legend weight 10")
	check(int(weights.get("hero", 0)) == 5, "hero weight 5")
	check(int(ContentDB.item("rage_amulet").get("max_stack", 0)) == 2, "rage amulet cap 2")
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
			check(int(f.get("minion_affix_count", 0)) >= 1, "boss floor minions have affixes")
	check(ContentDB.stage_for_level(10) == 0, "stage 1 at lv10")
	check(ContentDB.stage_for_level(30) == 1, "stage 2 at lv30")
	check(ContentDB.stage_for_level(59) == 1, "stage 2 at lv59")
	check(ContentDB.stage_for_level(60) == 2, "stage 3 at lv60")
	check(ContentDB.stage_for_level(120) == 2, "stage 3 at lv120")
	check(is_equal_approx(ContentDB.element_multiplier("fire", "grass"), 2.0), "fire beats grass")
	check(is_equal_approx(ContentDB.element_multiplier("fire", "water"), 0.5), "fire loses to water")
	check(is_equal_approx(ContentDB.element_multiplier("normal", "ghost"), 0.0), "normal misses ghost")
	check(is_equal_approx(ContentDB.element_multiplier("electric", "ground"), 0.0), "electric misses ground")
	check(is_equal_approx(ContentDB.element_multiplier("water", "fire"), 2.0), "water beats fire")
	var rarity_counts := {"common": 0, "rare": 0, "epic": 0, "legend": 0, "hero": 0}
	for p in ContentDB.data["pets"]:
		var rarity := str(p.get("rarity", ""))
		rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
		var mark: Dictionary = p.get("mark", {})
		if rarity == "common":
			check(mark.is_empty(), str(p["id"]) + " common has no mark")
		else:
			check(not mark.is_empty(), str(p["id"]) + " rare+ has a mark")
			var ult: Dictionary = p["skills"]["ultimate"]
			var sig: Dictionary = ult.get("signature", {})
			check(not str(sig.get("style", "")).is_empty(), str(p["id"]) + " has a signature")
	check(int(rarity_counts["common"]) == 18, "18 common pets")
	check(int(rarity_counts["rare"]) == 14, "14 rare pets")
	check(int(rarity_counts["epic"]) == 9, "9 epic pets")
	check(int(rarity_counts["legend"]) == 6, "6 legend pets")
	check(int(rarity_counts["hero"]) == 3, "3 hero pets")
	for dmn in ContentDB.data["demons"]:
		check(not ContentDB.all_pet_ids().has(str(dmn["id"])), "demon stays out of the chest pool")
	var lv10: Dictionary = ContentDB.pet_stats("p01", 10)
	var lv120: Dictionary = ContentDB.pet_stats("p01", 120)
	check(int(lv120["hp"]) > int(lv10["hp"]), "hp scales with level")
	check(int(lv120["atk"]) > int(lv10["atk"]), "atk scales with level")
	var raw := FileAccess.get_file_as_string("res://data/content.json")
	check(not raw.to_lower().contains("mirror"), "no mirror rule in data")
	check(not raw.to_lower().contains("higheststat"), "no highestStat rule in data")


func _test_scripts_load() -> void:
	print("-- script compilation")
	for path in SCREEN_SCRIPTS:
		var script = load(path)
		check(script != null, "loads " + path)


func _test_run_snapshot() -> void:
	print("-- run snapshot")
	GameState.start_run("novice", "p01", 4242)
	GameState.current_floor = 7
	var uid := int(GameState.roster[0]["uid"])
	var state_before: int = GameState.rng.state
	var snap: Dictionary = GameState.capture_run("map")
	GameState.roster.clear()
	GameState.current_floor = 1
	GameState.rng.randi()
	GameState.restore_run(snap)
	check(GameState.current_floor == 7, "snapshot restores floor")
	check(GameState.roster.size() == 1 and int(GameState.roster[0]["uid"]) == uid, "snapshot restores roster")
	check(int(GameState.rng.state) == state_before, "snapshot restores rng")
	check(GameState.run_seed == 4242, "snapshot keeps seed")
	check(str(snap.get("screen", "")) == "map", "snapshot records screen")
	check(TypeChartScript.ORDER.size() == 17, "type chart lists 17 elements")
	var doubled := false
	var immune := false
	for atk in TypeChartScript.ORDER:
		for def in TypeChartScript.ORDER:
			var mult := ContentDB.element_multiplier(atk, def)
			if mult >= 1.9:
				doubled = true
			if mult <= 0.01:
				immune = true
	check(doubled and immune, "type chart has advantage and immunity")


func _test_affix_caps() -> void:
	print("-- affix caps and replacement")
	GameState.start_run("novice", "p01", 12345)
	var added: Dictionary = GameState.add_owned_species("p02")
	var entry: Dictionary = added["entry"]
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


func _test_trainers() -> void:
	print("-- trainers, affix bag, unbound")
	GameState.start_run("novice", "p01", 11)
	var starter: Dictionary = GameState.roster[0]
	check(not bool(starter.get("uncapped", false)), "starter is no longer uncapped")
	check(bool(starter.get("chosen", false)), "starter is the chosen pet")
	check(not ("miracle" in starter["affixes"]["basic"]), "miracle is not pre-attached")
	check("miracle" in GameState.affix_bag, "novice keeps miracle in the bag")
	check("unbound" in GameState.affix_bag, "run starts with unbound")
	check(GameState.items.is_empty(), "novice starts with no items")
	var rare: Dictionary = GameState.add_owned_species("p02")["entry"]
	var refused := GameState.attach_from_bag(int(rare["uid"]), "normal", "unbound")
	check(refused.find("只能") >= 0, "unbound refuses a rare pet")
	check("unbound" in GameState.affix_bag, "refused unbound stays in the bag")
	var common_id := ""
	for p in ContentDB.data.get("pets", []):
		if str(p.get("rarity", "")) == "common":
			common_id = str(p["id"])
			break
	var common: Dictionary = GameState.add_owned_species(common_id)["entry"]
	var refused_common := GameState.attach_from_bag(int(common["uid"]), "basic", "unbound")
	check(refused_common.find("只能") >= 0, "unbound refuses a pet the player did not choose")
	var given := GameState.attach_from_bag(int(starter["uid"]), "basic", "unbound")
	check(bool(starter.get("uncapped", false)), "unbound removes the chosen pet cap")
	check(given.find("无限") >= 0, "unbound attaches to the chosen pet")
	check(GameState.attach_affix(int(starter["uid"]), "basic", "sharp"), "unbound chosen pet accepts an affix")
	check(GameState.attach_affix(int(starter["uid"]), "basic", "sharp"), "unbound chosen pet stacks the same affix")
	for i in range(8):
		GameState.attach_affix(int(starter["uid"]), "basic", "drain")
	check(GameState.total_affixes(starter) > 6, "unbound chosen pet passes the pet cap")
	var steps := 30
	for _i in range(steps):
		GameState.apply_victory()
	var base := int(ContentDB.combat().get("base_level", 10))
	var step := int(ContentDB.combat().get("level_up_per_floor", 5))
	var rare_cap := ContentDB.pet_max_level("p02", false, false)
	check(int(starter["level"]) == base + steps * step, "unbound chosen pet ignores the level cap")
	check(int(rare["level"]) == rare_cap, "rare pet caps at its rarity")
	check(int(common["level"]) == ContentDB.pet_max_level(common_id, false, false), "an unchosen common pet still caps")
	var capped_max := base
	for entry in GameState.roster:
		if not bool(entry.get("uncapped", false)):
			capped_max = maxi(capped_max, int(entry["level"]))
	check(GameState.party_level() == mini(150, capped_max), "party level follows the capped pets")
	check(ContentDB.pet_max_level("p01", false, true) == 0, "uncapped flag still means no level cap")
	var legend_id := ""
	common_id = ""
	for p in ContentDB.data.get("pets", []):
		if legend_id == "" and str(p.get("rarity", "")) == "legend":
			legend_id = str(p["id"])
		if common_id == "" and str(p.get("rarity", "")) == "common":
			common_id = str(p["id"])
	check(ContentDB.pet_max_level(common_id) == 60, "common pet caps at 60")
	check(ContentDB.pet_max_level(legend_id) == 90, "legend pet caps at 90")
	check(ContentDB.pet_max_level("d1", true) == 180, "demon caps at 180")
	check(ContentDB.pet_max_level("d5", true) == 195, "first king demon caps at 195")
	check(ContentDB.pet_max_level("d8", true) == 230, "fourth king demon caps at 230")
	check(ContentDB.pet_max_level("d11", true) == 500, "last king demon caps at 500")
	var roll := RandomNumberGenerator.new()
	roll.seed = 3
	var leaked := false
	for _i in range(200):
		for a in ContentDB.affix_candidates(roll, 3):
			var aid := str(a.get("id", ""))
			if aid in ["miracle", "unbound", "barrier_blade", "rebound", "volley", "aegis", "still"]:
				leaked = true
	check(not leaked, "special affixes stay out of the normal chest pool")
	var engine = BattleEngineScript.new()
	engine.combat = ContentDB.combat()
	engine.rng.seed = 7
	var src := {
		"atk": 100, "def": 20, "hp": 100, "max_hp": 100, "element": "fire",
		"statuses": {}, "crit": 0.05, "hooks": {}, "marks": {}, "link": {},
		"affixes": {"normal": ["miracle"], "ultimate": []},
	}
	var tgt := src.duplicate(true)
	tgt["element"] = "water"
	var hits := 0
	for _i in range(800):
		var info: Dictionary = engine._calc_damage(src, tgt, 1.0, "normal")
		if int(info.get("amount", 0)) >= 99999:
			hits += 1
	check(hits >= 1 and hits < 80, "miracle procs about 2 percent (%d/800)" % hits)
	GameState.start_run("veteran", "p01", 5, ["hp_charm", "atk_charm", "def_charm"])
	check(GameState.items.size() == 3, "advanced trainer keeps the three chosen items")
	var veteran_mods: Dictionary = GameState.trainer.get("mods", {})
	check(is_equal_approx(float(veteran_mods.get("def_mult", 0.0)), 0.10), "advanced trainer grants defense")
	GameState.start_run("veteran", "p01", 6, ["rage_amulet", "rage_amulet", "rage_amulet"])
	check(GameState.items.size() == 2, "starting items respect the stack cap")
	var hero_id := ""
	for p in ContentDB.data.get("pets", []):
		if str(p.get("rarity", "")) == "hero":
			hero_id = str(p["id"])
			break
	GameState.start_run("master", hero_id, 4)
	var hero: Dictionary = GameState.roster[0]
	check(bool(hero.get("hero", false)) and not bool(hero.get("uncapped", false)), "master starter is a capped hero")
	var hero_refuse := GameState.attach_from_bag(int(hero["uid"]), "normal", "unbound")
	check(hero_refuse.find("只能") >= 0, "unbound refuses a hero")
	var master_mods: Dictionary = GameState.trainer.get("mods", {})
	check(is_equal_approx(float(master_mods.get("hp_mult", 0.0)), 0.20), "veteran trainer grants 20 percent")


func _test_reward_odds() -> void:
	print("-- chest odds (2000 rolls)")
	GameState.start_run("novice", "p01", 98765)
	var trials := 2000
	var item_hits := 0
	var affix_hits := 0
	var pet_hits := 0
	var hero_cards := 0
	var hero_pets := 0
	for i in range(trials):
		GameState.roll_rewards()
		var pr: Dictionary = GameState.pending_rewards
		if not pr.is_empty():
			if str(pr.get("pet", {}).get("kind", "")) != "":
				pet_hits += 1
				var species := str(pr.get("pet", {}).get("species", ""))
				if str(ContentDB.pet(species).get("rarity", "")) == "hero":
					hero_pets += 1
			if str(pr.get("item", {}).get("kind", "none")) == "item":
				item_hits += 1
			if str(pr.get("affix", {}).get("kind", "none")) == "affix":
				affix_hits += 1
			if str(pr.get("hero", {}).get("kind", "none")) == "hero":
				hero_cards += 1
	var item_rate := float(item_hits) / float(trials)
	var affix_rate := float(affix_hits) / float(trials)
	var hero_rate := float(hero_pets) / float(trials)
	print("   pet %.1f%%  item %.1f%%  affix %.1f%%  hero species %.1f%%" % [
		float(pet_hits) * 100.0 / float(trials), item_rate * 100.0,
		affix_rate * 100.0, hero_rate * 100.0])
	check(pet_hits == trials, "pet reward is guaranteed")
	check(item_hits == trials, "item reward is guaranteed")
	check(affix_hits == trials, "affix reward is guaranteed")
	check(hero_cards == 0, "no separate hero card")
	check(absf(hero_rate - 0.05) < 0.025, "hero species ~5%")
	check(GameState.pending_rewards["affix"].get("candidates", []).size() == 3,
		"affix draft has three candidates")


func _test_item_cap() -> void:
	print("-- item stack caps")
	GameState.start_run("novice", "p01", 24680)
	check(GameState.add_item("rage_amulet"), "first rage amulet accepted")
	check(GameState.add_item("rage_amulet"), "second rage amulet accepted")
	check(not GameState.add_item("rage_amulet"), "third rage amulet rejected")
	check(int(GameState.item_counts().get("rage_amulet", 0)) == 2, "rage amulet capped at 2")
	var rolled_capped := 0
	for i in range(300):
		GameState.roll_rewards()
		if str(GameState.pending_rewards.get("item", {}).get("id", "")) == "rage_amulet":
			rolled_capped += 1
	check(rolled_capped == 0, "capped item is never rolled again")


func _test_resonance() -> void:
	print("-- element resonance")
	GameState.start_run("novice", "p01", 13579)
	# pick two species of the same element
	var by_element := {}
	for p in ContentDB.data["pets"]:
		var el := str(p["element"])
		if not by_element.has(el):
			by_element[el] = []
		(by_element[el] as Array).append(str(p["id"]))
	var picked: Array = []
	for el in by_element.keys():
		if (by_element[el] as Array).size() >= 2:
			picked = (by_element[el] as Array).slice(0, 2)
			break
	check(picked.size() == 2, "found two same-element species")
	var roster: Array = []
	var placements: Array = []
	for i in range(2):
		var e := GameState.create_pet(str(picked[i]), 20)
		roster.append(e)
		placements.append({"uid": int(e["uid"]), "row": i, "col": 0})
	GameState.roster = roster
	GameState.set_deployment(placements)
	var records: Array = GameState.resonance_records()
	check(records.size() == 1, "one element resonance active")
	if not records.is_empty():
		check(not (records[0]["tier"] as Dictionary).is_empty(), "resonance tier reached at 2 units")
	var mods: Dictionary = GameState.resonance_mods()
	var total := 0.0
	for key in mods.keys():
		total += float(mods[key])
	check(total > 0.0, "resonance mods are non-zero")
	var units: Array = GameState.build_player_units()
	check(units.size() == 2, "both resonance units built")


func _test_encounters() -> void:
	print("-- encounter generation")
	GameState.start_run("novice", "p01", 424242)
	for trial in range(6):
		for f in range(1, 21):
			GameState.current_floor = f
			var enc: Dictionary = GameState.generate_encounter(f)
			var enemies: Array = enc["enemies"]
			var floor_data: Dictionary = ContentDB.floor(f)
			var expected := int(floor_data.get("enemy_count", 1)) if str(floor_data["kind"]) != "boss" else int(floor_data.get("minion_count", 0)) + 1
			check(enemies.size() == expected, "floor %d enemy count %d" % [f, enemies.size()])
			var boss_seen := false
			var minions := 0
			var minion_affixes := 0
			var king_floor := bool(ContentDB.boss(str(floor_data.get("boss", ""))).get("demon_king", false))
			for e in enemies:
				if bool(e.get("is_boss", false)):
					boss_seen = true
					check((e.get("phases", []) as Array).size() >= 1, "floor %d boss has phases" % f)
					check(int(e.get("tier", 0)) >= 1, "floor %d boss tier" % f)
				else:
					minions += 1
					minion_affixes = maxi(minion_affixes, GameState.total_affixes(e))
					if king_floor:
						var rarity := str(e.get("rarity", ""))
						check(rarity in ["legend", "hero", "demon"], "floor %d escort is demon-tier" % f)
						check(bool(e.get("king_escort", false)), "floor %d escort flagged" % f)
						if rarity == "hero":
							check(str(e.get("name", "")).begins_with("堕落"), "floor %d hero fell" % f)
					else:
						check(str(e["species"]) in floor_data["pool"], "floor %d enemy from pool" % f)
			if str(floor_data["kind"]) == "boss":
				check(boss_seen, "floor %d has boss" % f)
				check(minions == int(floor_data["minion_count"]), "floor %d minion count" % f)
			else:
				check(not boss_seen, "floor %d no boss" % f)
			var expected_affixes := int(floor_data.get("minion_affix_count", 0))
			if expected_affixes > 0:
				check(minion_affixes >= mini(expected_affixes, 3), "floor %d minion affixes" % f)
			elif minions > 0:
				check(minion_affixes == 0, "floor %d early minions have no affixes" % f)


func _test_events() -> void:
	print("-- floor events")
	GameState.start_run("novice", "p01", 555)
	GameState.current_floor = 2
	check(not GameState.should_offer_event(), "floor 2 is not an event floor")
	GameState.current_floor = 4
	check(not GameState.should_offer_event(), "tower floor 4 is no longer a fixed event")
	check(not GameState.should_offer_route(), "tower floor 4 is not a route")
	GameState.current_floor = 3
	check(GameState.should_offer_route(), "tower floor 3 offers a route")
	GameState.current_floor = 10
	check(not GameState.should_offer_route(), "king floor 10 is not a route")
	var ev: Dictionary = GameState.roll_event()
	var options: Array = ev.get("options", [])
	check(options.size() == 3, "event offers three options")
	check(not GameState.pending_event.is_empty(), "event pending")
	if not options.is_empty():
		var text := GameState.apply_event(options[0])
		check(not text.is_empty(), "event resolves with text")
	check(not GameState.should_offer_event(), "event not offered twice on same floor")
	GameState.current_floor = 5
	check(not GameState.should_offer_event(), "floor 5 has no event")
	for n in [6, 9, 12, 15, 18, 21, 24, 27, 33, 36, 39]:
		GameState.current_floor = n
		GameState.route_done = []
		check(GameState.should_offer_route(), "tower floor %d offers a route" % n)
	GameState.run_mode = "conquest"
	for n in [4, 9, 14, 19, 24, 29, 34, 39]:
		GameState.current_floor = n
		GameState.event_done = []
		check(GameState.should_offer_event(), "conquest floor %d keeps the sword event" % n)
	GameState.run_mode = "tower"
	GameState.current_floor = 10
	check(not GameState.should_offer_event(), "floor 10 is a king floor, not an event")
	GameState.start_run("novice", "p01", 556)
	GameState.current_floor = 8
	check(not GameState.should_offer_event(), "floor 8 is not an event floor")
	GameState.current_floor = 9
	var pact_event: Dictionary = GameState.roll_event()
	var saw_blade := false
	var saw_demon_event := false
	for opt in pact_event.get("options", []):
		if str(opt.get("kind", "")) in ["pact", "abyss"]:
			saw_demon_event = true
		if str(opt.get("kind", "")) == "blade_trial":
			saw_blade = true
			var blade_text := GameState.apply_event(opt)
			check(blade_text.find("圣剑") >= 0, "blade trial resolves")
			break
	check(not saw_demon_event, "events no longer offer a demon pact")
	check(saw_blade, "floor 9 offers the sword trial before the first king")
	check(GameState.blade_trial_floor == 9, "sword trial stays on this floor")
	check(GameState.event_battle, "sword trial starts a fight on this floor")
	var trial_heroes := 0
	for enemy in GameState.encounter.get("enemies", []):
		if str(enemy.get("rarity", "")) == "hero":
			trial_heroes += 1
	check(trial_heroes == 1, "the first sword trial fields one hero")
	check(not GameState.owns_breaker(), "the sword is not granted before the trial is won")
	GameState.apply_victory()
	check("blade_shard_1" in GameState.items, "the first trial gives the first shard")
	check(not ("barrier_blade" in GameState.items), "one trial does not forge the sword")
	for _shard_step in range(3):
		GameState.blade_trial_floor = GameState.current_floor
		GameState.apply_victory()
	check("barrier_blade" in GameState.items, "four shards forge the sword")
	check(not ("blade_shard_1" in GameState.items), "forging consumes the shards")
	var given := GameState.carry_item(int(GameState.roster[0]["uid"]), "barrier_blade")
	check(given.find("破魔圣剑") >= 0 and GameState.owns_breaker(), "carried sword breaks the barrier")
	GameState.start_run("novice", "p01", 557)
	GameState.apply_victory()
	var affix_id := str(GameState.pending_rewards.get("affix", {}).get("candidates", [{}])[0].get("id", ""))
	check(affix_id != "", "chest offers an affix")
	check(GameState.stash_affix_reward(affix_id), "chosen affix can go into the bag")
	check(affix_id in GameState.affix_bag, "stashed affix sits in the bag")


func _test_curse() -> void:
	print("-- elite / curse floors")
	GameState.start_run("novice", "p01", 777)
	GameState.current_floor = 4
	GameState.curse_floors[4] = true
	var cursed: Dictionary = GameState.generate_encounter(4)
	check(bool(cursed.get("curse", false)), "cursed encounter flagged")
	var sample: Dictionary = cursed["enemies"][0]
	var st: Dictionary = ContentDB.pet_stats(str(sample["species"]), int(sample["level"]))
	var floor_data: Dictionary = ContentDB.floor(4)
	var expect := float(st["atk"]) * float(floor_data.get("enemy_stat_mult", 1.0)) * 1.25
	check(float(sample["atk"]) >= expect * 0.98, "curse raises enemy stats")
	GameState.apply_victory()
	check(GameState.pending_rewards.get("bonus_items", []).size() >= 1, "cursed floor grants bonus items")


func _test_kings() -> void:
	print("-- demon kings")
	check(str(ContentDB.floor(5).get("boss", "")) == "b1", "floor 5 keeps the first boss")
	check(str(ContentDB.floor(15).get("boss", "")) == "b2", "floor 15 keeps the second boss")
	check(str(ContentDB.floor(25).get("boss", "")) == "b4", "floor 25 keeps the third boss")
	check(str(ContentDB.floor(35).get("boss", "")) == "b3", "floor 35 keeps the old final boss")
	for pair in [[10, "k1"], [20, "k2"], [30, "k3"], [40, "k4"]]:
		var floor_n := int(pair[0])
		var boss_id := str(pair[1])
		var floor_row: Dictionary = ContentDB.floor(floor_n)
		var boss: Dictionary = ContentDB.boss(boss_id)
		check(str(floor_row.get("boss", "")) == boss_id, "king floor %d" % floor_n)
		check(bool(boss.get("demon_king", false)), boss_id + " is a demon king")
		check(not str(boss.get("reward_demon", "")).is_empty(), boss_id + " grants a demon")
	check(float(ContentDB.boss("k4")["stat_mult"]["hp"]) > float(ContentDB.boss("b3")["stat_mult"]["hp"]), "final king is sturdier than the old finale")
	var engine = BattleEngineScript.new()
	var king := {
		"uid": 1, "hp": 500, "max_hp": 500, "shield": 0, "rage": 0,
		"king_barrier": true, "side": "enemy", "statuses": {}, "hooks": {},
		"row": 1, "col": 2,
	}
	var common := {"uid": 2, "is_hero": false, "rarity": "common", "hooks": {}, "statuses": {}}
	var demon := {"uid": 3, "is_hero": true, "rarity": "demon", "hooks": {}, "statuses": {}}
	var held: Dictionary = engine._deal_damage(common, king, 80, false, 1.0, false)
	check(str(held.get("barrier", "")) == "hold", "ordinary hit is stopped")
	check(bool(king["king_barrier"]) and int(king["hp"]) == 500, "barrier stays up and absorbs the hit")
	var broke: Dictionary = engine._deal_damage(demon, king, 80, false, 1.0, false)
	check(str(broke.get("barrier", "")) == "break", "demon breaks the barrier")
	check(not bool(king["king_barrier"]) and int(king["hp"]) == 500, "the breaking hit deals no damage")
	var follow: Dictionary = engine._deal_damage(common, king, 40, false, 1.0, false)
	check(int(follow.get("damage", 0)) > 0 and int(king["hp"]) < 500, "after the break, anyone can hurt the king")
	var sealed := {
		"uid": 4, "hp": 500, "max_hp": 500, "shield": 0, "rage": 0,
		"king_barrier": true, "side": "enemy", "statuses": {}, "hooks": {},
		"row": 1, "col": 2,
	}
	var sword := common.duplicate(true)
	sword["affixes"] = {"normal": ["barrier_blade"], "ultimate": []}
	var sword_hit: Dictionary = engine._deal_damage(sword, sealed, 80, false, 1.0, false)
	check(str(sword_hit.get("barrier", "")) == "break", "barrier blade breaks the ward")
	check(not bool(sealed["king_barrier"]) and int(sealed["hp"]) == 500, "the sword's breaking hit deals no damage")
	GameState.start_run("novice", "p01", 880)
	GameState.current_floor = 10
	GameState.generate_encounter(10)
	var saw_barrier := false
	var escorts := 0
	for enemy in GameState.build_enemy_units():
		if bool(enemy.get("king_barrier", false)):
			saw_barrier = true
			check(bool(enemy.get("demon_king", false)), "barrier unit is a demon king")
		elif bool(enemy.get("king_escort", false)):
			escorts += 1
			check(str(enemy.get("rarity", "")) in ["legend", "hero", "demon"], "king escort is demon-tier")
	check(saw_barrier, "floor 10 encounter spawns the barrier")
	check(escorts >= 2, "king fight has at least two demon-tier escorts")
	var hero_id := ""
	for p in ContentDB.data.get("pets", []):
		if str(p.get("rarity", "")) == "hero":
			hero_id = str(p["id"])
			break
	var fallen := GameState.build_enemy_unit(hero_id, 40, 1.0, 0)
	var before_atk := int(fallen["atk"])
	GameState._empower_king_escort(fallen)
	check(bool(fallen.get("fallen", false)), "hero escort becomes fallen")
	check(str(fallen.get("name", "")).begins_with("堕落"), "fallen hero is renamed")
	check(int(fallen["atk"]) > before_atk, "fallen hero is stronger than the base hero")
	check(float(fallen.get("skill_power", 1.0)) > 1.0, "fallen hero skills hit harder")
	var hits := 0
	for _i in range(400):
		if str(GameState._king_reward().get("kind", "")) == "king":
			hits += 1
	check(hits > 30 and hits < 110, "king contract lands near 15 percent (%d/400)" % hits)
	GameState.pending_rewards = {
		"king": {"kind": "king", "species": "d5", "species_list": ["d5"]},
		"claimed": {"king": false},
	}
	var claimed: Dictionary = GameState.claim_king_reward()
	check(not claimed.is_empty(), "a successful contract adds the demon")


func _test_hero() -> void:
	print("-- hero spirits")
	GameState.start_run("novice", "p01", 31415)
	var normal_entry := GameState.create_pet("p01", 30)
	var hero_entry := GameState.add_hero_pet("p01", "frenzy")
	hero_entry["level"] = 30
	check(bool(hero_entry.get("hero", false)), "hero entry flagged")
	check(GameState.pet_name(hero_entry).begins_with("英雄·"), "hero name prefixed")
	var normal_stats: Dictionary = GameState.effective_stats(normal_entry)
	var hero_stats: Dictionary = GameState.effective_stats(hero_entry)
	check(int(hero_stats["hp"]) > int(normal_stats["hp"]), "hero has more hp than a normal pet")
	check(int(hero_stats["atk"]) > int(normal_stats["atk"]), "hero has more atk than a normal pet")
	var check1: Dictionary = GameState.can_upgrade_hero(int(hero_entry["uid"]))
	GameState.items.clear()
	check1 = GameState.can_upgrade_hero(int(hero_entry["uid"]))
	check(not bool(check1["ok"]), "hero upgrade needs an item")
	var item_id := str(ContentDB.data["items"][0]["id"])
	GameState.add_item(item_id)
	var res: Dictionary = GameState.upgrade_hero(int(hero_entry["uid"]))
	check(bool(res.get("ok", false)), "hero upgrade succeeds with an item")
	check(int(hero_entry["hero_star"]) == 1, "hero star increased")
	check(GameState.items.is_empty(), "item consumed by hero upgrade")
	var deployed: Array = [{"uid": int(hero_entry["uid"]), "row": 1, "col": 0}]
	GameState.set_deployment(deployed)
	var units: Array = GameState.build_player_units()
	check(units.size() == 1 and bool(units[0].get("is_hero", false)), "hero unit built")
	if units.size() == 1:
		check((units[0].get("phases", []) as Array).size() == 1, "hero has a phase")


func _test_save_slots() -> void:
	print("-- manual save slots")
	var path := GameState.slot_path(2)
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_bytes(path) if had else PackedByteArray()
	GameState.start_run("novice", "p01", 5150)
	GameState.current_floor = 12
	var snap := GameState.capture_run("map")
	snap["saved_at"] = 1_700_000_000
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_var(snap)
	out.close()
	var summary: Dictionary = GameState.slot_summary(2)
	check(int(summary.get("floor", 0)) == 12, "slot summary keeps the floor")
	check(str(summary.get("trainer", "")) != "", "slot summary names the trainer")
	GameState.current_floor = 1
	var where := GameState.load_slot(2)
	check(where == "map" and GameState.current_floor == 12, "manual slot restores the run")
	GameState.delete_slot(2)
	check(GameState.slot_summary(2).is_empty(), "deleted slot is empty")
	if had:
		var restore := FileAccess.open(path, FileAccess.WRITE)
		restore.store_buffer(backup)
	check(GameState.screen_label("reward") == "宝箱", "reward screen has a save label")


func _test_roster_view() -> void:
	print("-- roster display order")
	GameState.start_run("novice", "p01", 271828)
	var seen := {}
	for pid in ContentDB.all_pet_ids():
		var rarity := str(ContentDB.pet(str(pid)).get("rarity", "common"))
		if seen.has(rarity) or GameState.owned_species.has(pid):
			continue
		GameState.add_owned_species(str(pid))
		seen[rarity] = true
	var raw: Array = []
	for entry in GameState.roster:
		raw.append(int(entry["uid"]))
	var view: Array = GameState.roster_view()
	var view_ids: Array = []
	var prev_rank := 99
	var prev_index := -1
	for entry in view:
		var uid := int(entry["uid"])
		view_ids.append(uid)
		var rank := ContentDB.rarity_rank(str(ContentDB.pet(str(entry["species"])).get("rarity", "common")))
		var index := raw.find(uid)
		if rank == prev_rank:
			check(index > prev_index, "same rarity keeps acquisition order")
		else:
			check(rank < prev_rank, "roster view sorts rarer pets first")
		prev_rank = rank
		prev_index = index
	var raw_after: Array = []
	for entry in GameState.roster:
		raw_after.append(int(entry["uid"]))
	check(raw == raw_after, "roster view does not rewrite roster")
	for entry in GameState.roster:
		if bool(entry.get("hero", false)):
			entry["hero_star"] = int(entry.get("hero_star", 0)) + 1
	GameState.set_deployment([{"uid": int(GameState.roster[0]["uid"]), "row": 1, "col": 0}])
	var after: Array = []
	for entry in GameState.roster_view():
		after.append(int(entry["uid"]))
	check(view_ids == after, "deploy and star-up do not change roster view")


func _test_conquest() -> void:
	print("-- star tower conquest")
	GameState.pending_mode = "conquest"
	GameState.start_run("novice", "p01", 42)
	check(not ("barrier_blade" in GameState.affix_bag), "conquest does not start with the sword")
	var plan := GameState.conquest_plan()
	check(plan.size() == 16, "conquest has sixteen king floors")
	check((plan[0]["kings"] as Array).size() == 1, "the first king floor is one king")
	check((plan[4]["kings"] as Array).size() == 2, "after four solos the kings pair up")
	check((plan.back()["kings"] as Array).size() == 5, "the last king floor fields five kings")
	check(not GameState.is_conquest_king_floor(), "floor 1 is a normal climb")
	check(GameState.encounter.get("king_ids", []).is_empty(), "the opening fight is not a king")
	check(not GameState.run_won, "the first battle is not the conquest itself")
	GameState.current_floor = 10
	GameState.generate_conquest_encounter()
	check((GameState.encounter.get("king_ids", []) as Array).size() == 1, "floor 10 is the first king")
	check(GameState.encounter.get("enemies", []).size() == 2, "a solo king brings one escort")
	var party_lv := GameState.party_level()
	var level_ok := true
	var infinite := 0
	for enemy in GameState.encounter.get("enemies", []):
		if int(enemy.get("level", -1)) != party_lv:
			level_ok = false
		if str(enemy.get("name", "")).begins_with("无限·"):
			infinite += 1
	check(level_ok, "conquest enemies use the player's level")
	check(infinite == 0, "a king floor does not field an uncapped unit")
	var filler_ok := true
	for enemy in GameState.encounter.get("enemies", []):
		if bool(enemy.get("demon_king", false)):
			continue
		if str(enemy.get("rarity", "")) not in ["legend", "demon"]:
			filler_ok = false
	check(filler_ok, "king floor fillers are legends or demons")
	var before_lv := int(GameState.roster[0]["level"])
	GameState.apply_victory()
	check(int(GameState.roster[0]["level"]) == before_lv + GameState._growth_step(), "conquest victory uses the same level step as a normal floor")
	GameState.pending_rewards = {}
	GameState.current_floor = 6
	GameState.generate_conquest_encounter()
	check(GameState.encounter.get("enemies", []).size() == 5, "after floor 5 the enemy side is five")
	GameState.current_floor = 50
	GameState.generate_conquest_encounter()
	check((GameState.encounter.get("king_ids", []) as Array).size() == 2, "floor 50 is the first pair")
	GameState.current_floor = 160
	GameState.generate_conquest_encounter()
	var kings := 0
	var escorts := 0
	for enemy in GameState.encounter.get("enemies", []):
		if bool(enemy.get("demon_king", false)):
			kings += 1
		if bool(enemy.get("king_escort", false)):
			escorts += 1
	check(kings == 5 and GameState.encounter.get("enemies", []).size() == 5, "the finale is five demon kings and nothing else")
	check(escorts == 0, "the five-king fight has no escorts")
	check(GameState.is_conquest_finale(), "floor 160 is the finale")
	GameState.apply_victory()
	check(GameState.conquest_clear and GameState.run_won, "beating five kings conquers the tower")


func _arm_simulated_run() -> void:
	var common_id := ""
	for p in ContentDB.data.get("pets", []):
		if str(p.get("rarity", "")) == "common":
			common_id = str(p["id"])
			break
	if common_id != "" and not GameState.owned_species.has(common_id):
		var added: Dictionary = GameState.add_owned_species(common_id)
		GameState.attach_from_bag(int(added["entry"]["uid"]), "normal", "unbound")


func _simulate_run(trainer_id: String, starter_id: String, seed_value: int) -> Dictionary:
	GameState.start_run(trainer_id, starter_id, seed_value)
	_arm_simulated_run()
	var total := ContentDB.total_floors()
	for f in range(1, total + 1):
		if GameState.is_event_floor(f):
			if GameState.should_offer_event():
				GameState.roll_event()
				var opt := _pick_sim_event(GameState.pending_event.get("options", []))
				if opt.is_empty():
					GameState.skip_event()
				else:
					GameState.apply_event(opt)
				if GameState.event_battle:
					GameState.event_battle = false
				else:
					GameState.advance_floor()
					continue
			else:
				GameState.advance_floor()
				continue
		var boss_id := str(ContentDB.floor(f).get("boss", ""))
		if bool(ContentDB.boss(boss_id).get("demon_king", false)) and not GameState.owns_breaker():
			var uid := int(GameState.roster[0]["uid"])
			if not GameState.holds_sword():
				GameState.add_item("barrier_blade")
			if "barrier_blade" not in (GameState.get_roster_entry(uid).get("carried", []) as Array):
				GameState.carry_item(uid, "barrier_blade")
		_place_test_formation()
		var engine = BattleEngineScript.new()
		var result: Dictionary = engine.simulate(
			GameState.build_player_units(), GameState.build_enemy_units(),
			GameState.next_battle_seed())
		battles += 1
		total_rounds += int(result.get("rounds", 0))
		floor_attempts[f] = int(floor_attempts.get(f, 0)) + 1
		if _validated_runs < 8:
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
		GameState.claim_hero_reward()
		GameState.claim_king_reward()
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
		if f >= total:
			return {"won": true, "floor": total, "rounds": int(result.get("rounds", 0))}
		GameState.advance_floor()
	return {"won": false, "floor": total, "rounds": 0}


func _pick_sim_event(opts: Array) -> Dictionary:
	var blade := {}
	var best := {}
	var best_score := -1
	var rank := {
		"contract": 6, "relic": 5, "items": 4, "resonance": 3,
		"hero_forge": 3, "bless": 2, "trial": 1,
	}
	for opt in opts:
		var kind := str(opt.get("kind", ""))
		if kind == "blade_trial":
			blade = opt
			continue
		var score := int(rank.get(kind, 0))
		if score > best_score:
			best_score = score
			best = opt
	if not GameState.owns_breaker() and not GameState.holds_sword() and not blade.is_empty():
		return blade
	if best_score > 0:
		return best
	if not blade.is_empty():
		return blade
	return opts[0] if not opts.is_empty() else {}


func _place_test_formation() -> void:
	var ordered: Array = []
	var rest: Array = []
	for entry in GameState.roster:
		if GameState._entry_breaks_barrier(entry):
			ordered.append(entry)
		else:
			rest.append(entry)
	ordered.append_array(rest)
	var count := mini(ordered.size(), 5)
	var templates: Dictionary = ContentDB.data["formation"].get("player_templates", {})
	var positions: Array = templates.get(str(count), [])
	var placements: Array = []
	for i in range(mini(count, positions.size())):
		placements.append({
			"uid": int(ordered[i]["uid"]),
			"row": int(positions[i][0]),
			"col": int(positions[i][1]),
		})
	GameState.set_deployment(placements)


func _test_full_runs(count: int) -> void:
	print("-- full run simulations (%d runs x 40 floors)" % count)
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
		if (i + 1) % 8 == 0:
			print("   ... %d / %d runs" % [i + 1, count])
	check(battles >= count, "battles executed")
	check(run_wins > 0, "at least one full forty-floor clear in simulation")


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
	var starter_btn = _find_button(starter, "下一步")
	check(starter_btn != null, "starter confirm button wired")
	if starter_btn == null:
		return
	starter_btn.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	var picker = main.current_screen
	check(picker != null and picker.has_method("_add"), "item pick screen loaded")
	if picker == null or not picker.has_method("_add"):
		return
	picker.call("_add", "hp_charm")
	picker.call("_add", "atk_charm")
	picker.call("_add", "def_charm")
	var pick_btn = _find_button(picker, "带着这 3 件出发")
	check(pick_btn != null, "item pick confirm button wired")
	if pick_btn == null:
		return
	pick_btn.pressed.emit()
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
	check(int(GameState.roster[0]["level"]) == int(ContentDB.combat().get("base_level", 10)) + 5,
		"victory grants +5 levels")
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
	for f in range(1, ContentDB.total_floors() + 1):
		var attempts := int(floor_attempts.get(f, 0))
		var wins := int(floor_wins.get(f, 0))
		var rate := 0.0 if attempts == 0 else float(wins) * 100.0 / float(attempts)
		var tag := "BOSS" if str(ContentDB.floor(f).get("kind", "")) == "boss" else "    "
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
