# Tiny Chefs: polish round 2 (2026-10-03)

Owner's brief: much more polish. Nicer chef animation, better food physics, a small penalty for stacking in the
wrong order, a way to take things off / trash a plate, a much bigger upgrade tree with tiers (cheap first steps,
food pays less so it lasts), clearer order tickets, refined patty and sausage/bun models, other visuals fixed,
and far more chef customisation bought with a persistent currency. UI style stays as it is. Carry/aim controls
and their feel stay as they are. This file is the contract for every agent in this round.

## 1. Plate rules
- **Stack order.** A recipe's `items` list is its intended order, bottom to top. A dish is "tidy" when the plate
  holds a base item first (`bun_bottom`, `hotdog_bun`, or the first item of the recipe for bun-less dishes) and,
  if the recipe has a `bun_top`, that is last. Inner items are free; sides (`"side"`: fries, soda, onion rings)
  go before the base or after the top, never inside the bun. Serving an untidy dish still counts but pays
  `Tuning.MESSY_PAY` (0.85) of price and bonus, with a "Messy plate! -15%" toast; tidy dishes get a small
  "Tidy!" flourish. Stats count tidy/messy. Bots stack tidily.
- **Take off.** Grabbing (LMB) while aiming at a plate with food takes the TOP item off the stack into the
  chef's hands (normal carry rules). The highlight outlines the top item.
- **Scrape.** Holding work (RMB) on a plate with food for `Tuning.SCRAPE_HOLD` (1.2 s) scrapes everything off
  into the bin: items are deleted, a progress ring shows, no coin penalty. (Ringing the bell on a wrong plate
  keeps its existing behaviour.)

## 2. Food physics
Host-simulated as now, replicated with rotation. Releasing food while moving tosses it with the carrier's
velocity (capped, lighter = further). Round items (`tomato`, `onion`, `potato`, `egg`) roll and keep rolling a
little; flat items slide and settle flat. Loose items collide with each other and pile instead of overlapping.
Drops bounce once and squash-stretch on landing (visual). The plate stack sways when something lands on it
(visual only). An egg dropped from a toss cracks into a wasted splat (a `egg_splat` decal item that must be
ignored by recipes; if no model exists, a flat yellow-white disc primitive). Nothing here may change carry
speed, turn rates, or grab reach.

## 3. Upgrades become a tiered tree (`GameData.UPGRADES`, levels)
Each upgrade: `id, name, category, desc (with {value}), levels: [{price, value}]`, optional `requires`.
Owned state is `id -> level` (0 = not owned), replicated like today's upgrade list. `shift.upgrade_level(id)`,
`shift.upgrade_value(id, default)`. `--upgrades=id:level,...` for tests (bare id = max level).
Categories and lines (values are per level, cumulative effect shown; balance agent sets prices):
- Cooking: hot_griddle I-V (+15% cook and fry speed each), oven_mitts I-III (+25% burn window each),
  big_griddle I-II (+1 griddle slot each), big_fryer I (+1 fryer slot; a 7x6 fryer fits 4).
- Prep: sharp_knife I-IV (+25% chop speed each), quick_hands I-III (dispensers and soda 20% faster each).
- Movement: shoes I-IV (+7% move and carry speed each), protein_shake I-III (each level counts as +0.34 of a
  carrier for heavy food), tongs I-II (+25% grab reach each).
- Service: second_plate (one level, maps that have it), friendly_service I-IV (+10% order patience each),
  tip_jar I-IV (+8% pay each), insurance I-III (-25% expiry penalty each), combo_bell I-III (serving within
  20 s of the previous serve pays +5% per level per streak step, up to 5 steps).
- Chaos: gloves (punch), heavy_gloves I-II (+40% punch launch each, requires gloves), catapult? (not this round).
First levels are cheap (first purchase possible after shift 1), later levels escalate (~x1.6). Recipe prices
drop so the full tree takes many shifts: the balance agent measures and sets numbers.

