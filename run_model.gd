extends Control

const StageRules = preload("res://stage_rules.gd")
const Augments = preload("res://augments.gd")
const Upgrades = preload("res://upgrade_rules.gd")
const MAX_HP = 10
const START_MONEY = StageRules.START_MONEY
const MINE_DAMAGE = 2
const HEAL_REWARD = 4
const FINAL_STAGE = 10
const MAX_TICKET_COST = 1152921504606846976

var spent_cards = {}
var rerolled_slots = []
var offered_levels = {}
var bleed_digs = 0
var adaptation_uses = 0
var unfair_stage = -1
var effect_busy = false

var hp = MAX_HP
var max_hp = MAX_HP
var money = START_MONEY
var difficulty = "hard"
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
var expansion_level = 0 # Legacy field; individual levels are authoritative.
var augment_levels = {}
var upgrade_target = ""
var shield_charges = 0
var ticket_purchases = 0
var shop_result = ""
var ticket_pending = {}
var vitality_bonus = 0
var insurance_ready = false
var clear_heal_applied = false


func _has(id: String) -> bool:
	return id in owned_augments


func _rules_for(number: int, with_pending: bool = false) -> Dictionary:
	var rules = StageRules.for_stage(number, difficulty)
	var effective = owned_augments.duplicate()
	if with_pending and not pending_augment.is_empty():
		effective.append(pending_augment)
	var delta = (-int(_power("decontamination")) if "decontamination" in effective else 0)
	var capacity = mini(floori(rules["width"] * rules["height"] * StageRules.MAX_DENSITY), rules["width"] * rules["height"] - 9)
	rules["mines"] = clampi(rules["mines"] + delta, 1, capacity)
	if "cluster" in effective:
		rules["mines"] += 4 if number < 6 else 9
	if number == unfair_stage:
		rules["mines"] = rules["width"] * rules["height"]
	rules["stealth"] = 1 if "stealth" in effective else 0
	rules["max_hp"] = maxi(1, MAX_HP + (int(_power("heart")) if "heart" in effective else 0) + (int(_power("armor")) if "armor" in effective else 0) - (2 if "weakness" in effective else 0))
	rules["dig_cost"] += 1 if "dig_tax" in effective else 0
	if "reward_cut" in effective:
		rules["mine_reward"] = maxi(1, floori(rules["mine_reward"] * 0.75))
	return rules


func _new_run():
	spent_cards.clear()
	rerolled_slots.clear()
	offered_levels.clear()
	unfair_stage = -1
	effect_busy = false
	owned_augments.clear()
	offered_augments.clear()
	pending_augment = ""
	revival_used = false
	augment_levels.clear()
	upgrade_target = ""
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
	bleed_digs = 0
	adaptation_uses = 0
	rerolled_slots.clear()
	offered_levels.clear()
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
	shield_charges = 0
	accelerated_digs = 0
	shock_triggered = false
	first_explosion = false
	last_commit.clear()
	if _has("reserve"):
		money = maxi(money, dig_cost * int(_power("reserve")))
	cells.clear()
	for i in range(board_width * board_height):
		cells.append({"mine": false, "stealth": false, "adjacent": 0, "revealed": false, "flagged": false, "settled": false, "committed": false, "obscured": false})
	_build_board_view()
	message = "스테이지 %d / 10\n첫 파기는 안전합니다. 액티브는 첫 파기 후 사용 가능.\n은신지뢰: %d개" % [stage, stealth_count]
	if _has("decontamination"):
		var base = StageRules.for_stage(stage, difficulty)
		var removed = mini(int(_power("decontamination")), base["mines"] - 1)
		money += removed * mine_reward
		message += "\n사전 제독 지원금 +%d골드" % (removed * mine_reward)
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
	var excluded = _area(first_index, 1) if stage != unfair_stage else []
	var cluster = []
	if _has("cluster") and stage != unfair_stage:
		var centers = []
		for y in range(1, board_height-1):
			for x in range(1, board_width-1):
				var area = _area(y*board_width+x,1)
				if area.all(func(i): return i not in excluded): centers.append(y*board_width+x)
		_shuffle(centers)
		if not centers.is_empty(): cluster = _area(centers[0],1)
	var candidates = []
	for i in range(cells.size()):
		if i not in excluded and i not in cluster: candidates.append(i)
	_shuffle(candidates)
	candidates = cluster + candidates
	for i in range(mini(mine_count,candidates.size())):
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
	if effect_busy or not ticket_pending.is_empty() or phase != "playing" or index < 0 or index >= cells.size():
		return
	var cell = cells[index]
	if cell["revealed"] or cell["settled"]:
		return
	cell["flagged"] = not cell["flagged"]
	_refresh()


