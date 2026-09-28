# Rules Engine Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure, server-side Monopoly rules engine covering turns, dice, movement, Go salary, buying, rent, taxes and auctions — driven by player actions and fully unit-tested.

**Architecture:** One `GameState` table per match, changed only by `Engine.act(state, playerId, action)`, which validates the action (whose turn, which phase, affordability, malformed input) and returns `(ok, err)`. Every change is appended to `state.events` so the networking layer (next plan) can forward them to clients for animation and UI. Dice are injected, so tests script exact rolls. Rent is its own pure module.

**Tech Stack:** Luau, Rojo 7.7, in-Studio test runner from the board plan (`ServerStorage.Tests.TestRunner`).

**Spec:** Design agreed in conversation on 2026-09-27 (see Global Constraints). This is milestone 1 of the core game: later plans add networking/UI/bots (2), jail/doubles penalty/cards (3), buildings/mortgages/bankruptcy/win/trading (4), timers (5).

## Global Constraints

- Official US Monopoly rules. $1500 starting money, $200 Go salary (passing or landing).
- 2–6 players per game (bots count as players; the engine does not distinguish them beyond `isBot`).
- Server-authoritative: the engine is the only thing that changes game state; every action from a client goes through `Engine.act` and must be validated there.
- Board positions 0–39 as defined by `ReplicatedStorage.Shared.Board.Tiles`.
- Auctions (official rule when a player declines to buy) are run as sequential bidding: bidders take turns in seat order starting with the player who declined; each either bids higher or passes and is out. The last bidder standing wins at their bid; if everyone passes, the bank keeps the property.
- Out of scope for this plan (later plans): jail, three-doubles rule, Go To Jail, Chance/Community Chest, houses/hotels building, mortgaging, debt resolution, bankruptcy, winning. In this plan those tiles do nothing, and a player may go below $0 from rent or tax.
- Every new `.luau` file starts with `--!strict`. Tabs for indentation.

## Review Focus

1. **Malformed or malicious client actions** (nil action, wrong types, unknown action, NaN/fractional/huge bids, unknown player id) — expect `false, <reason>` and no state change. Pinned by Engine.spec "rejects malformed actions" and "bids must be higher, whole, and affordable".
2. **Out-of-turn actions** (someone else rolls, a non-bidder bids) — expect rejection. Pinned by "only the current player can roll, and only in the Roll phase" and "only the next bidder can act in an auction".
3. **Doubles followed by a purchase or auction** — expect the same player to roll again afterwards. Pinned by "doubles still give another roll after an auction".
4. **Last bidder standing with no bids yet** — expect they can still bid (and win) or pass. Pinned by "last bidder left can still bid".
5. **Rent larger than the player's cash** — expect it to be paid in full, leaving a negative balance, until the debt plan adds raising funds. Pinned by "rent is paid even if it leaves the player in debt".

## File Structure

```
src/server/Game/Types.luau     (create) shared type definitions for the engine
src/server/Game/Rent.luau      (create) rent owed for landing on an owned tile
src/server/Game/Engine.luau    (create) game creation + action handling
src/tests/GameFixtures.luau    (create) scripted dice + game/ownership helpers for specs
src/tests/Rent.spec.luau       (create)
src/tests/Engine.spec.luau     (create)
```

`src/server` is the `ServerScriptService.Server` Script, so the engine is `ServerScriptService.Server.Game.Engine`. It is server-only on purpose: clients never run rules.

## How to run the tests

Same as the board plan: `start_stop_play(true)`, `execute_luau(Server, 'return require(game.ServerStorage.Tests.TestRunner).run()')` (optionally `.run("Engine")`), `start_stop_play(false)`. Output: `"<n> passed, <m> failed"` plus one `FAIL` line per failure.

---

### Task 1: Types, fixtures and rent

**Files:**
- Create: `src/server/Game/Types.luau`, `src/server/Game/Rent.luau`
- Create: `src/tests/GameFixtures.luau`, `src/tests/Rent.spec.luau`

**Interfaces:**
- Consumes: `Tiles.at(position)`, `Tiles.list`, tile fields `kind`, `group`, `rent`.
- Produces:
  - Types (`require(ServerScriptService.Server.Game.Types)`): `Phase`, `Player`, `Ownership`, `Auction`, `Event`, `Action`, `DiceRoller`, `GameState` as defined below.
  - `Rent.calculate(state: GameState, position: number, diceTotal: number): number` — rent owed to the owner (0 if unowned or mortgaged). Does not check who landed.
  - `Rent.ownsGroup(state: GameState, owner: string, group: string): boolean`
  - `Rent.RAILROAD_RENT = { 25, 50, 100, 200 }`, `Rent.UTILITY_MULTIPLIER = { 4, 10 }`
  - `GameFixtures.scriptedDice(rolls: { { number } }): DiceRoller` (errors when it runs out), `GameFixtures.newGame(playerCount: number, rolls: { { number } }?): GameState` (players `p1`..`pN`), `GameFixtures.own(state, owner: string, position: number, houses: number?)`, `GameFixtures.eventsOfType(state, eventType: string): { Event }`

