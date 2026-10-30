extends "res://gui_test.gd"
func bounds_ok(control):
	var viewport = game.sidebar_scroll.get_global_rect()
	var bounds = control.get_global_rect()
	return bounds.position.x >= viewport.position.x - 1 and bounds.end.x <= viewport.end.x + 1
func _run():
	if not OS.get_cmdline_user_args().is_empty(): capture_dir=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	_expect(game.sidebar_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"Sidebar horizontal scrolling disabled")
	_expect(bounds_ok(game.rules_label) and bounds_ok(game.commit_button) and bounds_ok(game.shop_jump_button),"Initial text and buttons remain inside viewport")
	await _capture("01-sidebar-start.png")
	game.owned_augments=["domain","heart","revival","frugal","armor","insurance","blood_trade","instrument","weakness"]
	game._start_stage()
	game.message="주변 파기: 직접 18회 · 골드 -120 · HP +0\n아주 긴 상태 안내와 Commit 정산 및 강화 효과 설명을 표시합니다."
	game._refresh()
	await _frames()
	_expect(bounds_ok(game.message_label) and bounds_ok(game.inventory_label),"Long messages wrap inside sidebar")
	game.sidebar_scroll.ensure_control_visible(game.owned_cards.weakness.root)
	await _frames()
	_expect(game.sidebar_scroll.scroll_horizontal==0 and bounds_ok(game.owned_cards.weakness.root),"Scrolling to inventory never shifts sidebar horizontally")
	await _capture("02-sidebar-inventory.png")
	await _click(game.owned_cards.heart.root)
	await _press_key(KEY_ESCAPE)
	_expect(game.sidebar_scroll.scroll_horizontal==0,"Inspect and close preserve horizontal position")
	game.sidebar_scroll.scroll_vertical=0
	await _frames()
	_expect(bounds_ok(game.rules_label) and bounds_ok(game.commit_button),"Return to top preserves complete left edges")
	await _capture("03-sidebar-long-message.png")
	print("Finished %d sidebar checks with %d failures" % [checks,failures])
	quit(failures)
