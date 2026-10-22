# Lobby Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the domed marble lobby with a giant walkable Monopoly board holding 12 game tables, where you join a game by sitting down at a table.

**Architecture:** `LobbyBuilder` (server) builds the place: the game's own `BoardBuilder` board scaled 3x as the floor, a wooden tabletop rim, props, corner features and 12 tagged table models with `Seat` chairs. Pure modules decide geometry (`TableLayout`, shared) and seating (`Tables`, server). `TableService` (server) wires chair prompts and seats to `RoomService` through injected callbacks (no circular require), redraws table signs and chair states on every rooms change, and reseats players returning from a game. The lobby HUD gains Quick Play.

**Tech Stack:** Luau (strict), Rojo, Roblox Studio; tests run in a Studio playtest via the `RunTests` workspace attribute.

**Spec:** `docs/superpowers/specs/2026-10-21-lobby-revamp-design.md`

## Global Constraints

- Lobby centre stays `LobbyBuilder.CENTRE = Vector3.new(0, 0, 900)` (far from the game board at the origin).
- Board scale `3`: board side `Layout.BOARD_SIZE * 3` (222 studs), centre square `(BOARD_SIZE - 2 * CORNER_SIZE) * 3` (162). Tile tops at y = 0.6; tabletop top at y = 0.5.
- 12 tables: casual ids 1–8, ranked ids 9–12. 6 chairs per table. Chairs 1..maxPlayers are usable.
- No emoji or decorative symbols in any text (signs, prompts, panels).
- Studio-only behaviour stays behind `RunService:IsStudio()`.

## Review Focus

1. A player who sits, then the game starts: their chair empties when the character is removed. This must not count as leaving the room. (Task 4 test: standing while the room is Playing only frees the chair.)
2. Two players taking the last free chair at the same moment: the second must get the existing "that game is full" notice and stay standing. (Task 2 test: `freeChair` returns nil when chairs 1..max are taken.)
3. A room whose host leaves while others are seated keeps its table; an emptied room frees its table for the next host. (Task 2 test: `sync` releases tables whose room is gone and keeps the rest.)
4. Creating from the menu when every table of that kind is busy: a clear notice, no room created. (Task 2 test: `assign` returns nil when full; Task 4 wires the notice "all casual tables are in use" / "all ranked tables are in use".)
5. Lowering a room's player limit below a seated chair index: the seated player keeps their chair (settings already never go below the member count; chairs are reassigned lowest-first so this can't strand anyone). (Task 2 test: `freeChair` hands out the lowest free index.)

---

### Task 1: TableLayout (shared geometry)

**Files:**
- Create: `src/shared/Lobby/TableLayout.luau`
- Test: `src/tests/TableLayout.spec.luau`

**Interfaces:**
- Produces: `TableLayout.COUNT = 12`, `TableLayout.CHAIRS = 6`, `TableLayout.TABLE_RADIUS = 6`, `TableLayout.CHAIR_RADIUS = 9.5`, `TableLayout.kind(id: number): "Casual" | "Ranked"`, `TableLayout.ids(kind): { number }` (ascending), `TableLayout.offset(id: number): Vector3` (table centre relative to the lobby centre, y = 0), `TableLayout.chair(index: number): CFrame` (relative to the table centre, facing it), `TableLayout.RANKED_AREA: { min: Vector2, max: Vector2 }` (x/z rectangle of the VIP carpet), `TableLayout.CENTRE_HALF = 81`.
- Grid: columns x = {-48, -16, 16, 48}; casual rows z = 38 (ids 1–4) and z = 6 (ids 5–8); ranked row z = -44 (ids 9–12). Ranked area x -68..68, z -66..-26. Chair i at angle (i-1)·60°.

