class_name Tuning
extends RefCounted
## Every balance number in one place. Content tables (items, recipes, shifts, prices) are in game_data.gd.

# Chefs
const PLAYER_SPEED := 7.0          # m/s walking
const PLAYER_ACCEL := 45.0         # m/s^2 towards the target walking speed
const GRAVITY := 30.0
const REACH := 1.3                 # m from chef centre to the edge of an item/station footprint
const FALL_Y := -4.0               # below this a chef counts as fallen off
const RESPAWN_DELAY := 2.0
const KNOCK_DECAY := 18.0          # m/s^2 a punch shove decays at

# Carrying: speed = PLAYER_SPEED * clamp(carriers / weight, CARRY_MIN_FACTOR, 1)
const CARRY_MIN_FACTOR := 0.25
const CARRY_LIFT := 0.35           # carried food floats this far off the counter
const PUSH_SPEED := 2.4            # m/s a weight-1 loose item is shoved at by walking into it (divided by weight)

# Stations
const DISPENSE_HOLD := 0.5         # s of holding work at a dispenser per item
const MAX_LOOSE_ITEMS := 25
const COOK_TIME := 8.0             # raw -> cooked
const BURN_TIME := 10.0            # cooked -> burnt
const GRIDDLE_SLOTS := 4
const CHOP_TIME := 4.0             # s for one chef; each extra chef adds the same rate again
const CHOP_SLICES := 3
const PLATE_MAX_STACK := 10

# Orders and coins
const MAX_ORDERS := 4
const FIRST_ORDER_DELAY := 2.0
const EMPTY_ORDER_DELAY := 4.0     # when no order is open, the next one comes at most this soon
const WRONG_SERVE_PENALTY := 10
const EXPIRE_PENALTY := 10
const MIN_ORDER_INTERVAL := 12.0
const MIN_PATIENCE := 55.0
const SCALE_ORDER_RATE_PER_PLAYER := 0.35  # each extra player: orders this much more often
const SCALE_TARGET_PER_PLAYER := 0.5       # each extra player: target this much higher

# Upgrades
const SHOES_MULT := 1.2
const KNIFE_MULT := 2.0
const PUNCH_COOLDOWN := 0.6
const PUNCH_RANGE := 2.0           # m to the target's footprint edge
const PUNCH_ITEM_SPEED := 17.0     # m/s for weight 1, divided by sqrt(weight)
const PUNCH_ITEM_UP := 6.0
const PUNCH_PLAYER_SPEED := 15.0

# Camera (fixed yaw, looks towards -Z)
const CAMERA_PITCH_DEG := 50.0
const CAMERA_DISTANCE := 19.0
const CAMERA_FOV := 50.0
const CAMERA_SMOOTH := 5.0

# Network
const PORT := 7777
const MAX_PLAYERS := 4
const SNAPSHOT_EVERY := 2          # physics ticks between snapshots (60 Hz / 2 = 30 Hz)
const PUPPET_SMOOTH := 18.0        # client interpolation rate

# Physics layers (bit values)
const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_ITEMS := 4

# Flow
const AUTO_RESULTS_SECONDS := 4.0  # --autostart: results -> shop
const AUTO_SHOP_SECONDS := 6.0     # --autostart: shop -> next shift