func _effective_dig_cost() -> int:
	if accelerated_digs > 0 or (_has("frugal") and direct_digs < int(_power("frugal"))):
		return 0
	return dig_cost


func _chord_info(index: int) -> Dictionary:
	var result = {"eligible": false, "targets": [], "cost": 0, "committed": 0, "confirmed": 0, "required": 0, "reason": ""}
	if effect_busy or not ticket_pending.is_empty() or phase != "playing" or not generated or not targeting.is_empty() or index < 0 or index >= cells.size():
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
		var free = accelerated_digs > offset or (_has("frugal") and direct_digs + offset < int(_power("frugal")))
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
		hp = mini(max_hp, int(_power("revival")))
		message += "\n부활권 발동! HP %d" % hp


func _on_damage(_amount: int):
	pass


func _heal_amount(amount: int) -> int:
	return maxi(0, amount)


func _heal(amount: int):
	if hp > 0:
		hp = mini(max_hp, hp + _heal_amount(amount))


func _dig(index: int):
	if effect_busy or not ticket_pending.is_empty() or phase != "playing" or index < 0 or index >= cells.size():
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
	shield_charges = maxi(0, shield_charges - 1)
	shield_ready = shield_charges > 0
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
			salvage = floori(mine_reward * _power("salvage") / 100.0)
			money += salvage
		message = "지뢰 폭발 · 파기 -%d골드\n지뢰 피해 %d · 잔해 수입 +%d" % [cost, mine_damage, salvage]
	else:
		var opened = _reveal_area(index)
		if _has("echo") and echo_uses < int(_power("echo")):
			var extra = _hidden_safe()
			_shuffle(extra)
			if not extra.is_empty():
				_reveal_one(extra[0])
				echo_uses += 1
				opened += 1
		message = "%d칸 공개 · 파기 -%d골드" % [opened, cost]
	var ground_damage = 1 if _has("unstable_ground") and direct_digs % 30 == 0 else 0
	if ground_damage > 0:
		message += "\n불안정 지반 -1 HP"
	# One action resolves all damage, then revival, then surviving heal/income effects.
	var bleed = 1 if bleed_digs > 0 else 0
	bleed_digs = maxi(0, bleed_digs-1)
	_apply_damage(mine_damage + ground_damage + bleed)
	if mine_damage > 0 and _has("bleeding"): bleed_digs = 2
	if cell["mine"] and _has("chain"):
		for neighbor in _neighbors(index):
			if hp <= 0: break
			if cells[neighbor]["mine"] and not cells[neighbor]["revealed"] and not cells[neighbor]["settled"]:
				cells[neighbor]["revealed"] = true
				cells[neighbor]["settled"] = true
				_apply_damage(_mine_damage())
	if cell["mine"] and hp > 0: _adapt()
	if hp > 0:
		if first_hit and _has("shock"):
			_heal(int(_power("shock")))
			message += "\n충격 흡수 +%d HP (최대 제한)" % _heal_amount(int(_power("shock")))
		if _has("regeneration") and direct_digs % int(_power("regeneration")) == 0:
			_heal(1)
			message += "\n재생 세포 +1 HP (최대 제한)"
		if first_blast and _has("dividend"):
			money = floori(money * _power("dividend"))
			message += "\n폭발 배당! 보유 골드 ×%s" % str(_power("dividend"))
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
		if (cells[i]["flagged"] and not cells[i]["settled"] and not cells[i]["revealed"]) or (cells[i]["mine"] and cells[i]["settled"] and not cells[i].get("committed", false)):
			result.append(i)
	return result