- [ ] **Step 1: Write the failing tests** — `TableLayout.spec`:
  - `"twelve tables: eight casual, four ranked"`: `#ids("Casual") == 8`, `#ids("Ranked") == 4`, `kind(1) == "Casual"`, `kind(9) == "Ranked"`.
  - `"every table and chair fits in the centre square without overlapping"`: for each table, `|offset.X| + CHAIR_RADIUS + 1.5 <= CENTRE_HALF` and same for Z; any two tables' centres at least `2 * (CHAIR_RADIUS + 1.5)` apart.
  - `"six chairs round each table, facing it"`: for each chair, position magnitude ≈ `CHAIR_RADIUS`; `chair.LookVector:Dot(-chair.Position.Unit) > 0.99`.
  - `"ranked tables sit inside the ranked area, casual ones outside it"`.
- [ ] **Step 2: Run** `RunTests = "TableLayout"` — expect FAIL (module missing).
- [ ] **Step 3: Implement** `src/shared/Lobby/TableLayout.luau` with the values above.
- [ ] **Step 4: Run** — expect PASS.
- [ ] **Step 5: Commit** `lobby: table layout for the giant board's centre`.

### Task 2: Tables (server seating, pure)

**Files:**
- Create: `src/server/Lobby/Tables.luau`
- Test: `src/tests/Tables.spec.luau`

**Interfaces:**
- Consumes: `TableLayout.ids`, `TableLayout.kind`, `TableLayout.CHAIRS`.
- Produces:
  - `export type Seating = { tableOfRoom: { [number]: number }, roomAtTable: { [number]: number }, chairs: { [number]: { [number]: string } } }` (table id -> chair -> player id)
  - `Tables.new(): Seating`
  - `Tables.assign(s, roomId: number, ranked: boolean, wanted: number?): number?` — binds the room to `wanted` if it is free and of the right kind, else the lowest free table of that kind; nil when none.
  - `Tables.tableOf(s, roomId): number?`, `Tables.roomAt(s, tableId): number?`
  - `Tables.sync(s, liveRoomIds: { [number]: boolean })` — releases tables (and their chairs) whose room no longer exists.
  - `Tables.freeChair(s, tableId, maxPlayers: number): number?` — lowest index in 1..min(maxPlayers, CHAIRS) not taken.
  - `Tables.sit(s, tableId, chair, playerId)`, `Tables.stand(s, playerId): (number?, number?)` (returns the table and chair they left), `Tables.chairOf(s, playerId): (number?, number?)`
  - `export type RoomInfo = { id: number, ranked: boolean, status: string, players: number, maxPlayers: number }`
  - `Tables.quickPlay(s, rooms: { RoomInfo }): { join: number?, host: number? }?` — the waiting casual room with a table, a free seat and the most players (ties: lowest id); else `{ host = lowest free casual table }`; else nil.

- [ ] **Step 1: Write the failing tests** — `Tables.spec`:
  - `"assign takes the lowest free table of the room's kind"`: casual rooms 1, 2 → tables 1, 2; ranked room 3 → table 9.
  - `"assign honours a wanted free table and refuses a busy or wrong-kind one"`: wanted 5 → 5; wanted 5 again for another room → lowest free (not 5); wanted 9 for a casual room → a casual table.
  - `"assign returns nil when every table of that kind is taken"`: 8 casual rooms then a 9th → nil; ranked still assignable.
  - `"sync frees the tables of closed rooms only"`: rooms 1, 2 seated; `sync({[2]=true})` → `tableOf(1) == nil`, `roomAt(1) == nil`, chairs at table 1 cleared, room 2 kept.
  - `"free chairs go lowest first, within the player limit"`: sit chairs 1, 2 at table 1; `freeChair(s, 1, 4) == 3`; sit 3, 4 → `freeChair(s, 1, 4) == nil`; `freeChair(s, 1, 6) == 5`.
  - `"standing frees the chair and says which"`: `stand` returns (table, chair) then `chairOf` is nil; standing again returns nil.
  - `"quick play joins the fullest open casual room, else hosts at a free casual table"`: rooms {id 1 casual waiting 2/4}, {id 2 casual waiting 3/4}, {id 3 casual waiting 4/4}, {id 4 casual playing 1/4}, {id 5 ranked waiting 1/4} (all with tables) → `{ join = 2 }`; with only full/playing/ranked rooms → `{ host = <lowest free casual> }`; all casual tables taken and none joinable → nil.
