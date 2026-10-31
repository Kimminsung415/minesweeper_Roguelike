extends "res://gui_test.gd"
func _run():
	root.size=Vector2i(1200,850)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	game._select_mode("hard")
	game.phase="augment"
	game.offered_augments=["beast","survey","relief"]
	game._refresh()
	await _frames()
	_expect(not game.mobile and game.desktop_detail_buttons.size()==3,"Desktop detail buttons exist")
	await _click(game.desktop_detail_buttons[0])
	_expect(game.choice_info.visible and game.choice_info_text.text.contains("Lv.4") and game.choice_info_text.text.contains("×80"),"Desktop choice details show all levels")
	game.choice_info.hide()
	game.phase="playing"
	game.owned_augments=["beast"]
	game._refresh()
	game._show_augment_details("beast")
	await _frames()
	_expect(game.detail_status.text.contains("Lv.4") and game.detail_status.text.contains("×80"),"Desktop owned details show all levels")
	_expect(game.tile_buttons.all(func(b):return b.tooltip_text.is_empty()),"Desktop tile tooltips absent")
	root.get_texture().get_image().save_png("C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/desktop-beast-details.png")
	print("DESKTOP DETAIL ",checks," failures ",failures)
	quit(failures)