`GameFixtures.newGame` needs `Engine.new`, which Task 2 creates. To keep Task 1 self-contained, `Rent.spec` builds its state with `GameFixtures.bareState(playerCount)` (no engine needed); `newGame` is added in Task 2.

- [ ] **Step 1: Write the types**

`src/server/Game/Types.luau`:

```lua
--!strict
-- Shapes of the engine's game state, actions and events.

export type Phase = "Roll" | "BuyDecision" | "Auction" | "EndTurn" | "GameOver"

export type Player = {
	id: string,
	name: string,
	isBot: boolean,
	money: number,
	position: number,
	bankrupt: boolean,
}

export type Ownership = {
	owner: string,
	houses: number, -- 0-4 houses, 5 = hotel
	mortgaged: boolean,
}

export type Auction = {
	position: number,
	highBid: number,
	highBidder: string?,
	bidders: { string }, -- players still bidding, in bidding order
	nextBidder: number, -- index into bidders of who acts next
}

-- Events are plain tables with a `type` and event-specific fields, e.g.
-- { type = "Moved", player = "p1", from = 38, to = 3, passedGo = true }.
export type Event = { [string]: any }

export type Action = { [string]: any } -- { type = "Roll" | "Buy" | "Decline" | "Bid" | "PassBid" | "EndTurn", amount = number? }

export type DiceRoller = () -> (number, number)

export type GameState = {
	players: { Player },
	currentIndex: number,
	phase: Phase,
	properties: { [number]: Ownership }, -- keyed by board position; absent = owned by the bank
	lastRoll: { number }?,
	auction: Auction?,
	events: { Event },
	rollDice: DiceRoller,
}

return nil
```

- [ ] **Step 2: Write the fixtures (bare state only for now)**

`src/tests/GameFixtures.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ServerScriptService.Server.Game.Types)

local GameFixtures = {}

function GameFixtures.scriptedDice(rolls: { { number } }): Types.DiceRoller
	local index = 0
	return function()
		index += 1
		local roll = rolls[index]
		assert(roll, `scripted dice ran out after {index - 1} rolls`)
		return roll[1], roll[2]
	end
end

-- A state with players p1..pN and no engine involvement, for testing pure helpers.
function GameFixtures.bareState(playerCount: number): Types.GameState
	local players = {}
	for i = 1, playerCount do
		table.insert(players, { id = `p{i}`, name = `Player {i}`, isBot = false, money = 1500, position = 0, bankrupt = false })
	end
	return {
		players = players,
		currentIndex = 1,
		phase = "Roll",
		properties = {},
		lastRoll = nil,
		auction = nil,
		events = {},
		rollDice = GameFixtures.scriptedDice({}),
	}
end

function GameFixtures.own(state: Types.GameState, owner: string, position: number, houses: number?)
	state.properties[position] = { owner = owner, houses = houses or 0, mortgaged = false }
end

function GameFixtures.eventsOfType(state: Types.GameState, eventType: string): { Types.Event }
	local found = {}
	for _, event in state.events do
		if event.type == eventType then
			table.insert(found, event)
		end
	end
	return found
end

return GameFixtures
```

- [ ] **Step 3: Write the failing rent tests**

