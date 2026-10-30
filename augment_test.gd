extends SceneTree

const Model = preload("res://run_model.gd")
const Catalog = preload("res://augments.gd")
var game
var failures = 0
var checks = 0

func _initialize():
	call_deferred("_run")

func _expect(condition, description: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

# Synthetic numbered cells avoid flood randomness when testing action accounting.
func _fixture(ids: Array = [], mines: Array = [9, 10, 18]):
	game._new_run()
	game.owned_augments = ids.duplicate()
	game._start_stage()
	game.money = 100
	game.generated = true
	game.mine_count = mines.size()
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in mines, "stealth": false, "adjacent": 1, "revealed": false, "flagged": false, "settled": false, "obscured": false}

func _revealed_count() -> int:
	return game.cells.size() - game.mine_count - game._hidden_safe().size()

func _flag(indices: Array):
	for index in indices:
		game._toggle_flag(index)

func _clear_fixture():
	game.generated = true
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game._finish_action()

func _fuse_seed(draws: int) -> Dictionary:
	var probe = RandomNumberGenerator.new()
	for value in range(100):
		probe.seed = value
		var hits = 0
		for i in range(draws):
			hits += int(probe.randf() < 0.20)
		if hits > 0:
			return {"seed": value, "hits": hits}
	return {}

