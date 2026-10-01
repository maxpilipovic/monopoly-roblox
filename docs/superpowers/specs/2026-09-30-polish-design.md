# Polish Milestone — Design

Date: 2026-09-30. Agreed in conversation; each part gets its own implementation plan, built in order A → B → C. D is a note for later.

## Intent

Make the game feel finished to play: you can see who owns what at a glance, the camera puts you in the action instead of a fixed overhead shot, and there is a second, college-themed map to choose. The classic board stays as it is (the user's call; see the IP note under C).

---

## A. Ownership markers

**What players see:** a thin strip in the owner's seat color along each owned tile's outer edge (the board-edge side, opposite the color band and houses). The seat color is the one already used for that player's token and their name in the player list. Mortgaged deeds show a dark-gray strip with short owner-colored caps at each end. Unowned tiles show nothing.

**Units:**
- `src/shared/Board/OwnerLayout.luau` (new, pure): `OwnerLayout.cframe(position): CFrame` and `OwnerLayout.SIZE` — the strip's centre on the tile's top face along the outer edge, full tile width minus a small margin, 0.6 studs deep, 0.1 thick. Asserts the tile is ownable (Property, Railroad, Utility). Same math style as `BuildingLayout`.
- `src/client/OwnerMarkers.luau` (new): mirrors `Buildings.luau`. `OwnerMarkers.wanted(snapshot): { [number]: { seat: number, mortgaged: boolean } }` (pure); `apply(snapshot)` adds/removes/recolors only strips that changed; nil snapshot clears all.
- `GameClient`: `markers:apply(update.snapshot)` next to `buildings:apply`.

No server or protocol change: the snapshot already carries owner, mortgaged and each player's seat.

**Tests:** `OwnerLayout.spec` (strip lies inside the tile, on the outer edge, opposite the band; corners and tax tiles rejected), `OwnerMarkers.spec` (`wanted`: seat by owner, mortgaged flag, unowned omitted, nil snapshot → empty). Studio screenshot for the look.

---

## B. Camera

**What players see:**
- **Overhead, a little closer.** The resting view zooms in about 15% from today's fit (`OVERHEAD_ZOOM = 0.85` of the fitted distance), still fitted to the screen's aspect so phones in portrait see the whole board.
- **Chase on every move.** When any token (human or bot) starts moving, the camera swoops down behind it at a low angle and follows it hop by hop, looking along the direction of travel (turning at corners). When it lands, the camera holds on it for 1 second, then eases back to the overhead view over 0.8 seconds. A move that starts during the hold or the return takes the camera straight to that token.
- `ToJail` moves (a jump, not a walk) don't chase: the overhead view stays.

**Followups folded in:** field of view pinned to 70 at start; the camera is re-taken after a respawn (CharacterAdded) as well as on CameraType changes; tile labels get a `UITextSizeConstraint` so long names don't overflow on small screens.

**Units:**
- `BoardCamera.luau` (existing, extended, pure functions): `getOverheadCFrame` gains the zoom; new `BoardCamera.heading(fromPosition, toPosition): Vector3` (unit direction along the board between two tiles) and `BoardCamera.chaseCFrame(tokenPosition: Vector3, heading: Vector3): CFrame` (camera `CHASE_BACK` studs behind, `CHASE_UP` above, looking a few studs ahead of the token).
- `src/client/CameraDirector.luau` (new): a small state machine — `Overhead`, `Following(part, heading)`, `Holding(until)`, `Returning(from, startedAt)` — whose transitions are a pure function `CameraDirector.next(state, event, now)` (events: `MoveStarted`, `Hopped`, `MoveFinished`, `Tick`). A `RenderStepped` loop eases `camera.CFrame` toward the target each frame.
- `Tokens.luau`: `Tokens.new(parent, hooks?)` with optional `onMoveStarted(part, move)`, `onHop(part, fromPosition, toPosition)`, `onMoveFinished(part)` called from `runQueue`. No other behavior change.
- `init.client.luau` / `GameClient`: wire Tokens hooks to the director.

**Tests:** `BoardCamera.spec` (zoomed overhead is closer than the fit and still sees the board for 16:9 and 9:16; heading along each side and around a corner; chase camera is behind and above the token and looks toward it), `CameraDirector.spec` (state transitions: start → following, finish → hold → return → overhead after 1.8 s; a new move during hold/return follows the new token; ToJail never follows). Feel is tuned by playtest screenshots.

---

## C. College map

**What players see:** a **Map** option in the lobby, next to Timer and Length — `Map: Classic` / `Map: College` — set by whoever presses Start. The College map has the same board shape, prices, rents, color groups and card effects as Classic; only names and card text change, so all the rules (and bots) work unchanged. Card decks are titled **Pop Quiz** (Chance) and **Student Union** (Community Chest) on the college map.

**Architecture — one active map:** the server runs one game at a time, so instead of threading a map through 53 call sites, the board data has a single active map:
- `Tiles.use(mapId)` swaps `Tiles.list` (all callers already read `Tiles.list` / `Tiles.at` at call time; `Tiles.at` changes to read `Tiles.list`). `Tiles.MAPS = { "Classic", "College" }`.
- `Cards`: `byId` holds **both** maps' cards (college ids are prefixed `college.`), so a card id is meaningful on any client regardless of map. `Cards.use(mapId)` picks which ids `idsFor(deck)` deals and which titles `DECK_TITLES` shows.
- `src/shared/Board/Maps.luau` (new): `Maps.use(mapId)` calls both; `Maps.current()`.
- `MatchSettings` gains `map` ("Classic" default | "College"), with `nextMap` / `mapLabel`, validated like timer and length.
- `Engine.new(..., map?)` calls `Maps.use(map or "Classic")` and stores `state.map`, so every test's fresh game resets to Classic (a failed College test can't leak into others).
- `Snapshot` carries `map`; `GameClient` calls `Maps.use(snapshot.map)` before drawing anything.
- `BoardBuilder.relabel(model)` rewrites tile labels for the active map; `GameService` calls it when a game starts.
- Lobby: a Map cycle button in `HudView` like Timer/Length.

