extends PanelContainer
signal inspect_requested(unit: Dictionary)
signal selected(uid: int)

var select_mode: bool = false
## Compact battlefield card used by the battle screen.
## Style boxes and text are cached: during a long 5v5 fight this card is updated
## hundreds of times, and rebuilding theme overrides each time caused the
## late-floor stutter.

const BattleEngineScript = preload("res://scripts/core/battle_engine.gd")

var unit_data: Dictionary = {}
var is_enemy: bool = false
var title_label: Label
var sub_label: Label
var hp_bar: ProgressBar
var hp_wrap: Control
var shield_fill: ColorRect
var hp_text: Label
var buff_label: Label
var debuff_label: Label
var mark_label: Label
var _marks: Dictionary = {}
var pips: Array = []
var dead_label: Label

var _class_name: String = ""
var _hp_fill_styles: Dictionary = {}
var _hp_color_key: String = ""
var _sub_text: String = ""
var _rage_value: int = -1
var _hp_now: int = 1
var _hp_max: int = 1
var _shield_value: int = 0
var _active_state: bool = false
var _dead_state: bool = false
var _style_normal: StyleBoxFlat
var _style_active: StyleBoxFlat
var _style_ready: StyleBoxFlat
var _ult_ready: bool = false
var _pip_on: StyleBoxFlat
var _pip_off: StyleBoxFlat
var _hp_bg: StyleBoxFlat
var phone_battle: bool = false
var portrait: Control
var _pose: Tween


var card_size := Vector2(172, 156)
const BUFF_KEYS := ["haste", "atk_up", "thorns", "vamp", "cc_immune", "immune", "mirror"]
var _locking_size: bool = false


func _get_minimum_size() -> Vector2:
	return card_size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _locking_size and size != card_size:
		_locking_size = true
		size = card_size
		custom_minimum_size = card_size
		_locking_size = false


func setup(unit: Dictionary, enemy: bool) -> void:
	unit_data = unit
	is_enemy = enemy
	card_size = Vector2(196, 210) if phone_battle else Vector2(172, 156)
	clip_contents = true
	custom_minimum_size = card_size
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_name = ContentDB.class_name_for(str(unit_data.get("class", "")))
	_build()
	refresh_all()


