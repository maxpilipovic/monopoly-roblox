# College Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A second, college-themed map, picked in the lobby, with its own tile names and its own Pop Quiz / Student Union cards; the classic map is unchanged.

**Architecture:** One active map. `Tiles` and `Cards` each hold both maps' data and expose the active one through the fields every caller already reads (`Tiles.list`, `Tiles.at`, `Cards.idsFor`, `Cards.list`, `Cards.DECK_TITLES`); `Cards.byId` holds both maps' cards so any card id resolves anywhere. `Maps.use(id)` switches both. `Engine.new` sets the map (so every fresh game, including every test's, starts from a known map), `Snapshot` tells clients which map is on, and the server relabels the board when a game starts.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Rojo 7.7, tests run inside Studio.

**Spec:** `docs/superpowers/specs/2026-09-30-polish-design.md`, section C (the name table and card texts are the source of truth for content).

## Global Constraints

- Every module starts with `--!strict`; tabs; short comments that say why; match the surrounding module patterns.
- Classic stays exactly as it is: names, card text, ids, order. All existing tests keep passing untouched.
- College mirrors Classic in everything but names and card text: same positions, kinds, prices, groups, rents, tax amounts, card effects and card order; college card ids are `college.<classic id>`.
- Map ids: `"Classic"` (default) and `"College"`. Unknown ids from the network fall back to Classic (`MatchSettings.validate`); `Maps.use` with an unknown id is a programmer error and asserts.
- Deck titles on the college map: Chance → "Pop Quiz", Community Chest → "Student Union".
- Any test that switches to College must switch back to Classic even when it fails (use the `onCollege` helper from Task 1).
- Tests run in Studio, not a shell (stop playtest → start playtest → assert the edited script's `.Source` has a new line → `require(game.ServerStorage.Tests.TestRunner).run("<Spec>")` on the **Server** datamodel). Never `git checkout`/`git switch` to a branch with different files while Rojo is connected.

## Review Focus

1. A client that joins mid-game (or whose Studio session was on another map) shows the right names and card text: the map comes from the snapshot, before anything is drawn. (Task 4 playtest step; Task 3 snapshot test.)
2. A College game followed by a Classic game: the second game's decks, names and board labels are Classic again. (Task 3 test "a new game without a map is Classic, even after a College game"; Task 4 relabel test.)
3. A card drawn on the College map but described after the map changed (log replay on the results screen) still has text: ids resolve through `Cards.byId` for both maps. (Task 1 test "every card id resolves whatever map is active".)
4. Garbage map values from the network (`map = 5`, `map = "college"`) start a Classic game. (Task 2 test.)
5. Bots on the College map behave exactly as on Classic (they only read kinds, prices and groups). (Task 3 test "a College game plays like a Classic one".)

---

### Task 1: Map data — Tiles, Cards, Maps

**Files:**
- Modify: `src/shared/Board/Tiles.luau`
- Modify: `src/shared/Board/Cards.luau`
- Create: `src/shared/Board/Maps.luau`
- Create: `src/tests/MapTestHelper.luau` (test helper, not a spec)
- Test: `src/tests/Maps.spec.luau`

**Interfaces:**
- Produces (used by Tasks 2–4):
  - `Tiles.MAPS: { string }` = `{ "Classic", "College" }`; `Tiles.use(mapId: string)`; `Tiles.list` / `Tiles.at` now read the active map.
  - `Cards.use(mapId: string)`; `Cards.idsFor`, `Cards.list`, `Cards.DECK_TITLES` read the active map; `Cards.byId` holds every map's cards.
  - `Maps.IDS: { string }`, `Maps.DEFAULT = "Classic"`, `Maps.use(mapId: string)`, `Maps.current(): string`.
  - Test helper `MapTestHelper.onCollege(body: () -> ())` — runs `body` with College active and always switches back to Classic.

- [ ] **Step 1: Write the failing tests**

Create `src/tests/MapTestHelper.luau`:

```lua
--!strict
-- Runs a test body on the College map and always puts Classic back, so a failure can't leak.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.Shared.Board.Maps)

local MapTestHelper = {}

function MapTestHelper.onCollege(body: () -> ())
	Maps.use("College")
	local ok, err = pcall(body)
	Maps.use("Classic")
	if not ok then
		error(err, 0)
	end
end

return MapTestHelper
```

The TestRunner only runs modules whose name ends in `.spec` (`TestRunner.luau` line 12), so the helper is never run as a spec.

Create `src/tests/Maps.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local MapTestHelper = require(script.Parent.MapTestHelper)
local Expect = require(script.Parent.Expect)

local tests = {}

local function sameList(a: { number }?, b: { number }?, label: string)
	Expect.equal(a == nil, b == nil, `{label} presence`)
	if a and b then
		Expect.equal(table.concat(a, ","), table.concat(b, ","), label)
	end
end

tests["College tiles mirror Classic in everything but names"] = function()
	local classic = Tiles.list
	MapTestHelper.onCollege(function()
		local college = Tiles.list
		Expect.equal(#college, #classic, "count")
		for i, tile in college do
			local twin = classic[i]
			local label = `position {twin.position}`
			Expect.equal(tile.position, twin.position, label)
			Expect.equal(tile.kind, twin.kind, `{label} kind`)
			Expect.equal(tile.price, twin.price, `{label} price`)
			Expect.equal(tile.group, twin.group, `{label} group`)
			Expect.equal(tile.amount, twin.amount, `{label} amount`)
			sameList(tile.rent, twin.rent, `{label} rent`)
			assert(tile.name ~= twin.name, `{label} keeps the classic name {twin.name}`)
			Expect.equal(Tiles.at(tile.position), tile, `{label} at()`)
		end
		Expect.equal(Tiles.at(0).name, "Orientation", "Go")
		Expect.equal(Tiles.at(39).name, "Football Stadium", "Boardwalk")
		Expect.equal(Tiles.at(10).name, "Dean's Office", "Jail")
	end)
	Expect.equal(Tiles.at(39).name, "Boardwalk", "Classic is back")
end

tests["every Classic card has a College twin with the same effect, in the same order"] = function()
	local classic = {}
	for _, deck in Cards.DECKS do
		classic[deck] = Cards.idsFor(deck)
	end
	MapTestHelper.onCollege(function()
		for _, deck in Cards.DECKS do
			local ids = Cards.idsFor(deck)
			Expect.equal(#ids, #classic[deck], `{deck} size`)
			for i, id in ids do
				local twinId = classic[deck][i]
				Expect.equal(id, `college.{twinId}`, `{deck} #{i} id`)
				local card, twin = Cards.byId[id], Cards.byId[twinId]
				Expect.equal(card.deck, twin.deck, `{id} deck`)
				assert(card.text ~= twin.text, `{id} reuses the classic text`)
				for key, value in twin.effect do
					Expect.equal((card.effect :: any)[key], value, `{id} effect.{key}`)
				end
				for key in card.effect do
					assert((twin.effect :: any)[key] ~= nil, `{id} has an extra effect field {key}`)
				end
			end
		end
		Expect.equal(Cards.DECK_TITLES.Chance, "Pop Quiz")
		Expect.equal(Cards.DECK_TITLES.CommunityChest, "Student Union")
		Expect.equal(#Cards.list, 32, "active list is the college decks")
	end)
	Expect.equal(Cards.DECK_TITLES.Chance, "Chance", "Classic titles are back")
end

tests["every card id resolves whatever map is active"] = function()
	Expect.equal(Cards.byId["college.chance.go"].text, "Back to Orientation. Collect $200.", "college card on Classic")
	MapTestHelper.onCollege(function()
		Expect.equal(Cards.byId["chance.go"].text, "Advance to Go. Collect $200.", "classic card on College")
	end)
end

tests["Maps switches tiles and cards together and rejects unknown maps"] = function()
	Expect.equal(Maps.current(), "Classic")
	MapTestHelper.onCollege(function()
		Expect.equal(Maps.current(), "College")
		Expect.equal(Tiles.at(5).name, "North Campus Shuttle")
		Expect.equal(Cards.idsFor("Chance")[1], "college.chance.dividend")
	end)
	assert(not pcall(Maps.use, "Moon"), "unknown map accepted")
	Expect.equal(Maps.current(), "Classic", "a rejected map changes nothing")
end

return tests
```

- [ ] **Step 2: Run to verify they fail**

Run: `.run("Maps")`
Expected: `FAIL Maps.spec (load): …` (`Maps` module missing).

- [ ] **Step 3: Implement**

**`Tiles.luau`:** rename the existing `list` local to `classic` (only the table literal and the numbering loop), then replace everything from the numbering loop to the end of the file with:

```lua
-- Numbers a map's tiles 0-39 and freezes them.
local function finish(tiles: { Tile }): { Tile }
	for i, tile in tiles do
		tile.position = i - 1
		table.freeze(tile)
	end
	return table.freeze(tiles)
end

finish(classic)

-- The college map: the classic board with campus names. Everything that affects play is copied.
local COLLEGE_NAMES = {
	"Orientation", "Freshman Dorm", "Student Union", "Basement Laundry", "Tuition",
	"North Campus Shuttle", "Library Annex", "Pop Quiz", "Study Hall", "Writing Center",
	"Dean's Office", "Art Studio", "Campus Wi-Fi", "Music Hall", "Theater",
	"East Campus Shuttle", "Coffee Shop", "Student Union", "Bookstore", "Food Court",
	"The Quad", "Chemistry Lab", "Pop Quiz", "Physics Lab", "Engineering Hall",
	"South Campus Shuttle", "Fraternity Row", "Sorority Row", "Dining Hall", "Rec Center",
	"Caught Cheating", "Business School", "Law School", "Student Union", "Medical School",
	"West Campus Shuttle", "Pop Quiz", "President's House", "Parking Ticket", "Football Stadium",
}
assert(#COLLEGE_NAMES == #classic, "one college name per tile")

local college: { Tile } = {}
for i, tile in classic do
	local copy = table.clone(tile)
	copy.name = COLLEGE_NAMES[i]
	table.insert(college, copy)
end
finish(college)

local MAPS: { [string]: { Tile } } = { Classic = classic, College = college }

local Tiles = {}

Tiles.MAPS = table.freeze({ "Classic", "College" })
Tiles.COUNT = #classic
Tiles.list = classic -- the active map's tiles; switched by Tiles.use

function Tiles.use(mapId: string)
	Tiles.list = assert(MAPS[mapId], `unknown map {mapId}`)
end

function Tiles.at(position: number): Tile
	assert(position % 1 == 0 and position >= 0 and position < Tiles.COUNT, `invalid board position {position}`)
	return Tiles.list[position + 1]
end

return Tiles
```

(`table.clone` of a frozen table returns an unfrozen copy, so setting `name` is allowed.)

**`Cards.luau`:** keep `CHANCE` and `COMMUNITY_CHEST` exactly as they are. Add, after them:

```lua
-- College text for each classic card; same effect, same order, id "college.<classic id>".
local COLLEGE_TEXT: { [string]: string } = {
	["chance.dividend"] = "Your campus job pays out. Collect $50.",
	["chance.loan"] = "Your scholarship comes through. Collect $150.",
	["chance.speeding"] = "Library late fee: pay $15.",
	["chance.boardwalk"] = "Tickets to the big game: advance to the Football Stadium.",
	["chance.go"] = "Back to Orientation. Collect $200.",
	["chance.illinois"] = "Advance to Engineering Hall. If you pass Orientation, collect $200.",
	["chance.stCharles"] = "Advance to the Art Studio. If you pass Orientation, collect $200.",
	["chance.reading"] = "Catch the North Campus Shuttle. If you pass Orientation, collect $200.",
	["chance.railroad1"] = "Run for the nearest shuttle. If it is owned, pay the owner twice the fare.",
	["chance.railroad2"] = "Run for the nearest shuttle. If it is owned, pay the owner twice the fare.",
	["chance.utility"] = "Head to the nearest utility. If it is owned, roll the dice and pay the owner ten times the roll.",
	["chance.jailFree"] = "Doctor's note: get out of the Dean's Office free. Keep this card until needed.",
	["chance.back3"] = "Forgot your student ID. Go back 3 spaces.",
	["chance.jail"] = "Caught plagiarizing. Go to the Dean's Office. Do not pass Orientation, do not collect $200.",
	["chance.repairs"] = "Dorm damage inspection: pay $25 per house and $100 per hotel.",
	["chance.chairman"] = "Elected class president. Buy each player a $50 pizza.",
	["chest.taxRefund"] = "Textbook buyback. Collect $20.",
	["chest.bankError"] = "Financial aid office error in your favor. Collect $200.",
	["chest.doctor"] = "Campus clinic copay. Pay $50.",
	["chest.stock"] = "Sold your old laptop. Collect $50.",
	["chest.go"] = "Back to Orientation. Collect $200.",
	["chest.jailFree"] = "Get out of the Dean's Office free. Keep this card until needed.",
	["chest.jail"] = "Pulled the fire alarm. Go to the Dean's Office. Do not pass Orientation, do not collect $200.",
	["chest.holiday"] = "Summer internship pays off. Collect $100.",
	["chest.birthday"] = "It's your birthday. Collect $10 from every player.",
	["chest.lifeInsurance"] = "Won the hackathon. Collect $100.",
	["chest.hospital"] = "Slept through the final. Pay $100 to retake it.",
	["chest.school"] = "Lab fees due. Pay $50.",
	["chest.consultancy"] = "Tutored a classmate. Collect $25.",
	["chest.streetRepairs"] = "Housing fines for your parties: pay $40 per house and $115 per hotel.",
	["chest.beautyContest"] = "Second place in the talent show. Collect $10.",
	["chest.inherit"] = "Care package from home with $100 inside.",
}

local function collegeEntries(entries: { Entry }): { Entry }
	local out = {}
	for _, entry in entries do
		local text = COLLEGE_TEXT[entry.id]
		assert(text, `no college text for {entry.id}`)
		table.insert(out, { id = `college.{entry.id}`, text = text, effect = table.clone(entry.effect) })
	end
	return out
end
```

The 32 keys above were checked against the ids in `CHANCE` / `COMMUNITY_CHEST` when this plan was written; the `assert` in `collegeEntries` still fails loudly at load if a card is ever added without college text.

Replace the module body from `local Cards = {}` to the end with:

```lua
local Cards = {}

Cards.DECKS = table.freeze({ "Chance", "CommunityChest" } :: { DeckName })

type MapCards = { list: { Card }, idsByDeck: { [string]: { string } }, titles: { [string]: string } }

local byId: { [string]: Card } = {}

local function buildMap(chance: { Entry }, chest: { Entry }, titles: { [string]: string }): MapCards
	local list: { Card } = {}
	local idsByDeck: { [string]: { string } } = {}
	local function addDeck(deck: DeckName, entries: { Entry })
		local ids = {}
		for _, entry in entries do
			local card: Card = { id = entry.id, deck = deck, text = entry.text, effect = table.freeze(entry.effect) }
			table.freeze(card)
			table.insert(list, card)
			byId[card.id] = card
			table.insert(ids, card.id)
		end
		idsByDeck[deck] = table.freeze(ids)
	end
	addDeck("Chance", chance)
	addDeck("CommunityChest", chest)
	return { list = table.freeze(list), idsByDeck = idsByDeck, titles = table.freeze(titles) }
end

local MAPS: { [string]: MapCards } = {
	Classic = buildMap(CHANCE, COMMUNITY_CHEST, { Chance = "Chance", CommunityChest = "Community Chest" }),
	College = buildMap(collegeEntries(CHANCE), collegeEntries(COMMUNITY_CHEST), { Chance = "Pop Quiz", CommunityChest = "Student Union" }),
}
local active = MAPS.Classic

-- Every map's cards, so a card id from any game can be shown.
Cards.byId = table.freeze(byId)
-- The active map's cards and deck titles; switched by Cards.use.
Cards.list = active.list
Cards.DECK_TITLES = active.titles

function Cards.use(mapId: string)
	active = assert(MAPS[mapId], `unknown map {mapId}`)
	Cards.list = active.list
	Cards.DECK_TITLES = active.titles
end

-- A new array of the active map's card ids for a deck, in listed order (callers may shuffle it).
function Cards.idsFor(deck: string): { string }
	return table.clone(assert(active.idsByDeck[deck], `unknown deck {deck}`))
end

return Cards
```

**`Maps.luau`** (new):

```lua
--!strict
-- Which board is in play. One game runs at a time, so the board data has a single active map that
-- the server sets when a game starts and each client sets from the snapshot.

local Cards = require(script.Parent.Cards)
local Tiles = require(script.Parent.Tiles)

local Maps = {}

Maps.IDS = Tiles.MAPS
Maps.DEFAULT = "Classic"

local current = Maps.DEFAULT

function Maps.use(mapId: string)
	assert(table.find(Maps.IDS, mapId), `unknown map {mapId}`)
	Tiles.use(mapId)
	Cards.use(mapId)
	current = mapId
end

function Maps.current(): string
	return current
end

return Maps
```

- [ ] **Step 4: Run to verify they pass**

Run: `.run("Maps")`, `.run("Cards")`, `.run("Tiles")`, then `.run()`
Expected: `Maps` 4 passed; existing `Cards` and `Tiles` specs unchanged and passing; full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Board/Tiles.luau src/shared/Board/Cards.luau src/shared/Board/Maps.luau src/tests/MapTestHelper.luau src/tests/Maps.spec.luau
git commit -m "feat: college map data — campus tile names and Pop Quiz / Student Union cards"
```

---

### Task 2: MatchSettings — the map option

**Files:**
- Modify: `src/shared/Rules/MatchSettings.luau`
- Test: `src/tests/MatchSettings.spec.luau`

**Interfaces:**
- Produces: `Settings.map: string` ("Classic" | "College"); `MatchSettings.DEFAULT.map = "Classic"`; `MatchSettings.nextMap(id: string): string`; `MatchSettings.mapLabel(id: string): string` → `"Map: Classic"` / `"Map: College"`.

- [ ] **Step 1: Write the failing test** — append to `src/tests/MatchSettings.spec.luau` before `return tests`:

```lua
tests["the map defaults to Classic, validates, cycles and labels"] = function()
	Expect.equal(MatchSettings.DEFAULT.map, "Classic", "default")
	Expect.equal(MatchSettings.validate({ map = "College" }).map, "College", "known map kept")
	for i, raw in { nil, 5, { map = 5 }, { map = "college" }, { map = "__index" } } :: { any } do
		Expect.equal(MatchSettings.validate(raw).map, "Classic", `garbage #{i}`)
	end
	Expect.equal(MatchSettings.nextMap("Classic"), "College")
	Expect.equal(MatchSettings.nextMap("College"), "Classic", "wraps")
	Expect.equal(MatchSettings.mapLabel("College"), "Map: College")
	local chosen = MatchSettings.validate({ timer = "Fast", length = "Rounds15", map = "College" })
	Expect.equal(chosen.timer, "Fast", "other options untouched")
	Expect.equal(chosen.length, "Rounds15", "other options untouched")
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `.run("MatchSettings")`
Expected: FAIL `default: expected Classic, got nil`.

- [ ] **Step 3: Implement** in `MatchSettings.luau`:
- Settings type gains `map: string, -- "Classic" | "College"`.
- `local MAPS = { "Classic", "College" }` next to `TIMERS` — a literal rather than `require(Maps)`, so MatchSettings stays a leaf module. It must list the same ids as `Maps.IDS`; Task 3's GameSession test (settings → a College game) catches a mismatch.
- `MatchSettings.DEFAULT = table.freeze({ timer = "Relaxed", length = "Off", map = "Classic" }) :: Settings`
- In `validate` add `local map = if typeof(raw) == "table" and isOneOf(raw.map, MAPS) then raw.map else MatchSettings.DEFAULT.map` and return `{ timer = timer, length = length, map = map }`.
- Add:

```lua
function MatchSettings.nextMap(id: string): string
	return nextIn(MAPS, id)
end

function MatchSettings.mapLabel(id: string): string
	return `Map: {id}`
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `.run("MatchSettings")` then `.run()`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules/MatchSettings.luau src/tests/MatchSettings.spec.luau
git commit -m "feat: map option in match settings"
```

---

### Task 3: Engine, session and snapshot carry the map

**Files:**
- Modify: `src/server/Game/Types.luau` (`GameState.map`)
- Modify: `src/server/Game/Engine.luau` (`Engine.new`)
- Modify: `src/server/Game/GameSession.luau` (`GameSession.new` passes the map)
- Modify: `src/server/Game/Snapshot.luau`, `src/shared/Net/Protocol.luau` (`Snapshot.map`)
- Modify: `src/tests/GameFixtures.luau` (`bareState` gets `map = "Classic"`)
- Test: `src/tests/Engine.spec.luau`, `src/tests/Snapshot.spec.luau`, `src/tests/GameSession.spec.luau`

**Interfaces:**
- Consumes: `Maps.use` (Task 1), `Settings.map` (Task 2).
- Produces: `Engine.new(players, rollDice, shuffle?, roundLimit?, map?: string): GameState` (map defaults to `Maps.DEFAULT`); `GameState.map: string`; `Protocol.Snapshot.map: string`.

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/Engine.spec.luau` (add `local Maps = require(game:GetService("ReplicatedStorage").Shared.Board.Maps)` and `local Tiles = require(game:GetService("ReplicatedStorage").Shared.Board.Tiles)` to its requires if absent):

```lua
local function players(count: number)
	local infos = {}
	for i = 1, count do
		table.insert(infos, { id = `p{i}`, name = `Player {i}`, isBot = false })
	end
	return infos
end

tests["a new game without a map is Classic, even after a College game"] = function()
	local college = Engine.new(players(2), GameFixtures.scriptedDice({}), nil, nil, "College")
	local ok, err = pcall(function()
		Expect.equal(college.map, "College")
		Expect.equal(college.decks.Chance[1], "college.chance.dividend", "college cards dealt")
		Expect.equal(Tiles.at(39).name, "Football Stadium")
	end)
	local classic = GameFixtures.newGame(2) -- no map given
	Expect.equal(classic.map, "Classic")
	Expect.equal(Maps.current(), "Classic", "switched back")
	Expect.equal(classic.decks.Chance[1], "chance.dividend")
	assert(ok, err)
end

tests["a College game plays like a Classic one"] = function()
	local state = Engine.new(players(2), GameFixtures.scriptedDice({ { 1, 2 } }), nil, nil, "College")
	local ok, err = pcall(function()
		act(state, "p1", ROLL) -- to 3: Basement Laundry, $60 like Baltic
		Expect.equal(state.phase, "BuyDecision")
		act(state, "p1", BUY)
		Expect.equal(money(state, "p1"), 1440)
		Expect.equal(state.properties[3].owner, "p1")
	end)
	Maps.use("Classic")
	assert(ok, err)
end
```

(`act`, `ROLL`, `BUY`, `money` and `GameFixtures` are already locals in `Engine.spec.luau`; there is no existing `players` local.)

Append to `src/tests/Snapshot.spec.luau`:

```lua
tests["the snapshot says which map is in play"] = function()
	Expect.equal(Snapshot.fromState(GameFixtures.newGame(2)).map, "Classic")
	local state = GameFixtures.newGame(2)
	state.map = "College"
	Expect.equal(Snapshot.fromState(state).map, "College")
end
```

Append to `src/tests/GameSession.spec.luau` (add the `Maps` require if absent):

```lua
tests["the session starts the map from the settings"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}), nil, MatchSettings.validate({ map = "College" }))
	local map = session.state.map
	Maps.use("Classic")
	Expect.equal(map, "College")
end
```

(Add `local MatchSettings = require(game:GetService("ReplicatedStorage").Shared.Rules.MatchSettings)` to the GameSession spec if absent.)

- [ ] **Step 2: Run to verify they fail**

Run: `.run("Engine")`, `.run("Snapshot")`, `.run("GameSession")`
Expected: Engine fails on `college.map` (`expected College, got nil`); Snapshot `expected Classic, got nil`; GameSession `expected College, got nil`.

- [ ] **Step 3: Implement**
- `Types.luau` `GameState`: add `map: string, -- the board in play (Maps id)` after `phase`.
- `Engine.luau`: `local Maps = require(ReplicatedStorage.Shared.Board.Maps)` with the other shared requires (check the file's existing `ReplicatedStorage` local name). `Engine.new` gains a 5th parameter `map: string?`; first line of its body after the player-count assert:

```lua
	-- One game at a time: the board data follows the game being started.
	local mapId = map or Maps.DEFAULT
	Maps.use(mapId)
```

  and `map = mapId,` in the `state` table after `phase`.
- `GameSession.new`: `Engine.new(infos, rollDice, shuffle, MatchSettings.roundLimit(chosen), chosen.map)`.
- `Protocol.Snapshot`: `map: string, -- Maps id; clients switch to it before drawing` after `phase`.
- `Snapshot.fromState`: `map = state.map,` after `phase`.
- `GameFixtures.bareState`: `map = "Classic",` after `phase`.

- [ ] **Step 4: Run to verify they pass**

Run: `.run("Engine")`, `.run("Snapshot")`, `.run("GameSession")`, then `.run()`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Types.luau src/server/Game/Engine.luau src/server/Game/GameSession.luau src/server/Game/Snapshot.luau src/shared/Net/Protocol.luau src/tests/GameFixtures.luau src/tests/Engine.spec.luau src/tests/Snapshot.spec.luau src/tests/GameSession.spec.luau
git commit -m "feat: games start on the chosen map and the snapshot names it"
```

---

### Task 4: Board labels, lobby button, client map switch

**Files:**
- Modify: `src/server/BoardBuilder.luau` (new `relabel`)
- Modify: `src/server/GameService.luau` (relabel when a game starts)
- Modify: `src/client/GameClient.luau` (switch map from the snapshot; send the map on Start)
- Modify: `src/client/Hud/HudView.luau` (Map button in the lobby)
- Test: `src/tests/BoardBuilder.spec.luau`, `src/tests/EventText.spec.luau`

**Interfaces:**
- Consumes: `Maps.use`, `Tiles.at` (Task 1), `MatchSettings.nextMap/mapLabel` (Task 2), `Snapshot.map` (Task 3).
- Produces: `BoardBuilder.relabel(model: Model)` — rewrites every tile's label text and `TileName` attribute from the active map.

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/BoardBuilder.spec.luau` (add `local MapTestHelper = require(script.Parent.MapTestHelper)` if absent):

```lua
tests["relabel writes the active map's names onto the board"] = function()
	local holder = Instance.new("Folder")
	local model = BoardBuilder.build(holder)
	local function label(position: number): string
		for _, part in (model:FindFirstChild("Tiles") :: Folder):GetChildren() do
			if part:GetAttribute("TilePosition") == position then
				return (part:FindFirstChild("Label", true) :: TextLabel).Text
			end
		end
		error(`no tile {position}`)
	end
	MapTestHelper.onCollege(function()
		BoardBuilder.relabel(model)
		Expect.equal(label(39), "Football Stadium\n$400", "college street")
		Expect.equal(label(38), "Parking Ticket\nPay $100", "college tax")
	end)
	BoardBuilder.relabel(model)
	Expect.equal(label(39), "Boardwalk\n$400", "back to Classic")
	holder:Destroy()
end
```

Append to `src/tests/EventText.spec.luau` (add `local MapTestHelper = require(script.Parent.MapTestHelper)` if absent):

```lua
tests["a College card is logged with its own text and deck title"] = function()
	MapTestHelper.onCollege(function()
		Expect.equal(
			EventText.describe({ type = "CardDrawn", player = "p1", deck = "Chance", card = "college.chance.back3" }, NAMES),
			"Ana drew Pop Quiz: Forgot your student ID. Go back 3 spaces."
		)
	end)
end
```

(`NAMES` in that spec is `{ p1 = "Ana", p2 = "Bot 1" }`.)

- [ ] **Step 2: Run to verify they fail**

Run: `.run("BoardBuilder")`, `.run("EventText")`
Expected: BoardBuilder fails with `attempt to call a nil value` (no `relabel`); EventText **passes already** (card text and titles come from Task 1) — that's fine, it pins the behavior; note it in the ledger.

- [ ] **Step 3: Implement**

`BoardBuilder.luau`, after `BoardBuilder.build`:

```lua
-- Rewrites tile names for the active map (the shape, prices and colors are the same on every map).
function BoardBuilder.relabel(model: Model)
	local tiles = model:FindFirstChild("Tiles")
	if not tiles then
		return
	end
	for _, part in tiles:GetChildren() do
		local position = part:GetAttribute("TilePosition")
		if typeof(position) ~= "number" then
			continue
		end
		local tile = Tiles.at(position)
		part:SetAttribute("TileName", tile.name)
		local label = part:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			label.Text = labelText(tile)
		end
	end
end
```

`GameService.luau`:
- `local BoardBuilder = require(script.Parent.BoardBuilder)` with the other requires.
- In `onLobbyRequest`, right after `session = started` (the engine has switched the map by then):

```lua
		local board = workspace:FindFirstChild(BoardBuilder.MODEL_NAME)
		if board and board:IsA("Model") then
			BoardBuilder.relabel(board)
		end
```

`GameClient.luau`:
- `local Maps = require(ReplicatedStorage.Shared.Board.Maps)` with the shared requires.
- First thing in the `updateRemote.OnClientEvent` handler, after `hud:unlock()`:

```lua
		if update.snapshot then
			Maps.use(update.snapshot.map) -- names and card text follow the game being shown
		end
```

- `onStart` sends the map: `lobbyRemote:FireServer({ type = "Start", seats = seats, timer = settings.timer, length = settings.length, map = settings.map })`.

`HudView.luau`, after the Length `settingButton(4, …)` call:

```lua
	settingButton(5, function()
		return MatchSettings.mapLabel(self.settings.map)
	end, function()
		self.settings.map = MatchSettings.nextMap(self.settings.map)
	end)
```

and grow the lobby panel to fit the extra button: `panel("Lobby", UDim2.fromOffset(320, 300), …)`.

- [ ] **Step 4: Run to verify they pass**

Run: `.run("BoardBuilder")`, `.run("EventText")`, then `.run()`
Expected: green.

- [ ] **Step 5: Playtest**

Play Solo:
1. The lobby shows `Map: Classic`; click it → `Map: College`. Start a 2-seat game.
2. Screenshot the board: campus names on every tile (Orientation, Football Stadium, …), prices unchanged.
3. Play turns until someone lands on a Pop Quiz / Student Union tile: the card popup's title is "Pop Quiz" / "Student Union" with college text, and the log line matches.
4. Finish or leave the game (Back to lobby after GameOver, or stop/start the playtest), start a Classic game: names and cards are classic again.
5. Late joiner: if a second client is available (Test ▸ Clients and Servers), join one after a College game started — it shows college names. If not, record in the ledger that this step was not run.

- [ ] **Step 6: Commit**

```bash
git add src/server/BoardBuilder.luau src/server/GameService.luau src/client/GameClient.luau src/client/Hud/HudView.luau src/tests/BoardBuilder.spec.luau src/tests/EventText.spec.luau
git commit -m "feat: lobby map choice; the board and cards switch to the college map"
```

---

### Task 5: Wrap up

- [ ] **Step 1:** `.run()` — full suite green.
- [ ] **Step 2:** Whole-branch review (one reviewer, this plan's Review Focus). Fix Important; record Minors in `docs/superpowers/plans/2026-09-30-polish.followups.txt`.
- [ ] **Step 3:** Ask the user before merging to `main` and pushing.
