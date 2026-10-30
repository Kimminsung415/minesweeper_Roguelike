extends "res://shop_gui_test.gd"

func _run():
	if not OS.get_cmdline_user_args().is_empty():
		capture_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	_expect(game.get_window().title.contains("v" + game.release_info["version"]) and game.get_window().title.contains("build.%03d" % game.release_info["build"]), "Window displays version and build from release metadata")
	game.owned_augments = ["domain", "grant"]
	game.money = 1000
	game._start_stage()
	game._dig(0)
	await _frames()
	var before_gold = game.money
	var before_hp = game.hp
	var before_cells = game.cells.duplicate(true)
	_set_roll(false)
	game._purchase_ticket()
	_expect(game.ticket_overlay.visible and not game.ticket_pending.is_empty() and game.ticket_close_button.disabled and game.expansion_level == 0 and game.money == before_gold - 12 and game.ticket_purchases == 1, "Animation opens, charges one ticket, and defers visible result")
	var rolled_rng = game.rng.state
	game._purchase_ticket()
	game._buy_upgrade_ticket()
	game._toggle_flag(9)
	game._dig(9)
	game._commit_flags()
	game._use_active("grant")
	game._abandon()
	_expect(game.ticket_purchases == 1 and game.money == before_gold - 12 and game.hp == before_hp and game.cells == before_cells and game.rng.state == rolled_rng and game.phase == "playing", "Pending transaction blocks repeat purchase, digging, flags, Commit, active use, and abandon")
	await _press_key(KEY_SPACE)
	await _press_key(KEY_ENTER)
	await _press_key(KEY_ESCAPE)
	_expect(game.ticket_overlay.visible and not game.ticket_pending.is_empty() and game.ticket_purchases == 1, "Space, Enter, and Escape cannot skip or repeat an unfinished roll")
	await _click(game.tile_buttons[9])
	_expect(game.cells == before_cells and game.rng.state == rolled_rng, "Overlay blocks native board clicks and cosmetic animation consumes no gameplay RNG")
	await _capture("25-upgrade-charging.png")
	while not game.ticket_pending.is_empty():
		await process_frame
	_expect(game.ticket_overlay.visible and game.ticket_visual.result == "failure" and not game.ticket_close_button.disabled and game.expansion_level == 0 and game.money == before_gold - 12, "Failed roll reveals its result without a second charge or level change")
	await _capture("26-upgrade-failure.png")
	var result_rng = game.rng.state
	game._resolve_upgrade_ticket()
	_expect(game.rng.state == result_rng and game.money == before_gold - 12 and game.ticket_purchases == 1, "Repeated result resolution cannot reroll or charge again")
	await _press_key(KEY_ENTER)
	_expect(not game.ticket_overlay.visible and game.phase == "playing", "Enter closes the revealed result without committing or restarting")
	_set_roll(true)
	game._purchase_ticket()
	while not game.ticket_pending.is_empty():
		await process_frame
	_expect(game.ticket_visual.result == "success" and game.ticket_title.text.contains("성공") and game.expansion_level == 1 and game._ticket_cost() == 24 and game.ticket_purchases == 2 and game.money == before_gold - 24, "Successful animation reveals exactly one level and the doubled next price")
	await _capture("27-upgrade-success.png")
	await _click(game.ticket_close_button)
	_expect(not game.ticket_overlay.visible, "Native confirm button closes the result")
	_set_roll(true)
	game._purchase_ticket()
	game._new_run()
	await _frames()
	_expect(not game.ticket_overlay.visible and game.ticket_pending.is_empty() and game.expansion_level == 0 and game.ticket_purchases == 0 and game.money == 30, "Reset during pending animation clears old transaction and result overlay")
	var until = Time.get_ticks_msec() + 2400
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(game.expansion_level == 0 and game.money == 30 and game.ticket_pending.is_empty(), "Old animation cannot grant a late upgrade after reset")
	print("Finished %d animation checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)