- [ ] **Step 2: Run** `RunTests = "Tables"` — expect FAIL.
- [ ] **Step 3: Implement** `src/server/Lobby/Tables.luau`.
- [ ] **Step 4: Run** — expect PASS.
- [ ] **Step 5: Commit** `lobby: table seating rules`.

### Task 3: The board lobby (LobbyBuilder rewrite)

**Files:**
- Move: `src/client/TileEmblems.luau` → `src/shared/Board/TileEmblems.luau` (update its requires in `BoardView`), and give `TileEmblems.place(board: Model, scale: number?)` a scale multiplier for the emblem heights.
- Rewrite: `src/server/LobbyBuilder.luau`
- Modify: `src/client/LobbyFx.luau` (prompt hooks), `src/client/init.client.luau` (pass panel openers)
- Test: `src/tests/LobbyBuilder.spec.luau`

**Interfaces:**
- Consumes: `BoardBuilder.build`, `Layout`, `TileArt`, `TableLayout`, `TileEmblems.place`, `ReplicatedStorage.Assets`.
- Produces (tags and names `TableService` and `LobbyFx` rely on):
  - `LobbyBuilder.BOARD_SCALE = 3`, `LobbyBuilder.CENTRE`, `LobbyBuilder.TABLE_TAG = "LobbyTable"`, `LobbyBuilder.CHEST_TAG = "LobbyChests"`, `LobbyBuilder.CHALLENGES_TAG = "LobbyChallenges"`, `LobbyBuilder.SPIN_TAG`, `LobbyBuilder.BOARD_TAG` (unchanged names/values).
  - Each table: `Model` named `Table{id}`, tagged `TABLE_TAG`, attributes `TableId: number`, `Ranked: boolean`; children `Chairs` (Folder of `Seat`s named `Chair{i}`, attribute `Chair: number`, `CanTouch = false`, each with a `ProximityPrompt` named `SitPrompt`, `HoldDuration = 0`, `MaxActivationDistance = 10`), and `Sign` (a `BillboardGui` on an anchor part, with `TextLabel`s `Title` and `Status`).
  - `ProximityPrompt`s tagged `CHEST_TAG` (on the giant chest at Free Parking, ActionText "Open chests") and `CHALLENGES_TAG` (on the challenge board at Go To Jail, ActionText "Challenges").

Build steps (one `LobbyBuilder.build(parent)`):
1. Tabletop: a wood slab 400 x 20 x 400, top at y = 0.5; a raised wooden edge 3 high around it; invisible, collidable walls 60 high at the edge.
2. Board: `BoardBuilder.build(holder)` → `ScaleTo(BOARD_SCALE)`; every `SurfaceGui.PixelsPerStud /= BOARD_SCALE`; pivot so its centre is at `CENTRE` and tile tops at y = 0.6; `TileEmblems.place(board, BOARD_SCALE)`.
3. Spawn: an invisible neutral `SpawnLocation` (Transparency 1, CanCollide true, 12 x 1 x 12) on the GO tile's top.
4. Jail: the three leaderboard parts (same attributes/tag as today) standing in the jail cell, facing the lobby centre.
5. Free Parking: the giant `Emblems/Chest` (height 10) with the `CHEST_TAG` prompt. Go To Jail: a challenge board (dark panel with "CHALLENGES" in gold) with the `CHALLENGES_TAG` prompt.
6. Props (from Assets, when loaded): `Buildings/House` (height 12, green) on Baltic Avenue's band, `Buildings/Hotel` (height 18, red) on Boardwalk's band, a pair of `Dice/Rounded` (size 6) at centre offset (0, 64), one tagged `SPIN_TAG`; `Props/CashStack` (height 4) at (72, -8); `Pieces/TopHat` (height 10) at (-72, -8). Card piles: two 14 x 6 x 9 boxes at (±66, 62), Chance orange and Community Chest yellow, the deck's picture (`TileArt.IMAGES.Question` / `.Chest`) on the top face.
7. Ranked area: blue carpet over `TableLayout.RANKED_AREA`, gold rope stanchions along its front edge (z = -26) with a 16-stud gap in the middle, and a sign "RANKED" over the gap.
8. Tables: for each id, at `CENTRE + TableLayout.offset(id)`: a round top (radius `TABLE_RADIUS`, felt green casual / Boardwalk blue ranked, wood or gold rim), a little board (5.5-stud square, white with the 8 group colours along its edges), two small dice, a card stack; chairs at `TableLayout.chair(i)`; a sign anchor 9 studs above with the `Sign` billboard (MaxDistance 120).
9. Lighting: today's `setLighting` with `ClockTime = 15.5` and the roof-only Ambient lift removed (`Ambient = Color3.fromRGB(96, 90, 96)`).

