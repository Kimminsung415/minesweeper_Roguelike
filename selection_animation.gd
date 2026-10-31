extends Control
var ids = []
var chosen = ""
var caption = ""
var tear = false
var progress = 0.0:
	set(value):
		progress = value
		queue_redraw()
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.04,0.08,0.96))
	var font = get_theme_default_font()
	draw_string(font,Vector2(45,65),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color.GOLD)
	if ids.is_empty():
		var text = "₩  ×  %.2f" % (0.5+absf(sin(progress*60))*1.7) if progress<0.75 else caption
		draw_string(font,Vector2(size.x*0.22,size.y*0.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color.GOLD)
		return
	var cols = mini(7,ids.size())
	var rows = ceili(float(ids.size())/cols)
	var w = minf(150,(size.x-70)/cols)
	var h = minf(160,(size.y-140)/rows)
	var selected = ids.find(chosen)
	var cursor = int(progress*progress*50)%ids.size() if progress<0.72 else selected
	for i in range(ids.size()):
		var origin = Vector2((size.x-cols*w)/2+(i%cols)*w,(size.y-rows*h)/2+30+int(i/cols)*h)
		var rect = Rect2(origin,Vector2(w-10,h-32))
		var color = Color("#405c7c") if i != selected or progress<0.72 else Color("#b07434")
		if i == selected and progress>0.82 and tear:
			var shift = (progress-0.82)*300
			var left = rect
			left.size.x *= 0.5
			left.position.x -= shift
			var right = left
			right.position.x = rect.position.x+rect.size.x/2+shift
			draw_rect(left,color)
			draw_rect(right,color)
			var crack = PackedVector2Array()
			for j in range(9): crack.append(Vector2(rect.get_center().x+(-5 if j%2==0 else 5),rect.position.y+j*rect.size.y/8))
			draw_polyline(crack,Color.BLACK,4)
		else:
			draw_rect(rect,color)
			draw_texture_rect(preload("res://augment_art.gd").texture_for(ids[i]),Rect2(origin+Vector2(12,8),Vector2(48,48)),false)
			draw_string(font,origin+Vector2(6,80),preload("res://augments.gd").ALL[ids[i]]["name"],HORIZONTAL_ALIGNMENT_LEFT,w-18,15,Color.WHITE)
		if cursor == i:
			var c = origin+Vector2((w-10)/2,h-20)
			draw_colored_polygon(PackedVector2Array([c+Vector2(-9,8),c+Vector2(9,8),c+Vector2(0,-6)]),Color.GOLD)
