extends SceneTree
var game
var failures = 0
func check(ok, label):
	if not ok:
		failures += 1
		push_error(label)
	else: print("PASS: ", label)
func fixture():
	game._new_run()
	game.generated = true
	game.mine_count = 2
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in [62,63], "stealth": false, "adjacent": 1, "revealed": false, "settled": false, "committed": false, "flagged": false}
func _initialize(): call_deferred("run")
func run():
	game = load("res://run_model.gd").new()
	root.add_child(game)
	fixture()
	for cell in game.cells:
		if not cell.mine: cell.revealed = true
	game._finish_action()
	check(game.phase == "playing", "All safe tiles alone no longer clear")
	game._toggle_flag(62)
	game._commit_flags()
	check(game.phase == "playing" and game.money == 34, "Partial Commit pays and stays on stage")
	game._toggle_flag(63)
	game._commit_flags()
	check(game.phase == "augment" and game.money == 38, "Final Commit pays before clearing")
	fixture()
	game._toggle_flag(62)
	game._toggle_flag(63)
	game._commit_flags()
	check(game.phase == "augment" and not game.cells[0].revealed, "All mine Commit clears with safe cells still hidden")
	fixture()
	game.owned_augments = ["interference"]
	game._dig(62)
	game._dig(63)
	var gold = game.money
	var health = game.hp
	game._commit_flags()
	check(game.phase == "augment" and game.money == gold and game.hp == health, "Exploded mines can finish Commit without repeat income or damage even under interference")
	fixture()
	game.stage = 10
	game._settle_mines([62,63])
	game._finish_action()
	check(game.phase == "victory", "Stage ten ends after all mines Commit")
	print("Clear-condition failures: ", failures)
	quit(failures)
