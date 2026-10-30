extends "res://gui_test.gd"

func _set_roll(success: bool):
	var probe = RandomNumberGenerator.new()
	for seed_value in range(100000):
		probe.seed = seed_value
		if (probe.randf() < game._ticket_chance()) == success:
			game.rng.seed = seed_value
			return

func _shop_click():
	game.sidebar_scroll.scroll_vertical = 0
	await _frames()
	await _click(game.shop_jump_button)
	await _frames()
	await _click(game.shop_button)
	while not game.ticket_pending.is_empty():
		await process_frame
	await _press_key(KEY_ENTER)

func _run():
	if not OS.get_cmdline_user_args().is_empty():
		capture_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	_expect(game.shop_button.disabled and game.shop_button.text.contains("10%") and game.shop_button.text.contains("12골드"), "Shop displays starting cost and true ten-percent chance before unlocking")
	game.owned_augments = ["domain", "safe_dig", "vitality", "heart", "insurance", "medic", "healing_loss"]
	game.money = 200
	game.stage = 2
	game._start_stage()
	game.hp = game.max_hp
	game._dig(0)
	await _frames()
	_expect(not game.shop_button.disabled and game.max_hp == 13, "Shop unlocks after first dig with expanded heart HP gauge")
	var before_gold = game.money
	_set_roll(false)
	await _shop_click()
	_expect(game.money == before_gold - 24 and game.expansion_level == 0 and game.shop_status.text.contains("실패"), "Native ticket click charges current stage price and displays failure")
	_set_roll(true)
	await _shop_click()
	_expect(game.expansion_level == 1 and game.shop_label.text.contains("5×5") and game.shop_button.text.contains("8%") and game.shop_button.text.contains("48골드"), "Successful purchase immediately doubles the displayed price and updates level, area, and chance")
	_set_roll(true)
	await _shop_click()
	_expect(game.expansion_level == 2 and game.shop_label.text.contains("7×7") and game.shop_button.text.contains("6.4%") and game.shop_button.text.contains("96골드"), "Second success visibly stacks area, doubles price again, and lowers success chance")
	await _capture("22-shop-level-two.png")
	await _click(game.owned_cards["domain"]["root"])
	_expect(game.detail_status.text.contains("7×7") and game.detail_status.text.contains("Lv.2"), "Owned Domain inspector shows actual upgraded range")
	var purchases = game.ticket_purchases
	game._purchase_ticket()
	_expect(game.ticket_purchases == purchases, "Inspecting an augment blocks underlying shop purchase")
	await _capture("24-upgraded-domain-detail.png")
	await _click(game.detail_use_button)
	game.current_hover = 44
	game._refresh()
	await _frames()
	_expect(game.shop_button.disabled and game.tile_buttons[11].modulate == Color("#ffe083") and game.tile_buttons[77].modulate == Color("#ffe083") and game.tile_buttons[88].modulate != Color("#ffe083"), "Target preview matches expanded seven-by-seven footprint and locks ticket buying")
	game._cancel_target()
	await _click(game.owned_cards["vitality"]["root"])
	await _click(game.detail_use_button)
	_expect(game.max_hp == 15 and game.hp_label.maximum == 15 and game.hp == 15 and "vitality" in game.used_actives, "Vitality use updates current HP and gauge maximum together")
	game._apply_damage(2)
	game._refresh()
	_expect(game.damage_flash.color.a > 0 and game.damage_flash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Real HP damage starts a red overlay that does not block input")
	game.sidebar_scroll.scroll_vertical = 0
	await _capture("23-damage-feedback.png")
	var until = Time.get_ticks_msec() + 450
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(is_zero_approx(game.damage_flash.color.a), "Damage overlay fades back to transparent automatically")
	game._apply_damage(0)
	_expect(is_zero_approx(game.damage_flash.color.a), "Zero damage does not start the flash")
	game._apply_damage(1)
	game._new_run()
	_expect(is_zero_approx(game.damage_flash.color.a) and game.expansion_level == 0, "Restart clears both flash and stacked upgrades")
	print("Finished %d shop GUI checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)
