extends "res://gui_test.gd"
func _run():
	if not OS.get_cmdline_user_args().is_empty():
		capture_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	game.owned_augments = ["domain","heart","revival","shield","armor"]
	game.money=10000
	game._start_stage()
	game._dig(0)
	await _frames()
	await _click(game.owned_cards["domain"].root)
	_expect(game.detail_upgrade_button.visible and game.detail_upgrade_button.text.contains("30%") and game.detail_status.text.contains("5×5"),"Active inspector shows next range and 30 percent")
	await _capture("01-domain-upgrade.png")
	var probe = RandomNumberGenerator.new()
	for seed_value in range(10000):
		probe.seed=seed_value
		if probe.randf()<0.3:
			game.rng.seed=seed_value
			break
	await _click(game.detail_upgrade_button)
	_expect(game.ticket_overlay.visible and game.ticket_snapshot.id=="domain", "Native upgrade button targets selected card")
	while not game.ticket_pending.is_empty(): await process_frame
	_expect(game._level("domain")==2 and game._level("heart")==1,"Animation resolves only selected upgrade")
	await _capture("02-upgrade-success.png")
	await _press_key(KEY_ENTER)
	await _click(game.owned_cards["heart"].root)
	_expect(game.detail_upgrade_button.visible and game.detail_status.text.contains("최대 HP +4"),"Passive inspector offers its own improvement")
	await _capture("03-passive-upgrade.png")
	game.augment_levels.heart=4
	game._refresh()
	_expect(game.detail_upgrade_button.disabled and game.detail_upgrade_button.text=="최대 레벨", "Max level is disabled in inspector")
	print("Finished %d GUI level checks with %d failures" % [checks,failures])
	quit(failures)