func _communication_allows_commit() -> bool:
	if generated and _unsettled_mines().is_empty():
		return true
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
		if cell["mine"] and cell["settled"]:
			# Previously exploded/safely confirmed mines finish bookkeeping for free.
			# Their reward and damage remain consumed; never pay or trigger fuse twice.
			cell["committed"] = true
		if not cell["mine"] or cell["settled"] or cell["revealed"]:
			continue
		cell["flagged"] = false
		cell["settled"] = true
		cell["committed"] = true
		correct += 1
		if _has("fuse") and rng.randf() < 0.20:
			fuse_damage += 1
	var bonus = floori(mine_reward * _power("artisan")) if _has("artisan") and correct >= 3 and wrong == 0 else 0
	var fee = mini(correct * mine_reward + bonus, dig_cost) if correct > 0 and _has("settlement_fee") else 0
	var earned = correct * mine_reward + bonus - fee
	money += earned
	var wrong_damage = wrong * _wrong_flag_damage()
	if manual and insurance_ready:
		wrong_damage = ceili(wrong_damage * (100.0 - _power("insurance")) / 100.0)
		insurance_ready = false
	var damage = wrong_damage + fuse_damage
	message += "\n정답 %d · 오답 %d · +%d골드\n오답/신관 피해 %d (신관 %d)" % [correct, wrong, earned, damage, fuse_damage]
	if fee > 0:
		message += "\n정산 수수료 -%d골드 반영" % fee
	_apply_damage(damage)
	last_commit = {"correct": correct, "wrong": wrong, "earned": earned, "fuse_damage": fuse_damage, "bonus": bonus, "fee": fee, "wrong_damage": wrong_damage}
	return last_commit


func _commit_flags():
	if effect_busy or not ticket_pending.is_empty() or phase != "playing" or not generated:
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
	return not effect_busy and ticket_pending.is_empty() and phase == "playing" and (generated or Augments.ALL.get(id,{}).get("one_shot",false)) and _card_ready(id) and hp > 0 and _has(id) and Augments.ALL.has(id) and Augments.ALL[id]["kind"] == Augments.ACTIVE and id not in used_actives and (id != "blood_trade" or hp >= 3)


func _level(id: String) -> int:
	if id in owned_augments and id != "communism" and _has("communism") and Augments.ALL.has(id) and Augments.ALL[id]["kind"] != Augments.DEBUFF:
		return clampi(int(augment_levels.get("communism",1)),1,4)
	return clampi(int(augment_levels.get(id, 1)), 1, 4)

func _power(id: String):
	return Upgrades.value(id, _level(id))

func _active_radius(id: String) -> int:
	return int(_power(id))

func _ticket_cost() -> int:
	return _ticket_cost_for(upgrade_target)

func _ticket_chance() -> float:
	if _level(upgrade_target) >= 4: return 0.0
	return minf(1.0, [0.30, 0.20, 0.10, 0.0][_level(upgrade_target)-1] + (float(_power("smith"))/100.0 if _has("smith") else 0.0))

func _can_upgrade(id: String) -> bool:
	return (not _has("communism") or id == "communism") and not effect_busy and Upgrades.DATA.has(id) and _has(id) and _level(id) < 4 and phase == "playing" and generated and ticket_pending.is_empty() and targeting.is_empty() and money >= _ticket_cost_for(id)

func _ticket_cost_for(id: String) -> int:
	return maxi(1, ceili(dig_cost * 6 * (1 << (_level(id)-1)) * (0.5 if _has("smith") else 1.0)))

func _buy_upgrade_ticket():
	if _begin_upgrade_ticket():
		_resolve_upgrade_ticket()


func _begin_upgrade_ticket() -> bool:
	if hp <= 0 or not _can_upgrade(upgrade_target):
		return false
	var cost = _ticket_cost()
	var chance = _ticket_chance()
	money -= cost
	ticket_purchases += 1
	# One charge and one real roll. The animation never consumes gameplay RNG.
	ticket_pending = {"success": rng.randf() < chance, "cost": cost, "chance": chance, "level": _level(upgrade_target), "id": upgrade_target}
	message = Augments.ALL[upgrade_target]["name"] + " 강화 진행 중… · -%d골드" % cost
	_refresh()
	return true


func _resolve_upgrade_ticket():
	if ticket_pending.is_empty():
		return
	var result = ticket_pending.duplicate()
	ticket_pending.clear()
	var cost = result["cost"]
	if result["success"]:
		var id = result["id"]
		var old_max = max_hp
		augment_levels[id] = int(result["level"]) + 1
		if id in ["heart", "armor", "communism"]:
			max_hp = _rules_for(stage)["max_hp"] + vitality_bonus
			hp = mini(max_hp, hp + maxi(0, max_hp - old_max))
		shop_result = "강화 성공! %s Lv.%d · -%d골드" % [Augments.ALL[id]["name"], _level(id), cost]
	else:
		shop_result = "강화 실패 · -%d골드 · 레벨 유지" % cost
	if not result["success"] and _has("slip") and rng.randf() < 0.05:
		_remove_augment(result["id"])
		shop_result += " · 증강 파괴!"
	message = shop_result
	_finish_action()


