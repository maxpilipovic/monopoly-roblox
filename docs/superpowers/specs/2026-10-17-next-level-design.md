# Next Level: Buildings, Animations and Custom Cards — Design

Date: 2026-10-17. The user asked for this in one request and waived approvals ("No need to prompt for approvals. Just get it done"), so this records the decisions I made rather than ones we agreed.

The request:
- Blender models for houses and hotels, red "like in the actual game".
- Animations that take the game to the next level.
- Custom Chance and Community Chest cards.
- Custom cards for railroads, utilities "and stuff like that".
- Colour only on the properties around the board, so nothing else is confusing.
- Unique and very custom.

## Decisions

- **Colour belongs to properties only.** Today the Chance card is exactly the Orange group's colour (247, 148, 29), Community Chest is close to Light Blue, and the jail card uses the Red group's red. Every non-property card moves to a neutral family: ink, midnight, parchment and steel, with a metallic gold accent used only for thin foil lines. Gold (214, 172, 84) is distinct from Yellow (254, 242, 0) by hue and saturation. Property deeds keep their colour bands; they're now the only coloured cards.
- **Houses and hotels are red, both of them.** The user asked for red, so both are lacquered red with cream trim. A house is a cottage with a pitched roof and a chimney; a hotel is a wider, taller three-storey inn. The shapes tell them apart at a glance. The colours are one constant each in `Buildings.luau` if the user wants classic green houses.
- **Custom 3D emblems on cards and tiles.** Five small emblem models come from Blender through the same pipeline as the die:
  - a gold question mark (Chance)
  - a treasure chest (Community Chest)
  - a steam locomotive (railroads)
  - a light bulb (Electric Company / Power Plant)
  - a water tap (Water Works)

  Each card face shows its emblem slowly turning in a `ViewportFrame`. The same models stand on their board tiles, so the board, the cards and the deeds share one look. The tiles that carry emblems are Chance, Community Chest, the railroads and the utilities.
- **The jail card** gets the steel family and an iron-bars motif built from frames, with no new model.
- **Animations fit inside the existing timings.** `Pacing` is unchanged, so bots, the turn clock and the camera stay in step.

## Models (Blender → Roblox, the existing pipeline)

Rules from the models spec apply: 1 Blender unit = 1 stud, origin at the centre of the base, and Roblox +X = Blender −X, Roblox +Z = Blender +Y. Parts are named so the game can tint them.

| Shape | Kind folder | Footprint / max height (studs) | Parts | Triangle budget |
|---|---|---|---|---|
| House | Buildings | 1.0 × 1.0 / 1.2 | Body, Roof, Trim | 1,200 |
| Hotel | Buildings | 2.2 × 1.4 / 2.0 | Body, Roof, Trim | 2,000 |
| Question | Emblems | about 1.6 tall | Body | 2,000 |
| Chest | Emblems | about 1.6 × 1.1 × 1.2 | Body, Trim | 2,500 |
| Locomotive | Emblems | about 2.0 × 1.0 × 1.3 | Body, Trim | 3,000 |
| Bulb | Emblems | about 1.6 tall | Body, Trim | 2,000 |
| Tap | Emblems | about 1.6 tall | Body, Trim | 2,000 |

- A building's door faces the tile's outer edge (Roblox local +Z, Blender +Y), towards the players sitting outside the board.
- Sources: `tools/blender/buildings_classic.py` and `tools/blender/emblems.py`, saved to `assets/blender/buildings.blend` and `emblems.blend`.
- Exports go to `assets/export/Buildings/*.fbx` and `assets/export/Emblems/*.fbx`. `tools/upload-assets.ps1` uploads them and regenerates `AssetIds`.
- `Assets.luau` already loads every `AssetIds` entry into `ReplicatedStorage.Assets.<Kind>.<Shape>`.

## Buildings and their animation

`src/client/Buildings.luau` keeps `Buildings.wanted(snapshot)` and its diffing. It gains:

- **Models:** a house or hotel is a clone of the loaded model, tinted with Body red, Roof deep red and Trim cream. If the model isn't loaded, the block parts are built as today.
- **Build:** each new house drops from 3 studs up onto its spot with a quick squash-and-settle and a puff of dust. Houses added together drop one after another, 0.08 s apart.
- **Upgrade to a hotel:** the four houses sink into the board, then the hotel rises with an overshoot and a sparkle burst.
- **Sell:** a sold house or hotel shrinks and sinks away.
- **Snapshot jumps** (joining mid-game, returning to the lobby): buildings appear or go without animation, because only a change between two consecutive snapshots on screen animates.

