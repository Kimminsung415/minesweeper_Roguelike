extends "res://gui_test.gd"
func _frames():
	await process_frame
	await process_frame
	RenderingServer.force_draw()
func _run():
	if not OS.get_cmdline_user_args().is_empty(): capture_dir=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	_expect(Engine.max_fps==30 and OS.low_processor_usage_mode and not game.is_processing(),"Thirty FPS, low processor mode, no idle processing")
	for number in range(1,11):
		var rules=game.StageRules.for_stage(number)
		_expect(rules.dig_cost==number*2 and rules.mine_reward==number*4,"Linear cost and reward stage %d" % number)
	game.owned_augments=["domain"]
	game.money=1000
	game._start_stage()
	game._dig(0)
	game._apply_damage(1)
	_expect(game.is_processing() and game.damage_flash_remaining>0,"Damage wakes animation processing")
	var until=Time.get_ticks_msec()+500
	while Time.get_ticks_msec()<until: await process_frame
	_expect(not game.is_processing() and is_zero_approx(game.damage_flash.color.a),"Damage finishes and returns to idle")
	game.upgrade_target="domain"
	game._purchase_ticket()
	_expect(game.is_processing() and game.ticket_overlay.visible,"Purchase wakes animation processing")
	while not game.ticket_pending.is_empty(): await process_frame
	await _frames()
	var elapsed=game.ticket_elapsed
	_expect(not game.is_processing() and not game.ticket_close_button.disabled,"Result is revealed and animation processing stops")
	until=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<until: await process_frame
	_expect(game.ticket_elapsed==elapsed,"Result window remains static while open")
	await _press_key(KEY_ENTER)
	_expect(not game.ticket_overlay.visible and not game.is_processing(),"Result confirmation still works in idle mode")
	game._purchase_ticket()
	_expect(game.is_processing(),"Next animation can wake again")
	print("Finished %d efficiency checks with %d failures" % [checks,failures])
	quit(failures)
