# Lobby Revamp — Design

Date: 2026-10-21. Revised the same day after the user saw the first build: **keep the domed marble hall** (the giant-board floor was rejected) and put the game tables in it; **four casual tables**, not eight.

## Intent

Joining a game should need no menu: walk to a table, sit down, play. The hall stays as it was (fountain, statues, kiosks, leaderboards); tables are added. The menus stay as a backup and for quick play.

## 1. Tables in the hall

- **Four casual tables** round the fountain, inside the statues, one in each quarter between the red carpets (wood, green felt).
- **Four ranked tables** in a **VIP area** at the far side of the hall from the spawn, in front of the leaderboards: a blue carpet sector, gold posts with velvet rope along its inner edge, and a gold arch reading RANKED where the red carpet runs in. Ranked tables have gold trim, Boardwalk-blue felt.
- Each table: a round top with a little board, two dice and card stacks; **six chairs** (`Seat`s, no sitting by bumping into them); a **sign** above it (`Table 2` / `Ranked table 1`, then `Open · sit down to host` / `Waiting · host · 2/4` / `Playing · 3 players`). Chairs past the room's player limit are greyed with no prompt.

## 2. Sitting down to play

Unchanged from the first design: chair prompt "Host a game" / "Join game"; sitting opens the room panel; standing (jump) leaves a waiting room; Start as today; after the game you come back seated at your table; menu Create/Join seat you at a table; **Quick Play** in the Play panel seats you at the fullest open casual table or hosts at a free one; "all casual tables are in use" when none is free.

## Units

- `src/shared/Lobby/TableLayout.luau` (pure): 8 tables (casual 1–4, ranked 5–8), `offset(id)`, `chair(i)`, `number(id)` (per-kind number for labels), the hall's `PLAZA_RADIUS`, `FOUNTAIN_RADIUS`, `CARPET_ANGLES`, `RANKED_AREA` (sector).
- `src/server/Lobby/Tables.luau` (pure): table assignment, chairs, quick play.
- `src/server/Lobby/TableService.luau`: prompts, seats, signs, reseating, wired to `RoomService`.
- `src/server/LobbyBuilder.luau`: the hall as before, plus the VIP area and the tables.
- `src/client/Hud/LobbyHud.luau`: Quick Play, table labels.
- `Protocol`: `{ type = "QuickPlay" }`; `RoomView.tableId`.

## Not in scope

Spectating a running game from its table; a tutorial.
