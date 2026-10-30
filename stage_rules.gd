extends RefCounted

# Keep board growth and economy previews on the same source of truth.
const START_MONEY = 30
const BASE_SIDE = 8
const SIDE_GROWTH = 2
const BASE_DENSITY = 0.18
const DENSITY_GROWTH = 0.01
const MAX_DENSITY = 0.25
const MINE_REWARD_DIGS = 2
const CASH_REWARD_DIGS = 6


static func dig_cost(stage_number: int) -> int:
	var current = maxi(1, stage_number)
	var step = current - 1
	return 2 * current + floori(step * step / 4.0)


static func for_stage(stage_number: int) -> Dictionary:
	var current = maxi(1, stage_number)
	var step = current - 1
	var side = BASE_SIDE + SIDE_GROWTH * step
	var density = minf(BASE_DENSITY + DENSITY_GROWTH * step, MAX_DENSITY)
	var cost = dig_cost(current)
	return {
		"width": side,
		"height": side,
		"mines": floori(side * side * density),
		"dig_cost": cost,
		"mine_reward": cost * MINE_REWARD_DIGS,
		"cash_reward": dig_cost(current + 1) * CASH_REWARD_DIGS,
	}
