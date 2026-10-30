extends SceneTree

# Rendered integration test. Uses fixture state only to reach reward screens quickly.
var game
var failures = 0
var checks = 0
var capture_dir = "user://qa"

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, description: String):
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _frames():
	await process_frame
	await process_frame
	RenderingServer.force_draw()

func _click(control: Control, button_index = MOUSE_BUTTON_LEFT):
	if game.inventory_cards.is_ancestor_of(control):
		game.sidebar_scroll.ensure_control_visible(control)
		await _frames()
	var event = InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames()

func _capture(filename: String):
	await _frames()
	var error = root.get_texture().get_image().save_png(capture_dir.path_join(filename))
	_expect(error == OK, "Screenshot saved: " + filename)

func _press_key(keycode: int):
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames()

func _click_outside_details():
	var event = InputEventMouseButton.new()
	event.position = Vector2(8, 8)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames()

func _clear_fixture():
	game.generated = true
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game._finish_action()
	await _frames()

func _run():
	if not OS.get_cmdline_user_args().is_empty():
		capture_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.title = "Mine Ledger - UI verification"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.rng.seed = 71231
	await _frames()
	await _capture("01-start.png")
	_expect(game.find_child("GoldCoin", true, false) != null and game.hp_label.maximum == 10 and game.hp_label.value == 10, "HUD contains a gold coin and a full ten-HP gauge")
	var artwork_ready = true
	for id in game.Augments.ALL:
		artwork_ready = artwork_ready and game.owned_cards[id]["icon"].texture != null
	_expect(artwork_ready and game.Art.texture_for("domain").get_width() > 128, "Every augmentation has artwork and Domain uses the official anime still")
	_expect(game.remaining_mines_label.text == "남은 지뢰  011 / 011" and game.special_mines_label.text == "특수 · 은신  00 / 00", "Fixed HUD shows the starting remaining and special mine totals before board generation")
	await _click(game.tile_buttons[0])
	_expect(game.generated and game.money == 28, "Rendered tile left click opens board and charges once")
	var mine = -1
	for i in range(game.cells.size()):
		if game.cells[i]["mine"]:
			mine = i
			break
	await _click(game.tile_buttons[mine], MOUSE_BUTTON_RIGHT)
	_expect(game.cells[mine]["flagged"] and not game.commit_button.disabled, "Rendered right click enables Commit")
	_expect(game.remaining_mines_label.text == "남은 지뢰  011 / 011", "Unverified flags do not reduce the remaining mine counter")
	await _click(game.commit_button)
	_expect(game.money == 32 and game.cells[mine]["settled"], "Commit signal pays the flagged mine")
	_expect(game.remaining_mines_label.text == "남은 지뢰  010 / 011", "Commit immediately reduces the remaining mine counter")
	await _capture("02-playing.png")
	game.hp = 6
	await _clear_fixture()
	_expect(game.phase == "augment" and game.choice_cards.visible, "Mandatory augment cards are shown before resource reward")
	# Controlled offers isolate button wiring; random pools are checked in augment_test.
	game.offered_augments = ["domain", "hound", "revival"]
	game._refresh()
	await _capture("03-buff-choice.png")
	await _click(game.card_buttons[0])
	_expect(game.phase == "reward" and game.pending_augment == "domain" and not game._has("domain"), "Rendered buff card selects a pending effect without activating it early")
	await _capture("04-resource-reward.png")
	await _click(game.heal_reward_button)
	_expect(game.stage == 2 and game.hp == 10 and game.money == 32 and game.board_width == 10 and game.board_height == 10 and game._has("domain"), "Rendered heal button advances, activates buff, and preserves cash")
	await _capture("05-stage-two.png")
	await _click(game.active_buttons["domain"])
	_expect(game.detail_overlay.visible and game.detail_use_button.disabled and game.targeting.is_empty() and game.used_actives.is_empty() and game.money == 32, "Unstarted-stage active card opens readable details without consuming its use")
	await _click(game.detail_close_button)
	_expect(not game.detail_overlay.visible and game.money == 32, "Detail close button preserves game state")
	await _click(game.tile_buttons[0])
	var inspect_gold = game.money
	var inspect_cells = game.cells.duplicate(true)
	var inspect_rng = game.rng.state
	await _click(game.active_buttons["domain"])
	_expect(game.detail_overlay.visible and game.detail_description.text == game.Augments.ALL["domain"]["description"] and game.targeting.is_empty() and game.used_actives.is_empty() and game.money == inspect_gold and game.cells == inspect_cells and game.rng.state == inspect_rng, "Active-card inspection shows complete text without spending gold, changing tiles, or using RNG")
	await _capture("18-active-detail.png")
	await _press_key(KEY_TAB)
	_expect(game.detail_overlay.is_ancestor_of(game.get_viewport().gui_get_focus_owner()) and game.used_actives.is_empty(), "Keyboard focus stays inside details without activating underlying game controls")
	var target = game._unsettled_mines()[0]
	await _click(game.tile_buttons[target])
	_expect(game.detail_overlay.visible and game.cells == inspect_cells and game.money == inspect_gold and game.used_actives.is_empty(), "Detail modal blocks clicks on the underlying game board")
	await _click(game.detail_use_button)
	_expect(not game.detail_overlay.visible and game.targeting == "domain" and game.used_actives.is_empty(), "Explicit detail-use button starts target selection without consuming until a target is chosen")
	await _click(game.tile_buttons[target], MOUSE_BUTTON_RIGHT)
	_expect(game.targeting.is_empty() and game.used_actives.is_empty() and game._pending_flags().is_empty(), "Right click cancels active targeting without spending its use or placing a flag")
	await _click(game.active_buttons["domain"])
	await _click(game.detail_use_button)
	await _click(game.active_buttons["domain"])
	await _press_key(KEY_ESCAPE)
	_expect(not game.detail_overlay.visible and game.targeting == "domain" and game.used_actives.is_empty(), "Closing an inspection with Escape preserves an existing unspent target-selection action")
	var motion = InputEventMouseMotion.new()
	motion.position = game.tile_buttons[target].get_global_rect().get_center()
	Input.parse_input_event(motion)
	await _frames()
	_expect(game.current_hover == target, "Real mouse motion previews the active target region")
	await _capture("06-target-preview.png")
	var digs_before = game.direct_digs
	await _click(game.tile_buttons[target])
	_expect("domain" in game.used_actives and game.cells[target]["settled"] and game.direct_digs == digs_before and game.targeting.is_empty(), "Targeted Domain resolves via tile input without direct-dig count")
	await _capture("07-active-used.png")
	await _click(game.active_buttons["domain"])
	_expect(game.detail_overlay.visible and game.detail_use_button.disabled and game.detail_status.text.contains("0 / 1회") and game.targeting.is_empty(), "A used active remains inspectable while the use button is disabled")
	await _press_key(KEY_ESCAPE)
	_expect(not game.detail_overlay.visible and "domain" in game.used_actives, "Escape closes details without resetting an active cooldown")
	await _clear_fixture()
	game.offered_augments = ["dig_tax", "overcrowding"]
	game._refresh()
	_expect(game.card_buttons[0].visible and game.card_buttons[1].visible and not game.card_buttons[2].visible and game.choice_subtitle.text.contains("2개"), "Even-stage UI displays exactly two debuff choices")
	await _capture("08-debuff-choice.png")
	await _click(game.card_buttons[0])
	_expect(game.pending_augment == "dig_tax" and game.dig_cost == 4, "Rendered debuff card keeps current-stage cost unchanged")
	var before = game.money
	await _click(game.money_reward_button)
	_expect(game.stage == 3 and game.money == before + 48 and game.hp == 10 and game.dig_cost == 8 and game.mine_reward == 14, "Rendered cash reward funds the new taxed cost without inflating mine reward")
	var final_build = ["domain", "hound", "scanner", "transfusion", "revival", "stealth", "fuse", "weakness", "instrument"]
	game.owned_augments = final_build.duplicate()
	game.stage = 10
	game.money = 1000
	game._start_stage()
	await _capture("09-large-board.png")
	var hud_position = game.remaining_mines_label.global_position
	game.board_scroll.scroll_horizontal = 200
	game.board_scroll.scroll_vertical = 250
	await _frames()
	_expect(game.remaining_mines_label.global_position == hud_position and game.remaining_mines_label.get_global_rect().end.x < game.get_viewport_rect().end.x and game.special_mines_label.get_global_rect().end.x < game.get_viewport_rect().end.x, "Both mine counters remain visible and stationary when the 26x26 board is scrolled")
	await _capture("21-fixed-hud.png")
	game._generate_board(0)
	await _clear_fixture()
	_expect(game.phase == "victory" and game.victory_panel.visible and not game.reward_panel.visible and not game.choice_cards.visible, "Final clear shows victory without augment or resource choices")
	await _capture("10-victory.png")
	game._new_run()
	game._abandon()
	await _capture("11-game-over.png")
	await _click(game.face_button)
	_expect(game.stage == 1 and game.hp == 10 and game.money == 30 and not game.generated, "Smiley button starts a fresh run after game over")
	game.owned_augments = final_build.duplicate()
	game.stage = 10
	game.money = 1000
	game.hp = 6
	game._start_stage()
	game._dig(0)
	var masked = -1
	var stealth = -1
	for i in range(game.cells.size()):
		if game.cells[i].get("obscured", false) and not game.cells[i]["revealed"]:
			masked = i
		if game.cells[i].get("stealth", false):
			stealth = i
	if masked >= 0:
		game._dig(masked)
		_expect(game.tile_buttons[masked].text == "?", "Instrument failure displays a question mark rather than leaking the real clue")
	game._use_active("scanner", stealth)
	_expect(game.scan_result["count"] > 0 and game.inventory_label.text.contains("버프 5/5 · 디버프 4/4") and game.max_hp == 8 and game.hp_label.maximum == 8 and game.hp_label.value == game.hp, "Equipped HUD shows full inventory cards, weakened HP gauge, and stealth-inclusive scan")
	var visible_cards = 0
	for id in game.owned_cards:
		visible_cards += int(game.owned_cards[id]["root"].visible)
	_expect(visible_cards == 9 and game.owned_cards["domain"]["icon"].texture == game.Art.texture_for("domain"), "Sidebar shows nine illustrated owned cards, including the same Domain artwork")
	await _capture("12-equipped-scan.png")
	game.sidebar_scroll.ensure_control_visible(game.owned_cards["revival"]["root"])
	await _frames()
	await _click(game.owned_cards["revival"]["root"])
	_expect(game.detail_overlay.visible and game.detail_title.text.contains("부활권") and game.detail_description.text == game.Augments.ALL["revival"]["description"] and not game.detail_use_button.visible and not game.revival_used, "Passive card opens its complete description and remaining lifetime use")
	await _capture("19-passive-detail.png")
	game.revival_used = true
	game._refresh()
	_expect(game.detail_status.text.contains("이미 소모됨") and not game.detail_use_button.visible, "Consumed revival status is shown in passive details")
	await _click(game.detail_close_button)
	game.sidebar_scroll.ensure_control_visible(game.owned_cards["weakness"]["root"])
	await _frames()
	await _click(game.owned_cards["weakness"]["root"])
	_expect(game.detail_overlay.visible and game.detail_title.text.contains("디버프") and game.detail_description.text == game.Augments.ALL["weakness"]["description"] and not game.detail_use_button.visible and game.max_hp == 8, "Debuff card opens its full effect and current HP limit without an activation button")
	await _capture("20-debuff-detail.png")
	await _click_outside_details()
	_expect(not game.detail_overlay.visible and game.max_hp == 8, "Clicking outside closes details without removing the debuff")
	game._settle_mines([stealth])
	game._settle_mines([stealth])
	game._refresh()
	_expect(game.special_mines_label.text == "특수 · 은신  00 / 01", "Confirmed stealth mine reduces the special counter without counting it twice")
	# A real four-mine neighborhood, all four remaining neighbors are numbered.
	# This isolates actual UI chording from flood randomness.
	game._new_run()
	game.generated = true
	game.mine_count = 5
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in [0, 2, 16, 18, 63], "stealth": false, "adjacent": 0, "revealed": i == 9, "flagged": false, "settled": false, "committed": false, "obscured": false}
	game._recount_neighbors()
	for index in [0, 2, 16, 18]:
		game._toggle_flag(index)
	game._refresh()
	await _frames()
	await _click(game.tile_buttons[9])
	_expect(game.direct_digs == 0 and game.money == 30 and not game.cells[1]["revealed"], "Actual number click refuses a neighborhood with only pending flags")
	await _click(game.commit_button)
	_expect(game.money == 46 and game.cells[0]["committed"] and game.cells[18]["committed"], "Actual Commit button prepares all four neighboring mines for chord")
	game.money = 7
	game._refresh()
	await _click(game.tile_buttons[9])
	_expect(game.money == 7 and game.direct_digs == 0 and not game.cells[1]["revealed"] and not game.cells[17]["revealed"] and game.message_label.text.contains("필요 8 / 보유 7"), "Number click with insufficient total gold opens nothing and shows the full price")
	await _capture("13-chord-insufficient.png")
	game.money = 8
	game._refresh()
	await _click(game.tile_buttons[9])
	_expect(game.money == 0 and game.direct_digs == 4 and game.cells[1]["revealed"] and game.cells[8]["revealed"] and game.cells[10]["revealed"] and game.cells[17]["revealed"], "One actual number click opens all four eligible neighbors with exact funds")
	await _capture("14-chord-complete.png")
	game.money = 10
	game.hp = 3
	game._refresh()
	await _click(game.tile_buttons[63])
	_expect(game.hp == 1 and game.hp_label.value == 1 and game.hp_label.maximum == 10, "HP gauge updates after actual mine damage into its low-health state")
	_expect(game.remaining_mines_label.text == "남은 지뢰  000 / 005", "Exploded mines also reduce the remaining count to zero")
	await _capture("15-low-health.png")
	game.money = 30
	game._refresh()
	await _click(game.tile_buttons[54])
	var explosion_chord = game._chord_info(54)
	_expect(game.cells[54]["revealed"] and game.cells[63]["revealed"] and not game.cells[63]["committed"] and explosion_chord["confirmed"] == 1 and explosion_chord["committed"] == 0 and explosion_chord["eligible"], "Actual mine explosion permits a neighboring number chord without any Commit")
	var explosion_hp = game.hp
	var explosion_gold = game.money
	var explosion_digs = game.direct_digs
	await _click(game.tile_buttons[54])
	var targets_open = true
	for index in explosion_chord["targets"]:
		targets_open = targets_open and game.cells[index]["revealed"]
	_expect(targets_open and game.hp == explosion_hp and game.direct_digs > explosion_digs and explosion_gold - game.money == (game.direct_digs - explosion_digs) * game.dig_cost, "Actual number click opens neighbors around the exploded mine without repeat damage or mine payout")
	await _capture("17-exploded-mine-chord.png")
	print("Finished %d GUI checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)
