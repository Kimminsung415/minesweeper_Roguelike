extends SceneTree

var game
var checks = 0
var failures = 0

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, description: String):
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _key(code: int, repeat = false):
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = repeat
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	await process_frame

func _fixture():
	game._new_run()
	game.generated = true
	game.mine_count = 4
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in [0, 2, 16, 63], "stealth": false, "adjacent": 0, "revealed": false, "flagged": false, "settled": false, "committed": false, "obscured": false}
	game._recount_neighbors()
	game._toggle_flag(0)
	game._refresh()

func _run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await _key(KEY_SPACE)
	_expect(not game.generated and game.money == 30, "Space before board generation is harmless")
	for code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_fixture()
		game.face_button.grab_focus()
		await _key(code)
		_expect(game.cells[0]["committed"] and game.money == 34 and game.generated, "Commit shortcut overrides focused restart button: %d" % code)
		await _key(code)
		_expect(game.money == 34 and game.hp == 10, "Repeated shortcut cannot settle the mine twice: %d" % code)
	_fixture()
	await _key(KEY_SPACE, true)
	_expect(not game.cells[0]["settled"] and game.money == 30, "Held-key echo cannot Commit")
	game.owned_augments = ["domain"]
	game.targeting = "domain"
	await _key(KEY_ENTER)
	_expect(not game.cells[0]["settled"] and game.targeting == "domain", "Target selection blocks shortcut without cancelling targeting")
	game.targeting = ""
	game._show_augment_details("domain")
	await _key(KEY_ENTER)
	_expect(not game.cells[0]["settled"] and game.money == 30 and game.used_actives.is_empty(), "Detail modal prevents underlying Commit")
	game._close_augment_details()
	game.owned_augments = ["interference"]
	game._refresh()
	await _key(KEY_SPACE)
	_expect(not game.cells[0]["settled"] and game.money == 30, "Shortcut respects interference minimum flag count")
	game._toggle_flag(2)
	game._toggle_flag(16)
	await _key(KEY_SPACE)
	_expect(game.money == 42 and game.cells[16]["committed"], "Shortcut allows three flags under interference")
	for locked_phase in ["augment", "reward", "victory", "gameover"]:
		_fixture()
		game.phase = locked_phase
		game.face_button.grab_focus()
		await _key(KEY_ENTER)
		_expect(game.phase == locked_phase and not game.cells[0]["settled"] and game.money == 30, "Shortcut is inert during " + locked_phase)
	_fixture()
	game.tile_buttons[1].focus_mode = Control.FOCUS_ALL
	game.tile_buttons[1].grab_focus()
	await _key(KEY_ENTER)
	_expect(game.cells[0]["committed"] and not game.cells[1]["revealed"] and game.direct_digs == 0, "Enter commits instead of digging the focused tile")
	print("Finished %d shortcut checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)
