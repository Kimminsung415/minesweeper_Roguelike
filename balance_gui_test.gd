extends "res://gui_test.gd"
func _run():
	capture_dir="C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/v1.2.0-build008-preview"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	game._select_mode("easy")
	game.owned_augments=["gamble","cleanse","reroll","smith","communism","high_explosive"]
	game._start_stage()
	game._dig(0)
	game._use_active("gamble")
	check_busy()
	await create_timer(1.5).timeout
	_expect(not game.effect_busy,"Gamble animation completes")
	game._use_active("cleanse")
	await create_timer(1.7).timeout
	await _capture("01-selection-animation.png")
	await create_timer(1.0).timeout
	_expect(not game.effect_busy and not game._has("high_explosive"),"Removal animation completes")
	game.phase="augment"
	game.offered_augments=["beast","adaptation","relief"]
	game._refresh()
	await _capture("02-reroll-choice.png")
	await _click(game.reroll_buttons[0])
	_expect(0 in game.rerolled_slots,"GUI slot reroll input")
	game.phase="playing"
	game._refresh()
	game._show_augment_details("smith")
	await _capture("03-smith-details.png")
	print("GUI PATCH ",checks," failures ",failures)
	quit(failures)
func check_busy():
	_expect(game.effect_busy,"Gamble animation locks game input")