`src/tests/Rent.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Rent = require(ServerScriptService.Server.Game.Rent)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Board positions used below
local ORIENTAL, VERMONT, CONNECTICUT = 6, 8, 9 -- LightBlue, base rents 6, 6, 8
local PARK_PLACE, BOARDWALK = 37, 39
local READING, PENNSYLVANIA_RR, BO_RR, SHORT_LINE = 5, 15, 25, 35
local ELECTRIC, WATER_WORKS = 12, 28

tests["unowned or mortgaged tiles have no rent"] = function()
	local state = GameFixtures.bareState(2)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 0, "unowned")
	GameFixtures.own(state, "p2", ORIENTAL)
	state.properties[ORIENTAL].mortgaged = true
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 0, "mortgaged")
end

tests["base rent doubles when the owner has the whole color group"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", ORIENTAL)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 6, "single lot")
	GameFixtures.own(state, "p2", VERMONT)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 6, "two of three")
	GameFixtures.own(state, "p2", CONNECTICUT)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 12, "full group")
	Expect.equal(Rent.calculate(state, CONNECTICUT, 7), 16, "full group, other lot")
	assert(Rent.ownsGroup(state, "p2", "LightBlue"), "ownsGroup")
	assert(not Rent.ownsGroup(state, "p1", "LightBlue"), "ownsGroup other player")
end

tests["houses and hotels use the rent table"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", PARK_PLACE, 0)
	GameFixtures.own(state, "p2", BOARDWALK, 3)
	Expect.equal(Rent.calculate(state, BOARDWALK, 7), 1400, "3 houses")
	state.properties[BOARDWALK].houses = 5
	Expect.equal(Rent.calculate(state, BOARDWALK, 7), 2000, "hotel")
end

tests["railroad rent doubles for each railroad owned"] = function()
	local state = GameFixtures.bareState(2)
	local expected = { 25, 50, 100, 200 }
	for count, position in { READING, PENNSYLVANIA_RR, BO_RR, SHORT_LINE } do
		GameFixtures.own(state, "p2", position)
		Expect.equal(Rent.calculate(state, READING, 7), expected[count], `{count} railroads`)
	end
end

tests["utility rent is 4x the dice, or 10x with both utilities"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", ELECTRIC)
	Expect.equal(Rent.calculate(state, ELECTRIC, 7), 28, "one utility")
	GameFixtures.own(state, "p2", WATER_WORKS)
	Expect.equal(Rent.calculate(state, ELECTRIC, 7), 70, "both utilities")
end

return tests
```

- [ ] **Step 4: Run tests to verify they fail**

Run `.run("Rent")`. Expected: `0 passed, 1 failed` — `FAIL Rent.spec (load): ...` (the `Game` folder does not exist yet).

- [ ] **Step 5: Write the rent module**

`src/server/Game/Rent.luau`:

```lua
--!strict
-- Rent owed to a tile's owner. Callers decide whether rent applies (e.g. not to the owner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Types = require(script.Parent.Types)

local Rent = {}

Rent.RAILROAD_RENT = { 25, 50, 100, 200 }
Rent.UTILITY_MULTIPLIER = { 4, 10 }

local function countOwnedOfKind(state: Types.GameState, owner: string, kind: string): number
	local count = 0
	for _, tile in Tiles.list do
		local ownership = state.properties[tile.position]
		if tile.kind == kind and ownership and ownership.owner == owner then
			count += 1
		end
	end
	return count
end

function Rent.ownsGroup(state: Types.GameState, owner: string, group: string): boolean
	for _, tile in Tiles.list do
		if tile.group == group then
			local ownership = state.properties[tile.position]
			if not ownership or ownership.owner ~= owner then
				return false
			end
		end
	end
	return true
end

function Rent.calculate(state: Types.GameState, position: number, diceTotal: number): number
	local ownership = state.properties[position]
	if not ownership or ownership.mortgaged then
		return 0
	end

	local tile = Tiles.at(position)
	if tile.kind == "Property" then
		local rent = tile.rent :: { number }
		if ownership.houses > 0 then
			return rent[ownership.houses + 1]
		elseif Rent.ownsGroup(state, ownership.owner, tile.group :: string) then
			return rent[1] * 2
		end
		return rent[1]
	elseif tile.kind == "Railroad" then
		return Rent.RAILROAD_RENT[countOwnedOfKind(state, ownership.owner, "Railroad")]
	elseif tile.kind == "Utility" then
		return diceTotal * Rent.UTILITY_MULTIPLIER[countOwnedOfKind(state, ownership.owner, "Utility")]
	end
	return 0
end

return Rent
```

- [ ] **Step 6: Run tests to verify they pass**

Run all tests. Expected: `27 passed, 0 failed` (22 existing + 5 rent).

- [ ] **Step 7: Commit**

```bash
git add src/server/Game src/tests/GameFixtures.luau src/tests/Rent.spec.luau
git commit -m "feat: rent calculation and engine types"
```

---

### Task 2: Game creation, rolling, movement, buying, rent and tax

**Files:**
- Create: `src/server/Game/Engine.luau`
- Modify: `src/tests/GameFixtures.luau` (add `newGame`)
- Create: `src/tests/Engine.spec.luau`

