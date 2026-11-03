extends RefCounted
## Reads the real device window and the logical game view, then sizes option cards
## so a row stays inside the screen. Extra text scrolls inside the card.

const DESIGN := Vector2(1280, 720)


static func window_size() -> Vector2:
	var window := Vector2(DisplayServer.window_get_size())
	if window.x >= 2.0 and window.y >= 2.0:
		return window
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x >= 2.0 and screen.y >= 2.0:
		return screen
	return DESIGN


static func screen_size() -> Vector2:
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x >= 2.0 and screen.y >= 2.0:
		return screen
	return window_size()


static func usable(node: Node) -> Vector2:
	if node != null and node.is_inside_tree():
		var view := node.get_viewport().get_visible_rect().size
		if view.x >= 2.0 and view.y >= 2.0:
			return view
	return DESIGN


static func card_box(node: Node, count: int, gap: float, margin_x: float, reserved_y: float) -> Vector2:
	var view := usable(node)
	var n := maxi(count, 1)
	var width := (view.x - margin_x * 2.0 - gap * float(n - 1)) / float(n)
	width = clampf(width, 180.0, 460.0)
	var height := view.y - reserved_y
	height = clampf(height, 180.0, view.y - 96.0)
	return Vector2(width, height)


static func scroll_slot(horizontal: bool = false) -> Array:
	var host := Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.custom_minimum_size = Vector2(0, 140)
	host.clip_contents = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	host.add_child(scroll)
	return [host, scroll]


static func scrolling_body() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return scroll