func _build() -> void:
	var px := 64 if phone_battle else 76
	var name_px := 15 if phone_battle else 11
	var sub_px := 12 if phone_battle else 8
	var bar_h := 32 if phone_battle else 14
	var v := UI.vbox(3)
	v.add_theme_constant_override("separation", 2 if phone_battle else 3)
	add_child(v)
	var head := UI.hbox(6)
	v.add_child(head)
	var avatar_holder := CenterContainer.new()
	avatar_holder.custom_minimum_size = Vector2(px + 4, px + 4)
	avatar_holder.clip_contents = false
	head.add_child(avatar_holder)
	var av: Control = UI.avatar(str(unit_data.get("species", "p01")), px, int(unit_data.get("level", 1)),
		bool(unit_data.get("is_boss", false)), is_enemy)
	if bool(unit_data.get("is_boss", false)):
		var a_script = preload("res://scripts/ui/pet_avatar.gd")
		av = a_script.new()
		var boss_data: Dictionary = ContentDB.boss(str(unit_data.get("species", "")))
		if boss_data.is_empty():
			boss_data = {"id": "boss", "element": unit_data.get("element", "dark"), "class": unit_data.get("class", "warrior")}
		av.setup_boss(boss_data, px)
	av.clip_contents = true
	av.pivot_offset = Vector2(px, px) * 0.5
	portrait = av
	avatar_holder.add_child(av)

	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var name_color := UI.GOLD if bool(unit_data.get("is_boss", false)) else UI.TEXT
	if bool(unit_data.get("is_hero", false)):
		name_color = Color(1.0, 0.86, 0.48)
	if is_enemy and not bool(unit_data.get("is_boss", false)) and not bool(unit_data.get("is_hero", false)):
		name_color = UI.TEXT.lerp(UI.DANGER, 0.22)
	title_label = UI.label(str(unit_data.get("name", "?")), name_px, name_color)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	title_label.custom_minimum_size = Vector2(0, 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(title_label)
	sub_label = UI.label("Lv.%d" % int(unit_data.get("level", 1)), sub_px, UI.MUTED)
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_label.clip_text = true
	sub_label.custom_minimum_size = Vector2(0, 14)
	sub_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(sub_label)
	var rages := UI.hbox(3)
	info.add_child(rages)
	_pip_on = UI.soft_style(UI.GOLD, Color.TRANSPARENT, 0, 3, 0)
	_pip_off = UI.soft_style(Color("#243044"), Color.TRANSPARENT, 0, 3, 0)
	var pip_count := 0 if bool(unit_data.get("uses_spirit", false)) else int(ContentDB.combat().get("rage_max", 4))
	for i in range(pip_count):
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(11 if pip_count > 3 else 15, 5)
		pip.add_theme_stylebox_override("panel", _pip_off)
		rages.add_child(pip)
		pips.append(pip)

	hp_wrap = Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, bar_h)
	v.add_child(hp_wrap)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bg = UI.soft_style(Color(0.03, 0.05, 0.08, 0.95), Color(0.2, 0.26, 0.36, 0.6), 0, 3, 0)
	hp_bar.add_theme_stylebox_override("background", _hp_bg)
	hp_wrap.add_child(hp_bar)
	shield_fill = ColorRect.new()
	shield_fill.color = Color(0.28, 0.62, 1.0, 0.92)
	shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(shield_fill)
	hp_text = UI.label("", 14 if phone_battle else 8, Color(1, 1, 1, 0.95))
	hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(hp_text)
	hp_wrap.resized.connect(_layout_bars)

	buff_label = _tag_label(Color(0.45, 0.9, 0.62))
	debuff_label = _tag_label(Color(1.0, 0.55, 0.48))
	mark_label = _tag_label(Color(1.0, 0.82, 0.42))
	v.add_child(buff_label)
	v.add_child(debuff_label)
	v.add_child(mark_label)

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
	if bool(unit_data.get("is_hero", false)):
		border = Color(1.0, 0.82, 0.4)
	var edge := 0
	var edge_on := 0
	_style_normal = UI.soft_style(Color(0.045, 0.06, 0.10, 0.55 if phone_battle else 0.94), border, edge, 10, 6 if phone_battle else 8)
	_style_active = UI.soft_style(Color(0.10, 0.13, 0.20, 0.72 if phone_battle else 0.98), Color.WHITE, edge_on, 10, 6 if phone_battle else 8)
	_style_ready = UI.soft_style(Color(0.12, 0.10, 0.05, 0.72 if phone_battle else 0.98), Color(1.0, 0.8, 0.35), edge_on, 10, 6 if phone_battle else 8)
	add_theme_stylebox_override("panel", _style_normal)
	var hit := Button.new()
	hit.flat = true
	hit.text = ""
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.pressed.connect(func():
		if select_mode:
			selected.emit(int(unit_data.get("uid", -1)))
		else:
			inspect_requested.emit(unit_data))
	add_child(hit)


func refresh_all() -> void:
	refresh_hp(int(unit_data.get("hp", 1)), int(unit_data.get("max_hp", 1)))
	set_rage(int(unit_data.get("rage", 0)))
	set_shield(int(unit_data.get("shield", 0)))
	set_statuses(unit_data.get("statuses", {}))
	_show_marks()
	if int(unit_data.get("hp", 0)) <= 0:
		die()


func refresh_hp(hp: int, max_hp: int) -> void:
	_hp_now = maxi(0, hp)
	_hp_max = maxi(1, max_hp)
	hp_bar.max_value = _hp_max
	hp_bar.value = _hp_now
	hp_text.text = _hp_caption()
	var ratio := float(_hp_now) / float(_hp_max)
	var color := UI.hp_color(ratio)
	var key := color.to_html(false)
	if key != _hp_color_key:
		_hp_color_key = key
		if not _hp_fill_styles.has(key):
			_hp_fill_styles[key] = UI.soft_style(color, Color.TRANSPARENT, 0, 3, 0)
		hp_bar.add_theme_stylebox_override("fill", _hp_fill_styles[key])
	_layout_bars()
	var text := "Lv.%d · %s" % [int(unit_data.get("level", 1)), _class_name]
	var star := int(unit_data.get("hero_star", 0))
	if bool(unit_data.get("is_hero", false)) and star > 0:
		text += " · %d★" % star
	if bool(unit_data.get("king_barrier", false)):
		text += " · 屏障"
	if text != _sub_text:
		_sub_text = text
		sub_label.text = text
	if hp <= 0:
		die()