**Interfaces:**
- Consumes: `Types.*`, `Rent.calculate`, `Tiles.at`, `Tiles.COUNT`, `GameFixtures.scriptedDice/own/eventsOfType`.
- Produces:
  - `Engine.STARTING_MONEY = 1500`, `Engine.GO_SALARY = 200`, `Engine.MIN_PLAYERS = 2`, `Engine.MAX_PLAYERS = 6`
  - `type PlayerInfo = { id: string, name: string, isBot: boolean }` (exported from Engine)
  - `Engine.new(players: { PlayerInfo }, rollDice: DiceRoller): GameState` — errors on <2, >6, or duplicate ids. Emits `TurnStarted`.
  - `Engine.act(state: GameState, playerId: string, action: Action): (boolean, string?)`
  - `Engine.getPlayer(state, id: string): Player?`, `Engine.currentPlayer(state): Player`
  - Events emitted: `TurnStarted {player}`, `Rolled {player, dice = {a, b}}`, `Moved {player, from, to, passedGo}`, `Paid {from: string?, to: string?, amount, reason}` (nil side = bank; reasons `"Go"`, `"Rent"`, `"Tax"`, `"Purchase"`, `"Auction"`), `Bought {player, position, price}`, `OfferedPurchase {player, position}`
  - `GameFixtures.newGame(playerCount: number, rolls: { { number } }?): GameState`

Phase flow: `Roll` → (roll) → landing resolved → `BuyDecision` if the tile is an unowned purchasable, else the move finishes. Finishing a move goes to `Roll` again if the roll was doubles, otherwise `EndTurn`. `EndTurn` → next non-bankrupt player, `Roll`.

- [ ] **Step 1: Add `newGame` to the fixtures**

In `src/tests/GameFixtures.luau`, add after the `Types` require:

```lua
local Engine = require(ServerScriptService.Server.Game.Engine)
```

and add this function after `scriptedDice`:

```lua
-- A real engine game with players p1..pN and scripted dice.
function GameFixtures.newGame(playerCount: number, rolls: { { number } }?): Types.GameState
	local infos = {}
	for i = 1, playerCount do
		table.insert(infos, { id = `p{i}`, name = `Player {i}`, isBot = false })
	end
	return Engine.new(infos, GameFixtures.scriptedDice(rolls or {}))
end
```

- [ ] **Step 2: Write the failing engine tests**

