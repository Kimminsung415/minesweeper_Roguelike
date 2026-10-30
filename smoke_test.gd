extends SceneTree

var game
var failures = 0
var checks = 0


func _initialize():
	call_deferred("_run")


func _expect(condition, description):
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.rng.seed = 71231

	# 첫 파기 안전성 및 연쇄 공개 단일 과금
	var before = game.money
	game._dig(0)
	_expect(not game.cells[0]["mine"], "First dig is safe")
	_expect(game.cells[0]["adjacent"] == 0, "First dig has safe neighbors")
	_expect(game.hp == 10, "First dig does not damage HP")
	_expect(game.money == before - 2, "Flood reveal costs only one dig")

	# 이미 공개된 칸은 과금하지 않는다.
	before = game.money
	game._dig(0)
	_expect(game.money == before, "Repeated reveal is free")

	# 미공개 지뢰를 찾아 정산한다.
	var mine_index = -1
	for i in range(game.cells.size()):
		if game.cells[i]["mine"]:
			mine_index = i
			break
	game._toggle_flag(mine_index)
	before = game.money
	game._commit_flags()
	_expect(game.money == before + game.mine_reward, "Correct flag pays reward")
	_expect(game.cells[mine_index]["settled"], "Correct mine becomes settled")
	before = game.money
	game._toggle_flag(mine_index)
	game._commit_flags()
	_expect(game.money == before, "Settled mine cannot pay twice")

	# 직접 파낸 지뢰의 피해와 중복 보상 방지
	var second_mine = -1
	for i in range(game.cells.size()):
		if game.cells[i]["mine"] and not game.cells[i]["settled"]:
			second_mine = i
			break
	var old_hp = game.hp
	game._dig(second_mine)
	_expect(game.hp == old_hp - 2, "Mine dig damages HP")
	before = game.money
	game._toggle_flag(second_mine)
	game._commit_flags()
	_expect(game.money == before, "Exploded mine cannot pay reward")

	# 통제된 안전 칸으로 잘못된 깃발 검사
	var safe_index = 0
	game.cells[safe_index]["revealed"] = false
	game.cells[safe_index]["flagged"] = true
	old_hp = game.hp
	game._commit_flags()
	_expect(game.hp == old_hp - 2, "Wrong flag deals base mine damage")
	_expect(game.cells[safe_index]["revealed"], "Wrong flag reveals safe tile")

	# 모든 안전 칸 공개 및 회복 보상
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game._finish_action()
	_expect(game.phase == "augment", "All safe tiles trigger mandatory augment choice")
	_pick_augment()
	game.hp = 5
	game._choose_reward("heal")
	_expect(game.stage == 2 and game.hp == 9, "Healing advances the stage")
	_expect(game.dig_cost == 4, "Dig cost grows with stage")

	# 재화 선택과 상태 전환 잠금
	game.phase = "augment"
	_pick_augment()
	before = game.money
	var expected_reward = game._cash_reward()
	game._choose_reward("money")
	_expect(game.money == before + expected_reward, "Cash choice pays once")
	var old_stage = game.stage
	game._choose_reward("money")
	_expect(game.stage == old_stage, "Repeated reward selection is blocked")

	# 클리어보다 사망을 먼저 판정
	game._generate_board(0)
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game.hp = 0
	game._finish_action()
	_expect(game.phase == "gameover", "Death takes priority over clear")
	_test_boundaries()

	print("Finished %d checks with %d failure(s)." % [checks, failures])
	quit(0 if failures == 0 else 1)


# A fixed two-mine board isolates accounting from random flood sizes.
func _pick_augment():
	# Isolate the pre-existing accounting tests from randomized choice modifiers.
	var id = "armor" if game.stage % 2 == 1 else "high_explosive"
	game.offered_augments = [id]
	game._choose_augment(id)


