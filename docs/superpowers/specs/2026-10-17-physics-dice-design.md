# Physics Dice — Design

Date: 2026-10-17. Agreed in conversation. Builds on the models and pipeline spec (2026-10-02), whose pipeline test produced the Rounded die (asset 73288478231290). This pulls "3D dice that roll on the board" forward from that spec's project 2; choosing dice skins stays there.

## Intent

When a player rolls, two real-looking dice are thrown onto the board, tumble, and come to rest showing the roll. The user's priority is that it **looks and feels real**; the numbers themselves stay fair server picks, as today.

## Decisions made

- **The server still decides the roll.** `GameService` keeps rolling with `Random`; the engine, rules and their tests do not change. The dice are made to land on those numbers.
- **Recorded real throws.** Throws are recorded once in Studio with the Roblox physics engine and stored as data. At runtime a client plays a random recording, turning each die inside it so the wanted face ends up on top (a cube looks the same whichever way it is turned, so this never shows). This gives genuine physics motion with a fixed duration and none of live physics' failures (cocked dice, dice knocked off the board, lag).
- **Played on each client.** Every client plays its own random recording of the same numbers, so the tumbles may differ between screens; the result never does. Nothing about the dice is replicated.
- **Staging: centre, big.** The camera stays overhead; the dice are scaled up so they read at that distance.

## What players see

- **Every roll uses the 3D dice:** a normal turn, a doubles attempt in jail, and the roll for a utility card. All three arrive as a `Rolled` event.
- **The throw:** two Rounded dice, scaled to 4 studs (the 1.2-stud model × 10/3), come in from the roller's side of the board over the edge of the centre area. They bounce and tumble and settle in the open centre with the server's numbers on top.
- **Resting dice** stay where they landed until the next roll, then vanish as the new pair is thrown. They are removed when the game ends.
- **Timing:** `Pacing.DICE_SECONDS` goes from 1 to 2: every recording settles within 1.6 s, then a 0.4 s beat to read the result. The token walk, bots and turn clock already follow this value through `Pacing.timeline`, so they wait for the dice with no other change.
- **HUD:** the large 2D "stage" dice in the middle of the screen are no longer shown. The small dice in the action bar stay and show the result, without their own tumble, when the 3D dice settle.
- **Camera:** unchanged. Overhead during the roll, then the existing chase camera on the walk.
- **Colours:** ivory body, black pips. Finishes and skins are the skins project's work.
- **Fallback:** if the die model is not loaded (no network, a fresh Studio session), the 2D stage dice play exactly as today.

## Board geometry used

From `Layout`: the board is 74 studs square and centred on the origin, the centre area is the 54-stud square inside the corners, and its top surface is at y = 1. Recordings are made on a flat surface at that height and must keep both dice within 20 studs of the centre on both axes, which leaves room for the 4-stud dice inside the tiles.

## Recording (Studio, development time)

**`src/server/DevTools/DiceRecorder.luau`.** Studio-only and inert in a live server (it checks `RunService:IsStudio()`). `init.server.luau` starts it when the workspace attribute `RecordDice` is set, like the existing `RunTests` hook.