`src/tests/Engine.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local BUY = { type = "Buy" }
local END_TURN = { type = "EndTurn" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function money(state, id: string): number
	return (Engine.getPlayer(state, id) :: any).money
end

tests["new game gives each player 1500 at Go and the first player rolls"] = function()
	local state = GameFixtures.newGame(3)
	for _, player in state.players do
		Expect.equal(player.money, 1500, `{player.id} money`)
		Expect.equal(player.position, 0, `{player.id} position`)
	end
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
	Expect.equal(GameFixtures.eventsOfType(state, "TurnStarted")[1].player, "p1")
end

tests["new game requires 2 to 6 players with unique ids"] = function()
	local dice = GameFixtures.scriptedDice({})
	local function infos(count: number)
		local list = {}
		for i = 1, count do
			table.insert(list, { id = `p{i}`, name = `P{i}`, isBot = false })
		end
		return list
	end
	assert(not pcall(Engine.new, infos(1), dice), "1 player accepted")
	assert(not pcall(Engine.new, infos(7), dice), "7 players accepted")
	assert(pcall(Engine.new, infos(6), dice), "6 players rejected")
	local duplicate = infos(2)
	duplicate[2].id = "p1"
	assert(not pcall(Engine.new, duplicate, dice), "duplicate ids accepted")
end

tests["rolling moves the current player by the dice total"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", ROLL)
	Expect.equal(Engine.getPlayer(state, "p1").position, 6)
	local rolled = GameFixtures.eventsOfType(state, "Rolled")[1]
	Expect.equal(rolled.dice[1] + rolled.dice[2], 6, "rolled event")
	local moved = GameFixtures.eventsOfType(state, "Moved")[1]
	Expect.equal(moved.from, 0, "moved from")
	Expect.equal(moved.to, 6, "moved to")
end

tests["only the current player can roll, and only in the Roll phase"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	assert(not Engine.act(state, "p2", ROLL), "p2 rolled on p1's turn")
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "BuyDecision")
	assert(not Engine.act(state, "p1", ROLL), "rolled during BuyDecision")
end

tests["passing Go collects 200"] = function()
	local state = GameFixtures.newGame(2, { { 3, 2 } })
	Engine.getPlayer(state, "p1").position = 38
	act(state, "p1", ROLL)
	Expect.equal(Engine.getPlayer(state, "p1").position, 3)
	Expect.equal(money(state, "p1"), 1700)
	assert(GameFixtures.eventsOfType(state, "Moved")[1].passedGo, "passedGo flag")
end

tests["landing exactly on Go collects 200 once"] = function()
	local state = GameFixtures.newGame(2, { { 2, 3 } })
	Engine.getPlayer(state, "p1").position = 35
	act(state, "p1", ROLL)
	Expect.equal(Engine.getPlayer(state, "p1").position, 0)
	Expect.equal(money(state, "p1"), 1700)
end

tests["buying an unowned property"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", ROLL)
	Expect.equal(GameFixtures.eventsOfType(state, "OfferedPurchase")[1].position, 6, "offer")
	act(state, "p1", BUY)
	Expect.equal(money(state, "p1"), 1400)
	Expect.equal(state.properties[6].owner, "p1")
	Expect.equal(state.phase, "EndTurn")
end

tests["cannot buy without enough money"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.getPlayer(state, "p1").money = 50
	act(state, "p1", ROLL)
	local ok, err = Engine.act(state, "p1", BUY)
	assert(not ok, "bought without money")
	Expect.equal(err, "not enough money")
	Expect.equal(state.phase, "BuyDecision")
	Expect.equal(state.properties[6], nil, "ownership")
end

tests["landing on another player's property pays rent"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1494)
	Expect.equal(money(state, "p2"), 1506)
	Expect.equal(state.phase, "EndTurn")
end

tests["landing on your own property costs nothing"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p1", 6)
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500)
	Expect.equal(state.phase, "EndTurn")
end

tests["utility rent uses the dice just rolled"] = function()
	local state = GameFixtures.newGame(2, { { 5, 7 } }) -- 12 -> Electric Company
	GameFixtures.own(state, "p2", 12)
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500 - 48)
end

tests["rent is paid even if it leaves the player in debt"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	Engine.getPlayer(state, "p1").money = 3
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), -3)
	Expect.equal(money(state, "p2"), 1506)
end

tests["tax tiles charge their amount"] = function()
	local state = GameFixtures.newGame(2, { { 1, 3 } })
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1300)
	Expect.equal(state.phase, "EndTurn")
end

tests["other tiles just end the move"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } }) -- 7 -> Chance
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500)
	Expect.equal(state.phase, "EndTurn")
end

tests["doubles give the same player another roll"] = function()
	local state = GameFixtures.newGame(2, { { 1, 1 } }) -- 2 -> Community Chest
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
end

tests["end turn passes to the next player and wraps around"] = function()
	local state = GameFixtures.newGame(3, { { 3, 4 }, { 3, 4 }, { 3, 4 } })
	for _, id in { "p1", "p2", "p3" } do
		Expect.equal(Engine.currentPlayer(state).id, id, "current")
		act(state, id, ROLL)
		act(state, id, END_TURN)
	end
	Expect.equal(Engine.currentPlayer(state).id, "p1", "wrapped")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#GameFixtures.eventsOfType(state, "TurnStarted"), 4, "TurnStarted events")
end

tests["end turn skips bankrupt players"] = function()
	local state = GameFixtures.newGame(3, { { 3, 4 } })
	Engine.getPlayer(state, "p2").bankrupt = true
	act(state, "p1", ROLL)
	act(state, "p1", END_TURN)
	Expect.equal(Engine.currentPlayer(state).id, "p3")
end

tests["rejects malformed actions without changing state"] = function()
	local state = GameFixtures.newGame(2, {})
	for _, bad in { nil :: any, 5, {}, { type = 5 }, { type = "Fly" } } do
		assert(not Engine.act(state, "p1", bad), `accepted {tostring(bad)}`)
	end
	assert(not Engine.act(state, "nobody", ROLL), "unknown player accepted")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#state.events, 1, "only the TurnStarted event")
end

return tests
```

- [ ] **Step 3: Run tests to verify they fail**

Run `.run("Engine")`. Expected: `0 passed, 1 failed` — `FAIL Engine.spec (load): ...` (no Engine module).

Also run `.run("Rent")`: Rent.spec now fails to load too, because `GameFixtures` requires `Engine`. That is expected until Step 4.

- [ ] **Step 4: Write the engine**

`src/server/Game/Engine.luau`:

