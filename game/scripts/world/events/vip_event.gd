class_name VipEvent
extends ShiftEvent
## "vip": a gold VIP ticket (OrderManager.add_vip): Tuning.VIP_PAY_MULT x price and bonus, VIP_PATIENCE_MULT
## of the normal patience, VIP_EXPIRE_MULT x the expiry penalty. Serving it fires the big celebration
## (EventSystem.on_order_served). Tickets are gold on every peer via the replicated "vip" order flag.


func _init(w: World) -> void:
	super(w)
	id = "vip"
	period = Tuning.VIP_PERIOD
	lead = Tuning.VIP_LEAD


## One VIP at a time.
func available() -> bool:
	for o in world.orders.orders:
		if bool(o.get("vip", false)):
			return false
	return true


func telegraph() -> void:
	Net.event("A VIP is coming! Triple pay, short patience.", "ev_vip")


func hit() -> void:
	var o := world.orders.add_vip(world.shift.def)
	var dish := str(GameData.RECIPES[int(o["r"])]["name"])
	print("events: VIP order %s (patience %.0f s)" % [dish, float(o["patience"])])
