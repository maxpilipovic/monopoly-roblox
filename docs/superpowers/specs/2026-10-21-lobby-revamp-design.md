# Lobby Revamp — Design

Date: 2026-10-21. Agreed in conversation: giant walkable board, sit at a table to join, ranked in its own VIP area.

## Intent

The lobby should say "Monopoly" the moment you spawn, and joining a game should need no menu: walk to a table, sit down, play. Today's domed marble hall (fountain, statues, kiosks) goes; the menus stay as a backup and for quick play.

---

## 1. The place: a giant board

**What players see:** you spawn on **GO** of a huge Monopoly board lying on a wooden tabletop. The board's 40 tiles are the floor of the lobby: colour bands, names and prices, the printed corners (Go, Jail, Free Parking, Go To Jail), Chance and Community Chest, with giant locomotives on the railroads and the bulb and tap on the utilities. You are tiny on it, like a playing piece.

- The board is the game's own board (`BoardBuilder` + `TileArt`) built 3x size (74 → 222 studs a side; tiles 18 wide, corners 30), flush with the tabletop so it is all walkable. SurfaceGui pixel densities are divided by the scale so the words stay crisp at the larger size.
- Around the board: a wide wooden tabletop rim with a raised edge and invisible walls, under a warm "game night" sky.
- **Giant props** on and beside the board, as decor: a green house and a red hotel on property tiles, a pair of dice resting near Go, a fanned stack of cash near Free Parking, a top hat, and the Chance and Community Chest decks as tall card piles in the centre.
- **Corners as places:**
  - **Go** — the spawn.
  - **Jail** — the three leaderboards stand inside the jail cell ("the Hall of Fame behind bars"), facing the visitors.
  - **Free Parking** — a giant treasure chest that opens the Chests panel (proximity prompt), beside the parked car.
  - **Go To Jail** — the officer next to a challenge board that opens the Challenges panel.
- Removed: dome, colonnade, fountain, statues, kiosks.

## 2. Game tables in the centre

**What players see:** the board's centre square (162 studs) holds **12 round game tables**, 4 columns by 3 rows. The front two rows are **casual** (8 tables: wood with green felt); the back row is the **ranked VIP area** (4 tables: gold trim, Boardwalk-blue felt) on a blue carpet behind gold rope stanchions, with a "RANKED" sign over the gap in the rope.

Each table:
- A round table top with a little board on it (a coloured square with property-colour edges), two dice and a card stack.
- **Six chairs** facing the table (Roblox `Seat`s, touch-sitting disabled so nobody joins by bumping into one).
- A **sign** floating above it: `Table 3`, then `Open — sit down to host` / `Waiting · Max (host) · 2/4` / `Playing · 3 players`; ranked tables say `Ranked` in gold.
- Chairs past the room's player limit (a 4-player room) are tucked in and greyed, with no prompt.

## 3. Sitting down to play

- Each free chair has a proximity prompt: **"Host a game"** at an empty table, **"Join game"** at a waiting one. Taking it sits you down and puts you in that table's room (create or join, with the existing `Rooms` rules and error messages; ranked keeps its rating-readable check).
- The first person to sit is the **host**. Sitting opens the **room panel** (today's room view: settings, who's in, Start, Leave) on the right of the screen. Others see the same panel without the controls.
- **Standing up** (jump) leaves the room while it's waiting. The panel's Leave button stands you up.
- **Start** works as today. The game starts at the table: the room's players go to the board as now.
- **After the game** ("Back to lobby"), you respawn **sitting at your table**, still in the room, ready for a rematch; stand up to leave. Matched-queue rooms (dormant) still dissolve.
- **The menus still work, through the tables:** Create game and Join in the Play panel take a free table (or the room's table) and sit your avatar in a chair there. Every waiting room has a table, so the lobby is never out of sync with the menus.
- **Quick Play:** a big button at the top of the Play panel. It sits you at the fullest casual table still waiting with a free chair; failing that, it hosts at an empty casual table with default settings.
- If all tables of a kind are taken, creating says so ("all casual tables are in use").

## Units

- `src/shared/Lobby/TableLayout.luau` (new, pure): table ids, kinds (casual 1–8, ranked 9–12), each table's centre relative to the lobby centre, each chair's CFrame relative to its table.
- `src/server/Lobby/Tables.luau` (new, pure): which table a room sits at, and seating. `Tables.assign(reg, roomId, ranked) -> tableId?`, `Tables.release`, `Tables.tableOf(roomId)`, `Tables.roomAt(tableId)`, `Tables.freeChair(table, members, maxPlayers) -> chair?`, `Tables.quickPlay(rooms, tables) -> { join = roomId } | { host = tableId } | nil`. TDD.
- `src/server/Lobby/TableService.luau` (new): builds nothing; finds the table models `LobbyBuilder` made, wires prompts and seats to `RoomService` (create/join/leave), sits avatars, redraws signs and chair states on every rooms change, and reseats players returning from a game.
- `RoomService`: create/join take a table; leaving frees a chair; returns to lobby seat players back at their table; `RoomView` gains `tableId`. Exposes the small API `TableService` needs (`create`, `join`, `leave`, `onRoomsChanged`).
- `src/server/LobbyBuilder.luau`: rewritten for the board, rim, props, corners and tables (tagged for `TableService` and `LobbyFx`).
- `src/client/LobbyFx.luau`: leaderboards move to the jail; the chest and challenge prompts open their panels; the giant dice turn slowly.
- `src/client/Hud/LobbyHud.luau`: Quick Play button; the room panel opens on sitting and closes on standing; "Table N" on room rows.
- `Protocol`: `{ type = "QuickPlay" }` on the lobby remote; `RoomView.tableId`.

## Tests

- `TableLayout.spec`: 12 tables inside the centre square, not overlapping; 6 chairs per table, facing it; ranked tables behind the casual ones.
- `Tables.spec`: assigning prefers the right kind and fails when full; one room per table; release frees it; free chair respects the player limit and taken chairs; quick play prefers the fullest waiting casual table with room, then an empty table, never ranked or playing tables.
- `RoomService`/existing room tests keep passing; a room created from the menu gets a table.
- Studio: screenshots of the board lobby, a table sign, sitting and hosting, the room panel, a game started from a table, and coming back seated.

## Not in scope

Spectating a running game from its table; table chat bubbles (chat is already per table in game); a tutorial.
