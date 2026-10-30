extends SceneTree

const Model = preload("res://run_model.gd")
var game
var checks = 0
var failures = 0

func _initialize():
	call_deferred("_run")

func _expect(condition, description: String):
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

# Synthetic numbered cells isolate the two target digs from random flood sizes.
func _fixture(ids: Array = [], mines: Array = [9, 63]):
	game._new_run()
	game.owned_augments = ids.duplicate()
	game._start_stage()
	game.generated = true
	game.money = 100
	game.mine_count = mines.size()
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in mines, "stealth": false, "adjacent": 1, "revealed": i == 0, "flagged": false, "settled": false, "committed": false, "obscured": false}

func _commit(index: int = 9):
	game._toggle_flag(index)
	game._commit_flags()
	game.money = 100

func _run():
	game = Model.new()
	root.add_child(game)
	_fixture()
	game._dig(0)
	_expect(game.money == 100 and game.direct_digs == 0 and not game.cells[1]["revealed"], "Uncommitted neighbors cannot activate number-click digging")
	game._toggle_flag(9)
	game._dig(0)
	_expect(game.money == 100 and game.cells[9]["flagged"] and not game.cells[8]["revealed"], "A pending flag is insufficient even if correctly placed")
	game._commit_flags()
	_expect(game.cells[9]["committed"], "Manual Commit records a distinct committed-mine state")
	game.money = 3
	var before = game.cells.duplicate(true)
	var rng_before = game.rng.state
	game._dig(0)
	_expect(game.cells == before and game.money == 3 and game.direct_digs == 0 and game.hp == 10 and game.phase == "playing" and game.rng.state == rng_before, "Insufficient total gold leaves every tile, counter, HP, phase, and RNG unchanged")
	_expect(game.message.contains("필요 4 / 보유 3"), "Rejected chord explains required and available gold")
	game.money = 4
	game._dig(0)
	_expect(game.cells[1]["revealed"] and game.cells[8]["revealed"] and game.money == 0 and game.direct_digs == 2, "Exact total funds open both remaining neighbors and charge each direct dig")
	_expect(not game.cells[2]["revealed"] and not game.cells[16]["revealed"], "Chord never recursively activates newly revealed neighboring numbers")
	game._dig(0)
	_expect(game.money == 0 and game.direct_digs == 2, "Repeating a completed chord is free and does nothing")

	_fixture()
	game._dig(9)
	game.money = 100
	game._dig(0)
	_expect(game.direct_digs == 3 and game.money == 96 and game.hp == 8 and not game.cells[9]["committed"], "An exploded mine permits chord without repeat damage or a fake Commit reward")
	_fixture(["safe_dig"])
	game._use_active("safe_dig", 9)
	game._dig(0)
	_expect(game.direct_digs == 2 and not game.cells[9]["committed"] and game.money == 96 and game.hp == 10, "Rewardless safe confirmation also permits chord without becoming a rewarded Commit")
	_fixture([], [1, 9, 63])
	game.cells[0]["adjacent"] = 2
	_commit(9)
	game._dig(1)
	var mixed_info = game._chord_info(0)
	_expect(mixed_info["confirmed"] == 2 and mixed_info["committed"] == 1 and mixed_info["eligible"], "A Commit plus an exploded mine jointly satisfy a number-two clue")
	game._dig(0)
	_expect(game.cells[8]["revealed"] and game.direct_digs == 2 and game.money == 96 and game.hp == 8, "Mixed confirmation chord only charges for remaining safe neighbors")
	_fixture()
	game._dig(9)
	game.money = 3
	var exploded_before = game.cells.duplicate(true)
	game._dig(0)
	_expect(game.cells == exploded_before and game.money == 3 and game.hp == 8 and game.direct_digs == 1, "Exploded-mine eligibility still requires the entire batch budget before any dig")
	game.money = 4
	game._dig(0)
	_expect(game.money == 0 and game.direct_digs == 3 and game.hp == 8, "Exact funds work after explosion while the mine remains harmless and unpaid")
	_fixture(["hound"])
	game._use_active("hound")
	game.money = 100
	game._dig(0)
	_expect(game.cells[9]["committed"] and game.direct_digs == 2 and game.money == 96, "Automatic Commit from hound also permits neighbor digging")
	_fixture(["domain"])
	game._use_active("domain", 18)
	game.money = 100
	game._dig(0)
	_expect(game.cells[9]["committed"] and game.cells[1]["revealed"] and game.cells[8]["revealed"], "Domain Commit is recognized for neighboring number clicks")

	_fixture([], [1, 9, 63])
	game.cells[0]["adjacent"] = 2
	_commit()
	game._toggle_flag(1)
	game._dig(0)
	_expect(game.direct_digs == 0 and not game.cells[8]["revealed"], "Partially committed number-two neighborhood remains blocked")
	game._commit_flags()
	game.money = 100
	game._dig(0)
	_expect(game.direct_digs == 1 and game.cells[8]["revealed"] and game.money == 98, "Committing every required mine unlocks the remaining safe neighbor")

	_fixture()
	_commit()
	game._toggle_flag(1)
	_expect(game._chord_info(0)["targets"] == [8] and game._chord_info(0)["cost"] == 2, "Pending safe flags are excluded from both target list and price")
	game._dig(0)
	_expect(game.cells[1]["flagged"] and not game.cells[1]["revealed"] and game.cells[8]["revealed"] and game.money == 98, "Chord preserves flagged cells while digging eligible neighbors")

	_fixture(["dig_tax"])
	_commit()
	game.money = 5
	game._dig(0)
	_expect(game.direct_digs == 0 and game.money == 5, "Total-gold check includes the dig-tax modifier for every target")
	game.money = 6
	game._dig(0)
	_expect(game.direct_digs == 2 and game.money == 0, "Taxed chord charges the actual cost per dug tile")
	_fixture(["frugal"])
	_commit()
	game.direct_digs = 2
	game.money = 1
	game._dig(0)
	_expect(game.direct_digs == 2 and game.money == 1 and not game.cells[1]["revealed"], "Cannot spend a remaining free dig on a partially affordable batch")
	game.money = 2
	game._dig(0)
	_expect(game.direct_digs == 4 and game.money == 0, "Frugal free digs are included in the total batch quote")
	_fixture(["acceleration"])
	_commit()
	game._use_active("acceleration")
	game.accelerated_digs = 1
	game.money = 1
	game._dig(0)
	_expect(game.direct_digs == 0 and game.accelerated_digs == 1 and game.money == 1, "Rejected chord preserves acceleration uses")
	game.money = 2
	game._dig(0)
	_expect(game.direct_digs == 2 and game.accelerated_digs == 0 and game.money == 0, "Acceleration can cover part of an otherwise affordable chord")
	_fixture(["frugal", "acceleration"], [0, 63])
	game.cells[0]["revealed"] = false
	game.cells[9]["revealed"] = true
	_commit(0)
	game._use_active("acceleration")
	_expect(game._chord_info(9)["targets"].size() == 7 and game._chord_info(9)["cost"] == 6, "Overlapping free effects are not double-counted when pricing seven targets")
	game._dig(9)
	_expect(game.direct_digs == 7 and game.money == 94, "Free-effect overlap matches actual chord charges")

	_fixture()
	_commit()
	for cell in game.cells:
		if not cell["mine"]:
			cell["adjacent"] = 0
	game.cells[0]["adjacent"] = 1
	game.money = 2
	game._dig(0)
	_expect(game.direct_digs == 0 and not game.cells[1]["revealed"], "Preflight does not assume a future flood will make the rest affordable")
	game.money = 4
	game._dig(0)
	_expect(game.direct_digs == 1 and game.money == 2 and game.phase == "augment", "Flood-opened targets are not charged twice, and clear stops the batch")
	_fixture(["echo"])
	_commit()
	for i in range(game.cells.size()):
		if not game.cells[i]["mine"] and i not in [1, 8]:
			game.cells[i]["revealed"] = true
	game._dig(0)
	_expect(game.direct_digs == 1 and game.echo_uses == 1 and game.money == 98 and game.phase == "augment", "Echo can reveal a later target without recursive chord or duplicate charge")

	_fixture(["unstable_ground"])
	_commit()
	game.direct_digs = 5
	game.hp = 1
	game._dig(0)
	_expect(game.phase == "gameover" and game.direct_digs == 6 and game.money == 98 and not game.cells[8]["revealed"], "Lethal sixth-dig ground damage stops remaining chord targets")
	_fixture(["unstable_ground", "regeneration", "revival"])
	_commit()
	game.direct_digs = 5
	game.hp = 1
	game._dig(0)
	_expect(game.phase == "playing" and game.hp == 5 and game.revival_used and game.direct_digs == 7 and game.money == 96, "Chord preserves normal damage-revival-regeneration ordering per direct dig")

	_fixture(["stealth"], [1, 9, 63])
	game.cells[1]["stealth"] = true
	_commit()
	game._dig(0)
	_expect(game.cells[1]["revealed"] and game.hp == 8 and game.money == 96, "Uncommitted stealth remains a direct-dig risk rather than being secretly detected by chord")
	_fixture(["stealth"], [1, 9, 63])
	game.cells[1]["stealth"] = true
	_commit(1)
	_commit(9)
	_expect(game._chord_info(0)["committed"] == 1 and game._chord_info(0)["eligible"], "Committed stealth is not counted against a clue that excludes stealth")
	game._dig(0)
	_expect(game.direct_digs == 1 and game.hp == 10 and game.money == 98, "Already committed stealth is skipped safely")
	_fixture()
	_commit()
	game.cells[0]["obscured"] = true
	var hidden_clue = game._chord_info(0)
	game._dig(0)
	_expect(not hidden_clue["eligible"] and hidden_clue["required"] == 0 and game.direct_digs == 0 and game.money == 100, "Masked question-mark tiles cannot chord or leak their hidden clue through eligibility")

	_fixture()
	_commit()
	var locked = true
	for state in ["augment", "reward", "gameover", "victory"]:
		game.phase = state
		game._dig(0)
		locked = locked and game.money == 100 and game.direct_digs == 0
	_expect(locked, "All non-playing phases block chord input")
	_fixture()
	_commit()
	game.targeting = "scanner"
	game._chord(0)
	_expect(game.direct_digs == 0 and game.money == 100, "Active target selection cannot accidentally activate chord digging")
	_fixture()
	_commit()
	game.cells[0]["adjacent"] = 0
	game._dig(0)
	_expect(game.direct_digs == 0 and game.money == 100, "Blank zero tiles do not initiate number-tile chording")
	_fixture()
	_commit()
	game.stage = 10
	for i in range(game.cells.size()):
		if not game.cells[i]["mine"] and i not in [1, 8]:
			game.cells[i]["revealed"] = true
	game._dig(0)
	_expect(game.phase == "victory" and game.direct_digs == 2 and game.money == 96, "A final-stage chord can complete the run without any post-victory digging")
	print("Finished %d chord checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)
