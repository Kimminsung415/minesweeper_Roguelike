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
	scroll.scroll_vertical=10000
	await _frames()
	_expect(scroll.scroll_vertical>0,"Short phone can scroll down")
	_expect(game.card_buttons[2].get_global_rect().end.y<=scroll.get_global_rect().end.y,"Last choice becomes visible")
	root.get_texture().get_image().save_png("C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/mobile-choice-scroll.png")
	print("SCROLL failures ",failures)
	quit(failures)
