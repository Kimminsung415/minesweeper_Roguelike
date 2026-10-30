extends Control

const StageRules = preload("res://stage_rules.gd")
const Augments = preload("res://augments.gd")
const MAX_HP = 10
const START_MONEY = StageRules.START_MONEY
const MINE_DAMAGE = 2
const HEAL_REWARD = 4
const FINAL_STAGE = 10
const MAX_TICKET_COST = 1152921504606846976

var hp = MAX_HP
var max_hp = MAX_HP
var money = START_MONEY
var stage = 1
var board_width = 8
var board_height = 8
var mine_count = 11
var stealth_count = 0
var dig_cost = 2
var mine_reward = 4
var cells = []
var generated = false
var phase = "playing"
var rng = RandomNumberGenerator.new()
var message = ""
var owned_augments = []
var offered_augments = []
var pending_augment = ""
var used_actives = []
var targeting = ""
var scan_result = {}
var direct_digs = 0
var echo_uses = 0
var shield_ready = false
var accelerated_digs = 0
var shock_triggered = false
var first_explosion = false
var revival_used = false
var last_commit = {}
var expansion_level = 0
var ticket_purchases = 0
var shop_result = ""
var ticket_pending = {}
var vitality_bonus = 0
var insurance_ready = false
var clear_heal_applied = false


func _has(id: String) -> bool:
	return id in owned_augments


func _rules_for(number: int, with_pending: bool = false) -> Dictionary:
	var rules = StageRules.for_stage(number)
	var effective = owned_augments.duplicate()
	if with_pending and not pending_augment.is_empty():
		effective.append(pending_augment)
	var delta = (-2 if "decontamination" in effective else 0) + (3 if "overcrowding" in effective else 0)
	var capacity = mini(floori(rules["width"] * rules["height"] * StageRules.MAX_DENSITY), rules["width"] * rules["height"] - 9)
	rules["mines"] = clampi(rules["mines"] + delta, 1, capacity)
	rules["stealth"] = 1 if "stealth" in effective else 0
	rules["max_hp"] = maxi(1, MAX_HP + (3 if "heart" in effective else 0) - (2 if "weakness" in effective else 0))
	rules["dig_cost"] += 1 if "dig_tax" in effective else 0
	if "reward_cut" in effective:
		rules["mine_reward"] = maxi(1, floori(rules["mine_reward"] * 0.75))
	return rules


func _new_run():
	owned_augments.clear()
	offered_augments.clear()
	pending_augment = ""
	revival_used = false
	expansion_level = 0
	ticket_purchases = 0
	shop_result = ""
	ticket_pending.clear()
	max_hp = MAX_HP
	hp = MAX_HP
	money = START_MONEY
	stage = 1
	_start_stage()


func _start_stage():
	ticket_pending.clear()
	var rules = _rules_for(stage)
	board_width = rules["width"]
	board_height = rules["height"]
	mine_count = rules["mines"]
	stealth_count = rules["stealth"]
	dig_cost = rules["dig_cost"]
	mine_reward = rules["mine_reward"]
	max_hp = rules["max_hp"]
	vitality_bonus = 0
	insurance_ready = false
	clear_heal_applied = false
	hp = mini(hp, max_hp)
	generated = false
	phase = "playing"
	used_actives.clear()
	offered_augments.clear()
	pending_augment = ""
	targeting = ""
	scan_result.clear()
	direct_digs = 0
	echo_uses = 0
	shield_ready = false
	accelerated_digs = 0
	shock_triggered = false
	first_explosion = false
	last_commit.clear()
	if _has("reserve"):
		money = maxi(money, dig_cost * 3)
	cells.clear()
	for i in range(board_width * board_height):
		cells.append({"mine": false, "stealth": false, "adjacent": 0, "revealed": false, "flagged": false, "settled": false, "committed": false, "obscured": false})
	_build_board_view()
	message = "스테이지 %d / 10\n첫 파기는 안전합니다. 액티브는 첫 파기 후 사용 가능.\n은신지뢰: %d개" % [stage, stealth_count]
	_check_bankruptcy()
	_refresh()


func _build_board_view():
	pass


func _refresh():
	pass


func _neighbors(index: int) -> Array:
	var result = []
	var x = index % board_width
	var y = int(index / board_width)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < board_width and ny >= 0 and ny < board_height:
				result.append(ny * board_width + nx)
	return result