```lua
--!strict
-- Monopoly rules as state transitions. The server keeps one GameState per match and feeds it
-- player actions through Engine.act; every change is recorded in state.events for clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Rent = require(script.Parent.Rent)
local Types = require(script.Parent.Types)

type GameState = Types.GameState
type Player = Types.Player

export type PlayerInfo = {
	id: string,
	name: string,
	isBot: boolean,
}

local Engine = {}

Engine.STARTING_MONEY = 1500
Engine.GO_SALARY = 200
Engine.MIN_PLAYERS = 2
Engine.MAX_PLAYERS = 6

local PURCHASABLE = { Property = true, Railroad = true, Utility = true }

local function emit(state: GameState, event: Types.Event)
	table.insert(state.events, event)
end

function Engine.getPlayer(state: GameState, id: string): Player?
	for _, player in state.players do
		if player.id == id then
			return player
		end
	end
	return nil
end

function Engine.currentPlayer(state: GameState): Player
	return state.players[state.currentIndex]
end

-- Moves money between players; a nil side is the bank.
local function transfer(state: GameState, fromId: string?, toId: string?, amount: number, reason: string)
	if fromId then
		(Engine.getPlayer(state, fromId) :: Player).money -= amount
	end
	if toId then
		(Engine.getPlayer(state, toId) :: Player).money += amount
	end
	emit(state, { type = "Paid", from = fromId, to = toId, amount = amount, reason = reason })
end

local function rolledDoubles(state: GameState): boolean
	local roll = state.lastRoll
	return roll ~= nil and roll[1] == roll[2]
end

-- Called once everything caused by landing is settled.
local function finishMove(state: GameState)
	state.phase = if rolledDoubles(state) then "Roll" else "EndTurn"
end

local function resolveLanding(state: GameState, player: Player)
	local tile = Tiles.at(player.position)

	if PURCHASABLE[tile.kind] then
		local ownership = state.properties[tile.position]
		if not ownership then
			state.phase = "BuyDecision"
			emit(state, { type = "OfferedPurchase", player = player.id, position = tile.position })
			return
		end
		if ownership.owner ~= player.id then
			local roll = state.lastRoll :: { number }
			local rent = Rent.calculate(state, tile.position, roll[1] + roll[2])
			if rent > 0 then
				transfer(state, player.id, ownership.owner, rent, "Rent")
			end
		end
	elseif tile.kind == "Tax" then
		transfer(state, player.id, nil, tile.amount :: number, "Tax")
	end

	finishMove(state)
end

local function roll(state: GameState, player: Player)
	local a, b = state.rollDice()
	state.lastRoll = { a, b }
	emit(state, { type = "Rolled", player = player.id, dice = { a, b } })

	local from = player.position
	local steps = from + a + b
	player.position = steps % Tiles.COUNT
	local passedGo = steps >= Tiles.COUNT
	emit(state, { type = "Moved", player = player.id, from = from, to = player.position, passedGo = passedGo })
	if passedGo then
		transfer(state, nil, player.id, Engine.GO_SALARY, "Go")
	end

	resolveLanding(state, player)
end

local function buy(state: GameState, player: Player): (boolean, string?)
	local tile = Tiles.at(player.position)
	local price = tile.price :: number
	if player.money < price then
		return false, "not enough money"
	end
	transfer(state, player.id, nil, price, "Purchase")
	state.properties[tile.position] = { owner = player.id, houses = 0, mortgaged = false }
	emit(state, { type = "Bought", player = player.id, position = tile.position, price = price })
	finishMove(state)
	return true
end

local function endTurn(state: GameState)
	state.lastRoll = nil
	for _ = 1, #state.players do
		state.currentIndex = state.currentIndex % #state.players + 1
		if not Engine.currentPlayer(state).bankrupt then
			break
		end
	end
	state.phase = "Roll"
	emit(state, { type = "TurnStarted", player = Engine.currentPlayer(state).id })
end

function Engine.new(players: { PlayerInfo }, rollDice: Types.DiceRoller): GameState
	assert(
		#players >= Engine.MIN_PLAYERS and #players <= Engine.MAX_PLAYERS,
		`a game needs {Engine.MIN_PLAYERS}-{Engine.MAX_PLAYERS} players, got {#players}`
	)

	local seen = {}
	local playerStates = {}
	for _, info in players do
		assert(not seen[info.id], `duplicate player id {info.id}`)
		seen[info.id] = true
		table.insert(playerStates, {
			id = info.id,
			name = info.name,
			isBot = info.isBot,
			money = Engine.STARTING_MONEY,
			position = 0,
			bankrupt = false,
		})
	end

	local state: GameState = {
		players = playerStates,
		currentIndex = 1,
		phase = "Roll",
		properties = {},
		lastRoll = nil,
		auction = nil,
		events = {},
		rollDice = rollDice,
	}
	emit(state, { type = "TurnStarted", player = playerStates[1].id })
	return state
end

function Engine.act(state: GameState, playerId: string, action: Types.Action): (boolean, string?)
	if typeof(action) ~= "table" or typeof(action.type) ~= "string" then
		return false, "invalid action"
	end
	if state.phase == "GameOver" then
		return false, "the game is over"
	end
	local player = Engine.getPlayer(state, playerId)
	if not player or player.bankrupt then
		return false, "not in this game"
	end

	if Engine.currentPlayer(state).id ~= playerId then
		return false, "not your turn"
	end

	if action.type == "Roll" and state.phase == "Roll" then
		roll(state, player)
		return true
	elseif action.type == "Buy" and state.phase == "BuyDecision" then
		return buy(state, player)
	elseif action.type == "EndTurn" and state.phase == "EndTurn" then
		endTurn(state)
		return true
	end
	return false, `can't {action.type} now`
