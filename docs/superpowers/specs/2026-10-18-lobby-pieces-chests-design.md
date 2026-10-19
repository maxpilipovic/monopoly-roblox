# Lobby, Casual Games, Pieces, Rent Effects and Chests — Design

Date: 2026-10-18. The user asked for all of this in one request and said "Dont ask for prompts just get it done and report back to me the decisions you made". So every choice below is mine, and the final report lists them.

## What was asked

1. Default pieces: top hat, battleship and race car.
2. A lobby that players spawn into, professional and beautiful, with their stats: best win streak, total wins and Elo.
3. A GUI in the lobby to find and join casual games. The creator sets the starting money, the number of players, whether auctions are on, and whether Free Parking pays out.
4. Free Parking money shown in the middle of the board as stacks of cash models.
5. Many new pieces with special effects, won from chests.
6. Special rent effects, won from chests.
7. Chests opened with Robux.
8. Remove the odd tile in the middle of the board.

## Decisions

### The odd tile
It is the place file's default `SpawnLocation` at the origin. Its star decal shows through the board's centre. The server destroys any `SpawnLocation` that isn't the lobby's at startup, and the lobby has its own spawn.

### Casual games: rooms in one server, boards drawn on each client
- **Rooms.** A server holds any number of rooms. Each room has a host, settings, members (up to its maximum) and at most one running game. Game updates go only to that room's members.
- **One board position for every room.** The board is built on each client, and only while that client is in a game. Every room can therefore use the same board coordinates without boards overlapping, and the layout, tokens, camera and dice code stay unchanged. The board is no longer built on the server.
  - `BoardBuilder` moves to `src/shared/Board`.
  - `TileEmblems` moves to the client.
- **Why not teleporting to reserved servers:** that needs a second place, publishing, and can't be tested in Studio.
- **Lobby and game.** The lobby world is far from the board (centred at z = 900), so players in the lobby never see a board. When a game starts, its members' characters are removed and the board camera takes over. When they go back to the lobby, their characters respawn there.
- **Room settings** (`RoomSettings`, shared and validated on the server):
  - `maxPlayers`: 2–6, default 4. Bots fill seats that nobody took, if `bots` is on (the default).
  - `startingMoney`: 500–5,000 in steps of 250, default 1,500.
  - `auctions`: on/off, default on. When off, a declined property simply stays with the bank.
  - `freeParking`: on/off, default off. When on, taxes, fines and card payments to the bank go into a pot, and landing on Free Parking collects it.
  - `timer`, `length` and `map`, as today.
- **Flow:**
  - Players can create a game, join from the list, or leave.
  - The host can change settings while the room is waiting, and can start once at least one human is in it.
  - After a game, the results screen shows, then the room returns to waiting with the same members.
  - If the host leaves, the next member becomes host. An empty room is removed.

### Free Parking pot
- **Engine:** `state.freeParkingPot`. A `transfer` to the bank with reason Tax, Card (Pay or Repairs) or JailFine adds to the pot when the setting is on. Landing on Free Parking pays the pot out (`Paid`, reason `FreeParking`) and emits `FreeParkingPaid`. The snapshot carries `freeParkingPot`.
- **Display** (client): a plaque in the board's centre reads "FREE PARKING $X". Beside it, stacks of the new cash model grow with the pot: one stack per $100, up to 12 stacks of 1–6 bundles each, arranged in a fan. They pop in and out as the pot changes.

### Player data, stats and Elo
- `PlayerData` (server) keeps one DataStore key per player in `PlayerData_v1`:
  - `stats`: `wins`, `games`, `streak`, `bestStreak`, `elo` (starting at 1000)
  - `inventory`: owned piece and effect ids, with counts
  - `equipped`: `{ piece, rentEffect }`
  - `receipts`: the last 50 purchase ids, so a purchase is never granted twice
- Profiles load on join, with retries, and save on leave, after each game, after each purchase, and on shutdown. If DataStores aren't available (a Studio place without API access), the profile lives in memory and a warning is logged.
- **Elo** (pure `Elo` module), applied at game over to the humans in that game:
  - The winner is scored as beating every other player.
  - The others are scored as drawing with each other.
  - K = 32, scaled by 1/(n−1). Bots count as fixed 1000-rated opponents, so a solo game against bots still moves Elo slightly.
- **Streaks:** a win adds to `streak` and raises `bestStreak` when beaten; a loss resets `streak` to 0.
- **Leaderboards:** OrderedDataStores for wins, Elo and best streak, refreshed every 60 s. The lobby shows the top 10 of each on three boards. If OrderedDataStores aren't available, the boards show the players in the server.

### Pieces
- **Defaults** (everyone owns them): Top Hat, Battleship, Race Car. New players have the Top Hat equipped.
- **Chest pieces:** 12 new shapes, each with its own effect:

| Piece | Rarity | Effect |
|---|---|---|
| Rubber Duck | Common | bubbles |
| Cactus | Common | sand puffs |
| Anchor | Common | water droplets |
| Robot | Rare | neon glow and sparks |
| Lighthouse | Rare | a sweeping beam |
| Trophy | Rare | confetti |
| Rocket | Epic | a fire trail |
| Ghost | Epic | a translucent body and drifting mist |
| UFO | Epic | a tractor-beam glow |
| Crown | Legendary | gold sparkles and a halo |
| Diamond | Legendary | a frost shimmer and a light |
| Skull | Legendary | purple flames |

