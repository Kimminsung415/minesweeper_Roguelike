extends Control

var elapsed = 0.0
var progress = 0.0
var result = "pending"

func _draw():
	var center = size * 0.5
	var gold = Color("#ffd478")
	var cyan = Color("#64cfff")
	var tint = cyan if result == "pending" else (gold if result == "success" else Color("#e27b91"))
	var beat = 0.5 + 0.5 * sin(elapsed * (6.0 + progress * 12.0))
	for i in range(4):
		var radius = 66.0 + i * 21.0 + beat * 4.0
		var ring_color = tint
		ring_color.a = 0.10 + 0.10 * progress
		draw_arc(center, radius, elapsed * (0.4 + i * 0.1), elapsed * (0.4 + i * 0.1) + TAU * (0.30 + progress * 0.65), 90, ring_color, 2.0, true)
	for i in range(22):
		var angle = TAU * i / 22.0 + elapsed * 0.22
		var radius = 135.0 - fmod(elapsed * 25.0 + i * 11.0, 65.0)
		if result != "pending":
			radius = 70.0 + fmod(elapsed * 28.0 + i * 11.0, 70.0)
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(point, 1.5 + (i % 3) * 0.6, Color(tint, 0.65))
	var shake = Vector2.ZERO
	if result == "pending":
		shake = Vector2(sin(elapsed * 43.0), cos(elapsed * 37.0)) * progress * 3.0
	var ticket = Rect2(center + shake - Vector2(61, 42), Vector2(122, 84))
	draw_style_box(_ticket_style(tint), ticket)
	for y in range(3):
		draw_line(ticket.position + Vector2(20, 23 + y * 18), ticket.position + Vector2(102, 23 + y * 18), Color(tint, 0.6), 3.0, true)
	if result == "success":
		draw_line(center + Vector2(-20, 0), center + Vector2(-4, 16), gold, 7, true)
		draw_line(center + Vector2(-4, 16), center + Vector2(26, -20), gold, 7, true)
	elif result == "failure":
		var crack = PackedVector2Array([center + Vector2(5, -42), center + Vector2(-9, -12), center + Vector2(11, 4), center + Vector2(-5, 42)])
		draw_polyline(crack, Color("#091321"), 7, true)

func _ticket_style(tint: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#172b42")
	style.border_color = tint
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	return style