func _use_active(id: String, target: int = -1):
	if Augments.ALL.get(id,{}).get("one_shot",false):
		if _active_available(id): _use_consumable(id)
		return
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
		"gamble":
			var multiplier = rng.randf_range(float(_power(id)), [2.0,2.1,2.2,2.2][_level(id)-1])
			money = floori(money * multiplier)
			_effect_animation([], "", "가즈아!! ×%.2f → %d골드" % [multiplier,money])
		"beast":
			_beast_dig()
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
			_settle_mines(mines.slice(0, mini(int(_power("hound")), mines.size())))
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
			for index in safe.slice(0, mini(int(_power("survey")), safe.size())):
				_reveal_one(index)
		"shield":
			shield_charges = int(_power("shield"))
			shield_ready = true
		"transfusion":
			_heal(int(_power("transfusion")))
		"grant":
			money += dig_cost * int(_power("grant"))
		"audit":
			_shuffle(wrong_flags)
			for index in wrong_flags.slice(0, mini(int(_power("audit")), wrong_flags.size())):
				cells[index]["flagged"] = false
		"acceleration":
			accelerated_digs = int(_power("acceleration"))
		"vitality":
			vitality_bonus += int(_power("vitality"))
			max_hp += int(_power("vitality"))
			hp = mini(max_hp, hp + int(_power("vitality")))
			message += "\n이번 스테이지 최대 HP +2 · 현재 HP +2"
		"blood_trade":
			_apply_damage(2)
			money += dig_cost * int(_power("blood_trade"))
		"insurance":
			insurance_ready = true
	_finish_action()


func _finish_action():
	if effect_busy or not ticket_pending.is_empty() or phase != "playing":
		return
	if hp <= 0:
		_game_over("체력이 모두 소진되었습니다.")
	elif _all_mines_committed():
		if not clear_heal_applied:
			clear_heal_applied = true
			if _has("medic"):
				_heal(int(_power("medic")))
				message += "\n야전 의무관: 클리어 회복 +1 HP"
		targeting = ""
		if stage >= FINAL_STAGE:
			phase = "victory"
			message += "\n10스테이지 최종 승리!"
		else:
			rerolled_slots.clear()
			offered_levels.clear()
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


func _all_mines_committed() -> bool:
	if not generated:
		return false
	for cell in cells:
		if cell["mine"] and not cell.get("committed", false):
			return false
	return true


func _all_safe_revealed() -> bool:
	return generated and _hidden_safe().is_empty()


func _check_bankruptcy():
	if phase == "playing" and not generated and money < _effective_dig_cost():
		_game_over("첫 파기를 위한 골드가 부족합니다.")


func _cash_reward() -> int:
	return _rules_for(stage + 1, true)["dig_cost"] * StageRules.CASH_REWARD_DIGS


func _choose_augment(id: String):
	if effect_busy or phase != "augment" or id not in offered_augments or id in owned_augments:
		return
	pending_augment = id
	augment_levels[id] = int(offered_levels.get(id,1))
	owned_augments.append(id)
	_on_acquired(id)
	phase = "reward"
	message = "%s 선택! 다음 스테이지부터 적용됩니다.\n이제 골드 또는 HP 회복을 선택하세요." % Augments.ALL[id]["name"]
	_refresh()


func _choose_reward(kind: String):
	if effect_busy or phase != "reward" or pending_augment.is_empty() or kind not in ["money", "heal"]:
		return
	if kind == "money":
		money += _cash_reward()
	else:
		_heal(HEAL_REWARD)
	if pending_augment == "heart":
		hp += int(_power("heart"))
	if pending_augment not in owned_augments:
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

func _adapt():
	if _has("adaptation") and adaptation_uses < int(_power("adaptation")):
		adaptation_uses += 1
		vitality_bonus += 1
		max_hp += 1
		hp += 1