- **Setup:** a temporary anchored floor matching the centre area (54 × 54, top at y = 1), well away from the board, plus two 4-stud dice (unanchored, server network owner, with the die model's collision box and density set to feel weighty).
- **Each throw** is framed as if the roller sits on the board's side 0 (+Z): the dice start above the +Z edge of the centre area and are thrown towards −Z with randomised start offset, linear velocity and angular velocity, with ranges tuned by eye.
- **Sampling:** both dice's CFrames, relative to the centre of the floor, at 30 Hz from release until both have been still for 0.2 s.
- **A throw is rejected** if it takes longer than 1.6 s to settle, a die ends more than 5° from flat, or a die leaves the ±20 stud box. (Solid physics dice cannot end up overlapping.)
- **Kept throws:** it runs until 30 are kept. The result is serialised into a `StringValue` in `ServerStorage`. I read it over Studio MCP and write it to `src/shared/Dice/Throws.luau`. Studio cannot write files, so this step is manual and only repeats when the throws are re-recorded.

**`src/shared/Dice/Throws.luau`** (generated, about 100 KB): a list of throws; each is two dice, each die its frames flattened as position and rotation quaternion, rounded to 3 decimals. The face that ended on top is read from the last frame.

## Runtime

**`src/shared/Dice/DiceThrow.luau`** — pure, no instances:

- `DiceThrow.faceUp(rotation: CFrame): number` — which number shows on top for a die at that rotation, using the model's face layout (1 = +Y, 2 = +Z, 3 = +X; opposites sum to 7).
- `DiceThrow.plan(throw, dice: {number}, side: number, spin: {number}): Plan` — per die, the CFrame for each frame, relative to the board centre. Each die's recorded CFrame is post-multiplied by a fixed rotation about its own centre (one of the 24 cube rotations) chosen so the target number ends up where the recorded top face was. `spin` (0–3 per die) adds a quarter turn about the up axis for variety. The whole throw is rotated by `side × 90°` about the board centre so it comes from the roller's side.
- `DiceThrow.side(position: number): number` — the board side (0–3) of a tile position, matching `Layout`'s sides.
- Randomness (which throw, which spin) is passed in, so the module stays deterministic under test.

**`src/server/Assets.luau`** — the minimal loader from the models spec. `Assets.load()` runs at startup, loads every entry in `AssetIds` with `InsertService:LoadAsset`, and puts the inner model, renamed to `<Shape>`, in `ReplicatedStorage.Assets.<Kind>`. The `Assets` folder is created at runtime, so `default.project.json` does not change. A failed load is logged and skipped.

**`src/client/DiceView.luau`**:

- `DiceView.new(): DiceView` builds two dice once the model appears in `ReplicatedStorage.Assets.Dice.Rounded`. It clones the model, scales it with `Model:ScaleTo`, colours `Body` and `Pips`, anchors every part and disables collision. Until then `ready()` is false.
- `roll(dice: {number}, side: number)` picks a random throw and spins, builds the plan, and plays it on `RenderStepped`, interpolating between the 30 Hz frames. A new roll stops any roll still playing.
- `clear()` hides the dice (used at game end and when the game returns to the lobby).

**`src/client/GameClient.luau`** — where it calls `hud:rollDice(event.dice)` today:

- If `diceView:ready()`, it calls `diceView:roll(event.dice, DiceThrow.side(position))`, using the roller's position before this update's move (from the previous snapshot the client holds). It then calls `hud:showRoll(event.dice)`, which sets the action-bar dice without the stage dice.
- Otherwise it calls `hud:rollDice(event.dice)` as now.

**`src/shared/Rules/Pacing.luau`** — `DICE_SECONDS = 2`.

**`src/client/Hud/HudView.luau`** — new `showRoll(dice)`: action-bar dice only, shown after `DICE_SECONDS − 0.4` so they appear as the 3D dice settle.

## Tests

- **`DiceThrow.spec`:** `faceUp` reads all six faces. For every recorded throw, all 36 pairs of numbers and all 4 sides, the last frame of the plan shows the target numbers up. The dice end inside the centre area. Side 0 is the identity, and sides 1–3 are the same throw turned by 90° steps. `side()` matches `Layout` for all 40 tiles.
- **`Throws.spec`:** at least 20 throws; each has the same frame count for both dice, lasts at most 1.6 s, and ends with both dice flat (within 5°) and at rest (the last two frames are equal).
- **`Pacing.spec`:** updated for the 2-second dice.
- **Existing tests** keep passing. `Assets` and `DiceView` touch the live engine and are checked by eye.
- **Looks:** a Studio playtest with screenshots: a roll from each side, doubles, a jail roll, and a utility-card roll.

## Order of work

1. `Assets.luau` and the startup call; check that the die loads in a playtest.
2. `DiceRecorder`; tune the throw ranges by eye; record 30 throws; generate `Throws.luau`.
3. `DiceThrow` with its specs (TDD), plus `Throws.spec`.
4. `DiceView`, the `GameClient` and HUD hookup, and `Pacing`.
5. Playtest and screenshots.

## Constraints

- `--!strict`, tabs, short "why" comments, the repo's existing module patterns.
- No new top-level node in `default.project.json`.
- The recorder never runs outside Studio.
- All existing tests keep passing.
