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

func _fixture(ids: Array = []):
	game._new_run()
	game.owned_augments = ids.duplicate()
	game._start_stage()
	game.generated = true
	game.money = 100
	game.mine_count = 4
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in [9, 10, 18, 63], "stealth": i == 63, "adjacent": 1, "revealed": false, "flagged": false, "settled": false, "committed": false, "obscured": false}

func _roll_seed(success: bool) -> int:
	var probe = RandomNumberGenerator.new()
	for seed_value in range(100000):
		probe.seed = seed_value
		if (probe.randf() < game._ticket_chance()) == success:
			return seed_value
	return -1

func _run():
	game = load("res://run_model.gd").new()
	root.add_child(game)
	_fixture(["vitality", "heart", "weakness", "healing_loss"])
	_expect(game.max_hp == 11, "Heart and weakness combine to base max HP eleven")
	game.hp = 7
	game._use_active("vitality")
	_expect(game.max_hp == 13 and game.hp == 9 and game.vitality_bonus == 2, "Vitality increases current and max HP by two despite healing loss")
	game._use_active("vitality")
	_expect(game.max_hp == 13 and game.hp == 9, "Vitality cannot be reused in one stage")
	game.hp = 13
	game.stage = 2
	game._start_stage()
	_expect(game.max_hp == 11 and game.hp == 11 and game.vitality_bonus == 0, "Temporary maximum expires and current HP clamps on stage change")
	_fixture(["blood_trade", "armor", "high_explosive"])
	game.hp = 3
	game._use_active("blood_trade")
	_expect(game.hp == 1 and game.money == 112 and "blood_trade" in game.used_actives, "Blood trade spends exactly two HP and grants six digs of gold")
	_fixture(["blood_trade"])
	game.hp = 2
	game._use_active("blood_trade")
	_expect(game.hp == 2 and game.money == 100 and game.used_actives.is_empty(), "Blood trade at two HP is unavailable and free of side effects")
	_fixture(["insurance", "high_explosive", "armor"])
	_expect(game._mine_damage() == 2 and game._wrong_flag_damage() == 3, "Wrong Commit includes high explosives and ignores armor")
	game._use_active("insurance")
	game._settle_mines([9])
	_expect(game.insurance_ready, "Automatic Commit does not consume manual insurance")
	game._toggle_flag(0)
	game._commit_flags()
	_expect(game.hp == 8 and not game.insurance_ready and game.last_commit["wrong_damage"] == 2, "Insurance halves total wrong damage with upward rounding")
	game._toggle_flag(1)
	game._commit_flags()
	_expect(game.hp == 5, "Subsequent wrong Commit takes full explosive damage")
	_fixture(["insurance"])
	game._use_active("insurance")
	game._commit_flags()
	_expect(game.insurance_ready, "Empty Commit does not consume insurance")
	game._toggle_flag(9)
	game._commit_flags()
	_expect(not game.insurance_ready and game.hp == 10, "Valid clean manual Commit consumes insurance")
	_fixture(["healing_loss", "transfusion", "revival"])
	game.hp = 3
	game._use_active("transfusion")
	_expect(game.hp == 5, "Healing loss reduces transfusion from three to two")
	game._heal(1)
	_expect(game.hp == 6, "One-point recovery retains a minimum of one")
	game._apply_damage(100)
	_expect(game.hp == 4 and game.revival_used, "Revival bypasses healing loss")
	_fixture(["medic", "healing_loss"])
	game.hp = 5
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game._finish_action()
	_expect(game.hp == 6 and game.phase == "augment", "Medic heals once on clear before resource choice")
	game._finish_action()
	_expect(game.hp == 6, "Repeated clear handling does not heal again")
	game.offered_augments = ["heart"]
	game._choose_augment("heart")
	_expect(game.max_hp == 10 and not game._has("heart"), "Pending heart has no early max HP effect")
	game._choose_reward("heal")
	_expect(game.max_hp == 13 and game.hp == 12, "Reduced reward healing and first heart HP increase combine on entry")
	game.stage = 3
	game._start_stage()
	_expect(game.hp == 12 and game.max_hp == 13, "Heart does not repeatedly grant current HP each stage")
	_fixture(["reserve"])
	game.money = 0
	game.stage = 2
	game._start_stage()
	_expect(game.money == 12 and game.phase == "playing", "Reserve funds three current stage digs before bankruptcy checks")
	game.money = 1
	game._refresh()
	_expect(game.money == 1, "Reserve does not refill after spending mid-stage")
	_fixture(["settlement_fee", "artisan", "reward_cut"])
	game._settle_mines([9, 10, 18])
	_expect(game.money == 110 and game.last_commit["bonus"] == 3 and game.last_commit["fee"] == 2, "Fee applies once after reduced rewards and artisan bonus")
	game._settle_mines([9, 10, 18])
	_expect(game.money == 110 and game.last_commit["fee"] == 0, "Already settled mines neither pay again nor incur another fee")
	_fixture(["settlement_fee"])
	game.dig_cost = 10
	game._settle_mines([9])
	_expect(game.money == 100 and game.last_commit["earned"] == 0, "Settlement fee cannot make net reward negative")
	_fixture()
	_expect(game._ticket_cost() == 12 and is_equal_approx(game._ticket_chance(), 0.1), "Initial ticket costs six digs and has ten percent success")
	game.rng.seed = _roll_seed(false)
	game._buy_upgrade_ticket()
	_expect(game.money == 88 and game.expansion_level == 0 and game.ticket_purchases == 1 and game.shop_result.contains("실패"), "Failed ticket spends gold exactly once and leaves level unchanged")
	game.rng.seed = _roll_seed(true)
	game._buy_upgrade_ticket()
	_expect(game.money == 76 and game.expansion_level == 1 and game.ticket_purchases == 2, "Successful ticket spends gold and grants one stacking expansion level")
	_expect(game._ticket_cost() == 24 and is_equal_approx(game._ticket_chance(), 0.08), "Level one ticket costs twice as much and has eight percent success")
	game.rng.seed = _roll_seed(true)
	game._buy_upgrade_ticket()
	_expect(game.expansion_level == 2 and game.money == 52 and game._ticket_cost() == 48 and is_equal_approx(game._ticket_chance(), 0.064), "Further successes stack, double price, and reduce success chance")
	game.stage = 2
	game._start_stage()
	_expect(game.expansion_level == 2 and game.ticket_purchases == 3 and game._active_radius("domain") == 3, "Expansion and purchase history persist across stages")
	game._new_run()
	_expect(game.expansion_level == 0 and game.ticket_purchases == 0 and game.shop_result.is_empty(), "A new run resets shop upgrades and purchase history")
	_fixture()
	game.money = 11
	var before_rng = game.rng.state
	game._buy_upgrade_ticket()
	_expect(game.money == 11 and game.rng.state == before_rng and game.ticket_purchases == 0, "Unaffordable ticket changes neither gold nor RNG")
	for lock in ["augment", "reward", "victory", "gameover"]:
		_fixture()
		game.phase = lock
		before_rng = game.rng.state
		game._buy_upgrade_ticket()
		_expect(game.money == 100 and game.rng.state == before_rng, "Shop locked during " + lock)
	_fixture()
	game.generated = false
	game._buy_upgrade_ticket()
	_expect(game.money == 100 and game.ticket_purchases == 0, "Shop locked until board generation")
	game.generated = true
	game.targeting = "domain"
	game._buy_upgrade_ticket()
	_expect(game.money == 100 and game.ticket_purchases == 0, "Shop locked while selecting an active target")
	_fixture(["domain", "scanner", "safe_dig"])
	game.expansion_level = 1
	_expect(game._active_radius("domain") == 2 and game._active_radius("scanner") == 3 and game._active_radius("safe_dig") == 1, "Every spatial active grows one radius per level")
	game._use_active("scanner", 27)
	_expect(game.scan_result["indices"].size() == 49 and game.scan_result["count"] == 3, "Upgraded scanner inspects a seven by seven area")
	game._use_active("domain", 27)
	_expect(game.cells[9]["settled"] and game.cells[10]["settled"] and game.cells[18]["settled"] and not game.cells[63]["settled"] and game.direct_digs == 0, "Upgraded domain resolves five by five without outside effects")
	var used_before = game.used_actives.duplicate()
	game.rng.seed = _roll_seed(true)
	game._buy_upgrade_ticket()
	_expect(game.used_actives == used_before, "Ticket upgrade never recharges spent actives")
	_fixture(["safe_dig", "fuse", "echo"])
	game.expansion_level = 1
	game._use_active("safe_dig", 9)
	_expect(game.cells[9]["settled"] and game.cells[10]["settled"] and game.cells[18]["settled"] and game.cells[0]["revealed"] and not game.cells[63]["settled"] and game.hp == 10 and game.money == 100 and game.last_commit.is_empty() and game.echo_uses == 0 and game.direct_digs == 0, "Upgraded safe excavation resolves entire area without rewards, fuse, echo, or dig cost")
	_fixture(["domain"])
	game.expansion_level = 100
	_expect(game._area(0, game._active_radius("domain")).size() == 64 and game._ticket_cost() == game.MAX_TICKET_COST and game._ticket_chance() > 0, "High stacking clips area to board and saturates price without overflow")
	_fixture(["dig_tax"])
	game.stage = 10
	game._start_stage()
	var previous_cost = 0
	for level in range(8):
		game.expansion_level = level
		var cost = game._ticket_cost()
		_expect(cost == 246 * (1 << level) and (level == 0 or cost == previous_cost * 2), "Stage-ten taxed price doubles exactly at level %d" % level)
		previous_cost = cost
	_fixture()
	game.expansion_level = 1
	game.money = game._ticket_cost()
	game.rng.seed = _roll_seed(false)
	game._buy_upgrade_ticket()
	_expect(game.money == 0 and game.expansion_level == 1 and game._ticket_cost() == 24 and is_equal_approx(game._ticket_chance(), 0.08), "Exact funds buy one failed roll without changing price, chance, or level")
	_fixture(["instrument"])
	game.generated = false
	game._start_stage()
	game.rng.seed = 82
	game._generate_board(27)
	var numbers = 0
	var masked = 0
	for cell in game.cells:
		numbers += int(not cell["mine"] and cell["adjacent"] > 0)
		masked += int(cell["obscured"])
	_expect(masked == floori(numbers * 0.1), "Question marks cover exactly ten percent of numbered safe tiles rounded down")
	print("Finished %d shop and expansion checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)
