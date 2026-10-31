extends "res://gui_test.gd"
func _run():
	root.size=Vector2i(390,500)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	game._select_mode("easy")
	game.phase="augment"
	game.offered_augments=["beast","survey","relief"]
	game._refresh()
	await _frames()
	var scroll=game.choice_cards.get_parent().get_parent().get_parent()
	_expect(scroll is ScrollContainer,"Choice screen has scroll container")
	var press=InputEventScreenTouch.new()
	press.index=0
	var scale_factor=float(root.size.x)/game.get_viewport_rect().size.x
	press.position=game.card_buttons[1].get_global_rect().get_center()*scale_factor
	press.pressed=true
	Input.parse_input_event(press)
	await process_frame
	var drag=InputEventScreenDrag.new()
	drag.index=0
	drag.position=press.position+Vector2(0,-300)*scale_factor
	drag.relative=Vector2(0,-300)*scale_factor
	Input.parse_input_event(drag)
	await process_frame
	press.position=drag.position
	press.pressed=false
	Input.parse_input_event(press)
	await process_frame
	_expect(game.phase=="augment","Dragging over a card never selects it")
	await _frames()
	_expect(scroll.scroll_vertical>0,"Short phone can scroll down")
	_expect(game.card_buttons[2].get_global_rect().end.y<=scroll.get_global_rect().end.y,"Last choice becomes visible")
	root.get_texture().get_image().save_png("C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/mobile-choice-scroll.png")
	press.position=game.card_buttons[2].get_global_rect().get_center()*scale_factor
	press.pressed=true
	Input.parse_input_event(press)
	await process_frame
	press.pressed=false
	Input.parse_input_event(press)
	await _frames()
	_expect(game.phase=="reward" and game.pending_augment=="relief","Tap after scrolling selects the visible card")
	print("SCROLL failures ",failures)
	quit(failures)