func _fixture():
	game._new_run()
	game.generated = true
	game.mine_count = 2
	for i in range(game.cells.size()):
		game.cells[i] = {"mine": i in [62, 63], "adjacent": 0, "revealed": false, "flagged": false, "settled": false}
	for i in range(game.cells.size()):
		for neighbor in game._neighbors(i):
			if game.cells[neighbor]["mine"]:
				game.cells[i]["adjacent"] += 1
	game._refresh()


func _test_boundaries():
	game._new_run()
	game._toggle_flag(0)
	game._dig(0)
	_expect(not game.generated and game.money == 30, "Flagged first dig neither generates nor charges")
	game._commit_flags()
	_expect(game.hp == 10 and game.cells[0]["flagged"], "Commit before generation is blocked")
	_expect(game.commit_button.disabled, "Commit UI is disabled before first dig")
	game._toggle_flag(0)
	game._toggle_flag(1)
	game.rng.seed = 31
	game._dig(0)
	_expect(not game.cells[1]["revealed"], "Flood preserves flagged safe cells")
	var actual_mines = 0
	for cell in game.cells:
		actual_mines += int(cell["mine"])
	_expect(actual_mines == 11, "Generation places exactly the stage mine count")

	_fixture()
	game._toggle_flag(0)
	game._toggle_flag(62)
	var before_money = game.money
	game._commit_flags()
	_expect(game.money == before_money + 4 and game.hp == 8, "Mixed Commit applies income and damage together")
	_expect(game.cells[0]["revealed"] and not game.cells[1]["revealed"], "Wrong zero flag reveals only its own cell")
	_expect(not game.cells[0]["flagged"] and not game.cells[62]["flagged"], "Commit clears processed flags")
	_expect(game.cells[54]["adjacent"] == 2, "Settled mine remains part of adjacent numbers")
	game._dig(62)
	_expect(game.money == before_money + 4 and game.hp == 8, "Settled mine cannot be dug or damaged")
	game._dig(63)
	var after_hp = game.hp
	var after_money = game.money
	game._dig(63)
	_expect(game.hp == after_hp and game.money == after_money, "Repeated exploded-mine dig is free and harmless")

	_fixture()
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	before_money = game.money
	game._finish_action()
	_expect(game.phase == "augment" and game.money == before_money, "Clear grants no automatic uncommitted mine income")
	_expect(game.choice_overlay.visible and game.commit_button.disabled, "Intermission UI locks Commit")
	game._toggle_flag(62)
	game._dig(62)
	game._commit_flags()
	_expect(not game.cells[62]["flagged"] and game.hp == 10 and game.money == before_money, "All board actions are locked during rewards")
	_pick_augment()
	game._choose_reward("invalid")
	_expect(game.phase == "reward" and game.stage == 1, "Invalid reward does not consume the choice")
	game.hp = 8
	game._choose_reward("heal")
	_expect(game.hp == 10 and game.money == before_money, "Healing caps at max and preserves money")
	_expect(game.board_width == 10 and game.board_height == 10 and game.mine_count == 19, "Stage two grows both board axes by two")
	_expect(not game.generated and game.phase == "playing" and not game.reward_panel.visible, "Next stage resets board and reward UI")
	game.phase = "augment"
	_pick_augment()
	game.hp = 6
	before_money = game.money
	game._choose_reward("money")
	_expect(game.stage == 3 and game.money == before_money + 42 and game.hp == 6, "Cash choice carries HP and funds six next-stage digs")
	_expect(game.board_width == 12 and game.board_height == 12 and game.dig_cost == 7, "Stage three grows both axes and raises dig cost")

	_fixture()
	game.money = 0
	game._check_bankruptcy()
	_expect(game.phase == "playing", "Zero money remains playable with uncommitted mines")
	game._toggle_flag(62)
	game._commit_flags()
	_expect(game.money == 4 and game.phase == "playing", "Free Commit restores spending power at zero money")
	_fixture()
	game.money = 0
	game.hp = 5
	for i in range(game.cells.size()):
		if game.cells[i]["mine"]:
			game.cells[i]["settled"] = true
		elif i > 1:
			game.cells[i]["revealed"] = true
	game._check_bankruptcy()
	_expect(game.phase == "playing", "HP-only completion is allowed when one HP will remain")
	game._toggle_flag(0)
	game._toggle_flag(1)
	game._commit_flags()
	_expect(game.phase == "augment" and game.hp == 1, "Two wrong flags can complete stage without money")
	_pick_augment()
	game._choose_reward("money")
	_expect(game.phase == "playing" and game.money == 24, "Cash reward rescues next stage from zero funds")
	_fixture()
	game.money = 0
	game.hp = 4
	for i in range(game.cells.size()):
		if game.cells[i]["mine"]:
			game.cells[i]["settled"] = true
		elif i > 1:
			game.cells[i]["revealed"] = true
	game._check_bankruptcy()
	_expect(game.phase == "gameover", "HP equal to remaining safe tiles cannot survive and is bankrupt")
	_expect(game.commit_button.disabled and game.abandon_button.disabled, "Direct bankruptcy refreshes UI immediately")
	game._new_run()
	game.money = 0
	game._check_bankruptcy()
	_expect(game.phase == "gameover", "Unfunded first dig is bankrupt")

	_fixture()
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game.cells[0]["revealed"] = false
	game.hp = 1
	game._toggle_flag(0)
	game._toggle_flag(62)
	before_money = game.money
	game._commit_flags()
	_expect(game.phase == "gameover" and game.hp == 0, "Lethal last-safe Commit loses before rewarding stage clear")
	_expect(game.money == before_money + 4, "Lethal mixed Commit still accounts for all correct flags")
	game._toggle_flag(63)
	game._choose_reward("money")
	_expect(not game.cells[63]["flagged"] and game.stage == 1, "Game-over blocks flag and reward mutations")
	game._new_run()
	_expect(game.hp == 10 and game.money == 30 and game.stage == 1 and not game.generated, "New run resets all resources and generation")
	game._abandon()
	_expect(game.phase == "gameover", "Abandon ends the active run")
	game._new_run()
	game.stage = 10
	game.money = 1000
	game._start_stage()
	_expect(game.board_width == 26 and game.board_height == 26 and game.mine_count == 169, "Stage ten grows beyond the old board caps at 25 percent density")
	_expect(game.dig_cost == 40 and game.mine_reward == 80, "Late-stage cost rises while reward remains two digs")
	game.rng.seed = 100
	game._dig(161)
	_expect(game.cells[161]["adjacent"] == 0 and game.hp == 10, "High-density first click still has safe neighbors")

	# Resource-sensitive reward warning must use the same cost as the next board.
	_fixture()
	for cell in game.cells:
		if not cell["mine"]:
			cell["revealed"] = true
	game.money = 3
	game._finish_action()
	_pick_augment()
	_expect(game.reward_hint.text.contains("파산"), "Heal preview warns when three gold cannot pay stage-two cost of four")
	game._choose_reward("heal")
	_expect(game.phase == "gameover" and game.stage == 2 and game.money == 3, "Unfunded heal choice uses the actual new-stage cost")

	var previous = game.StageRules.for_stage(1)
	var growth_ok = true
	var density_ok = true
	var cost_ok = true
	for number in range(2, 31):
		var current = game.StageRules.for_stage(number)
		growth_ok = growth_ok and current["width"] == previous["width"] + 2 and current["height"] == previous["height"] + 2
		density_ok = density_ok and current["mines"] > previous["mines"] and current["mines"] <= floori(current["width"] * current["height"] * 0.25)
		cost_ok = cost_ok and current["dig_cost"] > previous["dig_cost"] and current["mine_reward"] == current["dig_cost"] * 2
		previous = current
	_expect(growth_ok, "Every stage through thirty adds two rows and two columns without an old-size cap")
	_expect(density_ok, "Mine population grows with area and respects the density ceiling")
	_expect(cost_ok, "Dig cost grows every stage without restoring the old four-dig reward")
