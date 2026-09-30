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
const CARRY_TURN_RATE := 9.0       # rad/s a lone carrier swings the held item round, divided by its weight
const CARRY_FACE_RATE := 18.0      # rad/s the chef's body turns to the held item (grab, group carry)
const CARRY_HOLD_GAP := 0.15       # m between the chef's body and the edge of the item held in front
const CARRY_HOLD_EASE := 10.0      # 1/s the item eases into the held spot after a grab
const GRAB_AIM_RADIUS := 1.5       # m: an item in reach this close to the cursor is the one grabbed
const GRAB_FRONT_BIAS := 0.8       # m: an item right behind the chef must be this much nearer to win

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
const CAMERA_PITCH_DEG := 36.0          # pitch at the close zoom limit
const CAMERA_PITCH_FAR_DEG := 52.0      # pitch at the overview limit (steeper = more counter)
const CAMERA_DISTANCE := 17.5           # default distance from the focus point
const CAMERA_DISTANCE_MIN := 9.0        # close zoom limit
const CAMERA_DISTANCE_MAX := 27.0       # overview limit (~35 m of counter across at 16:9)
const CAMERA_FOV := 38.0
const CAMERA_SMOOTH := 5.0              # follow spring rate (1/s)
const CAMERA_ZOOM_STEP := 0.9           # distance factor per wheel notch
const CAMERA_ZOOM_PAD_RATE := 1.2       # pad shoulders: distance factor per second (exp)
const CAMERA_ZOOM_SMOOTH := 10.0
const CAMERA_LOOKAHEAD_SEC := 0.3       # focus leads the chef by velocity * this
const CAMERA_LOOKAHEAD_MAX := 2.2       # m
const CAMERA_CARRY_PULLBACK := 1.13     # distance factor while carrying
const CAMERA_CARRY_SMOOTH := 3.0
const CAMERA_FOCUS_Z := -1.5            # m: look this far behind the chef (towards -Z) so the chef sits low and scenery shows
const CAMERA_EDGE_MARGIN := 4.0         # m: focus stays this far inside the counter's side edges

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