func set_rage(value: int) -> void:
	if value == _rage_value:
		return
	_rage_value = value
	for i in range(pips.size()):
		pips[i].add_theme_stylebox_override("panel", _pip_on if i < value else _pip_off)
	var now_ready := value >= int(ContentDB.combat().get("rage_max", 4))
	if now_ready != _ult_ready:
		_ult_ready = now_ready
		if not _dead_state:
			add_theme_stylebox_override("panel", _style_ready if now_ready and not _active_state else (_style_active if _active_state else _style_normal))
		if now_ready and not _dead_state:
			var tw := create_tween()
			tw.tween_property(self, "modulate", Color(1.18, 1.1, 0.82), 0.1)
			tw.tween_property(self, "modulate", Color(1, 1, 1), 0.2)


func set_shield(value: int) -> void:
	_shield_value = maxi(0, value)
	if hp_text != null:
		hp_text.text = _hp_caption()
	_layout_bars()


func _hp_caption() -> String:
	if not phone_battle:
		return ContentDB.fmt(_hp_now)
	return "生命 %s\n护盾 %s" % [ContentDB.fmt(_hp_now), ContentDB.fmt(_shield_value)]


func set_statuses(statuses: Dictionary) -> void:
	var buffs: Array = []
	var debuffs: Array = []
	for key in statuses.keys():
		var st: Dictionary = statuses[key]
		var nm := BattleEngineScript.status_name(str(key))
		var dur := int(st.get("dur", 0))
		var shown := nm + ("%d" % dur if dur < 90 else "")
		if BUFF_KEYS.has(str(key)):
			buffs.append(shown)
		else:
			debuffs.append(shown)
	_set_tag(buff_label, "增益", buffs)
	_set_tag(debuff_label, "减益", debuffs)


func set_marks(marks: Array) -> void:
	_marks.clear()
	for row in marks:
		var name := str(row.get("name", ""))
		if name == "":
			continue
		_marks[name] = int(row.get("n", 0))
	_show_marks()


func set_mark(mark_name: String, stacks: int) -> void:
	if mark_name == "":
		return
	if stacks <= 0:
		_marks.erase(mark_name)
	else:
		_marks[mark_name] = stacks
	_show_marks()


func _show_marks() -> void:
	var parts: Array = []
	for name in _marks.keys():
		parts.append("%s%d" % [name, int(_marks[name])])
	_set_tag(mark_label, "印记", parts)


func _set_tag(label: Label, title: String, parts: Array) -> void:
	label.text = title + " " + (" ".join(parts) if not parts.is_empty() else "—")


func _tag_label(color: Color) -> Label:
	var label := UI.label("—", 12 if phone_battle else 8, color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(0, 14 if phone_battle else 11)
	return label


func _layout_bars() -> void:
	if hp_wrap == null or shield_fill == null:
		return
	var width := hp_wrap.size.x
	if width <= 1.0:
		return
	var hp_ratio := clampf(float(_hp_now) / float(maxi(1, _hp_max)), 0.0, 1.0)
	var cover := 0.0
	if _hp_now > 0 and _shield_value > 0:
		cover = minf(1.0, float(_shield_value) / float(_hp_now))
	shield_fill.position = Vector2.ZERO
	shield_fill.size = Vector2(width * hp_ratio * cover, hp_wrap.size.y)


func die() -> void:
	if _dead_state:
		return
	_dead_state = true
	dead_label.visible = true
	modulate = Color(0.45, 0.45, 0.5, 0.8)


func revive() -> void:
	_dead_state = false
	dead_label.visible = false
	modulate = Color(1, 1, 1, 1)


func set_active(active: bool) -> void:
	if active == _active_state:
		return
	_active_state = active
	if active:
		add_theme_stylebox_override("panel", _style_active)
	elif _ult_ready:
		add_theme_stylebox_override("panel", _style_ready)
	else:
		add_theme_stylebox_override("panel", _style_normal)


func play_strike(toward_right: bool) -> void:
	_pose_portrait(0.28 if toward_right else -0.28, Vector2(1.12, 0.9))


func play_flinch(from_right: bool) -> void:
	_pose_portrait(-0.22 if from_right else 0.22, Vector2(0.86, 1.08))


func _pose_portrait(angle: float, squash: Vector2) -> void:
	if portrait == null:
		return
	if _pose != null and _pose.is_valid():
		_pose.kill()
	portrait.rotation = 0.0
	portrait.scale = Vector2.ONE
	_pose = create_tween()
	_pose.set_parallel(true)
	_pose.tween_property(portrait, "rotation", angle, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.tween_property(portrait, "scale", squash, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.set_parallel(false)
	_pose.tween_interval(0.04)
	_pose.set_parallel(true)
	_pose.tween_property(portrait, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.tween_property(portrait, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