## 4. Chef rig v2 (model + procedural animation + body shapes)
`chef.glb` is re-exported as separate parts under a `Chef` root: `Body` (jacket+apron, material `ChefBody`
tinted), `Head` (skin, face features as sub-meshes: `Eyes`, `Brows`, `Mouth`, built-in moustache moves to a
beard slot), `Toque`, `HandL`, `HandR`, `FootL`, `FootR`, plus attachment anchors as empty nodes: `HatAnchor`,
`FaceAnchor`, `BeardAnchor`, `BackAnchor`, `NeckAnchor`. A code animator (`world/chef_anim.gd`) drives: idle
breathing and occasional blink/look-around, walk cycle (feet step, hands swing, body bob and lean into
acceleration and turns), carry (hands reach to the item, lean back by weight, strain wobble when under-staffed),
work (chop: hand hammering; dispense/soda: reach and pull; bell: slap), punch wind-up and swing, toss, fall
flail and landing squash, serve celebration (hop + arms up), fail slump, emote on ping. All cheap, no skeleton.
Body shapes scale parts: `standard`, `tall`, `stout`, `big_arms` (huge hands and forearms), `big_head`, `tiny`,
`long_legs`. Collider and gameplay size never change.
Built (rig v2): chef.glb tree `Chef` -> `Body` (origin = hips (0, 0.246, 0.0388)) -> `Head` (neck, (0, 0.776, 0.0388))
-> `Eyes`, `Brows`, `Mouth`, `Toque`, `HatAnchor` (0, 0.981, 0.0388), `FaceAnchor` (0, 0.906, 0.2568), `BeardAnchor`
(0, 0.823, 0.2415); `Body` -> `BackAnchor` (0, 0.606, -0.1784), `NeckAnchor` (0, 0.776, 0.0388); `Chef` -> `HandL`/`HandR`
(hand centre, x +-0.335), `FootL`/`FootR` (ankle, y 0.116) -> `LegL`/`LegR`. Positions are chef-local rest values for the
`standard` body (Godot metres, +Z front); a cosmetic model's origin sits exactly on its anchor, no rotation, no scale
(anchors follow animation and body shape). `outfit_<id>.glb` is authored in chef space (origin at the feet) and hung
under `Body`. Default beard = `beard_moustache.glb` (the old built-in moustache).
Arms (p3): `Chef` -> `ArmL`/`ArmR` (empty at the shoulder, Body-local (+-0.19, 0.41, 0)) -> `UpperArm*`, `Forearm*` (ChefBody
sleeve segments, mesh along -Y, 0.08 m), `Cuff*` (white); the old sleeve stumps left `Body`. ChefAnim aims them at the
hands every frame; `shape()` sets meta `rig_arm` (upper/forearm thickness from body width and hand scale: `big_arms`
= 1.4 / 1.8). Old-vs-new check: `CHEF_COMPARE=1` in `scenes/dev/chef_preview.tscn` (frozen `dev/chef_anim_v1.gd` +
`assets/models/dev/chef_v1.glb`).

## 5. Wardrobe (persistent, per player, local file)
Currency: **tokens**, saved per player in `user://progress.cfg`. After each shift every player earns
`floor(team coins earned this shift / 40) + 5 per new campaign star` (a replay pays no stars again). Categories: hat, outfit, beard,
accessory, back item, body shape, colour stays free. Each category has 1 to 2 free starters; the rest cost
tokens (10 to 80). Owned items and the equipped look are saved locally and the equipped look is sent to the
host as today (`Net` look sync; the look dict gains `outfit, beard, back, body`). A Wardrobe screen is reachable
from the menu and the lobby: category tabs, item cards with a live chef preview, price or "Owned", Buy / Wear.
Model names: `hat_<id>.glb` at `HatAnchor`, `acc_<id>.glb` at `FaceAnchor`, `beard_<id>.glb` at `BeardAnchor`,
`back_<id>.glb` at `BackAnchor`, `outfit_<id>.glb` at the chef origin (worn over the body; must leave the
`ChefBody` colour clearly visible from above and behind so players stay identifiable).

## 6. Order tickets
Tickets show real ingredient thumbnails (each kind's model rendered once to a small texture and cached) in
stack order, with count badges, ticks for what is on the plate, and the dish name; a mini "burger stack"
reading bottom to top so the tidy order is obvious. Same design system. Mystery orders still hide them.

## 7. Art
Refine `patty_raw/cooked/burnt`, `sausage_raw/cooked/burnt`, `hotdog_bun` (owner dislikes them), and touch up
the weakest models. Add a VFX pass (steam, sizzle, sparks, footstep dust, serve confetti, coin pops, impact
stars). New cosmetic models per section 5.