func _card_ready(id: String) -> bool:
	if not Augments.ALL.get(id,{}).get("one_shot",false): return true
	if not spent_cards.has(id): return true
	return _has("recycle") and stage - int(spent_cards[id]) >= int(_power("recycle"))

func _use_consumable(id: String):
	var targets = []
	if id == "cleanse":
		for item in owned_augments:
			if Augments.ALL[item]["kind"] == Augments.DEBUFF: targets.append(item)
	if id == "genius":
		for item in owned_augments:
			if Upgrades.DATA.has(item) and _level(item) < 4 and (not _has("communism") or item == "communism"): targets.append(item)
	if id in ["cleanse","genius"] and targets.is_empty():
		message = "적용 대상 없음 · 일회용 사용 보존"
		_refresh()
		return
	spent_cards[id] = stage
	if id == "relief": money += 500
	else:
		var chosen = targets[rng.randi_range(0,targets.size()-1)]
		if id == "cleanse": _remove_augment(chosen)
		else:
			var old_max = max_hp
			augment_levels[chosen] = 4
			_sync_hp()
			hp = mini(max_hp,hp+maxi(0,max_hp-old_max))
		_effect_animation(targets, chosen, "디버프 제거" if id == "cleanse" else "Lv.4 승급", id == "cleanse")
	message = Augments.ALL[id]["name"] + " 사용 완료"
	_refresh()

func _remove_augment(id: String):
	owned_augments.erase(id)
	augment_levels.erase(id)
	if id == "revival": revival_used = true
	if id == "shield":
		shield_charges = 0
		shield_ready = false
	if id == "acceleration": accelerated_digs = 0
	if id == "insurance": insurance_ready = false
	if id == "vitality": vitality_bonus = 0
	if targeting == id: targeting = ""
	_sync_hp()

func _sync_hp():
	max_hp = _rules_for(stage)["max_hp"] + vitality_bonus
	hp = mini(hp,max_hp)

func _on_acquired(id: String):
	if id == "hynix": money = floori(money*0.5)
	if id == "unfair": unfair_stage = stage+1
	if id == "reversal":
		var candidates = []
		for item in owned_augments:
			if Augments.ALL[item]["kind"] != Augments.DEBUFF: candidates.append(item)
		if not candidates.is_empty():
			var chosen = candidates[rng.randi_range(0,candidates.size()-1)]
			_remove_augment(chosen)
			_effect_animation(candidates,chosen,"반전술식 · 버프 무효화",true)
	if Augments.ALL[id].get("immediate",false): _use_consumable(id)

func _reroll_slot(slot: int):
	if effect_busy or phase != "augment" or not _has("reroll") or slot in rerolled_slots or slot < 0 or slot >= offered_augments.size(): return
	var excluded = owned_augments + offered_augments
	var pool = Augments.pool("buff" if stage%2==1 else Augments.DEBUFF,excluded)
	if pool.is_empty(): return
	rerolled_slots.append(slot)
	var id = pool[rng.randi_range(0,pool.size()-1)]
	offered_augments[slot] = id
	offered_levels[id] = 2 if stage%2==1 and Upgrades.DATA.has(id) and rng.randf()*100 < float(_power("reroll")) else 1
	_refresh()

func _beast_dig():
	var candidates = []
	for i in range(cells.size()):
		if not cells[i]["revealed"] and not cells[i]["settled"] and not cells[i]["flagged"]: candidates.append(i)
	_shuffle(candidates)
	for index in candidates.slice(0,int(_power("beast"))):
		if hp <= 0: break
		if cells[index]["revealed"] or cells[index]["settled"]: continue
		if cells[index]["mine"]:
			cells[index]["revealed"] = true
			cells[index]["settled"] = true
			_apply_damage(_mine_damage())
			if _has("bleeding"): bleed_digs = 2
			if _has("chain"):
				for neighbor in _neighbors(index):
					if hp <= 0: break
					if cells[neighbor]["mine"] and not cells[neighbor]["revealed"] and not cells[neighbor]["settled"]:
						cells[neighbor]["revealed"] = true
						cells[neighbor]["settled"] = true
						_apply_damage(_mine_damage())
			if hp > 0: _adapt()
		else:
			_reveal_one(index)
			money += dig_cost*3

func _effect_animation(_ids: Array, _chosen: String, _caption: String, _tear: bool = false):
	pass
