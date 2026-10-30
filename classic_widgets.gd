extends RefCounted

# Code-drawn classic UI: no external image/font assets or import step required.
static func bevel(sunken: bool = false, padding: int = 6) -> StyleBoxTexture:
	var light = Color("#ffffff" if not sunken else "#808080")
	var dark = Color("#808080" if not sunken else "#ffffff")
	var bitmap = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color("#c0c0c0"))
	for y in range(12):
		for x in range(12):
			if x < 3 or y < 3 or x >= 9 or y >= 9:
				bitmap.set_pixel(x, y, light if x + y < 12 else dark)
	var style = StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(bitmap)
	style.set_texture_margin_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


class LedDisplay extends Control:
	const DIGITS = ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]
	var value: int = 0:
		set(next):
			value = maxi(0, next)
			custom_minimum_size = Vector2(maxi(3, str(value).length()) * 31 + 12, 61)
			queue_redraw()

	func _init():
		custom_minimum_size = Vector2(105, 61)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color("#191010"))
		var digits = str(value).pad_zeros(3)
		for i in range(digits.length()):
			var active: String = DIGITS[int(digits[i])]
			var origin = Vector2(6 + i * 31, 5)
			_segment(origin, [Vector2(4, 1), Vector2(23, 1), Vector2(19, 5), Vector2(8, 5)], active.contains("a"))
			_segment(origin, [Vector2(24, 2), Vector2(24, 24), Vector2(20, 20), Vector2(20, 6)], active.contains("b"))
			_segment(origin, [Vector2(24, 27), Vector2(24, 49), Vector2(20, 45), Vector2(20, 31)], active.contains("c"))
			_segment(origin, [Vector2(4, 50), Vector2(23, 50), Vector2(19, 46), Vector2(8, 46)], active.contains("d"))
			_segment(origin, [Vector2(3, 27), Vector2(7, 31), Vector2(7, 45), Vector2(3, 49)], active.contains("e"))
			_segment(origin, [Vector2(3, 2), Vector2(7, 6), Vector2(7, 20), Vector2(3, 24)], active.contains("f"))
			_segment(origin, [Vector2(4, 25), Vector2(8, 22), Vector2(19, 22), Vector2(23, 25), Vector2(19, 28), Vector2(8, 28)], active.contains("g"))

	func _segment(origin: Vector2, points: Array, on: bool):
		var polygon = PackedVector2Array()
		for point in points:
			polygon.append(origin + point)
		draw_colored_polygon(polygon, Color("#ff1616") if on else Color("#420b0b"))


class FaceButton extends Button:
	var mood = "playing":
		set(next):
			mood = next
			queue_redraw()

	func _init():
		custom_minimum_size = Vector2(66, 66)
		tooltip_text = "새 런 시작 (체력·골드·스테이지 초기화)"
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw():
		var center = size / 2 + (Vector2.ONE * 2 if is_pressed() else Vector2.ZERO)
		draw_circle(center, 23, Color.BLACK)
		draw_circle(center, 20, Color("#ffff00"))
		if mood == "gameover":
			for x in [-7, 7]:
				var eye = center + Vector2(x, -6)
				draw_line(eye - Vector2(3, 3), eye + Vector2(3, 3), Color.BLACK, 3)
				draw_line(eye - Vector2(3, -3), eye + Vector2(3, -3), Color.BLACK, 3)
			draw_arc(center + Vector2(0, 14), 9, PI + 0.2, TAU - 0.2, 16, Color.BLACK, 3, true)
		else:
			if mood == "reward":
				draw_rect(Rect2(center + Vector2(-15, -10), Vector2(30, 4)), Color.BLACK)
				for x in [-8, 8]:
					draw_rect(Rect2(center + Vector2(x - 6, -10), Vector2(12, 9)), Color.BLACK)
			else:
				draw_circle(center + Vector2(-7, -6), 3, Color.BLACK)
				draw_circle(center + Vector2(7, -6), 3, Color.BLACK)
			draw_arc(center, 12, 0.25, PI - 0.25, 20, Color.BLACK, 3, true)


class CoinIcon extends Control:
	func _init():
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var center = size / 2
		var radius = minf(size.x, size.y) * 0.45
		draw_circle(center + Vector2(1, 2), radius, Color("#8f5817"))
		draw_circle(center, radius, Color("#f0b732"))
		draw_arc(center, radius - 2, 0, TAU, 32, Color("#ffe78d"), 2, true)
		draw_line(center + Vector2(0, -radius * 0.5), center + Vector2(0, radius * 0.5), Color("#a36a17"), 3)
		draw_line(center + Vector2(-radius * 0.25, -radius * 0.35), center + Vector2(radius * 0.25, -radius * 0.35), Color("#a36a17"), 2)


class HealthGauge extends Control:
	var value: int = 10:
		set(next):
			value = maxi(0, next)
			queue_redraw()
	var maximum: int = 10:
		set(next):
			maximum = maxi(1, next)
			queue_redraw()

	func _init():
		custom_minimum_size = Vector2(126, 61)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color("#17241e"))
		var ratio = float(value) / maximum
		var ink = Color("#55d98a") if ratio > 0.5 else (Color("#f6c65b") if ratio > 0.25 else Color("#f27e7e"))
		var gap = 2.0
		var segment = (size.x - 12.0 - (maximum - 1) * gap) / maximum
		for i in range(maximum):
			draw_rect(Rect2(6 + i * (segment + gap), 7, segment, 23), ink if i < value else Color("#32453c"))
		var font = get_theme_default_font()
		var text = "%d / %d" % [value, maximum]
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, Vector2((size.x - width) / 2, 52), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#f0f6ef"))


class TileButton extends Button:
	# Draw numbers without Button text affecting the grid's minimum size.
	var number_text = "":
		set(value):
			number_text = value
			queue_redraw()
	var number_color = Color.BLACK

	func _draw():
		if number_text.is_empty():
			return
		var font = get_theme_font("font")
		var pixels = get_theme_font_size("font_size")
		var width = font.get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
		var baseline = (size.y - font.get_height(pixels)) / 2 + font.get_ascent(pixels)
		draw_string(font, Vector2((size.x - width) / 2, baseline), number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, number_color)


class TileMark extends Control:
	var mark = "":
		set(next):
			mark = next
			queue_redraw()

	func _init():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw():
		var c = size / 2
		var unit = size.x / 48.0
		if mark in ["flag", "paid"]:
			var flag_color = Color("#ef0000") if mark == "flag" else Color("#008000")
			draw_line(c + Vector2(2, -13) * unit, c + Vector2(2, 12) * unit, Color.BLACK, 3 * unit)
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -13) * unit, c + Vector2(-13, -7) * unit, c + Vector2(1, -2) * unit]), flag_color)
			draw_rect(Rect2(c + Vector2(-9, 10) * unit, Vector2(22, 4) * unit), Color.BLACK)
			if mark == "paid":
				draw_line(c + Vector2(6, 0) * unit, c + Vector2(10, 4) * unit, flag_color, 3 * unit)
				draw_line(c + Vector2(10, 4) * unit, c + Vector2(17, -5) * unit, flag_color, 3 * unit)
		elif mark == "mine":
			for i in range(8):
				var axis = Vector2.from_angle(i * PI / 4)
				draw_line(c + axis * 6 * unit, c + axis * 16 * unit, Color.BLACK, 2 * unit)
			draw_circle(c, 11 * unit, Color.BLACK)
			draw_rect(Rect2(c + Vector2(-5, -6) * unit, Vector2(4, 4) * unit), Color.WHITE)