- [ ] **Step 1: Write the failing tests** — `LobbyBuilder.spec` (build into a scratch folder):
  - `"builds twelve tables with six chairs each, where TableLayout puts them"`: 12 tagged models; each `TableId` matches its position `CENTRE + offset(id)` within 0.1; each has `Chairs` with 6 `Seat`s with `SitPrompt` and `CanTouch == false`.
  - `"the floor is the game board at three times size"`: `Lobby.Board.Tiles` has 40 tiles; the GO tile's top is at y ≈ 0.6 and its size ≈ `Layout.CORNER_SIZE * 3` across.
  - `"spawn on GO"`: one `SpawnLocation` whose position lies within the GO tile's footprint.
  - `"chest and challenge prompts are tagged"`: one prompt each.
- [ ] **Step 2: Run** `RunTests = "LobbyBuilder"` — expect FAIL.
- [ ] **Step 3: Move TileEmblems (with scale) and rewrite LobbyBuilder** as above.
- [ ] **Step 4: Run all tests** — expect PASS (BoardView still finds TileEmblems).
- [ ] **Step 5: LobbyFx**: keep the board/leaderboard/spin code; replace the kiosk hook with `LobbyFx.start(open: (panel: string) -> ())` hooking `CHEST_TAG` → `open("Chests")` and `CHALLENGES_TAG` → `open("Challenges")`; `init.client` passes `function(name) lobby:openPanel(name) end`.
- [ ] **Step 6: Studio check**: playtest, screenshots from above and from a character on GO. Fix anything ugly.
- [ ] **Step 7: Commit** `lobby: the giant board lobby`.

### Task 4: Sitting down to play (TableService + RoomService)

**Files:**
- Create: `src/server/Lobby/TableService.luau`
- Modify: `src/server/RoomService.luau`, `src/shared/Net/Protocol.luau`
- Test: `src/tests/Tables.spec.luau` (one more case), Studio playtest

**Interfaces:**
- Consumes: `Tables` (Task 2), table models (Task 3).
- Produces:
  - `TableService.start(handlers: { request: (Player, { [string]: any }) -> (), roomOf: (Player) -> { id: number, status: string }? })`
  - `TableService.seating: Tables.Seating` (the one shared seating RoomService also reads)
  - `TableService.seat(player: Player, tableId: number): boolean` — free chair, `Tables.sit`, `seat:Sit(humanoid)`.
  - `TableService.unseat(player: Player)` — `Tables.stand` and get them out of the chair.
  - `TableService.refresh(views: { Rooms.RoomView })` — `Tables.sync`, then each table's sign and chair states.
  - Protocol: `{ type = "QuickPlay" }` on the lobby remote; `RoomView.tableId: number?`.

