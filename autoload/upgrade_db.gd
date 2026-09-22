extends Node
## Catalog of cyber-cab upgrades. Expand by adding entries to UPGRADES.

const UPGRADES: Array[Dictionary] = [
	{
		"id": "efficient_cells",
		"name": "Efficient Cells",
		"desc": "Fuel burns slower while thrusting.",
		"cost": 80,
		"fuel_burn": -2.0,
	},
	{
		"id": "big_tank",
		"name": "Big Tank",
		"desc": "+40 max fuel capacity.",
		"cost": 100,
		"max_fuel": 40.0,
	},
	{
		"id": "gyro_stabilizer",
		"name": "Gyro Stabilizer",
		"desc": "Rides feel smoother — less bump penalty.",
		"cost": 120,
		"stability": 0.45,
	},
	{
		"id": "turbo_props",
		"name": "Turbo Props",
		"desc": "Stronger thrust and higher top speed.",
		"cost": 140,
		"thrust": 90.0,
		"max_speed": 40.0,
	},
	{
		"id": "soft_landing",
		"name": "Soft Skids",
		"desc": "Extra drag for easier control.",
		"cost": 70,
		"drag": 0.8,
		"stability": 0.15,
	},
	{
		"id": "vip_meter",
		"name": "VIP Meter",
		"desc": "Happy riders tip more.",
		"cost": 150,
		"tip_bonus": 0.25,
	},
	{
		"id": "idle_sip",
		"name": "Idle Sip",
		"desc": "Hovering costs less fuel.",
		"cost": 90,
		"fuel_idle": -0.8,
	},
]


func get_all() -> Array[Dictionary]:
	return UPGRADES.duplicate(true)


func get_upgrade(id: String) -> Dictionary:
	for up in UPGRADES:
		if str(up.get("id", "")) == id:
			return up
	return {}


func get_available_for_purchase() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for up in UPGRADES:
		var id: String = str(up.get("id", ""))
		if not GameState.has_upgrade(id):
			out.append(up)
	return out