end

return Engine
```

- [ ] **Step 5: Run tests to verify they pass**

Run all tests. Expected: `45 passed, 0 failed` (27 + 18 engine).

- [ ] **Step 6: Commit**

```bash
git add src/server/Game/Engine.luau src/tests/GameFixtures.luau src/tests/Engine.spec.luau
git commit -m "feat: engine turns, movement, buying, rent and tax"
```

---

### Task 3: Auctions

**Files:**
- Modify: `src/server/Game/Engine.luau`
- Create: `src/tests/Auction.spec.luau`

**Interfaces:**
- Consumes: everything from Task 2; `Types.Auction`.
- Produces:
  - Actions `{ type = "Decline" }` (in `BuyDecision`), `{ type = "Bid", amount = number }`, `{ type = "PassBid" }` (in `Auction`, only by `auction.bidders[auction.nextBidder]`).
  - `Engine.currentBidder(state): string?` — who must act in the auction, or nil when there is none.
  - Events: `AuctionStarted {position, bidders}`, `BidPlaced {player, amount}`, `BidPassed {player}`, `AuctionEnded {position, winner: string?, amount}` (+ `Paid` with reason `"Auction"` when there is a winner).

- [ ] **Step 1: Write the failing auction tests**

`src/tests/Auction.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ORIENTAL = 6

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function bid(amount: number)
	return { type = "Bid", amount = amount }
end
local PASS = { type = "PassBid" }

