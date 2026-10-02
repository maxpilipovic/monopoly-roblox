# Models and Pipeline — Design

Date: 2026-10-02. Agreed in conversation. This is project 1 of 3; it covers roadmap item 2.

## Intent

Replace the cylinder tokens and block buildings with models that look like a luxury physical board game, and build the catalogue of pieces, buildings and dice that later becomes the pool of unlockable skins. The user's bar is "the best Monopoly game": quality comes from silhouette and material, and the rare skins must look visibly more valuable than the common ones.

**The three projects** (each its own spec, plan and build):

1. **Models and pipeline (this spec).** Blender sources, upload to Roblox, a skin catalogue, and the game drawing the default skins.
2. **Skins in the game.** 3D dice that roll on the board; each player's chosen piece, dice and building set shown to everyone.
3. **Crates and unlocks.** Saved inventory, crate opening, odds, how skins are earned or bought. Needs saved player data (reverses the earlier "nothing persisted" decision) and published odds for paid random items.

**Not in this project:** 3D dice in play (dice stay 2D in the HUD), choosing a skin, inventory, crates, the jail cell model and the go-to-jail animation (roadmap item 2's remaining parts, planned after this).

## Decisions made

- **Style: premium tabletop.** Cast-metal pieces, lacquered buildings, resin dice.
- **Upload: Open Cloud API key.** The user creates one key with asset-upload permission; models are uploaded by script.
- **Original pieces.** No top hat, thimble, dog or other Hasbro tokens, because of the takedown risk already noted in the roadmap.
- **Modelling by scripted geometry.** No AI generator is enabled in the user's Blender, so shapes are hard-surface objects that scripted modelling does well.

## Catalogue: shapes × finishes

A **skin** is a shape plus a finish. Shapes are meshes made in Blender. Finishes are applied in Roblox, so one mesh yields many skins.

### Shapes

| Kind | Shapes |
|---|---|
| Piece (8) | Crown, Rocket, Sailboat, Roadster, Locomotive, Lighthouse, Anchor, Airship |
| Building set (4), each a house and a hotel | Cottage + Inn, Townhouse + Deco Tower, Villa + High-Rise, Pagoda + Palace |
| Dice (3) | Rounded (engraved pips), Casino (sharp edges), Gem-Cut (faceted corners) |

### Finishes

| Rarity | Finishes |
|---|---|
| Common | Pewter, Ivory, Oak |
| Uncommon | Brass, Red Lacquer, Blue Lacquer |
| Rare | Gold, Chrome, Ruby Resin |
| Epic | Jade, Marble, Obsidian |
| Legendary | Crystal, Aurora (glowing) |

Each finish is a record: Roblox material, colour, reflectance, transparency, an accent colour (dice pips, building trim), and optional texture asset IDs for a `SurfaceAppearance` (Jade, Marble, Oak and Obsidian are textured; the rest are untextured).

### Skins

Every shape is offered in every finish, and a skin's rarity is its finish's rarity. Two exceptions:

- **Gem-Cut dice** come only in Epic and Legendary finishes.
- **Classic** is one extra Common building finish: green houses and red hotels. It is the default building skin, so the board keeps its familiar look.

That gives 112 piece skins, 60 building-set skins and 33 dice skins. Defaults for every player in this project: the six seats get the first six pieces in table order, all in Pewter; buildings are Cottage + Inn in Classic.

Unique Epic and Legendary shapes are left to project 3, when the crate pool is designed.

## Model rules

- **Units:** 1 Blender unit = 1 stud. Origin at the centre of the base, +Y up in Roblox.
- **Footprints** match today's layout, so `TokenLayout` and `BuildingLayout` do not change:

| Kind | Footprint (studs) | Max height | Triangle budget |
|---|---|---|---|
| Piece | 1.4 diameter | 2.4 | 6,000 |
| House | 1.0 × 1.0 | 1.2 | 2,000 |
| Hotel | 2.2 × 1.4 | 2.0 | 2,000 |
| Die | 1.2 cube | 1.2 | 3,000 |

  Building budgets are low because a full board can show more than a hundred buildings.
- **Parts per model:**
  - Piece: `Base` (a ring, tinted in the player's seat colour so metal pieces stay tellable apart) and `Body` (takes the finish).
  - House and hotel: `Body` (finish) and `Trim` (accent colour: roof, door, windows).
  - Die: `Body` (finish) and `Pips` (accent colour). Opposite faces sum to 7; 1 faces +Y, 2 faces +Z, 3 faces +X. Project 2 relies on this.
- **Shading:** smooth shading with bevelled edges; no flat-shaded low-poly look.

## Pipeline

1. **Source.** One `.blend` per kind in `assets/blender/` (`pieces.blend`, `buildings.blend`, `dice.blend`), one collection per shape.
2. **Export.** Each shape to `assets/export/<Kind>/<Shape>.fbx`, modifiers applied.
3. **Upload.** `tools/upload-assets.ps1` sends new or changed exports to the Open Cloud Assets API as Model assets, using `curl.exe`. PowerShell because the machine has no Python. It reads the key from `.roblox-api-key` and the creator ID from `assets/upload.config.json`, and writes results to `assets/asset-ids.json` (shape → asset ID, plus the file hash so unchanged files are skipped). `.roblox-api-key` is added to `.gitignore`. Textures for the textured finishes go through the same script as Image assets.
4. **Catalogue.** `src/shared/Cosmetics/AssetIds.luau` is generated from `asset-ids.json` by the upload script, so IDs are never typed by hand.
5. **Runtime.** At startup the server loads each catalogue model once with `InsertService:LoadAsset` into `ReplicatedStorage.Assets`; clients clone from there. If the pipeline test shows `LoadAsset` cannot be used, the fallback is `AssetService:CreateMeshPartAsync` from mesh IDs, with no other change to this design.

**Pipeline test, before any other modelling:** the Rounded die goes through all five steps and appears in a running Studio session at the right size and orientation. This is the roadmap's agreed first step and it settles step 5.

## Code

**New, shared (pure):**

- `src/shared/Cosmetics/Finishes.luau` — the finish records and their rarities.
- `src/shared/Cosmetics/Catalog.luau` — shapes by kind with footprint and height, the skin list built from shapes × finishes with the two exceptions, and `Catalog.defaultPiece(seat)`, `Catalog.defaultBuildings()`. Skin IDs are strings like `piece.Rocket.Gold`.
- `src/shared/Cosmetics/AssetIds.luau` — generated.

**New, runtime:**

- `src/server/Assets.luau` — loads catalogue models into `ReplicatedStorage.Assets` at startup; logs and skips any that fail.
- `src/client/Skins.luau` — `Skins.build(skinId, seatColor?): Model?` clones the shape, applies the finish to `Body`, the accent to `Trim` or `Pips`, the seat colour to `Base`, anchors the primary part and welds the rest to it. Returns nil when the shape is not loaded.

**Changed:**

- `src/client/Tokens.luau` — a token is built with `Skins.build(Catalog.defaultPiece(seat), seatColor)`; `token.part` is the model's `Base`, so hops, hooks and the camera work unchanged. The bankrupt fade applies to every part of the model. If `Skins.build` returns nil, the cylinder is used as today.
- `src/client/Buildings.luau` — houses and hotels are built from the default building skin, with the same nil fallback to the blocks.
- `src/server/init.server.luau` — calls `Assets.load()`.

The fallbacks keep the game playable and the tests passing when assets are missing, which is the case in a fresh Studio session before any upload.

## Tests

- `Finishes.spec` — every finish has a valid rarity, material and colours; textured finishes have texture IDs.
- `Catalog.spec` — skin counts (112, 60, 33); IDs are unique; Gem-Cut has no Common, Uncommon or Rare skin; Classic exists only for buildings; every shape's footprint and height are inside the limits above; defaults exist for all six seats and are distinct.
- `AssetIds.spec` — every entry in `AssetIds` names a catalogue shape. From step 4 of the order of work onward it also requires an ID for every catalogue shape.
- `Tokens.spec`, `Buildings.spec` — existing tests keep passing through the fallback path.
- **Looks** are checked by eye: Blender viewport screenshots of each shape for the user's approval before upload, then Studio screenshots of the board with the models in place.

## Order of work

1. Pipeline test with the Rounded die.
2. Model the shapes: dice, then buildings, then pieces. The user approves screenshots of each batch before it is uploaded.
3. Finishes, textures and the catalogue module.
4. Upload everything and generate `AssetIds`.
5. Switch `Tokens` and `Buildings` to the models; Studio playtest.

## Constraints

- `--!strict`, tabs, short "why" comments, the repo's existing module patterns.
- No new top-level node in `default.project.json` (it forces a Rojo restart); `ReplicatedStorage.Assets` is created at runtime.
- All existing tests keep passing.
- The API key never enters git or any log.
