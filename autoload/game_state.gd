extends Node
## Persistent run state: money, batteries, upgrades, level progression.

signal money_changed(amount: int)
signal battery_changed(current: float, maximum: float)
signal level_changed(level: int)
signal run_reset()

const STORE_EVERY_N_LEVELS := 3
const BASE_MAX_BATTERY := 100.0
const BASE_FARE := 40

var money: int = 0
var level: int = 1
var battery: float = BASE_MAX_BATTERY
var max_battery: float = BASE_MAX_BATTERY
var fares_completed_this_level: int = 0
var fares_required_this_level: int = 3

var owned_upgrades: Array[String] = []

var thrust: float = 520.0
var drag: float = 1.2
var battery_burn_rate: float = 8.0
var battery_idle_burn: float = 1.5
var battery_charge_mult: float = 1.0 ## From upgrades / debug.
var stability: float = 1.0
var tip_bonus: float = 0.0
var max_speed: float = 240.0


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	money = 0
	level = 1
	owned_upgrades.clear()
	_recompute_stats()
	battery = max_battery
	fares_completed_this_level = 0
	fares_required_this_level = _fares_for_level(level)
	run_reset.emit()
	money_changed.emit(money)
	battery_changed.emit(battery, max_battery)
	level_changed.emit(level)


func _fares_for_level(lvl: int) -> int:
	return mini(3 + (lvl - 1) / 2, 8)


func _recompute_stats() -> void:
	max_battery = BASE_MAX_BATTERY
	thrust = 520.0
	drag = 1.2
	battery_burn_rate = 8.0
	battery_idle_burn = 1.5
	battery_charge_mult = 1.0
	stability = 1.0
	tip_bonus = 0.0
	max_speed = 240.0
	for id in owned_upgrades:
		var up: Dictionary = UpgradeDB.get_upgrade(id)
		if up.is_empty():
			continue
		max_battery += float(up.get("max_battery", up.get("max_fuel", 0.0)))
		thrust += float(up.get("thrust", 0.0))
		drag += float(up.get("drag", 0.0))
		battery_burn_rate += float(up.get("battery_burn", up.get("fuel_burn", 0.0)))
		battery_idle_burn += float(up.get("battery_idle", up.get("fuel_idle", 0.0)))
		battery_charge_mult += float(up.get("battery_charge", 0.0))
		stability += float(up.get("stability", 0.0))
		tip_bonus += float(up.get("tip_bonus", 0.0))
		max_speed += float(up.get("max_speed", 0.0))
	battery = mini(battery, max_battery)
	battery_changed.emit(battery, max_battery)


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func set_battery(value: float) -> void:
	battery = clampf(value, 0.0, max_battery)
	battery_changed.emit(battery, max_battery)


func consume_battery(amount: float) -> void:
	set_battery(battery - amount)


func charge_battery(amount: float) -> void:
	set_battery(battery + amount * battery_charge_mult)


func refill_battery() -> void:
	set_battery(max_battery)


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
	refill_battery()
	level_changed.emit(level)


func store_after_this_level() -> bool:
	return level % STORE_EVERY_N_LEVELS == 0


func should_visit_store() -> bool:
	return level > 1 and (level - 1) % STORE_EVERY_N_LEVELS == 0


func calc_fare_payout(happiness: float, distance: float) -> int:
	var base := BASE_FARE + int(distance / 40.0)
	var mult := lerpf(0.35, 1.35, clampf(happiness, 0.0, 1.0)) + tip_bonus
	return maxi(5, int(round(base * mult)))
