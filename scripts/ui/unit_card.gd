extends PanelContainer
## Compact battlefield card used by the battle screen.

const BattleEngineScript = preload("res://scripts/core/battle_engine.gd")

var unit_data: Dictionary = {}
var is_enemy: bool = false
var title_label: Label
var sub_label: Label
var hp_bar: ProgressBar
var shield_label: Label
var status_label: Label
var pips: Array = []
var dead_label: Label
var _hp_fill_styles: Dictionary = {}


func setup(unit: Dictionary, enemy: bool) -> void:
	unit_data = unit
	is_enemy = enemy
	custom_minimum_size = Vector2(172, 128)
	size = Vector2(172, 128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	refresh_all()


func _build() -> void:
	var v := UI.vbox(3)
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	var head := UI.hbox(6)
	v.add_child(head)
	var avatar_holder := CenterContainer.new()
	avatar_holder.custom_minimum_size = Vector2(48, 48)
	head.add_child(avatar_holder)
	var av: Control = UI.avatar(str(unit_data.get("species", "p01")), 46, int(unit_data.get("level", 1)),
		bool(unit_data.get("is_boss", false)), is_enemy)
	if bool(unit_data.get("is_boss", false)):
		var a_script = preload("res://scripts/ui/pet_avatar.gd")
		av = a_script.new()
		var boss_data: Dictionary = ContentDB.boss(str(unit_data.get("species", "")))
		if boss_data.is_empty():
			boss_data = {"id": "boss", "element": unit_data.get("element", "dark"), "class": unit_data.get("class", "warrior")}
		av.setup_boss(boss_data, 48)
	avatar_holder.add_child(av)

	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var name_color := UI.GOLD if bool(unit_data.get("is_boss", false)) else UI.TEXT
	if is_enemy and not bool(unit_data.get("is_boss", false)):
		name_color = UI.TEXT.lerp(UI.DANGER, 0.22)
	title_label = UI.label(str(unit_data.get("name", "?")), 13, name_color)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size = Vector2(96, 0)
	info.add_child(title_label)
	sub_label = UI.label("Lv.%d" % int(unit_data.get("level", 1)), 9, UI.MUTED)
	info.add_child(sub_label)
	var rages := UI.hbox(3)
	info.add_child(rages)
	for i in range(int(ContentDB.combat().get("rage_max", 2))):
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(15, 5)
		pip.add_theme_stylebox_override("panel", UI.soft_style(Color("#243044"), Color.TRANSPARENT, 0, 3, 0))
		rages.add_child(pip)
		pips.append(pip)

	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, 11)
	v.add_child(hp_wrap)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(hp_bar)

	var foot := UI.hbox(4)
	v.add_child(foot)
	shield_label = UI.label("", 9, UI.BLUE)
	foot.add_child(shield_label)
	var grow := UI.grow()
	foot.add_child(grow)
	status_label = UI.label("", 9, UI.MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(status_label)

	dead_label = UI.label("倒下", 15, UI.DANGER)
	dead_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dead_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dead_label.visible = false
	add_child(dead_label)

	var element := str(unit_data.get("element", "fire"))
	var border := ContentDB.element_color(element).darkened(0.45)
	if bool(unit_data.get("is_boss", false)):
		border = UI.GOLD
	add_theme_stylebox_override("panel", UI.soft_style(Color(0.045, 0.06, 0.10, 0.94), border, 1, 10, 8))


func refresh_all() -> void:
	refresh_hp(int(unit_data.get("hp", 1)), int(unit_data.get("max_hp", 1)))
	set_rage(int(unit_data.get("rage", 0)))
	set_shield(int(unit_data.get("shield", 0)))
	set_statuses(unit_data.get("statuses", {}))
	var cls := ContentDB.class_name_for(str(unit_data.get("class", "")))
	sub_label.text = "Lv.%d · %s" % [int(unit_data.get("level", 1)), cls]
	if int(unit_data.get("hp", 0)) <= 0:
		die()


func refresh_hp(hp: int, max_hp: int) -> void:
	hp_bar.max_value = maxi(1, max_hp)
	hp_bar.value = maxi(0, hp)
	var ratio := float(hp) / float(maxi(1, max_hp))
	var color := UI.hp_color(ratio)
	var key := color.to_html(false)
	if not _hp_fill_styles.has(key):
		_hp_fill_styles[key] = UI.soft_style(color, Color.TRANSPARENT, 0, 3, 0)
	hp_bar.add_theme_stylebox_override("fill", _hp_fill_styles[key])
	hp_bar.add_theme_stylebox_override("background", UI.soft_style(Color(0.03, 0.05, 0.08, 0.95), Color(0.2, 0.26, 0.36, 0.6), 0, 3, 0))
	sub_label.text = "Lv.%d · %s · %s/%s" % [
		int(unit_data.get("level", 1)),
		ContentDB.class_name_for(str(unit_data.get("class", ""))),
		ContentDB.fmt(hp), ContentDB.fmt(max_hp)]
	if hp <= 0:
		die()


func set_rage(value: int) -> void:
	for i in range(pips.size()):
		var on := i < value
		var color := UI.GOLD if on else Color("#243044")
		pips[i].add_theme_stylebox_override("panel", UI.soft_style(color, Color.TRANSPARENT, 0, 3, 0))


func set_shield(value: int) -> void:
	if value > 0:
		shield_label.text = "盾 %s" % ContentDB.fmt(value)
		shield_label.visible = true
	else:
		shield_label.text = ""
		shield_label.visible = false


func set_statuses(statuses: Dictionary) -> void:
	var parts: Array = []
	for key in statuses.keys():
		var st: Dictionary = statuses[key]
		var nm := BattleEngineScript.status_name(str(key))
		parts.append(nm + ("%d" % int(st.get("dur", 0)) if int(st.get("dur", 0)) < 90 else ""))
	if parts.is_empty():
		status_label.text = ""
	else:
		status_label.text = " ".join(parts)
		status_label.add_theme_color_override("font_color", UI.PURPLE)


func die() -> void:
	dead_label.visible = true
	modulate = Color(0.45, 0.45, 0.5, 0.8)


func set_active(active: bool) -> void:
	var element := str(unit_data.get("element", "fire"))
	var border := ContentDB.element_color(element).darkened(0.45)
	if bool(unit_data.get("is_boss", false)):
		border = UI.GOLD
	if active:
		border = Color.WHITE
	add_theme_stylebox_override("panel", UI.soft_style(
		Color(0.06, 0.08, 0.13, 0.98) if active else Color(0.045, 0.06, 0.10, 0.94),
		border, 2 if active else 1, 10, 8))
