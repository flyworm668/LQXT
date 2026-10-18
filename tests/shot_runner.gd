extends Node
## Visual smoke test: walks every screen and saves PNGs to res://shots/.
## Run with:  Godot --path . -- --shots

const DIR := "res://shots"

var main: Node


func _ready() -> void:
	main = get_tree().current_scene
	var abs_dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	await get_tree().create_timer(0.8).timeout
	await _shot("01_title")
	var title_screen = main.current_screen
	if title_screen != null and title_screen.has_method("_show_help"):
		title_screen.call("_show_help")
		await get_tree().create_timer(0.3).timeout
		await _shot("16_help")
		title_screen.queue_free()
		main.current_screen = null
		await get_tree().process_frame

	await main.goto("res://scripts/ui/trainer_screen.gd")
	await _shot("02_trainer")

	await main.goto("res://scripts/ui/starter_screen.gd", {"trainer": "veteran"})
	await _shot("03_starter")

	GameState.persist_enabled = false
	GameState.start_run("veteran", "p01", 20261018)
	_place_roster()
	await main.goto("res://scripts/ui/map_screen.gd")
	await _shot("04_map")
	var map_screen = main.current_screen
	if map_screen != null and map_screen.has_method("_show_team_details"):
		map_screen.call("_show_team_details")
		await get_tree().create_timer(0.3).timeout
		await _shot("17_team_modal")
		map_screen.queue_free()
		main.current_screen = null
		await get_tree().process_frame

	await main.goto("res://scripts/ui/formation_screen.gd")
	await _shot("05_formation")

	await main.goto("res://scripts/ui/battle_screen.gd")
	await get_tree().create_timer(1.6).timeout
	await _shot("06_battle")
	var battle_screen = main.current_screen
	if battle_screen != null and battle_screen.has_method("_skip"):
		battle_screen.call("_skip")
	await get_tree().create_timer(3.2).timeout
	await _shot("07_battle_result")

	if GameState.pending_rewards.is_empty():
		GameState.apply_victory()
	var pr: Dictionary = GameState.pending_rewards
	if str(pr.get("affix", {}).get("kind", "none")) != "affix":
		pr["affix"] = {"kind": "affix", "candidates": ContentDB.affix_candidates(GameState.rng, 3)}
		pr["claimed"]["affix"] = false
	await main.goto("res://scripts/ui/reward_screen.gd", {"evolutions": []})
	await _shot("08_reward")

	await main.goto("res://scripts/ui/affix_screen.gd")
	await _shot("09_affix")
	var affix_screen = main.current_screen
	if affix_screen != null:
		var candidates: Array = GameState.pending_rewards.get("affix", {}).get("candidates", [])
		if not candidates.is_empty():
			affix_screen.selected_affix_id = str(candidates[0]["id"])
			affix_screen.call("_go_step_two")
			await get_tree().create_timer(0.4).timeout
			await _shot("10_affix_skill")

	await main.goto("res://scripts/ui/result_screen.gd", {"win": true})
	await _shot("11_result")

	# --- 5v5 mid-game visual ---
	GameState.start_run("veteran", "p01", 555777)
	var extra := 0
	for pid in ContentDB.all_pet_ids():
		if extra >= 4:
			break
		if not GameState.owned_species.has(pid):
			GameState.add_owned_species(str(pid))
			extra += 1
	for entry in GameState.roster:
		entry["level"] = 50
	GameState.current_floor = 5
	GameState.generate_encounter(5)
	_place_roster()
	await main.goto("res://scripts/ui/map_screen.gd")
	await _shot("12_map_5v5")
	await main.goto("res://scripts/ui/battle_screen.gd")
	await get_tree().create_timer(2.0).timeout
	await _shot("13_battle_5v5")

	# --- boss floor visual ---
	for entry in GameState.roster:
		entry["level"] = 40
	GameState.current_floor = 4
	GameState.generate_encounter(4)
	_place_roster()
	await main.goto("res://scripts/ui/map_screen.gd")
	await _shot("14_map_boss")
	await main.goto("res://scripts/ui/battle_screen.gd")
	await get_tree().create_timer(1.2).timeout
	await _shot("15_battle_boss")

	# --- floor 8 stress / FPS sample ---
	GameState.start_run("veteran", "p01", 888888)
	var added := 0
	for pid in ContentDB.all_pet_ids():
		if added >= 4:
			break
		if not GameState.owned_species.has(pid):
			GameState.add_owned_species(str(pid))
			added += 1
	for entry in GameState.roster:
		entry["level"] = 80
	for i in range(6):
		var it := ContentDB.random_item(GameState.rng)
		if not it.is_empty():
			GameState.items.append(str(it["id"]))
	GameState.current_floor = 8
	GameState.generate_encounter(8)
	_place_roster()
	await main.goto("res://scripts/ui/battle_screen.gd")
	await get_tree().create_timer(0.8).timeout
	await _shot("18_battle_floor8")
	var samples: Array = []
	for i in range(10):
		await get_tree().create_timer(0.35).timeout
		samples.append(Engine.get_frames_per_second())
	print("FLOOR8 FPS SAMPLES: ", samples)

	print("SHOTS SAVED: ", abs_dir)
	get_tree().quit()


func _place_roster() -> void:
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


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [DIR, shot_name]
	var err := img.save_png(path)
	print("shot ", path, " -> ", err)
	await get_tree().create_timer(0.12).timeout