func _area(index: int, radius: int) -> Array:
	var result = []
	var x = index % board_width
	var y = int(index / board_width)
	for ny in range(maxi(0, y - radius), mini(board_height, y + radius + 1)):
		for nx in range(maxi(0, x - radius), mini(board_width, x + radius + 1)):
			result.append(ny * board_width + nx)
	return result


func _shuffle(items: Array):
	for i in range(items.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp


func _generate_board(first_index: int):
	var excluded = _area(first_index, 1)
	var candidates = []
	for i in range(cells.size()):
		if i not in excluded:
			candidates.append(i)
	_shuffle(candidates)
	for i in range(mine_count):
		cells[candidates[i]]["mine"] = true
		cells[candidates[i]]["stealth"] = i < stealth_count
	_recount_neighbors()
	if _has("instrument"):
		var numbers = []
		for i in range(cells.size()):
			if not cells[i]["mine"] and cells[i]["adjacent"] > 0:
				numbers.append(i)
		_shuffle(numbers)
		for i in range(floori(numbers.size() * 0.10)):
			cells[numbers[i]]["obscured"] = true
	generated = true


func _recount_neighbors():
	for i in range(cells.size()):
		var count = 0
		for neighbor in _neighbors(i):
			if cells[neighbor]["mine"] and not cells[neighbor].get("stealth", false):
				count += 1
		cells[i]["adjacent"] = count


func _toggle_flag(index: int):
	if not ticket_pending.is_empty() or phase != "playing" or index < 0 or index >= cells.size():
		return
	var cell = cells[index]
	if cell["revealed"] or cell["settled"]:
		return
	cell["flagged"] = not cell["flagged"]
	_refresh()


func _effective_dig_cost() -> int:
	if accelerated_digs > 0 or (_has("frugal") and direct_digs < 3):
		return 0
	return dig_cost


func _chord_info(index: int) -> Dictionary:
	var result = {"eligible": false, "targets": [], "cost": 0, "committed": 0, "confirmed": 0, "required": 0, "reason": ""}
	if not ticket_pending.is_empty() or phase != "playing" or not generated or not targeting.is_empty() or index < 0 or index >= cells.size():
		return result
	var cell = cells[index]
	if not cell["revealed"] or cell["mine"] or cell["adjacent"] <= 0:
		return result
	if cell.get("obscured", false):
		result["reason"] = "? 타일은 숫자를 확인할 수 없어 주변 파기를 사용할 수 없습니다."
		return result
	result["required"] = cell["adjacent"]
	for neighbor in _neighbors(index):
		var other = cells[neighbor]
		# A publicly confirmed mine is enough: Commit, direct explosion, or
		# rewardless safe excavation. Pending flags never confirm a mine.
		if other["mine"] and (other["settled"] or other["revealed"]) and not other.get("stealth", false):
			result["confirmed"] += 1
			if other.get("committed", false):
				result["committed"] += 1
		if not other["revealed"] and not other["settled"] and not other["flagged"]:
			result["targets"].append(neighbor)
	if result["confirmed"] != result["required"]:
		result["reason"] = "주변 일반 지뢰를 먼저 확인하세요. (Commit·폭발·안전 확정 %d/%d)" % [result["confirmed"], result["required"]]
		return result
	if result["targets"].is_empty():
		result["reason"] = "주변에 파낼 미공개 칸이 없습니다. 깃발 칸은 제외됩니다."
		return result
	# Preflight every currently diggable neighbor. Never count future rewards,
	# reveals, or random echo results as funds already available to the player.
	for offset in range(result["targets"].size()):
		var free = accelerated_digs > offset or (_has("frugal") and direct_digs + offset < 3)
		if not free:
			result["cost"] += dig_cost
	result["eligible"] = true
	if money < result["cost"]:
		result["reason"] = "주변 %d칸을 모두 팔 골드가 부족합니다. 필요 %d / 보유 %d" % [result["targets"].size(), result["cost"], money]
	return result


func _chord(index: int):
	var info = _chord_info(index)
	if not info["eligible"] or money < info["cost"]:
		if not info["reason"].is_empty():
			message = info["reason"]
			_refresh()
		return
	var before_gold = money
	var before_hp = hp
	var before_digs = direct_digs
	for neighbor in info["targets"]:
		if phase != "playing":
			break
		var cell = cells[neighbor]
		# Flood/echo may already have opened later targets. Do not click a newly
		# revealed number recursively or charge for it a second time.
		if cell["revealed"] or cell["settled"] or cell["flagged"]:
			continue
		_dig(neighbor)
	message = "주변 파기: 직접 %d회 · 골드 %+d · HP %+d\n%s" % [direct_digs - before_digs, money - before_gold, hp - before_hp, message]
	_refresh()


func _mine_damage() -> int:
	return maxi(1, MINE_DAMAGE + (1 if _has("high_explosive") else 0) - (1 if _has("armor") else 0))


func _wrong_flag_damage() -> int:
	return MINE_DAMAGE + (1 if _has("high_explosive") else 0)


func _apply_damage(amount: int):
	if amount > 0 and hp > 0:
		_on_damage(amount)
	hp = maxi(0, hp - amount)
	if hp <= 0 and _has("revival") and not revival_used:
		revival_used = true
		hp = mini(max_hp, 4)
		message += "\n부활권 발동! HP %d" % hp


func _on_damage(_amount: int):
	pass


func _heal_amount(amount: int) -> int:
	return maxi(1, amount - (1 if _has("healing_loss") else 0)) if amount > 0 else 0


func _heal(amount: int):
	if hp > 0:
		hp = mini(max_hp, hp + _heal_amount(amount))


func _dig(index: int):
	if not ticket_pending.is_empty() or phase != "playing" or index < 0 or index >= cells.size():
		return
	var cell = cells[index]
	if cell["revealed"]:
		_chord(index)
		return
	if cell["flagged"] or cell["settled"]:
		return
	var cost = _effective_dig_cost()
	if money < cost:
		message = "파기 골드 부족. 깃발 정산 또는 남은 액티브를 활용하세요."
		_check_bankruptcy()
		_refresh()
		return
	if not generated:
		_generate_board(index)
	money -= cost
	direct_digs += 1
	if accelerated_digs > 0:
		accelerated_digs -= 1
	var protected = shield_ready
	shield_ready = false
	var mine_damage = 0
	var first_blast = false
	var first_hit = false
	var salvage = 0
	if cell["mine"]:
		cell["revealed"] = true
		cell["settled"] = true
		cell["committed"] = false
		mine_damage = 0 if protected else _mine_damage()
		first_blast = not first_explosion
		first_explosion = true
		first_hit = mine_damage > 0 and not shock_triggered
		if mine_damage > 0:
			shock_triggered = true
		if _has("salvage"):
			salvage = floori(mine_reward * 0.5)
			money += salvage
		message = "지뢰 폭발 · 파기 -%d골드\n지뢰 피해 %d · 잔해 수입 +%d" % [cost, mine_damage, salvage]
	else:
		var opened = _reveal_area(index)
		if _has("echo") and echo_uses < 4:
			var extra = _hidden_safe()
			_shuffle(extra)
			if not extra.is_empty():
				_reveal_one(extra[0])
				echo_uses += 1
				opened += 1
		message = "%d칸 공개 · 파기 -%d골드" % [opened, cost]
	var ground_damage = 1 if _has("unstable_ground") and direct_digs % 6 == 0 else 0
	if ground_damage > 0:
		message += "\n불안정 지반 -1 HP"
	# One action resolves all damage, then revival, then surviving heal/income effects.
	_apply_damage(mine_damage + ground_damage)
	if hp > 0:
		if first_hit and _has("shock"):
			_heal(3)
			message += "\n충격 흡수 +%d HP (최대 제한)" % _heal_amount(3)
		if _has("regeneration") and direct_digs % 6 == 0:
			_heal(1)
			message += "\n재생 세포 +1 HP (최대 제한)"
		if first_blast and _has("dividend"):
			money *= 2
			message += "\n폭발 배당! 보유 골드 2배"
	_finish_action()


func _reveal_one(index: int):
	if not cells[index]["mine"]:
		cells[index]["revealed"] = true
		cells[index]["flagged"] = false


func _reveal_area(start_index: int) -> int:
	var queue = [start_index]
	var cursor = 0
	var opened = 0
	while cursor < queue.size():
		var index = queue[cursor]
		cursor += 1
		var cell = cells[index]
		if cell["revealed"] or cell["flagged"] or cell["mine"]:
			continue
		cell["revealed"] = true
		opened += 1
		if cell["adjacent"] == 0:
			for neighbor in _neighbors(index):
				if not cells[neighbor]["revealed"] and not cells[neighbor]["flagged"] and not cells[neighbor]["mine"]:
					queue.append(neighbor)
	return opened


func _pending_flags() -> Array:
	var result = []
	for i in range(cells.size()):
		if cells[i]["flagged"] and not cells[i]["settled"] and not cells[i]["revealed"]:
			result.append(i)
	return result


func _communication_allows_commit() -> bool:
	if not _has("interference") or _pending_flags().size() >= 3:
		return true
	var hidden = 0
	for cell in cells:
		if not cell["revealed"] and not cell["settled"]:
			hidden += 1
	return hidden < 3


func _settle_mines(indices: Array, wrong: int = 0, manual: bool = false) -> Dictionary:
	var correct = 0
	var fuse_damage = 0
	for index in indices:
		var cell = cells[index]
		if not cell["mine"] or cell["settled"] or cell["revealed"]:
			continue
		cell["flagged"] = false
		cell["settled"] = true
		cell["committed"] = true
		correct += 1
		if _has("fuse") and rng.randf() < 0.20:
			fuse_damage += 1
	var bonus = mine_reward if _has("artisan") and correct >= 3 and wrong == 0 else 0
	var fee = mini(correct * mine_reward + bonus, dig_cost) if correct > 0 and _has("settlement_fee") else 0
	var earned = correct * mine_reward + bonus - fee
	money += earned
	var wrong_damage = wrong * _wrong_flag_damage()
	if manual and insurance_ready:
		wrong_damage = ceili(wrong_damage * 0.5)
		insurance_ready = false
	var damage = wrong_damage + fuse_damage
	message += "\n정답 %d · 오답 %d · +%d골드\n오답/신관 피해 %d (신관 %d)" % [correct, wrong, earned, damage, fuse_damage]
	if fee > 0:
		message += "\n정산 수수료 -%d골드 반영" % fee
	_apply_damage(damage)
	last_commit = {"correct": correct, "wrong": wrong, "earned": earned, "fuse_damage": fuse_damage, "bonus": bonus, "fee": fee, "wrong_damage": wrong_damage}
	return last_commit


func _commit_flags():
	if not ticket_pending.is_empty() or phase != "playing" or not generated:
		return
	if not _communication_allows_commit():
		message = "통신 장애: 미검증 깃발을 3개 이상 설치해야 수동 Commit 가능."
		_refresh()
		return
	var flags = _pending_flags()
	if flags.is_empty():
		message = "정산할 깃발이 없습니다."
		_refresh()
		return
	var mines = []
	var wrong = 0
	for index in flags:
		if cells[index]["mine"]:
			mines.append(index)
		else:
			_reveal_one(index)
			wrong += 1
	message = "COMMIT 정산"
	_settle_mines(mines, wrong, true)
	_finish_action()


func _hidden_safe() -> Array:
	var result = []
	for i in range(cells.size()):
		if not cells[i]["mine"] and not cells[i]["revealed"]:
			result.append(i)
	return result


func _unsettled_mines() -> Array:
	var result = []
	for i in range(cells.size()):
		if cells[i]["mine"] and not cells[i]["settled"] and not cells[i]["revealed"]:
			result.append(i)
	return result


func _active_available(id: String) -> bool:
	return ticket_pending.is_empty() and phase == "playing" and generated and hp > 0 and _has(id) and Augments.ALL.has(id) and Augments.ALL[id]["kind"] == Augments.ACTIVE and id not in used_actives and (id != "blood_trade" or hp >= 3)


func _active_radius(id: String) -> int:
	return {"domain": 1, "scanner": 2, "safe_dig": 0}.get(id, 0) + expansion_level


func _ticket_cost() -> int:
	var cost = clampi(dig_cost * 6, 1, MAX_TICKET_COST)
	for level in range(expansion_level):
		# Saturate before multiplication so very high levels cannot wrap negative.
		if cost >= MAX_TICKET_COST / 2:
			return MAX_TICKET_COST
		cost *= 2
	return cost


func _ticket_chance() -> float:
	return 0.10 * pow(0.8, expansion_level)


func _buy_upgrade_ticket():
	if _begin_upgrade_ticket():
		_resolve_upgrade_ticket()


func _begin_upgrade_ticket() -> bool:
	if not ticket_pending.is_empty() or phase != "playing" or not generated or hp <= 0 or not targeting.is_empty() or money < _ticket_cost():
		return false
	var cost = _ticket_cost()
	var chance = _ticket_chance()
	money -= cost
	ticket_purchases += 1
	# One charge and one real roll. The animation never consumes gameplay RNG.
	ticket_pending = {"success": rng.randf() < chance, "cost": cost, "chance": chance, "level": expansion_level}
	message = "영역 확장 강화 진행 중… · -%d골드" % cost
	_refresh()
	return true


func _resolve_upgrade_ticket():
	if ticket_pending.is_empty():
		return
	var result = ticket_pending.duplicate()
	ticket_pending.clear()
	var cost = result["cost"]
	if result["success"]:
		expansion_level += 1
		shop_result = "강화 성공! 영역 확장 Lv.%d · -%d골드" % [expansion_level, cost]
	else:
		shop_result = "강화 실패 · -%d골드 · 레벨 유지" % cost
	message = shop_result
	_finish_action()


func _use_active(id: String, target: int = -1):
	if not _active_available(id):
		return
	if Augments.ALL[id].get("target", false) and (target < 0 or target >= cells.size()):
		return
	if id == "safe_dig" and (cells[target]["revealed"] or cells[target]["settled"]):
		message = "안전 굴착: 미공개·미정산 칸을 선택하세요."
		_refresh()
		return
	var mines = _unsettled_mines()
	var safe = _hidden_safe()
	var wrong_flags = []
	for index in _pending_flags():
		if not cells[index]["mine"]:
			wrong_flags.append(index)
	if (id == "hound" and mines.is_empty()) or (id == "survey" and safe.is_empty()) or (id == "audit" and wrong_flags.is_empty()) or (id == "transfusion" and hp >= max_hp):
		message = "현재 적용할 대상이 없어 사용 횟수를 보존합니다."
		_refresh()
		return
	used_actives.append(id)
	targeting = ""
	message = Augments.ALL[id]["name"] + " 사용"
	match id:
		"domain":
			var area_mines = []
			for index in _area(target, _active_radius(id)):
				if cells[index]["mine"]:
					area_mines.append(index)
				else:
					_reveal_one(index)
			_settle_mines(area_mines)
		"hound":
			_shuffle(mines)
			_settle_mines(mines.slice(0, mini(2, mines.size())))
		"scanner":
			var indices = _area(target, _active_radius(id))
			var count = 0
			for index in indices:
				if index in mines:
					count += 1
			scan_result = {"indices": indices, "count": count, "center": target}
			var side = _active_radius(id) * 2 + 1
			message += "\n%d×%d 영역의 미확정 지뢰: %d개\n위치는 공개하지 않습니다." % [side, side, count]
		"safe_dig":
			# Expanded excavation fixes every mine first, then opens safe cells;
			# flood still skips all mines and no Commit side effects are triggered.
			var indices = _area(target, _active_radius(id))
			for index in indices:
				if cells[index]["settled"] or cells[index]["revealed"]:
					continue
				cells[index]["flagged"] = false
				if cells[index]["mine"]:
					cells[index]["settled"] = true
					cells[index]["committed"] = false
				else:
					_reveal_one(index)
			if not cells[target]["mine"]:
				# Preserve the original safe-cell flood behavior.
				cells[target]["revealed"] = false
				_reveal_area(target)
			message += "\n범위 내 지뢰 확정. 보상·피해 없음."
		"survey":
			_shuffle(safe)
			for index in safe.slice(0, mini(3, safe.size())):
				_reveal_one(index)
		"shield":
			shield_ready = true
		"transfusion":
			_heal(3)
		"grant":
			money += dig_cost * 4
		"audit":
			_shuffle(wrong_flags)
			for index in wrong_flags.slice(0, mini(3, wrong_flags.size())):
				cells[index]["flagged"] = false
		"acceleration":
			accelerated_digs = 4
		"vitality":
			vitality_bonus = 2
			max_hp += 2
			hp = mini(max_hp, hp + 2)
			message += "\n이번 스테이지 최대 HP +2 · 현재 HP +2"
		"blood_trade":
			_apply_damage(2)
			money += dig_cost * 6
		"insurance":
			insurance_ready = true
	_finish_action()


func _finish_action():
	if not ticket_pending.is_empty() or phase != "playing":
		return
	if hp <= 0:
		_game_over("체력이 모두 소진되었습니다.")
	elif _all_safe_revealed():
		if not clear_heal_applied:
			clear_heal_applied = true
			if _has("medic"):
				_heal(1)
				message += "\n야전 의무관: 클리어 회복 +1 HP"
		targeting = ""
		if stage >= FINAL_STAGE:
			phase = "victory"
			message += "\n10스테이지 최종 승리!"
		else:
			phase = "augment"
			if stage % 2 == 1:
				var actives = Augments.pool(Augments.ACTIVE, owned_augments)
				var passives = Augments.pool(Augments.PASSIVE, owned_augments)
				_shuffle(actives)
				_shuffle(passives)
				offered_augments = [actives.pop_back(), passives.pop_back()]
				var remainder = actives + passives
				_shuffle(remainder)
				offered_augments.append(remainder[0])
				_shuffle(offered_augments)
			else:
				offered_augments = Augments.pool(Augments.DEBUFF, owned_augments)
				_shuffle(offered_augments)
				offered_augments = offered_augments.slice(0, 2)
			message += "\n스테이지 클리어! 증강 1개와 골드/회복을 선택하세요."
	else:
		_check_bankruptcy()
	_refresh()


func _all_safe_revealed() -> bool:
	return generated and _hidden_safe().is_empty()


func _check_bankruptcy():
	if not ticket_pending.is_empty() or phase != "playing" or money >= _effective_dig_cost():
		return
	if not generated:
		_game_over("첫 파기를 위한 골드가 부족합니다.")
		return
	# Rescue powers and an unused revival can still complete a zero-cash board.
	if _has("revival") and not revival_used:
		return
	for id in ["domain", "hound", "safe_dig", "survey", "transfusion", "grant", "acceleration", "vitality", "blood_trade", "insurance"]:
		if not _active_available(id):
			continue
		# Even at full HP, wrong-flag digging can spend HP before transfusion.
		if id == "hound" and _unsettled_mines().is_empty():
			continue
		return
	var possible_income = _unsettled_mines().size() * mine_reward
	if _has("artisan") and _unsettled_mines().size() >= 3:
		possible_income += int(_unsettled_mines().size() / 3) * mine_reward
	# Ignore fees here deliberately: an optimistic bound avoids false bankruptcy.
	var hp_cost = _hidden_safe().size() * _wrong_flag_damage()
	if insurance_ready:
		hp_cost = ceili(hp_cost * 0.5)
	if money + possible_income < dig_cost and hp <= hp_cost:
		_game_over("파산: 남은 정산 수입·체력·구조 액티브로도 진행할 수 없습니다.")
	else:
		message += "\n골드 부족: 깃발 정산으로 진행하세요."


func _cash_reward() -> int:
	return _rules_for(stage + 1, true)["dig_cost"] * StageRules.CASH_REWARD_DIGS


func _choose_augment(id: String):
	if phase != "augment" or id not in offered_augments or id in owned_augments:
		return
	pending_augment = id
	phase = "reward"
	message = "%s 선택! 다음 스테이지부터 적용됩니다.\n이제 골드 또는 HP 회복을 선택하세요." % Augments.ALL[id]["name"]
	_refresh()


func _choose_reward(kind: String):
	if phase != "reward" or pending_augment.is_empty() or kind not in ["money", "heal"]:
		return
	if kind == "money":
		money += _cash_reward()
	else:
		_heal(HEAL_REWARD)
	if pending_augment == "heart":
		hp += 3
	owned_augments.append(pending_augment)
	stage += 1
	_start_stage()


func _abandon():
	if ticket_pending.is_empty() and phase == "playing":
		_game_over("런을 포기했습니다.")


func _game_over(reason: String):
	phase = "gameover"
	targeting = ""
	message = "GAME OVER\n" + reason + "\n스마일 버튼으로 다시 도전하세요."
	_refresh()