- **Models:** made in Blender with scripted geometry, like the dice and buildings. The footprint is 1.4 studs and the height at most 2.4.
- **Tokens:** a token is now its piece's model, welded to the existing invisible root part. The hops, the camera and the jail logic don't change. A seat-coloured ring at the base keeps pieces tellable apart. If a model isn't loaded, the old coloured cylinder is used.
- **Effects** (client `PieceEffects`): particles, trails and lights built from code by effect id, attached to the piece.
- **Snapshot:** `PlayerView` gains `piece` and `rentEffect`, filled from player data. Bots get random defaults.

### Rent effects
- **Catalogue:**

| Effect | Rarity |
|---|---|
| Coin Burst | Common |
| Confetti Pop | Common |
| Money Rain | Rare |
| Golden Aura | Rare |
| Lightning Strike | Epic |
| Fireworks | Epic |
| Black Hole | Legendary |

- **When it plays:** when a `Paid` event with reason `Rent` plays, the receiver's equipped effect plays over the payer's token. The receiver is shown flexing on the payer. "None" is the default.

### Chests (Robux)
- **Three chests:**

| Chest | Price | Common | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Silver | 49 R$ | 70% | 25% | 4.5% | 0.5% |
| Gold | 149 R$ | 35% | 45% | 17% | 3% |
| Diamond | 399 R$ | 0% | 40% | 45% | 15% |

- **Which item:** inside a rarity, the item is picked evenly from that rarity's pieces and effects. Duplicates are allowed and counted.
- **Odds are shown** in the shop before purchase, as Roblox's paid-random-items policy requires.
- **Purchases:**
  - Developer Products, with ids in `src/shared/Store/Products.luau`.
  - The ids are 0 until the products are created on the Creator Dashboard. The API key doesn't have permission to create products.
  - While an id is 0, Studio offers a free test open, and a live server refuses.
- **Server:** `MarketplaceService.ProcessReceipt` → find the chest by product id → skip a purchase id already granted → roll → grant → save → return `PurchaseGranted`. If anything fails it returns `NotProcessedYet`, so Roblox retries.
- **Client opening:** the chest model shakes, bursts open, and reveals the item on a card with its rarity colour. The item can be equipped right there.

### Lobby world
- **Built from code** by the server's `LobbyBuilder`, so it lives in git:
  - a round marble plaza 140 studs across with a gold inlay ring
  - a central fountain with water and sparkles, topped by a giant turning die (the uploaded die model)
  - giant house, hotel and emblem statues on plinths around the plaza
  - lamp posts with warm lights, and colonnade arches
  - three leaderboard boards
  - a spawn pad
- **Lighting:** a warm late-afternoon look, with atmosphere, bloom and sun rays.
- **Lobby HUD** (client): a stats card at top left with your avatar, name, Elo, total wins, best streak, current streak and games played. A bottom dock has Play (the casual games browser), Pieces (equip pieces and rent effects) and Chests (the shop).
- **The browser:**
  - A list of rooms, each showing its name, host, players/max, settings chips and status, with a Join button.
  - "Create game" opens a settings panel: players, starting money, auctions, Free Parking, bots, timer, length, map.
  - Inside a room: the member list, settings (editable by the host) and Start (host only).

## Tests (pure modules first)
- `RoomSettings.spec`: validation, clamping and defaults.
- `Rooms.spec`: create, join, leave, host handover, max players, start rules, list view.
- `FreeParking.spec` (engine): the pot fills from tax, card and fine payments only when the setting is on, and pays out on landing.
- `Auctions.spec`: a declined property stays unowned when auctions are off.
- `StartingMoney.spec`: every player starts with the room's amount.
- `Elo.spec`: the expected results add up and the changes go the right way, including against bots.
- `Profile.spec`: game records, streaks, granting, equipping (owned items only) and receipt de-duplication.
- `Chests.spec`: the odds add up to 1, the roll is deterministic for a given random seed, and every catalogue item can drop from some chest.
- `PieceCatalog.spec`: ids are unique, the defaults are owned, every piece has an effect id and every rarity is valid.
- `CashStacks.spec`: pot → stack layout.
- Existing tests keep passing, with requires updated for the moved `BoardBuilder`.

## Out of scope
Ranked queues, trading items, and selling items for currency.

## Addendum (2026-10-19): Ranked and Unranked, rated by placement

At the user's request:
- **Unranked** is the casual rooms above; they never change rating.
- **Ranked** is a matchmaking queue.
  - **Modes:** Duel (2) or Table (4). Each player's rating window starts at ±100 and widens by 5 a second, up to ±600.
  - **Fixed rules:** $1500, auctions on, no Free Parking pot, no bots, the Relaxed timer, and 30 or 60 minutes.
- **Ratings feel like chess.**
  - Everyone starts at 1000. The first 20 ranked games are provisional (K 40); after that K is 20, and 10 at 2100+.
  - Titles run from Beginner to Grandmaster (`Ranks`).
- **Every place counts** (`Placement`, `Elo`).
  - The finishing order is: the winner, then the solvent players by net worth (equal net worth shares a place), then the bankrupt players in reverse order of going broke.
  - Each pair of players is scored like a chess game: above is a win, below a loss, the same place a draw. K is shared out over the table.
  - Walking out places you as if you went broke that moment.
- **Leaderboards and streaks** track ranked play only (ranked wins, Elo, best ranked streak); total wins count every game.
