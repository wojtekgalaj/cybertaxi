extends Node
## Persistent run state: money, fuel, upgrades, level progression.

signal money_changed(amount: int)
signal fuel_changed(current: float, maximum: float)
signal level_changed(level: int)
signal run_reset()

const STORE_EVERY_N_LEVELS := 3
const BASE_MAX_FUEL := 100.0
const BASE_FARE := 40

var money: int = 0
var level: int = 1
var fuel: float = BASE_MAX_FUEL
var max_fuel: float = BASE_MAX_FUEL
var fares_completed_this_level: int = 0
var fares_required_this_level: int = 3

## Owned upgrade ids (from UpgradeDB).
var owned_upgrades: Array[String] = []

## Live cab stats (recomputed from upgrades).
var thrust: float = 420.0
var drag: float = 2.8
var fuel_burn_rate: float = 8.0
var fuel_idle_burn: float = 1.5
var stability: float = 1.0 ## Higher = less bumpiness penalty.
var tip_bonus: float = 0.0 ## Extra fare multiplier.
var max_speed: float = 220.0


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	money = 0
	level = 1
	owned_upgrades.clear()
	_recompute_stats()
	fuel = max_fuel
	fares_completed_this_level = 0
	fares_required_this_level = _fares_for_level(level)
	run_reset.emit()
	money_changed.emit(money)
	fuel_changed.emit(fuel, max_fuel)
	level_changed.emit(level)


func _fares_for_level(lvl: int) -> int:
	return mini(3 + (lvl - 1) / 2, 8)


func _recompute_stats() -> void:
	max_fuel = BASE_MAX_FUEL
	thrust = 420.0
	drag = 2.8
	fuel_burn_rate = 8.0
	fuel_idle_burn = 1.5
	stability = 1.0
	tip_bonus = 0.0
	max_speed = 220.0
	for id in owned_upgrades:
		var up: Dictionary = UpgradeDB.get_upgrade(id)
		if up.is_empty():
			continue
		max_fuel += float(up.get("max_fuel", 0.0))
		thrust += float(up.get("thrust", 0.0))
		drag += float(up.get("drag", 0.0))
		fuel_burn_rate += float(up.get("fuel_burn", 0.0))
		fuel_idle_burn += float(up.get("fuel_idle", 0.0))
		stability += float(up.get("stability", 0.0))
		tip_bonus += float(up.get("tip_bonus", 0.0))
		max_speed += float(up.get("max_speed", 0.0))
	fuel = mini(fuel, max_fuel)
	fuel_changed.emit(fuel, max_fuel)


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func set_fuel(value: float) -> void:
	fuel = clampf(value, 0.0, max_fuel)
	fuel_changed.emit(fuel, max_fuel)


func consume_fuel(amount: float) -> void:
	set_fuel(fuel - amount)


func regain_fuel(amount: float) -> void:
	set_fuel(fuel + amount)


func refill_fuel() -> void:
	set_fuel(max_fuel)


func own_upgrade(id: String) -> void:
	if id in owned_upgrades:
		return
	owned_upgrades.append(id)
	_recompute_stats()


func has_upgrade(id: String) -> bool:
	return id in owned_upgrades


func register_fare_complete() -> void:
	fares_completed_this_level += 1


func level_complete() -> bool:
	return fares_completed_this_level >= fares_required_this_level


func advance_level() -> void:
	level += 1
	fares_completed_this_level = 0
	fares_required_this_level = _fares_for_level(level)
	refill_fuel()
	level_changed.emit(level)


func store_after_this_level() -> bool:
	## Call before advance_level(): store opens after levels 3, 6, 9...
	return level % STORE_EVERY_N_LEVELS == 0


func should_visit_store() -> bool:
	## Call after advance_level().
	return level > 1 and (level - 1) % STORE_EVERY_N_LEVELS == 0


func calc_fare_payout(happiness: float, distance: float) -> int:
	var base := BASE_FARE + int(distance / 40.0)
	var mult := lerpf(0.35, 1.35, clampf(happiness, 0.0, 1.0)) + tip_bonus
	return maxi(5, int(round(base * mult)))