Behaviour:
- Chair prompt (server `Triggered`): empty table → `request(player, { type = "Create", table = id, ranked = <table ranked>, settings = nil })`; waiting room → `request(player, { type = "Join", room = roomAt(id) })`. ActionText: "Host a game" / "Join game"; ObjectText: `Table {id}` (plus " · Ranked").
- `onLobbyRequest` Create: `Tables.assign(seating, room.id, ranked, request.table)` right after `Rooms.create`; if it returns nil, `Rooms.leave` the new room and notice `all casual tables are in use` / `all ranked tables are in use`. On success, and after a successful Join, `TableService.seat(player, table)`.
- QuickPlay: `Tables.quickPlay(seating, views)` → Join or Create (casual, default settings, that table); nil → notice "every table is busy right now".
- `leaveRoom` calls `TableService.unseat(player)`.
- Seat `Occupant` → nil for a seated player: `Tables.stand`; then if `roomOf(player)` is Waiting, `request(player, { type = "Leave" })`. While Playing, only the chair is freed.
- `CharacterAdded`: if `roomOf(player)` is Waiting and its room has a table, seat them (back from a game).
- `sendRooms` adds `tableId` to each view and calls `TableService.refresh(views)`.
- Signs: Title `Table {id}` (Ranked tables: `Ranked table {id - 8}`, gold); Status `Open · sit down to host` / `Waiting · {hostName} · {players}/{max}` / `Playing · {players} players`.
- Chairs: index > room's maxPlayers → grey (`Color` 120,120,120, `Transparency` 0.4) and prompt disabled; taken → prompt disabled; table Playing → all disabled.

- [ ] **Step 1: Write the failing test** — add to `Tables.spec`: `"standing up during a game frees the chair but the seating keeps the room's table"`: seat player at table 1 for room 1; `stand` → chair free; `tableOf(1) == 1`.
- [ ] **Step 2: Run** — expect PASS once Task 2 is in (the rule lives in Tables); if it fails, fix `stand`.
- [ ] **Step 3: Implement TableService and the RoomService/Protocol changes** above.
- [ ] **Step 4: Run all tests** — expect PASS.
- [ ] **Step 5: Studio playtest**: sit at table 1 (host), room panel opens, sign reads Waiting; jump → room gone, sign Open; sit again → Start → game runs (bots); play to the results (Studio `RoundLimit = 1`) → Back to lobby → seated at table 1 again. Ranked table sits create ranked rooms. Menu Create sits you at a free table.
- [ ] **Step 6: Commit** `lobby: sit at a table to host or join`.

### Task 5: HUD — Quick Play and table labels

**Files:**
- Modify: `src/client/Hud/LobbyHud.luau`
- Test: `src/tests/LobbyHud.spec.luau` if present, else Studio check

**Interfaces:**
- Consumes: `RoomView.tableId`, lobby request `{ type = "QuickPlay" }`.

- [ ] **Step 1**: In `renderGames` (Play view, no room): a full-width "Quick Play" primary button above the tabs (sends `{ type = "QuickPlay" }`), and the hint line "Or walk up to any table and sit down." Shift tabs and body down by the button's height.
- [ ] **Step 2**: Room cards show `Table {tableId}` before the player count; the room view's heading becomes `{room.name} · Table {tableId}`.
- [ ] **Step 3**: Run all tests — PASS. Studio: screenshot of the Play panel and of Quick Play seating you.
- [ ] **Step 4: Commit** `lobby: quick play and table labels`.

### Task 6: Review and wrap-up

- [ ] Full test run; Studio walk-through screenshots (spawn on GO, the tables, a sign, sitting, the VIP area, Free Parking chest prompt, jail leaderboards).
- [ ] Opus reviewer subagent over the branch diff; fix Important findings.
- [ ] Followups file `docs/superpowers/plans/2026-10-21-lobby-revamp.followups.txt` for deferred minors.