-- p1 lands on Oriental Avenue and declines it.
local function declinedGame(playerCount: number, rolls: { { number } }?)
	local state = GameFixtures.newGame(playerCount, rolls or { { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	return state
end

tests["declining starts an auction with the decliner bidding first"] = function()
	local state = declinedGame(3)
	Expect.equal(state.phase, "Auction")
	Expect.equal(Engine.currentBidder(state), "p1")
	local started = GameFixtures.eventsOfType(state, "AuctionStarted")[1]
	Expect.equal(started.position, ORIENTAL, "position")
	Expect.equal(table.concat(started.bidders, ","), "p1,p2,p3", "bidders")
end

tests["bidding order starts from the decliner and wraps"] = function()
	local state = GameFixtures.newGame(3, { { 3, 4 }, { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "EndTurn" })
	act(state, "p2", { type = "Roll" })
	act(state, "p2", { type = "Decline" })
	local started = GameFixtures.eventsOfType(state, "AuctionStarted")[1]
	Expect.equal(table.concat(started.bidders, ","), "p2,p3,p1", "bidders")
end

tests["auction goes to the highest bidder"] = function()
	local state = declinedGame(3)
	act(state, "p1", bid(10))
	act(state, "p2", bid(20))
	act(state, "p3", PASS)
	act(state, "p1", PASS)
	Expect.equal(state.properties[ORIENTAL].owner, "p2")
	Expect.equal(Engine.getPlayer(state, "p2").money, 1480)
	Expect.equal(Engine.getPlayer(state, "p1").money, 1500)
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(Engine.currentPlayer(state).id, "p1", "turn stays with p1")
	local ended = GameFixtures.eventsOfType(state, "AuctionEnded")[1]
	Expect.equal(ended.winner, "p2")
	Expect.equal(ended.amount, 20)
end

tests["if everyone passes the bank keeps the property"] = function()
	local state = declinedGame(2)
	act(state, "p1", PASS)
	act(state, "p2", PASS)
	Expect.equal(state.properties[ORIENTAL], nil)
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(GameFixtures.eventsOfType(state, "AuctionEnded")[1].winner, nil)
end

tests["last bidder left can still bid"] = function()
	local state = declinedGame(3)
	act(state, "p1", PASS)
	act(state, "p2", PASS)
	Expect.equal(state.phase, "Auction", "still open for p3")
	Expect.equal(Engine.currentBidder(state), "p3")
	act(state, "p3", bid(1))
	Expect.equal(state.properties[ORIENTAL].owner, "p3")
	Expect.equal(Engine.getPlayer(state, "p3").money, 1499)
end

tests["bids must be higher, whole, and affordable"] = function()
	local state = declinedGame(2)
	act(state, "p1", bid(10))
	for _, bad in { 10, 5, 10.5, 2000, 0 / 0, math.huge, "20" :: any } do
		assert(not Engine.act(state, "p2", bid(bad)), `accepted bid {tostring(bad)}`)
	end
	Expect.equal(Engine.currentBidder(state), "p2", "p2 still to act")
	act(state, "p2", bid(1500))
end

tests["only the next bidder can act in an auction"] = function()
	local state = declinedGame(3)
	assert(not Engine.act(state, "p2", bid(10)), "p2 bid out of order")
	assert(not Engine.act(state, "p1", { type = "Roll" }), "rolled during auction")
	assert(not Engine.act(state, "p1", { type = "EndTurn" }), "ended turn during auction")
	act(state, "p1", bid(10))
end

tests["doubles still give another roll after an auction"] = function()
	local state = declinedGame(2, { { 3, 3 } })
	act(state, "p1", PASS)
	act(state, "p2", PASS)
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
end

tests["bankrupt players are left out of auctions"] = function()
	local state = GameFixtures.newGame(3, { { 2, 4 } })
	Engine.getPlayer(state, "p2").bankrupt = true
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	local started = GameFixtures.eventsOfType(state, "AuctionStarted")[1]
	Expect.equal(table.concat(started.bidders, ","), "p1,p3", "bidders")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run `.run("Auction")`. Expected: `0 passed, 9 failed`, each failing with `p1 Decline failed: can't Decline now` (or `Engine.currentBidder` being nil for the tests that don't reach it).

- [ ] **Step 3: Add auctions to the engine**

In `src/server/Game/Engine.luau`, add after `buy`:

```lua
function Engine.currentBidder(state: GameState): string?
	local auction = state.auction
	return if auction then auction.bidders[auction.nextBidder] else nil
end

local function startAuction(state: GameState, position: number)
	-- Everyone still in the game bids, starting with the player who declined.
	local bidders = {}
	for offset = 0, #state.players - 1 do
		local player = state.players[(state.currentIndex - 1 + offset) % #state.players + 1]
		if not player.bankrupt then
			table.insert(bidders, player.id)
		end
	end
	state.auction = { position = position, highBid = 0, highBidder = nil, bidders = bidders, nextBidder = 1 }
	state.phase = "Auction"
	emit(state, { type = "AuctionStarted", position = position, bidders = table.clone(bidders) })
end

local function endAuctionIfSettled(state: GameState)
	local auction = state.auction :: Types.Auction
	local settled = #auction.bidders == 0 or (#auction.bidders == 1 and auction.bidders[1] == auction.highBidder)
	if not settled then
		return
	end

	state.auction = nil
	local winner = auction.highBidder
	if winner then
		transfer(state, winner, nil, auction.highBid, "Auction")
		state.properties[auction.position] = { owner = winner, houses = 0, mortgaged = false }
	end
	emit(state, { type = "AuctionEnded", position = auction.position, winner = winner, amount = auction.highBid })
	finishMove(state)
end

local function placeBid(state: GameState, player: Player, amount: any): (boolean, string?)
	local auction = state.auction :: Types.Auction
	if typeof(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount <= auction.highBid then
		return false, `bid must be a whole number above {auction.highBid}`
	end
	if amount > player.money then
		return false, "not enough money"
	end
	auction.highBid = amount
	auction.highBidder = player.id
	emit(state, { type = "BidPlaced", player = player.id, amount = amount })
	auction.nextBidder = auction.nextBidder % #auction.bidders + 1
	endAuctionIfSettled(state)
	return true
end

local function passBid(state: GameState, player: Player)
	local auction = state.auction :: Types.Auction
	table.remove(auction.bidders, auction.nextBidder)
	emit(state, { type = "BidPassed", player = player.id })
	if auction.nextBidder > #auction.bidders then
		auction.nextBidder = 1
	end
	endAuctionIfSettled(state)
end
```

(`amount ~= amount` catches NaN; `math.huge % 1` is NaN, so infinity is rejected by the whole-number check.)

In `Engine.act`, replace:

```lua
	if Engine.currentPlayer(state).id ~= playerId then
		return false, "not your turn"
	end
```

with:

```lua
	if state.phase == "Auction" then
		if Engine.currentBidder(state) ~= playerId then
			return false, "not your turn to bid"
		elseif action.type == "Bid" then
			return placeBid(state, player, action.amount)
		elseif action.type == "PassBid" then
			passBid(state, player)
			return true
		end
		return false, "an auction is in progress"
	end

	if Engine.currentPlayer(state).id ~= playerId then
		return false, "not your turn"
	end
```

and add a `Decline` branch after the `Buy` branch:

```lua
	elseif action.type == "Decline" and state.phase == "BuyDecision" then
		startAuction(state, player.position)
		return true
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: `54 passed, 0 failed` (45 + 9 auction).

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Engine.luau src/tests/Auction.spec.luau
git commit -m "feat: property auctions"
```
