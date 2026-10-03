# Tiny Chefs: cosmetics catalogue (contract for polish round 2, wave B)

Currency: tokens (persistent, per player, local). Price 0 = free starter. Ids are final; model file =
`<prefix>_<id>.glb` in `game/assets/models/`. Attachment anchors and conventions: `docs/design/polish-2.md`
sections 4 and 5 (HatAnchor (0, 0.981, 0.0388), FaceAnchor (0, 0.906, 0.2568), BeardAnchor (0, 0.823, 0.2415),
BackAnchor (0, 0.606, -0.1784); models authored with their origin at the anchor, facing +Z in Godot; outfits are
authored in chef space (origin at the chef's feet) and hang under `Body`). The chef is about 0.7 wide x 1.45
tall; head radius about 0.26. Everything must read at game distance (camera ~17 m away) and look good close up
in the lobby. Style: chunky vinyl toy, smooth shading, flat colours, no textures, each under ~3k triangles.
A material named `HatTint` / `OutfitTint` (optional) takes the player's colour.

## Hats (`hat_`)
toque 0 (built in), beanie 0, paper 10, bandana 10 (these four exist), and new:
cowboy 20, crown 60, viking 40 (horned helmet), top_hat 30, propeller 25 (beanie with a spinning propeller:
propeller as a separate mesh object named `Spin`), sombrero 35, pirate 35 (tricorn + skull badge shape),
wizard 45 (tall pointed, stars), pot 15 (a cooking pot worn upside down, handles out), cone 20 (traffic cone),
party 15 (cone hat with pompom + elastic), fez 20, beret 15, cap 15 (baseball cap, peak forward),
santa 30, headphones 30, frog 40 (frog hood with eyes on top), halo 50 (floating ring: mesh named `Float`).

## Beards (`beard_`)
moustache 0 (exists), none 0 (no model), handlebar 15, full 20 (full beard), goatee 15, mutton 20 (mutton
chops), wizard 40 (long white beard), stubble 10, soul_patch 10, walrus 25.

## Face accessories (`acc_`)
none 0 (no model), glasses 10 (exists), sunglasses 15, monocle 25, eyepatch 20, clown_nose 15,
goggles 20 (ski/safety goggles), mask 25 (superhero eye mask), 3d_glasses 15.
(The old `acc_moustache` is retired: it becomes `beard_handlebar`.)

## Outfits (`outfit_`, worn over the body; MUST leave the tinted `ChefBody` jacket clearly visible from above
and behind: outfits are bibs, aprons, belts, collars, shoulder pieces, not full covers)
classic 0 (no model: the built-in apron), stripes 15 (striped apron), tuxedo 40 (bow tie, lapels, cummerbund),
overalls 25 (denim bib with straps), hero 45 (chest emblem + belt), bbq 20 (apron with a flame shape + oven
mitt in a pocket), knight 50 (breastplate + pauldrons), scarf 15 (long winter scarf), hawaiian 25 (flower lei
+ grass skirt band), sash 35 (winner's sash + medal).

## Back items (`back_`)
none 0 (no model), cape 30 (`HatTint`-style material `OutfitTint`), backpack 20, wings 60 (small angel
wings), jetpack 70 (two tanks + nozzles), guitar 35, shell 40 (turtle shell), pan 15 (frying pan strapped on),
balloon 25 (a balloon on a string: balloon mesh named `Float`), sword 30 (giant spatula "sword" in a sling).

## Body shapes (code, no models)
standard 0, stout 0, tall 20, long_legs 25, tiny 30, big_head 30, big_arms 40.

## Earning tokens
After each shift every player earns `floor(team coins earned this shift / 40) + 5 x campaign stars earned` (`Progress.COINS_PER_TOKEN`, `TOKENS_PER_STAR`).