New pure module `src/shared/Board/BuildingChanges.luau` exports `BuildingChanges.diff(old: {[number]: number}, new: {[number]: number}): { Change }`, where a `Change` is `{ position, from, to }`, sorted by position. Buildings plays each change: houses added, houses removed, upgraded to a hotel, or a hotel broken back into houses.

## Other animations

- **Token hops** (`Tokens.luau`): the token leans into each hop and squashes slightly on landing. When its whole move ends, a ring in its seat colour ripples out across the tile. A jump to jail is a high, spinning arc. The hop timings don't change.
- **Money pops** (`src/client/MoneyPops.luau`): when a `Paid` event plays, "+$X" (green) rises from the payee's token and "−$X" (red) from the payer's. The bank shows nothing. Passing Go also makes the Go tile flash gold.
  - New pure function `MoneyPops.fromEvent(event): { { player: string, amount: number } }`, where a negative amount is a payment.
- **Purchase:** when a deed is bought, its ownership strip grows along the tile edge from the middle out, instead of popping in. This is in `OwnerMarkers.luau`, on a new strip only.
- **Cards** (`CardReveal`): the reveal keeps its land-and-flip sequence. A foil shine then sweeps across the face once, and the 3D emblem turns slowly while the card is up.

## Custom cards

New `src/client/Hud/CardStyle.luau` (pure), so tests can pin the colour rule:

- `CardStyle.deck(deck: string): Style` for Chance, CommunityChest and Jail.
- `CardStyle.deed(kind: string, groupColor: Color3?): Style` for Property, Railroad and Utility.
- `Style = { back: Color3, face: Color3, ink: Color3, foil: Color3, band: Color3, emblem: string? }`, where `emblem` is a shape name under `Assets.Emblems`.
- The rule, pinned by a test: no `Style` except a property deed's may use a colour within a set distance of any colour group's colour.

The families:

| Card | Back | Face | Band | Emblem |
|---|---|---|---|---|
| Chance | midnight (18, 22, 38) with gold foil frame | parchment | midnight | Question |
| Community Chest | charcoal (34, 34, 38) with gold foil (a brown leather look was rejected: too close to the Brown group) | parchment | charcoal | Chest |
| Jail | steel (70, 76, 86) with iron bars | parchment | steel | none (bars) |
| Railroad deed | — | parchment | midnight | Locomotive |
| Utility deed | — | parchment | charcoal | Bulb or Tap (by tile) |
| Property deed | — | parchment | group colour | none |

Chance and Community Chest are told apart by the emblem and the deck name, not by hue. Midnight and charcoal still read differently: one has a blue cast, the other is neutral.

- **`CardReveal`:** the back shows the foil frame, the deck name in gold and the emblem in a `ViewportFrame` (the "?" text falls back when there's no model). The front's header band uses the style's band colour, with a small emblem viewport beside the title.
- **`DeedCard`:** railroad and utility deeds draw their band in the style's band colour, with the turning emblem under the name.
- **`Theme`:** `Theme.color.chance` and `Theme.color.chest` are removed. Any other use of them moves to `CardStyle`.

## Board tile emblems

New server module `src/server/TileEmblems.luau`. Once `Assets` has loaded the emblems, it stands the right emblem on each Chance, Community Chest, railroad and utility tile. Each one is about 2.4 studs tall, placed in the tile's inner half, anchored and non-colliding, and stays still so the board stays calm.

- Emblems are part of the `Board` model, so they replicate, and they're placed again when the board is rebuilt.
- The tile label moves to the outer half of those tiles.

## Tests

- `BuildingChanges.spec`: add, remove, upgrade to a hotel, hotel back to houses, unchanged, and sorting.
- `MoneyPops.spec`: a player-to-player payment gives two pops, a bank payment one, and a zero amount none.
- `CardStyle.spec`:
  - every non-property style keeps clear of every colour group's colour
  - a property deed's band is its group colour
  - Chance and Community Chest differ
  - each emblem name is one of the five
- All existing tests keep passing. Anything visual is checked in a Studio playtest.

## Out of scope

Token piece models, finishes and skins (the models spec), sounds, and the phone layout.