**College content** (positions, kinds, prices, groups identical to Classic):

| Pos | Classic | College |
|---|---|---|
| 0 | Go | Orientation |
| 1, 3 | Mediterranean, Baltic | Freshman Dorm, Basement Laundry |
| 4 | Income Tax $200 | Tuition $200 |
| 5, 15, 25, 35 | Reading, Pennsylvania, B&O, Short Line | North / East / South / West Campus Shuttle |
| 6, 8, 9 | Oriental, Vermont, Connecticut | Library Annex, Study Hall, Writing Center |
| 10 | Jail | Dean's Office |
| 11, 13, 14 | St. Charles, States, Virginia | Art Studio, Music Hall, Theater |
| 12 | Electric Company | Campus Wi-Fi |
| 16, 18, 19 | St. James, Tennessee, New York | Coffee Shop, Bookstore, Food Court |
| 20 | Free Parking | The Quad |
| 21, 23, 24 | Kentucky, Indiana, Illinois | Chemistry Lab, Physics Lab, Engineering Hall |
| 26, 27, 29 | Atlantic, Ventnor, Marvin Gardens | Fraternity Row, Sorority Row, Rec Center |
| 28 | Water Works | Dining Hall |
| 30 | Go To Jail | Caught Cheating |
| 31, 32, 34 | Pacific, North Carolina, Pennsylvania Ave | Business School, Law School, Medical School |
| 37, 39 | Park Place, Boardwalk | President's House, Football Stadium |
| 38 | Luxury Tax $100 | Parking Ticket $100 |
| 2, 17, 33 / 7, 22, 36 | Community Chest / Chance | Student Union / Pop Quiz |

Cards mirror Classic one for one (same effect, same order, id `college.<classic id>`):

*Pop Quiz (Chance):* dividend — "Your campus job pays out. Collect $50." · loan — "Your scholarship comes through. Collect $150." · speeding — "Library late fee: pay $15." · boardwalk — "Tickets to the big game: advance to the Football Stadium." · go — "Back to Orientation. Collect $200." · illinois — "Advance to Engineering Hall. If you pass Orientation, collect $200." · stCharles — "Advance to the Art Studio. If you pass Orientation, collect $200." · reading — "Catch the North Campus Shuttle. If you pass Orientation, collect $200." · railroad1/2 — "Run for the nearest shuttle. If it is owned, pay the owner twice the fare." · utility — "Head to the nearest utility. If it is owned, roll the dice and pay the owner ten times the roll." · jailFree — "Doctor's note: get out of the Dean's Office free. Keep this card until needed." · back3 — "Forgot your student ID. Go back 3 spaces." · jail — "Caught plagiarizing. Go to the Dean's Office. Do not pass Orientation, do not collect $200." · repairs — "Dorm damage inspection: pay $25 per house and $100 per hotel." · chairman — "Elected class president. Buy each player a $50 pizza."

*Student Union (Community Chest):* taxRefund — "Textbook buyback. Collect $20." · bankError — "Financial aid office error in your favor. Collect $200." · doctor — "Campus clinic copay. Pay $50." · stock — "Sold your old laptop. Collect $50." · go — "Back to Orientation. Collect $200." · jailFree — "Get out of the Dean's Office free. Keep this card until needed." · jail — "Pulled the fire alarm. Go to the Dean's Office. Do not pass Orientation, do not collect $200." · holiday — "Summer internship pays off. Collect $100." · birthday — "It's your birthday. Collect $10 from every player." · lifeInsurance — "Won the hackathon. Collect $100." · hospital — "Slept through the final. Pay $100 to retake it." · school — "Lab fees due. Pay $50." · consultancy — "Tutored a classmate. Collect $25." · streetRepairs — "Housing fines for your parties: pay $40 per house and $115 per hotel." · beautyContest — "Second place in the talent show. Collect $10." · inherit — "Care package from home with $100 inside." Any Classic card not listed here gets a college line in the same spirit; the test below guarantees none is missed.

**Tests:** `Maps.spec` (College tiles match Classic in position, kind, price, group, rent, amount — only names differ; every Classic card has a `college.` twin with an identical effect, in the same order; `use` switches `Tiles.at`, `Cards.idsFor`, `DECK_TITLES` and back), `MatchSettings` (map validates, cycles, labels), `Engine` (a College game deals college card ids; a new game without a map is Classic), `Snapshot` (carries map), `EventText` (a college card line uses its text and the Pop Quiz title). Playtest: start a College game, land on a card tile, check labels and card popup.

**IP note (recorded, user's decision):** the Classic board keeps Monopoly's street names, card text and title. Publishing that on Roblox risks a takedown; the College map could be the public default with Classic renamed later. Nothing in A–C depends on this.

---

## D. Models (later — not planned yet)

Tokens, houses/hotels, dice, a jail cell model, and a ToJail animation that doesn't read as a teleport. Open question: Blender MCP vs Roblox-generated meshes. To be brainstormed as its own sub-project after C.

## Error handling and constraints (all parts)

- `--!strict`, tabs, short "why" comments, the repo's existing module patterns.
- Client renderers tolerate nil snapshots (lobby) and destroyed instances.
- Unknown map ids fall back to Classic everywhere (`MatchSettings.validate`, `Maps.use` asserts only on programmer error).
- All existing 293 tests keep passing.