func _run():
	game = Model.new()
	root.add_child(game)
	_test_actives()
	_test_passives()
	_test_debuffs()
	_test_choices_and_survival()
	print("Finished %d augment checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_actives():
	_expect(Catalog.pool("active", []).size() == 13 and Catalog.pool("passive", []).size() == 13 and Catalog.pool("debuff", []).size() == 12, "Catalog contains thirteen actives, thirteen passives, twelve debuffs")
	var locked = true
	for id in Catalog.pool("active", []):
		_fixture([id])
		game.generated = false
		game._use_active(id, 0)
		locked = locked and game.used_actives.is_empty() and game.money == 100 and _revealed_count() == 0
	_expect(locked, "Every active is locked before first board generation")

	_fixture(["domain"])
	game.cells[3]["adjacent"] = 0
	game._use_active("domain", 9)
	_expect(_revealed_count() == 6 and not game.cells[3]["revealed"], "Domain reveals only safe cells inside its three-by-three region")
	_expect(game.money == 112 and game.hp == 10 and game._unsettled_mines().is_empty(), "Domain settles all three region mines without direct explosion damage")
	_expect(game.direct_digs == 0 and game.used_actives == ["domain"], "Domain consumes one active use, no direct dig")
	game._use_active("domain", 20)
	_expect(game.money == 112 and _revealed_count() == 6, "Repeated Domain cannot reveal or pay twice")
	_fixture(["domain", "artisan"])
	game._use_active("domain", 9)
	_expect(game.money == 116 and game.last_commit["bonus"] == 4, "Clean three-mine automatic Commit can trigger artisan bonus")
	_fixture(["domain", "fuse"])
	var roll = _fuse_seed(3)
	game.rng.seed = roll["seed"]
	game._use_active("domain", 9)
	_expect(game.hp == 10 - roll["hits"] and game.money == 112, "Domain automatic Commit applies each fuse roll while paying full income")

	_fixture(["hound"])
	game._use_active("hound")
	_expect(game._unsettled_mines().size() == 1 and game.money == 108, "Hound settles exactly two available mines")
	game._use_active("hound")
	_expect(game._unsettled_mines().size() == 1 and game.money == 108, "Hound cannot be reused this stage")
	_fixture(["hound", "stealth"], [9])
	game.cells[9]["stealth"] = true
	game._use_active("hound")
	_expect(game.cells[9]["settled"] and game.money == 104, "Hound finds stealth and handles fewer than two remaining mines")
	var hound_fuse = false
	for seed_number in range(20):
		_fixture(["hound", "fuse"])
		game.rng.seed = seed_number
		game._use_active("hound")
		if game.last_commit["fuse_damage"] > 0:
			hound_fuse = game.hp == 10 - game.last_commit["fuse_damage"] and game.money == 108
			break
	_expect(hound_fuse, "Hound automatic Commit also applies unstable fuse")

	_fixture(["scanner"], [9, 10, 18, 63])
	game.cells[18]["stealth"] = true
	game.cells[9]["settled"] = true
	game._use_active("scanner", 9)
	_expect(game.scan_result["count"] == 2, "Scanner counts unsettled normal and stealth mines, excluding settled mines")
	_expect(_revealed_count() == 0 and game.money == 100 and game.direct_digs == 0 and not game.cells[10]["settled"], "Scanner reports only a count and does not reveal, settle, or charge")
	_fixture(["safe_dig", "fuse", "artisan"])
	game._use_active("safe_dig", 9)
	_expect(game.cells[9]["settled"] and game.hp == 10 and game.money == 100 and game.last_commit.is_empty(), "Safe excavation confirms a mine without pay, damage, or Commit side effects")
	_fixture(["safe_dig", "echo"], [63])
	game.cells[0]["adjacent"] = 0
	game._use_active("safe_dig", 0)
	_expect(_revealed_count() == 4 and game.direct_digs == 0 and game.echo_uses == 0, "Safe active can flood but never counts as direct digging or triggers echo")
	_fixture(["safe_dig"])
	game.cells[0]["revealed"] = true
	game._use_active("safe_dig", 0)
	game._use_active("safe_dig", -1)
	_expect(game.used_actives.is_empty(), "Invalid or already revealed active targets preserve their use")

	_fixture(["survey", "echo"])
	for cell in game.cells:
		cell["adjacent"] = 0
	game._use_active("survey")
	_expect(_revealed_count() == 3 and game.echo_uses == 0 and game.direct_digs == 0 and game.money == 100, "Survey opens exactly three safe cells without flood, echo, or direct count")
	_fixture(["shield"])
	game._use_active("shield")
	game._dig(9)
	_expect(game.hp == 10 and game.money == 98 and not game.shield_ready, "Blast stance blocks next direct mine damage but charges the dig")
	game._dig(10)
	_expect(game.hp == 8, "Blast stance does not protect a second mine")
	_fixture(["shield"])
	game._use_active("shield")
	_flag([0])
	game._dig(0)
	_expect(game.shield_ready and game.direct_digs == 0, "Invalid flagged dig does not consume blast stance")
	_flag([0])
	game._dig(0)
	_expect(not game.shield_ready, "A valid safe direct dig consumes next-dig blast stance")

	_fixture(["transfusion"])
	game._use_active("transfusion")
	_expect(game.used_actives.is_empty(), "Full-health transfusion preserves the use")
	game.hp = 8
	game._use_active("transfusion")
	_expect(game.hp == 10 and game.money == 100, "Transfusion heals three with max-HP cap and no cost")
	_fixture(["grant", "dig_tax"])
	game.money = 0
	game._check_bankruptcy()
	game._use_active("grant")
	_expect(game.money == 12 and game.phase == "playing", "Emergency grant rescues zero funds using four taxed dig costs")
	_fixture(["audit"])
	_flag([0, 1, 2, 3, 9])
	game._use_active("audit")
	_expect(game._pending_flags().size() == 2 and game.cells[9]["flagged"] and _revealed_count() == 0 and game.hp == 10 and game.money == 100, "Flag audit removes at most three wrong flags, preserving correct flag and all tiles")
	_fixture(["audit"])
	_flag([9])
	game._use_active("audit")
	_expect(game.used_actives.is_empty() and game.cells[9]["flagged"], "Audit with no wrong flags preserves the use")
	_fixture(["acceleration"])
	game._use_active("acceleration")
	_flag([0])
	game._dig(0)
	_expect(game.accelerated_digs == 4 and game.direct_digs == 0, "Invalid dig does not consume free acceleration")
	_flag([0])
	for index in range(4):
		game._dig(index)
	_expect(game.money == 100 and game.direct_digs == 4 and game.accelerated_digs == 0, "Acceleration makes four valid direct digs free and counts them normally")
	game._dig(4)
	_expect(game.money == 98, "Fifth accelerated-sequence dig pays normally")

func _test_passives():
	_fixture(["shock"])
	game.hp = 8
	game._dig(9)
	_expect(game.hp == 9, "Shock absorption heals three after nonlethal first mine damage")
	game._dig(10)
	_expect(game.hp == 7, "Shock absorption triggers only once per stage")
	_fixture(["shock"])
	game.hp = 1
	game._dig(9)
	_expect(game.phase == "gameover" and game.hp == 0, "Shock absorption alone cannot prevent lethal damage")
	_fixture(["shock", "revival"])
	game.hp = 1
	game._dig(9)
	_expect(game.hp == 7 and game.revival_used and game.phase == "playing", "Revival resolves before surviving shock-absorption healing")
	_fixture(["dividend"])
	game._dig(9)
	_expect(game.money == 196, "Explosion dividend doubles remaining gold after first paid mine dig")
	game._dig(10)
	_expect(game.money == 194, "Explosion dividend is not repeated on another mine")
	_fixture(["dividend"])
	game.hp = 1
	game._dig(9)
	_expect(game.money == 98 and game.phase == "gameover", "Lethal explosion does not pay survivor dividend")
	_fixture(["dividend", "salvage"])
	game._dig(9)
	_expect(game.money == 200, "Salvage is included before survivor dividend doubles gold")
	_fixture(["dividend", "shield"])
	game._use_active("shield")
	game._dig(9)
	_expect(game.hp == 10 and game.money == 196, "Protected first mine explosion can still pay dividend")

	_fixture(["regeneration"])
	game.hp = 5
	for index in range(6):
		game._dig(index)
	_expect(game.hp == 6 and game.direct_digs == 6 and game.money == 88, "Regeneration heals on sixth valid direct dig")
	_fixture(["regeneration", "unstable_ground"])
	game.hp = 1
	for index in range(6):
		game._dig(index)
	_expect(game.hp == 0 and game.phase == "gameover", "Regeneration does not heal through lethal sixth-dig ground damage")
	_fixture(["regeneration", "unstable_ground", "revival"])
	game.hp = 1
	for index in range(6):
		game._dig(index)
	_expect(game.hp == 5 and game.revival_used, "Sixth-dig ground damage revives first, then applies survivor regeneration")
	_fixture(["revival"])
	game._apply_damage(100)
	_expect(game.hp == 4 and game.revival_used, "Revival resolves lethal damage once per run")
	game.hp = 5
	game.stage = 2
	game._start_stage()
	game._apply_damage(100)
	_expect(game.hp == 0 and game.revival_used, "Changing stages does not reset a consumed revival")
	_fixture(["revival"])
	game.max_hp = 2
	game._apply_damage(100)
	_expect(game.hp == 2, "Revival respects an unusually low max HP")

	_fixture(["echo"])
	for i in range(4):
		game._dig(game._hidden_safe()[0])
	_expect(_revealed_count() == 8 and game.echo_uses == 4 and game.direct_digs == 4, "Echo adds exactly four nonrecursive safe reveals across four direct digs")
	game._dig(game._hidden_safe()[0])
	_expect(_revealed_count() == 9 and game.echo_uses == 4, "Fifth direct dig cannot trigger an exhausted echo")
	_fixture(["decontamination"])
	_expect(game._rules_for(2)["mines"] == 17, "Decontamination removes two generated mines from next stage")
	_fixture(["decontamination", "overcrowding"])
	_expect(game._rules_for(2)["mines"] == 20, "Decontamination and overcrowding combine before the density cap")
	_fixture(["armor"])
	game._dig(9)
	_expect(game.hp == 9, "Armor reduces direct mine damage to minimum one")
	_flag([0])
	game._commit_flags()
	_expect(game.hp == 7, "Armor does not reduce wrong-flag damage")
	_fixture(["armor", "high_explosive"])
	game._dig(9)
	_expect(game.hp == 8, "Armor and high explosives combine to two direct mine damage")
	_fixture(["artisan"])
	_flag([9, 10, 18])
	game._commit_flags()
	_expect(game.money == 116 and game.last_commit["bonus"] == 4, "Artisan grants one extra mine reward for a clean three-mine Commit")
	_fixture(["artisan"])
	_flag([9, 10, 18, 0])
	game._commit_flags()
	_expect(game.money == 112 and game.hp == 8 and game.last_commit["bonus"] == 0, "A wrong flag prevents artisan bonus while correct mines still pay")

	_fixture(["frugal"])
	game.money = 0
	for index in range(3):
		game._dig(index)
	_expect(game.money == 0 and game.direct_digs == 3, "Frugal excavation grants three zero-cash direct digs")
	game._dig(3)
	_expect(game.direct_digs == 3, "Fourth frugal dig requires payment and invalid attempt does not count")
	game.money = 2
	game._dig(3)
	_expect(game.money == 0 and game.direct_digs == 4, "Funded fourth frugal dig pays normally")
	game._new_run()
	game.owned_augments = ["frugal"]
	game.money = 0
	game._start_stage()
	game._dig(0)
	_expect(game.generated and game.money == 0 and game.phase == "playing", "Frugal can fund board generation before actives unlock")
	_fixture(["frugal", "acceleration"])
	game._use_active("acceleration")
	for index in range(4):
		game._dig(index)
	game._dig(4)
	_expect(game.money == 98 and game.accelerated_digs == 0, "Overlapping frugal and acceleration cover the same next digs rather than adding uses")
	_fixture(["salvage", "reward_cut"])
	game._dig(9)
	_expect(game.money == 99 and game.cells[9]["settled"], "Salvage floors half of reduced mine reward and locks the exploded mine")
	_flag([9])
	game._commit_flags()
	_expect(game.money == 99, "Salvaged mine can never pay again")

func _test_debuffs():
	game._new_run()
	game.owned_augments = ["stealth", "instrument"]
	game._start_stage()
	game.rng.seed = 82
	game._generate_board(27)
	var stealth = []
	var numbers = 0
	var obscured = 0
	var safe_zone = true
	var count_correct = true
	for index in game._area(27, 1):
		safe_zone = safe_zone and not game.cells[index]["mine"]
	for i in range(game.cells.size()):
		if game.cells[i]["stealth"]:
			stealth.append(i)
		var count = 0
		for neighbor in game._neighbors(i):
			count += int(game.cells[neighbor]["mine"] and not game.cells[neighbor]["stealth"])
		count_correct = count_correct and count == game.cells[i]["adjacent"]
		if not game.cells[i]["mine"] and game.cells[i]["adjacent"] > 0:
			numbers += 1
		if game.cells[i]["obscured"]:
			obscured += 1
	_expect(stealth.size() == 1 and game.stealth_count == 1 and safe_zone, "One advertised stealth mine is generated outside first-click safety zone")
	_expect(count_correct, "All adjacent clues exclude stealth mines, including around settled mines")
	_expect(obscured == floori(numbers * 0.10) and obscured > 0, "Instrument failure masks ten percent of numbered safe cells")
	_fixture(["stealth"], [9])
	game.cells[9]["stealth"] = true
	game._recount_neighbors()
	var opened = game._reveal_area(0)
	_expect(opened == 63 and not game.cells[9]["revealed"] and game.hp == 10, "Zero flood skips stealth without exploding it")
	game._dig(9)
	_expect(game.hp == 8 and game.cells[9]["revealed"], "Directly clicking stealth still causes normal mine damage")
	_fixture(["high_explosive"])
	game._dig(9)
	_expect(game.hp == 7, "High explosives increase direct mine damage to three")

	_fixture(["fuse"])
	_flag([9, 10, 18])
	var roll = _fuse_seed(3)
	game.rng.seed = roll["seed"]
	game._commit_flags()
	_expect(game.hp == 10 - roll["hits"] and game.money == 112, "Manual Commit applies independent twenty-percent fuse rolls per correct mine")
	_fixture(["fuse", "revival", "armor"])
	game.hp = 1
	_flag([9, 10, 18])
	game.rng.seed = roll["seed"]
	game._commit_flags()
	_expect(game.hp == 4 and game.revival_used and game.money == 112, "Lethal fuse can revive, armor does not negate it, and all income is retained")
	game._new_run()
	game.stage = 2
	game._start_stage()
	_clear_fixture()
	game.offered_augments = ["weakness"]
	game._choose_augment("weakness")
	_expect(game.max_hp == 10 and game.hp == 10 and not game._has("weakness"), "Selected weakness is pending and does not apply on the cleared stage")
	game._choose_reward("heal")
	_expect(game.stage == 3 and game.max_hp == 8 and game.hp == 8, "Weakness lowers and clamps HP only when entering next stage")
	_fixture(["overcrowding"])
	_expect(game._rules_for(2)["mines"] == 22 and game._rules_for(8)["mines"] == 121, "Overcrowding adds three mines but preserves twenty-five-percent density cap")
	game._new_run()
	game.owned_augments = ["overcrowding"]
	game._start_stage()
	game._dig(27)
	var safe_zone_ok = true
	for index in game._area(27, 1):
		safe_zone_ok = safe_zone_ok and not game.cells[index]["mine"]
	_expect(safe_zone_ok, "Overcrowding preserves the full first-click safe zone")
	_fixture(["dig_tax"])
	game._dig(0)
	_expect(game.money == 97 and game.mine_reward == 4, "Dig tax increases spending without increasing mine payouts")
	_expect(game._cash_reward() == 30, "Cash-choice preview uses six actual next-stage taxed costs")
	_fixture(["reward_cut"])
	game._use_active("hound")
	_flag([9])
	game._commit_flags()
	_expect(game.mine_reward == 3 and game.money == 103, "Reward cut floors mine payouts to seventy-five percent")
	_fixture(["interference"])
	_flag([9])
	game._commit_flags()
	_expect(game.money == 100 and game.cells[9]["flagged"] and not game.cells[9]["settled"], "Communication failure blocks one-flag manual Commit")
	_flag([10, 18])
	game._commit_flags()
	_expect(game.money == 112, "Three pending flags permit communication-limited Commit")
	_fixture(["interference"])
	for i in range(game.cells.size()):
		if i not in [0, 9]:
			game.cells[i]["revealed"] = true
	_flag([9])
	game._commit_flags()
	_expect(game.money == 104, "Fewer than three remaining hidden unsettled cells allow final one-flag Commit")
	_fixture(["interference", "hound"])
	game._use_active("hound")
	_expect(game.money == 108, "Communication threshold does not block automatic mine settlement")
	_fixture(["unstable_ground", "acceleration"])
	game._use_active("acceleration")
	for index in range(6):
		game._dig(index)
	_expect(game.hp == 9 and game.direct_digs == 6 and game.money == 96, "Sixth valid direct dig damages HP even when earlier digs were free")
	for index in [6, 7, 8, 11, 12, 13]:
		game._dig(index)
	_expect(game.hp == 8 and game.direct_digs == 12, "Unstable ground triggers again on twelfth direct dig")
	_fixture(["unstable_ground", "shield"])
	game.direct_digs = 5
	game._use_active("shield")
	game._dig(9)
	_expect(game.hp == 9, "Blast stance blocks mine damage but not same-action ground damage")

func _test_choices_and_survival():
	_fixture(["transfusion"])
	game.money = 0
	var hidden = [0, 1, 2, 3, 4]
	for i in range(game.cells.size()):
		if game.cells[i]["mine"]:
			game.cells[i]["settled"] = true
		elif i not in hidden:
			game.cells[i]["revealed"] = true
	game._check_bankruptcy()
	_expect(game.phase == "playing" and game.hp == 10, "Full-health unused transfusion preserves a future HP-spending route at zero cash")
	_flag([0, 1])
	game._commit_flags()
	game._use_active("transfusion")
	_expect(game.hp == 9 and game._hidden_safe().size() == 3, "Spend HP first, then transfuse to fund the remaining safe cells")
	_flag(game._hidden_safe())
	game._commit_flags()
	_expect(game.phase == "augment" and game.hp == 3, "Deferred full-health transfusion route can actually complete the board")
	_fixture(["grant"])
	game.money = 0
	for cell in game.cells:
		if cell["mine"]:
			cell["settled"] = true
	game._check_bankruptcy()
	_expect(game.phase == "playing", "Unused resource active prevents premature bankruptcy with no mine income")
	game._use_active("grant")
	_expect(game.money == 8 and game.phase == "playing", "Rescue active remains usable in zero-fund state")
	_fixture(["revival"])
	game.money = 0
	game.hp = 1
	for cell in game.cells:
		if cell["mine"]:
			cell["settled"] = true
		else:
			cell["flagged"] = true
	game._check_bankruptcy()
	_expect(game.phase == "playing", "Unused revival can still fund survival of an HP-only completion batch")
	game._commit_flags()
	_expect(game.phase == "augment" and game.hp == 4 and game.revival_used, "Whole wrong-flag completion batch revives before clear evaluation")
	_fixture(["domain", "revival"])
	game._use_active("domain", 9)
	game.revival_used = true
	game.direct_digs = 6
	game.echo_uses = 4
	game.accelerated_digs = 2
	game.shield_ready = true
	game.stage = 2
	game._start_stage()
	_expect(game.used_actives.is_empty() and game.direct_digs == 0 and game.echo_uses == 0 and game.accelerated_digs == 0 and not game.shield_ready, "All per-stage active and dig counters reset on entry")
	_expect(game.revival_used and game._has("domain") and game._has("revival"), "Run effects persist while consumed revival stays consumed")
	game._new_run()
	_expect(game.owned_augments.is_empty() and not game.revival_used and game.max_hp == 10, "New run removes every acquired effect and lifetime-use marker")

	for run_seed in [3, 27, 102]:
		game._new_run()
		game.rng.seed = run_seed
		for number in range(1, 11):
			game.money = 10000
			game.hp = game.max_hp
			_clear_fixture()
			if number == 10:
				_expect(game.phase == "victory" and game.stage == 10 and game.offered_augments.is_empty(), "Stage ten ends immediately in victory without another choice (seed %d)" % run_seed)
				var previous_gold = game.money
				game._choose_reward("money")
				game._use_active("grant")
				_expect(game.money == previous_gold and game.stage == 10, "Victory blocks further reward and active actions (seed %d)" % run_seed)
				break
			var offers = game.offered_augments.duplicate()
			var offer_count = 3 if number % 2 == 1 else 2
			var legal = offers.size() == offer_count
			var unique = {}
			var kinds = {}
			for id in offers:
				unique[id] = true
				kinds[Catalog.ALL[id]["kind"]] = true
				legal = legal and id not in game.owned_augments
				legal = legal and (Catalog.ALL[id]["kind"] == Catalog.DEBUFF if number % 2 == 0 else Catalog.ALL[id]["kind"] != Catalog.DEBUFF)
			if number % 2 == 1:
				legal = legal and kinds.has(Catalog.ACTIVE) and kinds.has(Catalog.PASSIVE)
			_expect(legal and unique.size() == offer_count, "Stage %d offers %d distinct unowned effects, mixing active/passive on odd stages (seed %d)" % [number, offer_count, run_seed])
			game._choose_reward("money")
			_expect(game.stage == number and game.phase == "augment", "Resource reward cannot skip mandatory augment at stage %d (seed %d)" % [number, run_seed])
			game._choose_augment("invalid")
			_expect(game.phase == "augment", "Invalid effect cannot advance intermission")
			var selected = offers[0]
			game._choose_augment(selected)
			_expect(not game._has(selected) and game.phase == "reward", "Acquisition stays pending until resource reward confirms next stage")
			game._choose_augment(offers[1])
			game._choose_reward("money")
			_expect(game.stage == number + 1 and game._has(selected) and game.pending_augment.is_empty(), "Exactly one acquisition activates on next-stage entry")
		var buffs = 0
		var debuffs = 0
		for id in game.owned_augments:
			if Catalog.ALL[id]["kind"] == Catalog.DEBUFF:
				debuffs += 1
			else:
				buffs += 1
		_expect(buffs == 5 and debuffs == 4 and game.owned_augments.size() == 9, "Final stage has exactly five buffs and four debuffs (seed %d)" % run_seed)
