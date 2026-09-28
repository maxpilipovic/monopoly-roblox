# Buildings and Mortgages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players build houses/hotels, sell them back, and mortgage/unmortgage property through a HUD Properties panel on their own turn; bots build steadily; houses and hotels appear on the board.

**Architecture:** A pure shared `PropertyRules` module decides legality and costs from a plain view (`properties`, `bankHouses`, `bankHotels`) — `GameState` is such a view on the server, and the HUD builds one from the snapshot, so the UI only offers actions the engine accepts. The engine adds four actions (`Build`, `SellBuilding`, `Mortgage`, `Unmortgage`) allowed in the current player's Roll/EndTurn phases, plus a bank house/hotel supply. Client: `HudModel.propertyRows` (pure) feeds a scrolling panel in `HudView`; a `Buildings` view places house/hotel parts using a shared `BuildingLayout`.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7, in-Studio test runner, Studio MCP for playtests.

**Spec:** `docs/superpowers/specs/2026-09-28-buildings-and-mortgages-design.md` (read it; this plan implements it). Builds on `docs/superpowers/plans/2026-09-28-jail-and-cards.md`.

## Global Constraints

- Property actions only on your own turn, phase `Roll` or `EndTurn`; never BuyDecision/Auction/GameOver. Allowed while in jail.
- House price = `ColorGroups[group].houseCost` (50/100/150/200 by board side — identical to the spec's per-side prices). Hotel costs one more house price and returns 4 houses to the bank.
- Bank: 32 houses, 12 hotels. Build evenly; sell evenly; selling returns half the house price. Selling a hotel needs 4 houses in the bank (else refused).
- Mortgage: half the price, only if the set has no buildings (streets). Unmortgage: `value + ceil(value / 10)` (integer math — never `value * 1.1`, floating point makes `ceil(33.000000000000004) = 34`).
- Bots: before rolling, unmortgage cheapest when `money - cost >= 3 × CASH_RESERVE`, else build cheapest legal when `money - price >= CASH_RESERVE`, else existing logic. Never mortgage voluntarily.
- Out of scope: house-shortage auctions, 10% transfer interest (trading), raising cash while in debt (part 2), ownership markers / mortgaged tile look (polish).
- Every new `.luau` file starts with `--!strict`. Tabs.

## Review Focus

1. **A tampered client sends a property action with a garbage position** (nil, "1", 1.5, -1, 40, NaN, a Chance tile) — expect a clean rejection and no state change. Pinned by BuildingActions.spec "garbage positions are rejected without changing anything".
2. **The bank runs out of houses mid-game** — Build must be refused with a clear reason and the HUD must stop offering it. Pinned by PropertyRules.spec "the bank's supply limits building" and HudModel.spec rows (built from the same rules).
3. **Selling a hotel when the bank is short of houses** — refused, nothing changes. Pinned by PropertyRules.spec "selling a hotel needs 4 houses in the bank" and BuildingActions.spec "selling a hotel returns it and takes 4 houses".
4. **Bots loop forever building or unmortgaging** — each bot action must reduce money or change state so the loop ends in a Roll. Pinned by Bot.spec "an all-bot game keeps making legal moves" (2000 steps) and "two bots eventually build".
5. **Unmortgage cost rounding** — $33 for a $30 mortgage, $83 for $75. Pinned by PropertyRules.spec "mortgage values and unmortgage costs".

## File Structure

```
src/shared/Rules/PropertyRules.luau      (create) legality + costs for Build/Sell/Mortgage/Unmortgage
src/shared/Board/BuildingLayout.luau     (create) where houses/hotel sit on a tile's color band
src/server/Game/Types.luau               (modify) bankHouses/bankHotels; Action comment
src/server/Game/Engine.luau              (modify) bank supply, four property actions
src/server/Game/Snapshot.luau            (modify) bankHouses/bankHotels
src/shared/Net/Protocol.luau             (modify) Snapshot.bankHouses/bankHotels
src/server/Game/Bot.luau                 (modify) unmortgage/build before rolling
src/client/Hud/HudModel.luau             (modify) propertyRows, buildingText
src/client/Hud/EventText.luau            (modify) Built/BuildingSold/Mortgaged/Unmortgaged lines
src/client/Hud/HudView.luau              (modify) Properties toggle + scrolling panel; wider action bar
src/client/Buildings.luau                (create) house/hotel parts in step with the snapshot
src/client/GameClient.luau               (modify) drive Buildings
src/tests/GameFixtures.luau              (modify) bank fields in bareState
src/tests/PropertyRules.spec.luau, BuildingActions.spec.luau, BuildingLayout.spec.luau, Buildings.spec.luau (create)
src/tests/Rent.spec.luau, Snapshot.spec.luau, Bot.spec.luau, HudModel.spec.luau, EventText.spec.luau (modify)
```

`src/shared/Rules/` is a new folder under the already-synced `src/shared`, so no project-file change and no Rojo restart.

## How to run the tests

Studio MCP: `start_stop_play(true)`, `execute_luau(Server, 'return require(game.ServerStorage.Tests.TestRunner).run()')`, `start_stop_play(false)`. **Before every run**, confirm with `execute_luau(Edit, ...)` that each file edited since the last run contains its newest snippet in `.Source` — Studio sometimes misses a Rojo patch; if one is stuck, make a real content change to that file (append then strip a trailing newline). Baseline: 128 passed, 0 failed.

---

### Task 1: PropertyRules

**Files:**
- Create: `src/shared/Rules/PropertyRules.luau`, `src/tests/PropertyRules.spec.luau`

**Interfaces:**
- Consumes: `Tiles.at/list`, `ColorGroups[group].houseCost`, `GameFixtures.bareState/own`.
- Produces (all pure; `view` is anything with `properties: { [number]: { owner: string, houses: number, mortgaged: boolean } }`, `bankHouses: number`, `bankHotels: number` — `GameState` qualifies):
  - `PropertyRules.HOTEL = 5`, `PropertyRules.HOUSES_PER_HOTEL = 4`
  - `housePrice(position): number` (errors for non-streets), `mortgageValue(position): number`, `unmortgageCost(position): number`
  - `groupPositions(group: string): { number }`
  - `canBuild(view, playerId, money, position): (boolean, string?)`
  - `canSell(view, playerId, position): (boolean, string?)`
  - `canMortgage(view, playerId, position): (boolean, string?)`
  - `canUnmortgage(view, playerId, money, position): (boolean, string?)`
  - Reasons (exact strings): `"you don't own it"`, `"only streets can have buildings"`, `"you need the whole color set"`, `"a property in this set is mortgaged"`, `"it already has a hotel"`, `"build evenly across the set"`, `"the bank has no hotels left"`, `"the bank has no houses left"`, `"not enough money"`, `"no buildings to sell"`, `"sell evenly across the set"`, `"the bank doesn't have 4 houses to replace the hotel"`, `"it is already mortgaged"`, `"sell the buildings in this set first"`, `"it isn't mortgaged"`.

- [ ] **Step 1: Write the failing tests**

Create `src/tests/PropertyRules.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Brown set: Mediterranean (1) and Baltic (3). Light blue: 6, 8, 9. Reading Railroad: 5. Electric Company: 12.
local MEDITERRANEAN, BALTIC, READING, ELECTRIC = 1, 3, 5, 12

local function brownSet(houses1: number?, houses3: number?)
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p1", MEDITERRANEAN, houses1)
	GameFixtures.own(state, "p1", BALTIC, houses3)
	return state
end

local function refused(ok: boolean, reason: string?, expected: string, label: string)
	assert(not ok, `{label}: allowed`)
	Expect.equal(reason, expected, label)
end

tests["house prices follow the board side"] = function()
	Expect.equal(PropertyRules.housePrice(1), 50, "brown")
	Expect.equal(PropertyRules.housePrice(11), 100, "pink")
	Expect.equal(PropertyRules.housePrice(21), 150, "red")
	Expect.equal(PropertyRules.housePrice(39), 200, "dark blue")
	assert(not pcall(PropertyRules.housePrice, READING), "railroad has a house price")
end

tests["mortgage values and unmortgage costs"] = function()
	Expect.equal(PropertyRules.mortgageValue(MEDITERRANEAN), 30, "Mediterranean")
	Expect.equal(PropertyRules.mortgageValue(READING), 100, "Reading")
	Expect.equal(PropertyRules.mortgageValue(ELECTRIC), 75, "Electric")
	Expect.equal(PropertyRules.unmortgageCost(MEDITERRANEAN), 33, "30 + 10%")
	Expect.equal(PropertyRules.unmortgageCost(ELECTRIC), 83, "75 + 10%, rounded up")
	Expect.equal(PropertyRules.unmortgageCost(READING), 110, "100 + 10%")
	Expect.equal(PropertyRules.unmortgageCost(39), 220, "200 + 10%")
end

tests["group positions list a color set"] = function()
	Expect.equal(table.concat(PropertyRules.groupPositions("LightBlue"), ","), "6,8,9")
	Expect.equal(table.concat(PropertyRules.groupPositions("DarkBlue"), ","), "37,39")
end

tests["building needs the whole set, unmortgaged, and a street"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p1", MEDITERRANEAN)
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "you need the whole color set", "half a set")
	GameFixtures.own(state, "p2", BALTIC)
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "you need the whole color set", "other owner")
	refused(PropertyRules.canBuild(state, "p2", 1500, MEDITERRANEAN), "you don't own it", "not the owner")

	state = brownSet()
	assert(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "full set refused")
	state.properties[BALTIC].mortgaged = true
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "a property in this set is mortgaged", "mortgaged")

	GameFixtures.own(state, "p1", READING)
	refused(PropertyRules.canBuild(state, "p1", 1500, READING), "only streets can have buildings", "railroad")
end

tests["building is even across the set"] = function()
	local state = brownSet(1, 0)
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "build evenly across the set", "ahead")
	assert(PropertyRules.canBuild(state, "p1", 1500, BALTIC), "behind refused")
	state = brownSet(5, 5)
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "it already has a hotel", "hotel")
end

tests["building costs the house price"] = function()
	local state = brownSet()
	refused(PropertyRules.canBuild(state, "p1", 49, MEDITERRANEAN), "not enough money", "49")
	assert(PropertyRules.canBuild(state, "p1", 50, MEDITERRANEAN), "50 refused")
end

tests["the bank's supply limits building"] = function()
	local state = brownSet()
	state.bankHouses = 0
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "the bank has no houses left", "no houses")
	state = brownSet(4, 4)
	state.bankHouses = 0
	assert(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "hotel needs no houses from the bank")
	state.bankHotels = 0
	refused(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "the bank has no hotels left", "no hotels")
end

tests["selling is even across the set"] = function()
	local state = brownSet(0, 0)
	refused(PropertyRules.canSell(state, "p1", MEDITERRANEAN), "no buildings to sell", "nothing built")
	state = brownSet(2, 1)
	refused(PropertyRules.canSell(state, "p1", BALTIC), "sell evenly across the set", "behind")
	assert(PropertyRules.canSell(state, "p1", MEDITERRANEAN), "ahead refused")
	refused(PropertyRules.canSell(state, "p2", MEDITERRANEAN), "you don't own it", "not the owner")
end

tests["selling a hotel needs 4 houses in the bank"] = function()
	local state = brownSet(5, 4)
	state.bankHouses = 3
	refused(PropertyRules.canSell(state, "p1", MEDITERRANEAN), "the bank doesn't have 4 houses to replace the hotel", "3 houses")
	state.bankHouses = 4
	assert(PropertyRules.canSell(state, "p1", MEDITERRANEAN), "4 houses refused")
end

tests["mortgaging needs no buildings in the set"] = function()
	local state = brownSet(0, 1)
	refused(PropertyRules.canMortgage(state, "p1", MEDITERRANEAN), "sell the buildings in this set first", "buildings")
	state = brownSet(0, 0)
	assert(PropertyRules.canMortgage(state, "p1", MEDITERRANEAN), "empty set refused")
	state.properties[MEDITERRANEAN].mortgaged = true
	refused(PropertyRules.canMortgage(state, "p1", MEDITERRANEAN), "it is already mortgaged", "twice")
	GameFixtures.own(state, "p1", READING)
	assert(PropertyRules.canMortgage(state, "p1", READING), "railroad refused")
	refused(PropertyRules.canMortgage(state, "p1", 0), "you don't own it", "Go")
	refused(PropertyRules.canMortgage(state, "p2", READING), "you don't own it", "not the owner")
end

tests["unmortgaging needs a mortgage and the money"] = function()
	local state = brownSet()
	refused(PropertyRules.canUnmortgage(state, "p1", 1500, MEDITERRANEAN), "it isn't mortgaged", "not mortgaged")
	state.properties[MEDITERRANEAN].mortgaged = true
	refused(PropertyRules.canUnmortgage(state, "p1", 32, MEDITERRANEAN), "not enough money", "32")
	assert(PropertyRules.canUnmortgage(state, "p1", 33, MEDITERRANEAN), "33 refused")
	refused(PropertyRules.canUnmortgage(state, "p2", 1500, MEDITERRANEAN), "you don't own it", "not the owner")
end

return tests
```

`GameFixtures.bareState` has no `bankHouses`/`bankHotels` yet — add them in this task (Step 3) so the fixture is a full view.

- [ ] **Step 2: Run tests to verify they fail**

Run: `.run("PropertyRules")`. Expected: `FAIL PropertyRules.spec (load)` (module missing).

- [ ] **Step 3: Implement**

`src/tests/GameFixtures.luau` — in `bareState`'s state literal, after `rollAgain = false,` add `bankHouses = 32, bankHotels = 12,`. (Types gain these fields in Task 2; until then the fixture's extra fields are harmless.)

Create `src/shared/Rules/PropertyRules.luau`:

```lua
--!strict
-- Whether a player may build, sell, mortgage or unmortgage, and what it costs. Pure: works on any
-- view with properties + the bank's supply, so the server (GameState) and the HUD (snapshot) agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Ownership = {
	owner: string,
	houses: number, -- 0-4 houses, 5 = hotel
	mortgaged: boolean,
}

export type View = {
	properties: { [number]: Ownership },
	bankHouses: number,
	bankHotels: number,
}

local PropertyRules = {}

PropertyRules.HOTEL = 5
PropertyRules.HOUSES_PER_HOTEL = 4

local groupCache: { [string]: { number } } = {}

function PropertyRules.groupPositions(group: string): { number }
	local cached = groupCache[group]
	if not cached then
		cached = {}
		for _, tile in Tiles.list do
			if tile.group == group then
				table.insert(cached, tile.position)
			end
		end
		table.freeze(cached)
		groupCache[group] = cached
	end
	return cached
end

function PropertyRules.housePrice(position: number): number
	local tile = Tiles.at(position)
	assert(tile.kind == "Property", `{tile.name} can't have buildings`)
	return ColorGroups[tile.group :: string].houseCost
end

function PropertyRules.mortgageValue(position: number): number
	return (Tiles.at(position).price :: number) // 2
end

function PropertyRules.unmortgageCost(position: number): number
	local value = PropertyRules.mortgageValue(position)
	return value + math.ceil(value / 10) -- integer math: value * 1.1 has rounding error
end

local function owned(view: View, playerId: string, position: number): Ownership?
	local ownership = view.properties[position]
	return if ownership and ownership.owner == playerId then ownership else nil
end

function PropertyRules.canBuild(view: View, playerId: string, money: number, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	end
	local tile = Tiles.at(position)
	if tile.kind ~= "Property" then
		return false, "only streets can have buildings"
	end
	local fewest = math.huge
	for _, other in PropertyRules.groupPositions(tile.group :: string) do
		local otherOwnership = owned(view, playerId, other)
		if not otherOwnership then
			return false, "you need the whole color set"
		elseif otherOwnership.mortgaged then
			return false, "a property in this set is mortgaged"
		end
		fewest = math.min(fewest, otherOwnership.houses)
	end
	if ownership.houses >= PropertyRules.HOTEL then
		return false, "it already has a hotel"
	elseif ownership.houses > fewest then
		return false, "build evenly across the set"
	elseif ownership.houses == PropertyRules.HOUSES_PER_HOTEL and view.bankHotels < 1 then
		return false, "the bank has no hotels left"
	elseif ownership.houses < PropertyRules.HOUSES_PER_HOTEL and view.bankHouses < 1 then
		return false, "the bank has no houses left"
	elseif money < PropertyRules.housePrice(position) then
		return false, "not enough money"
	end
	return true
end

function PropertyRules.canSell(view: View, playerId: string, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	elseif ownership.houses == 0 then
		return false, "no buildings to sell"
	end
	for _, other in PropertyRules.groupPositions(Tiles.at(position).group :: string) do
		local otherOwnership = view.properties[other]
		if otherOwnership and otherOwnership.houses > ownership.houses then
			return false, "sell evenly across the set"
		end
	end
	if ownership.houses == PropertyRules.HOTEL and view.bankHouses < PropertyRules.HOUSES_PER_HOTEL then
		return false, "the bank doesn't have 4 houses to replace the hotel"
	end
	return true
end

function PropertyRules.canMortgage(view: View, playerId: string, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	elseif ownership.mortgaged then
		return false, "it is already mortgaged"
	end
	local tile = Tiles.at(position)
	if tile.kind == "Property" then
		for _, other in PropertyRules.groupPositions(tile.group :: string) do
			local otherOwnership = view.properties[other]
			if otherOwnership and otherOwnership.houses > 0 then
				return false, "sell the buildings in this set first"
			end
		end
	end
	return true
end

function PropertyRules.canUnmortgage(view: View, playerId: string, money: number, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	elseif not ownership.mortgaged then
		return false, "it isn't mortgaged"
	elseif money < PropertyRules.unmortgageCost(position) then
		return false, "not enough money"
	end
	return true
end

return PropertyRules
```

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: 128 + 12 = 140 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules/PropertyRules.luau src/tests/PropertyRules.spec.luau src/tests/GameFixtures.luau
git commit -m "feat: rules for building, selling and mortgaging"
```

---

### Task 2: Engine actions and the bank's supply

**Files:**
- Modify: `src/server/Game/Types.luau`, `src/server/Game/Engine.luau`, `src/server/Game/Snapshot.luau`, `src/shared/Net/Protocol.luau`, `src/tests/Rent.spec.luau`, `src/tests/Snapshot.spec.luau`
- Create: `src/tests/BuildingActions.spec.luau`

**Interfaces:**
- Consumes: Task 1 `PropertyRules.*`.
- Produces:
  - `Engine.BANK_HOUSES = 32`, `Engine.BANK_HOTELS = 12`; `GameState.bankHouses/bankHotels`.
  - Actions `{ type = "Build" | "SellBuilding" | "Mortgage" | "Unmortgage", position = number }`, current player only, phase Roll/EndTurn. Garbage position → `false, "invalid position"`.
  - Events: `Built { player, position, amount, hotel }`, `BuildingSold { player, position, amount, hotel }`, `Mortgaged { player, position, amount }`, `Unmortgaged { player, position, amount }`; money via `Paid` reason `"Building"` or `"Mortgage"`.
  - `Protocol.Snapshot.bankHouses/bankHotels: number`.

- [ ] **Step 1: Write the failing tests**

Create `src/tests/BuildingActions.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local MEDITERRANEAN, BALTIC, READING = 1, 3, 5

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 owns the brown set, it's p1's turn to roll.
local function brownGame(houses1: number?, houses3: number?, rolls: { { number } }?)
	local state = GameFixtures.newGame(2, rolls)
	GameFixtures.own(state, "p1", MEDITERRANEAN, houses1)
	GameFixtures.own(state, "p1", BALTIC, houses3)
	return state
end

local function build(position: number)
	return { type = "Build", position = position }
end

tests["new games start with 32 houses and 12 hotels in the bank"] = function()
	local state = GameFixtures.newGame(2)
	Expect.equal(state.bankHouses, 32, "houses")
	Expect.equal(state.bankHotels, 12, "hotels")
	local snapshot = Snapshot.fromState(state)
	Expect.equal(snapshot.bankHouses, 32, "snapshot houses")
	Expect.equal(snapshot.bankHotels, 12, "snapshot hotels")
end

tests["building a house charges the price and takes a house from the bank"] = function()
	local state = brownGame()
	act(state, "p1", build(MEDITERRANEAN))
	Expect.equal(state.properties[MEDITERRANEAN].houses, 1, "houses")
	Expect.equal(player(state, "p1").money, 1450, "money")
	Expect.equal(state.bankHouses, 31, "bank houses")
	local built = GameFixtures.eventsOfType(state, "Built")[1]
	Expect.equal(built.position, MEDITERRANEAN, "event position")
	Expect.equal(built.amount, 50, "event amount")
	Expect.equal(built.hotel, false, "event hotel")
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[1].reason, "Building", "paid reason")
	Expect.equal(state.phase, "Roll", "still p1's roll")
end

tests["a fifth building is a hotel and returns four houses"] = function()
	local state = brownGame(4, 4)
	state.bankHouses = 24
	act(state, "p1", build(MEDITERRANEAN))
	Expect.equal(state.properties[MEDITERRANEAN].houses, 5, "hotel")
	Expect.equal(state.bankHotels, 11, "bank hotels")
	Expect.equal(state.bankHouses, 28, "houses returned")
	Expect.equal(player(state, "p1").money, 1450, "money")
	Expect.equal(GameFixtures.eventsOfType(state, "Built")[1].hotel, true, "event hotel")
end

tests["selling a house refunds half and returns it to the bank"] = function()
	local state = brownGame(1, 1)
	state.bankHouses = 30
	act(state, "p1", { type = "SellBuilding", position = BALTIC })
	Expect.equal(state.properties[BALTIC].houses, 0, "houses")
	Expect.equal(player(state, "p1").money, 1525, "money")
	Expect.equal(state.bankHouses, 31, "bank houses")
	local sold = GameFixtures.eventsOfType(state, "BuildingSold")[1]
	Expect.equal(sold.amount, 25, "event amount")
	Expect.equal(sold.hotel, false, "event hotel")
end

tests["selling a hotel returns it and takes 4 houses"] = function()
	local state = brownGame(5, 4)
	state.bankHouses = 3
	state.bankHotels = 11
	local ok, err = Engine.act(state, "p1", { type = "SellBuilding", position = MEDITERRANEAN })
	assert(not ok, "sold without houses in the bank")
	Expect.equal(err, "the bank doesn't have 4 houses to replace the hotel")
	Expect.equal(state.properties[MEDITERRANEAN].houses, 5, "unchanged")

	state.bankHouses = 4
	act(state, "p1", { type = "SellBuilding", position = MEDITERRANEAN })
	Expect.equal(state.properties[MEDITERRANEAN].houses, 4, "back to 4 houses")
	Expect.equal(state.bankHouses, 0, "4 houses taken")
	Expect.equal(state.bankHotels, 12, "hotel returned")
	Expect.equal(GameFixtures.eventsOfType(state, "BuildingSold")[1].hotel, true, "event hotel")
end

tests["mortgaging pays half the price; unmortgaging costs that plus 10%"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", READING)
	act(state, "p1", { type = "Mortgage", position = READING })
	Expect.equal(state.properties[READING].mortgaged, true, "mortgaged")
	Expect.equal(player(state, "p1").money, 1600, "paid out")
	Expect.equal(GameFixtures.eventsOfType(state, "Mortgaged")[1].amount, 100, "event amount")
	act(state, "p1", { type = "Unmortgage", position = READING })
	Expect.equal(state.properties[READING].mortgaged, false, "unmortgaged")
	Expect.equal(player(state, "p1").money, 1490, "paid 110")
	Expect.equal(GameFixtures.eventsOfType(state, "Unmortgaged")[1].amount, 110, "event amount")
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[2].reason, "Mortgage", "paid reason")
end

tests["rule violations are refused with the rule's reason"] = function()
	local state = brownGame(1, 0)
	local ok, err = Engine.act(state, "p1", build(MEDITERRANEAN))
	assert(not ok, "built unevenly")
	Expect.equal(err, "build evenly across the set")
	ok, err = Engine.act(state, "p1", { type = "Mortgage", position = BALTIC })
	assert(not ok, "mortgaged with buildings in the set")
	Expect.equal(err, "sell the buildings in this set first")
end

tests["property actions work after moving, in the EndTurn phase"] = function()
	local state = brownGame(nil, nil, { { 3, 4 } }) -- 7: Chance, dividend (money-only)
	act(state, "p1", { type = "Roll" })
	Expect.equal(state.phase, "EndTurn")
	act(state, "p1", build(MEDITERRANEAN))
	Expect.equal(state.properties[MEDITERRANEAN].houses, 1)
end

tests["property actions only on your own turn, never mid-decision"] = function()
	local state = brownGame(nil, nil, { { 2, 4 } }) -- 6: Oriental Avenue, unowned
	local ok, err = Engine.act(state, "p2", { type = "Mortgage", position = MEDITERRANEAN })
	assert(not ok, "p2 acted on p1's turn")
	Expect.equal(err, "not your turn")
	act(state, "p1", { type = "Roll" })
	Expect.equal(state.phase, "BuyDecision")
	assert(not Engine.act(state, "p1", build(MEDITERRANEAN)), "built during a buy decision")
	act(state, "p1", { type = "Decline" })
	Expect.equal(state.phase, "Auction")
	assert(not Engine.act(state, "p1", build(MEDITERRANEAN)), "built during an auction")
	Expect.equal(state.properties[MEDITERRANEAN].houses, 0, "nothing built")
end

tests["garbage positions are rejected without changing anything"] = function()
	local state = brownGame()
	GameFixtures.own(state, "p1", READING)
	local eventCount = #state.events
	-- nil can't sit in a table literal (iteration would skip it), so it gets its own check.
	for _, kind in { "Build", "SellBuilding", "Mortgage", "Unmortgage" } do
		local ok, err = Engine.act(state, "p1", { type = kind })
		assert(not ok, `{kind} accepted a missing position`)
		Expect.equal(err, "invalid position", `{kind} nil`)
		for _, bad in { "1", 1.5, -1, 40, 0 / 0, math.huge } :: { any } do
			ok, err = Engine.act(state, "p1", { type = kind, position = bad })
			assert(not ok, `{kind} accepted {tostring(bad)}`)
			Expect.equal(err, "invalid position", `{kind} {tostring(bad)}`)
		end
	end
	local ok = Engine.act(state, "p1", build(7)) -- Chance
	assert(not ok, "built on Chance")
	Expect.equal(#state.events, eventCount, "no events")
	Expect.equal(player(state, "p1").money, 1500, "money unchanged")
	Expect.equal(state.bankHouses, 32, "bank unchanged")
end

tests["rent follows the houses you build"] = function()
	local state = brownGame(nil, nil, { { 3, 4 }, { 1, 2 } })
	act(state, "p1", build(MEDITERRANEAN))
	act(state, "p1", build(BALTIC))
	act(state, "p1", build(MEDITERRANEAN))
	act(state, "p1", { type = "Roll" }) -- 7, dividend
	act(state, "p1", { type = "EndTurn" })
	player(state, "p2").position = 38
	act(state, "p2", { type = "Roll" }) -- 38 + 3 = 1, Mediterranean with 2 houses
	Expect.equal(player(state, "p2").money, 1500 + 200 - 30, "Go, then 2-house rent")
end

return tests
```

`src/tests/Rent.spec.luau` — add (characterisation: already true, pins the spec's rent rule):

```lua
tests["a full set still doubles bare lots when another lot in it is mortgaged"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", 1)
	GameFixtures.own(state, "p2", 3)
	state.properties[3].mortgaged = true
	Expect.equal(Rent.calculate(state, 1, 7), 4, "Mediterranean base 2, doubled")
end
```

(Check the top of `Rent.spec.luau` for how `GameFixtures`/`Rent` are required and match it.)

`src/tests/Snapshot.spec.luau` — nothing extra; bank counts are covered by the first BuildingActions test.

- [ ] **Step 2: Run tests to verify they fail**

Run: full suite. Expected: BuildingActions failures such as `houses: expected 32, got nil` and `Build failed: can't Build now`; the Rent test passes already (characterisation — note it, don't count it as RED).

- [ ] **Step 3: Implement**

`src/server/Game/Types.luau` — `GameState` gains after `decks`:

```lua
	bankHouses: number, -- houses left in the bank
	bankHotels: number, -- hotels left in the bank
```

and the `Action` comment becomes:

```lua
export type Action = { [string]: any } -- { type = "Roll" | "Buy" | "Decline" | "Bid" | "PassBid" | "EndTurn" | "PayJailFine" | "UseJailCard" | "Build" | "SellBuilding" | "Mortgage" | "Unmortgage", amount = number?, position = number? }
```

`src/server/Game/Engine.luau`:

1. Require: `local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)`.
2. Constants after `Engine.MAX_DOUBLES`: `Engine.BANK_HOUSES = 32` and `Engine.BANK_HOTELS = 12`.
3. After `useJailCard`, add:

```lua
local PROPERTY_ACTIONS = { Build = true, SellBuilding = true, Mortgage = true, Unmortgage = true }

local function isPosition(value: any): boolean
	return typeof(value) == "number" and value % 1 == 0 and value >= 0 and value < Tiles.COUNT
end

local function propertyAction(state: GameState, player: Player, kind: string, position: any): (boolean, string?)
	if not isPosition(position) then
		return false, "invalid position"
	end
	local ok, err
	if kind == "Build" then
		ok, err = PropertyRules.canBuild(state, player.id, player.money, position)
	elseif kind == "SellBuilding" then
		ok, err = PropertyRules.canSell(state, player.id, position)
	elseif kind == "Mortgage" then
		ok, err = PropertyRules.canMortgage(state, player.id, position)
	else
		ok, err = PropertyRules.canUnmortgage(state, player.id, player.money, position)
	end
	if not ok then
		return false, err
	end

	local ownership = state.properties[position]
	if kind == "Build" or kind == "SellBuilding" then
		local price = PropertyRules.housePrice(position)
		local building = kind == "Build"
		-- A hotel swaps with four houses: building one returns them, selling one takes them.
		local hotel = if building then ownership.houses == PropertyRules.HOUSES_PER_HOTEL else ownership.houses == PropertyRules.HOTEL
		local direction = if building then 1 else -1
		if hotel then
			state.bankHotels -= direction
			state.bankHouses += direction * PropertyRules.HOUSES_PER_HOTEL
		else
			state.bankHouses -= direction
		end
		ownership.houses += direction
		local amount = if building then price else price // 2
		if building then
			transfer(state, player.id, nil, amount, "Building")
		else
			transfer(state, nil, player.id, amount, "Building")
		end
		emit(state, { type = if building then "Built" else "BuildingSold", player = player.id, position = position, amount = amount, hotel = hotel })
	elseif kind == "Mortgage" then
		local amount = PropertyRules.mortgageValue(position)
		ownership.mortgaged = true
		transfer(state, nil, player.id, amount, "Mortgage")
		emit(state, { type = "Mortgaged", player = player.id, position = position, amount = amount })
	else
		local amount = PropertyRules.unmortgageCost(position)
		ownership.mortgaged = false
		transfer(state, player.id, nil, amount, "Mortgage")
		emit(state, { type = "Unmortgaged", player = player.id, position = position, amount = amount })
	end
	return true
end
```

(`value % 1 == 0` is false for NaN and for ±inf, since `inf % 1` is NaN — same trick as `placeBid`.) If strict mode rejects passing `state` as `PropertyRules.View`, cast with `state :: any` at the four call sites and ledger it.

4. `Engine.new`: add `bankHouses = Engine.BANK_HOUSES, bankHotels = Engine.BANK_HOTELS,` to the state literal after `decks = decks,`.
5. `Engine.act`: after the `UseJailCard` branch add:

```lua
	elseif PROPERTY_ACTIONS[action.type] and (state.phase == "Roll" or state.phase == "EndTurn") then
		return propertyAction(state, player, action.type, action.position)
```

`src/shared/Net/Protocol.luau` — `Snapshot` gains:

```lua
	bankHouses: number,
	bankHotels: number,
```

`src/server/Game/Snapshot.luau` — add `bankHouses = state.bankHouses, bankHotels = state.bankHotels,` to the returned table.

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: 140 + 12 = 152 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/server/Game src/shared/Net/Protocol.luau src/tests
git commit -m "feat: build, sell, mortgage and unmortgage actions"
```

---

### Task 3: Bots build and unmortgage

**Files:**
- Modify: `src/server/Game/Bot.luau`, `src/tests/Bot.spec.luau`

**Interfaces:**
- Consumes: `PropertyRules.canBuild/canUnmortgage/housePrice/unmortgageCost`, Task 2 actions.
- Produces: `Bot.RICH_MULTIPLIER = 3`. `Bot.chooseAction` in Roll phase returns, in order: `Unmortgage` (cheapest cost, ties → lowest position) if `money - cost >= RICH_MULTIPLIER * CASH_RESERVE`; `Build` (cheapest legal house price, ties → lowest position) if `money - price >= CASH_RESERVE`; then the existing jail/roll choice.

- [ ] **Step 1: Write the failing tests**

Add to `src/tests/Bot.spec.luau` before the all-bot test:

```lua
tests["a bot with a full set builds evenly while it keeps its reserve"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Build", "builds")
	Expect.equal(action.position, 1, "lowest position first")
	act(state, "p1", action)
	Expect.equal(Bot.chooseAction(state, "p1").position, 3, "then evens out")
	Engine.getPlayer(state, "p1").money = Bot.CASH_RESERVE + 49
	Expect.equal(Bot.chooseAction(state, "p1").type, "Roll", "keeps the reserve")
end

tests["a bot builds its cheapest set first"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 37, 39, 1, 3 } do -- dark blue ($200 houses) and brown ($50)
		GameFixtures.own(state, "p1", position)
	end
	Expect.equal(Bot.chooseAction(state, "p1").position, 1)
end

tests["a rich bot lifts its cheapest mortgage before building"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	GameFixtures.own(state, "p1", 5)
	GameFixtures.own(state, "p1", 12)
	state.properties[5].mortgaged = true -- costs 110
	state.properties[12].mortgaged = true -- costs 83
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Unmortgage", "unmortgages")
	Expect.equal(action.position, 12, "cheapest first")
	Engine.getPlayer(state, "p1").money = 3 * Bot.CASH_RESERVE + 82 -- 83 would leave 449
	Expect.equal(Bot.chooseAction(state, "p1").type, "Build", "not rich enough: builds instead")
end

tests["two bots eventually build"] = function()
	local random = Random.new(99)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	for step = 1, 4000 do
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
		if #GameFixtures.eventsOfType(state, "Built") > 0 then
			return
		end
	end
	error("no bot built anything in 4000 steps")
end
```

(`act` is the helper already at the top of `Bot.spec.luau`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `.run("Bot")`. Expected: `builds: expected Build, got Roll`, `unmortgages: expected Unmortgage, got Roll`, and "no bot built anything in 4000 steps".

- [ ] **Step 3: Implement**

`src/server/Game/Bot.luau` — require `local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)`, add `Bot.RICH_MULTIPLIER = 3`, and before `Bot.chooseAction`:

```lua
-- Before rolling: lift the cheapest mortgage when rich, else build the cheapest legal house.
local function propertyPlan(state: Types.GameState, me: Types.Player): Types.Action?
	local best: number?, bestCost = nil, math.huge
	for _, tile in Tiles.list do
		local position = tile.position
		if PropertyRules.canUnmortgage(state, me.id, me.money, position) then
			local cost = PropertyRules.unmortgageCost(position)
			if me.money - cost >= Bot.RICH_MULTIPLIER * Bot.CASH_RESERVE and cost < bestCost then
				best, bestCost = position, cost
			end
		end
	end
	if best then
		return { type = "Unmortgage", position = best }
	end

	for _, tile in Tiles.list do
		local position = tile.position
		if tile.kind == "Property" and PropertyRules.canBuild(state, me.id, me.money, position) then
			local price = PropertyRules.housePrice(position)
			if me.money - price >= Bot.CASH_RESERVE and price < bestCost then
				best, bestCost = position, price
			end
		end
	end
	if best then
		return { type = "Build", position = best }
	end
	return nil
end
```

(Board order + strict `<` gives the lowest position on ties.) In `chooseAction`, the Roll branch starts with:

```lua
	if state.phase == "Roll" then
		local plan = propertyPlan(state, me)
		if plan then
			return plan
		end
		if me.inJail then
```

Update the header comment: `-- A simple bot: keeps a cash reserve when buying, bidding and building, lifts mortgages when rich, and leaves jail as soon as it can spare the fine.`

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: 152 + 4 = 156 passed. If "two bots eventually build" still fails, check whether bots ever complete a set with seed 99 (count `Bought`/`AuctionEnded` per group) before touching the seed; ledger any seed change as a ruling.

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Bot.luau src/tests/Bot.spec.luau
git commit -m "feat: bots build and lift mortgages"
```

---

### Task 4: HUD model rows and log lines

**Files:**
- Modify: `src/client/Hud/HudModel.luau`, `src/client/Hud/EventText.luau`, `src/tests/HudModel.spec.luau`, `src/tests/EventText.spec.luau`

**Interfaces:**
- Consumes: `PropertyRules.*`, snapshot `properties`/`bankHouses`/`bankHotels`.
- Produces:
  - `HudModel.PropertyRow = { position: number, name: string, group: string, houses: number, mortgaged: boolean, buttons: { Button } }` (`group` = color group, or `"Railroad"`/`"Utility"`).
  - `HudModel.propertyRows(snapshot, localId): { PropertyRow }` — the local player's deeds: streets in board order, then railroads, then utilities. Buttons only when `snapshot.currentPlayer == localId`, phase Roll/EndTurn, no auction. Button order: build, sell, mortgage, unmortgage. Labels: `+🏠 $50` / `+🏨 $50` (building the hotel), `−🏠 +$25` / `−🏨 +$25` (selling the hotel), `Mortgage +$30`, `Unmortgage $33`.
  - `HudModel.buildingText(row): string` — `"MORTGAGED"`, `"🏨"`, `"🏠"` × houses, or `""`.
  - EventText: `Built` → `"{name} built a house on {tile}"` / `"… built a hotel on {tile}"`; `BuildingSold` → `"{name} sold a house on {tile}"` / `"… sold a hotel on {tile}"`; `Mortgaged` → `"{name} mortgaged {tile} for ${amount}"`; `Unmortgaged` → `"{name} paid ${amount} to unmortgage {tile}"`; `Paid` reasons `Building`/`Mortgage` → nil.

- [ ] **Step 1: Write the failing tests**

Add to `src/tests/HudModel.spec.luau`:

```lua
local function rowLabels(row): string
	return labels(row.buttons)
end

tests["property rows list your deeds: streets, then railroads, then utilities"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 12, 5, 3, 1 } do
		GameFixtures.own(state, "p1", position)
	end
	GameFixtures.own(state, "p2", 6)
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(#rows, 4, "only p1's deeds")
	local order = {}
	for _, row in rows do
		table.insert(order, `{row.position}:{row.group}`)
	end
	Expect.equal(table.concat(order, ","), "1:Brown,3:Brown,5:Railroad,12:Utility")
	Expect.equal(rows[1].name, "Mediterranean Avenue", "name")
end

tests["property rows offer the legal actions with prices on your turn"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "−🏠 +$25", "ahead: sell only")
	Expect.equal(rowLabels(rows[2]), "+🏠 $50", "behind: build only")
	Expect.equal(rowLabels(rows[3]), "Unmortgage $110", "mortgaged railroad")
	Expect.equal(rows[2].buttons[1].action.type, "Build", "action type")
	Expect.equal(rows[2].buttons[1].action.position, 3, "action position")

	state.properties[1].houses = 0
	rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "+🏠 $50|Mortgage +$30", "bare full set")
end

tests["property rows label hotels"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 4)
	GameFixtures.own(state, "p1", 3, 5)
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "+🏨 $50", "build the hotel")
	Expect.equal(rowLabels(rows[2]), "−🏨 +$25", "sell the hotel")
	Expect.equal(HudModel.buildingText(rows[2]), "🏨", "hotel text")
	Expect.equal(HudModel.buildingText(rows[1]), "🏠🏠🏠🏠", "houses text")
end

tests["property rows have no buttons off your turn or mid-decision"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	state.properties[3].mortgaged = true
	Expect.equal(#HudModel.propertyRows(Snapshot.fromState(state), "p2"), 0, "p2 owns nothing")
	Engine.act(state, "p1", { type = "Roll" }) -- BuyDecision on Oriental
	for _, row in HudModel.propertyRows(Snapshot.fromState(state), "p1") do
		Expect.equal(#row.buttons, 0, `row {row.position} during a buy decision`)
	end
	Expect.equal(HudModel.buildingText(HudModel.propertyRows(Snapshot.fromState(state), "p1")[2]), "MORTGAGED")
	state.phase = "Roll"
	state.currentIndex = 2
	for _, row in HudModel.propertyRows(Snapshot.fromState(state), "p1") do
		Expect.equal(#row.buttons, 0, `row {row.position} on p2's turn`)
	end
end
```

Add to the `cases` list in `src/tests/EventText.spec.luau`:

```lua
		{ { type = "Built", player = "p1", position = 1, amount = 50, hotel = false }, "Ana built a house on Mediterranean Avenue" },
		{ { type = "Built", player = "p1", position = 1, amount = 50, hotel = true }, "Ana built a hotel on Mediterranean Avenue" },
		{ { type = "BuildingSold", player = "p1", position = 3, amount = 25, hotel = false }, "Ana sold a house on Baltic Avenue" },
		{ { type = "BuildingSold", player = "p1", position = 3, amount = 25, hotel = true }, "Ana sold a hotel on Baltic Avenue" },
		{ { type = "Mortgaged", player = "p1", position = 5, amount = 100 }, "Ana mortgaged Reading Railroad for $100" },
		{ { type = "Unmortgaged", player = "p1", position = 5, amount = 110 }, "Ana paid $110 to unmortgage Reading Railroad" },
```

and to the skipped list:

```lua
		{ type = "Paid", from = "p1", to = nil, amount = 50, reason = "Building" },
		{ type = "Paid", from = nil, to = "p1", amount = 100, reason = "Mortgage" },
```

- [ ] **Step 2: Run tests to verify they fail**

Run: full suite. Expected: `attempt to call a nil value` for `propertyRows`; EventText `Built: expected Ana built a house on Mediterranean Avenue, got nil`.

- [ ] **Step 3: Implement**

`src/client/Hud/HudModel.luau` — require `local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)`, then add after `HudModel.status`:

```lua
export type PropertyRow = {
	position: number,
	name: string,
	group: string, -- color group, or "Railroad" / "Utility"
	houses: number,
	mortgaged: boolean,
	buttons: { Button },
}

local KIND_ORDER = { Property = 1, Railroad = 2, Utility = 3 }

local function rulesView(snapshot: Protocol.Snapshot): PropertyRules.View
	local properties = {}
	for _, property in snapshot.properties do
		properties[property.position] = { owner = property.owner, houses = property.houses, mortgaged = property.mortgaged }
	end
	return { properties = properties, bankHouses = snapshot.bankHouses, bankHotels = snapshot.bankHotels }
end

-- The local player's deeds with the property actions they may take right now.
function HudModel.propertyRows(snapshot: Protocol.Snapshot, localId: string): { PropertyRow }
	local me = findPlayer(snapshot, localId)
	if not me then
		return {}
	end
	local canAct = snapshot.currentPlayer == localId
		and snapshot.auction == nil
		and (snapshot.phase == "Roll" or snapshot.phase == "EndTurn")
	local view = rulesView(snapshot)

	local rows = {}
	for _, property in snapshot.properties do
		if property.owner ~= localId then
			continue
		end
		local position = property.position
		local tile = Tiles.at(position)
		local buttons = {}
		if canAct then
			if tile.kind == "Property" then
				local price = PropertyRules.housePrice(position)
				if PropertyRules.canBuild(view, localId, me.money, position) then
					local icon = if property.houses == PropertyRules.HOUSES_PER_HOTEL then "🏨" else "🏠"
					table.insert(buttons, { label = `+{icon} ${price}`, action = { type = "Build", position = position } })
				end
				if PropertyRules.canSell(view, localId, position) then
					local icon = if property.houses == PropertyRules.HOTEL then "🏨" else "🏠"
					table.insert(buttons, { label = `−{icon} +${price // 2}`, action = { type = "SellBuilding", position = position } })
				end
			end
			if PropertyRules.canMortgage(view, localId, position) then
				table.insert(buttons, {
					label = `Mortgage +${PropertyRules.mortgageValue(position)}`,
					action = { type = "Mortgage", position = position },
				})
			end
			if PropertyRules.canUnmortgage(view, localId, me.money, position) then
				table.insert(buttons, {
					label = `Unmortgage ${PropertyRules.unmortgageCost(position)}`,
					action = { type = "Unmortgage", position = position },
				})
			end
		end
		table.insert(rows, {
			position = position,
			name = tile.name,
			group = tile.group or tile.kind,
			houses = property.houses,
			mortgaged = property.mortgaged,
			buttons = buttons,
		})
	end

	table.sort(rows, function(a, b)
		local kindA, kindB = KIND_ORDER[Tiles.at(a.position).kind], KIND_ORDER[Tiles.at(b.position).kind]
		if kindA ~= kindB then
			return kindA < kindB
		end
		return a.position < b.position
	end)
	return rows
end

function HudModel.buildingText(row: PropertyRow): string
	if row.mortgaged then
		return "MORTGAGED"
	elseif row.houses == PropertyRules.HOTEL then
		return "🏨"
	end
	return string.rep("🏠", row.houses)
end
```

`src/client/Hud/EventText.luau` — in the `Paid` branch nothing changes (unknown reasons already return nil). Add before `PlayerReplaced`:

```lua
	elseif kind == "Built" then
		return `{name(event.player)} built a {if event.hotel then "hotel" else "house"} on {tileName(event.position)}`
	elseif kind == "BuildingSold" then
		return `{name(event.player)} sold a {if event.hotel then "hotel" else "house"} on {tileName(event.position)}`
	elseif kind == "Mortgaged" then
		return `{name(event.player)} mortgaged {tileName(event.position)} for ${event.amount}`
	elseif kind == "Unmortgaged" then
		return `{name(event.player)} paid ${event.amount} to unmortgage {tileName(event.position)}`
```

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: 156 + 4 = 160 passed.

- [ ] **Step 5: Commit**

```bash
git add src/client/Hud/HudModel.luau src/client/Hud/EventText.luau src/tests
git commit -m "feat: property rows and log lines for buildings and mortgages"
```

---

### Task 5: Houses on the board, the Properties panel — and playtest

**Files:**
- Create: `src/shared/Board/BuildingLayout.luau`, `src/client/Buildings.luau`, `src/tests/BuildingLayout.spec.luau`, `src/tests/Buildings.spec.luau`
- Modify: `src/client/Hud/HudView.luau`, `src/client/GameClient.luau`

**Interfaces:**
- Consumes: `HudModel.propertyRows/buildingText`, `ColorGroups`, `Layout.getTilePlacement/ORIGIN`, snapshot properties.
- Produces:
  - `BuildingLayout.HOTEL = 5`, `BuildingLayout.HOUSE_SIZE = Vector3.new(1, 0.8, 1)`, `BuildingLayout.HOTEL_SIZE = Vector3.new(2.2, 1, 1.4)`, `BuildingLayout.cframe(position, index): CFrame` — base centre of house `index` (1–4) or the hotel (5) on the top of the tile's color band, oriented with the tile. Errors for non-street tiles or bad indexes.
  - `Buildings.new(parent)`, `Buildings.apply(self, snapshot?)`, and pure `Buildings.wanted(snapshot?): { [number]: number }` (position → houses, only built positions).
  - `HudView`: a Properties toggle in the action bar and a scrolling panel of `HudModel.propertyRows`.

- [ ] **Step 1: Write the failing tests**

Create `src/tests/BuildingLayout.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingLayout = require(ReplicatedStorage.Shared.Board.BuildingLayout)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Expect = require(script.Parent.Expect)

local tests = {}

local BAND_DEPTH = 2.5
local BAND_THICKNESS = 0.1

tests["buildings stand on the color band of every street"] = function()
	for _, tile in Tiles.list do
		if tile.kind ~= "Property" then
			continue
		end
		local placement = Layout.getTilePlacement(tile.position)
		local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
		for index = 1, BuildingLayout.HOTEL do
			local size = if index == BuildingLayout.HOTEL then BuildingLayout.HOTEL_SIZE else BuildingLayout.HOUSE_SIZE
			local spot = tileTop:PointToObjectSpace(BuildingLayout.cframe(tile.position, index).Position)
			local label = `tile {tile.position} index {index}`
			Expect.near(spot.Y, BAND_THICKNESS, `{label} height`)
			assert(math.abs(spot.X) + size.X / 2 <= placement.size.X / 2, `{label} off the side`)
			assert(spot.Z - size.Z / 2 >= -placement.size.Z / 2, `{label} off the inner edge`)
			assert(spot.Z + size.Z / 2 <= -placement.size.Z / 2 + BAND_DEPTH, `{label} off the band`)
		end
	end
end

tests["houses on one street don't overlap"] = function()
	for a = 1, 4 do
		for b = a + 1, 4 do
			local gap = (BuildingLayout.cframe(1, a).Position - BuildingLayout.cframe(1, b).Position).Magnitude
			assert(gap >= BuildingLayout.HOUSE_SIZE.X, `houses {a} and {b} overlap`)
		end
	end
end

tests["buildings only go on streets, at indexes 1-5"] = function()
	assert(not pcall(BuildingLayout.cframe, 5, 1), "railroad accepted")
	assert(not pcall(BuildingLayout.cframe, 1, 0), "index 0 accepted")
	assert(not pcall(BuildingLayout.cframe, 1, 6), "index 6 accepted")
end

return tests
```

Create `src/tests/Buildings.spec.luau`:

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Buildings = require(StarterPlayer.StarterPlayerScripts.Client.Buildings)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["wanted lists only built positions"] = function()
	local snapshot = {
		properties = {
			{ position = 1, owner = "p1", houses = 2, mortgaged = false },
			{ position = 3, owner = "p1", houses = 0, mortgaged = false },
			{ position = 39, owner = "p2", houses = 5, mortgaged = false },
		},
	} :: any
	local wanted = Buildings.wanted(snapshot)
	Expect.equal(wanted[1], 2, "two houses")
	Expect.equal(wanted[3], nil, "bare lot")
	Expect.equal(wanted[39], 5, "hotel")
	Expect.equal(next(Buildings.wanted(nil)), nil, "lobby: nothing")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run: full suite. Expected: `BuildingLayout.spec (load)` and `Buildings.spec (load)` fail.

- [ ] **Step 3: Implement**

Create `src/shared/Board/BuildingLayout.luau`:

```lua
--!strict
-- Where houses and hotels stand: in a row along the color band on a street's inner edge.

local Layout = require(script.Parent.Layout)
local Tiles = require(script.Parent.Tiles)

local BuildingLayout = {}

BuildingLayout.HOTEL = 5
BuildingLayout.HOUSE_SIZE = Vector3.new(1, 0.8, 1)
BuildingLayout.HOTEL_SIZE = Vector3.new(2.2, 1, 1.4)

local BAND_DEPTH = 2.5 -- matches the color band BoardBuilder draws
local BAND_THICKNESS = 0.1
local HOUSE_X = { -2.1, -0.7, 0.7, 2.1 }

function BuildingLayout.cframe(position: number, index: number): CFrame
	assert(Tiles.at(position).kind == "Property", `{Tiles.at(position).name} can't have buildings`)
	assert(index % 1 == 0 and index >= 1 and index <= BuildingLayout.HOTEL, `invalid building index {index}`)
	local placement = Layout.getTilePlacement(position)
	local bandZ = -(placement.size.Z / 2 - BAND_DEPTH / 2)
	local x = if index == BuildingLayout.HOTEL then 0 else HOUSE_X[index]
	return Layout.ORIGIN
		* placement.cframe
		* CFrame.new(x, placement.size.Y / 2 + BAND_THICKNESS, bandZ)
end

return BuildingLayout
```

Create `src/client/Buildings.luau`:

```lua
--!strict
-- Client-side houses and hotels, kept in step with the snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingLayout = require(ReplicatedStorage.Shared.Board.BuildingLayout)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)

local HOUSE_COLOR = Color3.fromRGB(46, 160, 67)
local HOTEL_COLOR = Color3.fromRGB(200, 40, 40)

local Buildings = {}
Buildings.__index = Buildings

export type BuildingsView = typeof(setmetatable({} :: { folder: Folder, shown: { [number]: number } }, Buildings))

function Buildings.new(parent: Instance): BuildingsView
	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = parent
	return setmetatable({ folder = folder, shown = {} }, Buildings)
end

-- Position -> houses (5 = hotel) for every built street.
function Buildings.wanted(snapshot: Protocol.Snapshot?): { [number]: number }
	local wanted = {}
	if snapshot then
		for _, property in snapshot.properties do
			if property.houses > 0 then
				wanted[property.position] = property.houses
			end
		end
	end
	return wanted
end

local function makePart(name: string, size: Vector3, base: CFrame, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = base * CFrame.new(0, size.Y / 2, 0)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
end

local function show(self: BuildingsView, position: number, houses: number)
	local existing = self.folder:FindFirstChild(tostring(position))
	if existing then
		existing:Destroy()
	end
	self.shown[position] = if houses > 0 then houses else nil
	if houses == 0 then
		return
	end
	local group = Instance.new("Folder")
	group.Name = tostring(position)
	group.Parent = self.folder
	if houses == BuildingLayout.HOTEL then
		makePart("Hotel", BuildingLayout.HOTEL_SIZE, BuildingLayout.cframe(position, BuildingLayout.HOTEL), HOTEL_COLOR, group)
	else
		for index = 1, houses do
			makePart(`House{index}`, BuildingLayout.HOUSE_SIZE, BuildingLayout.cframe(position, index), HOUSE_COLOR, group)
		end
	end
end

function Buildings.apply(self: BuildingsView, snapshot: Protocol.Snapshot?)
	local wanted = Buildings.wanted(snapshot)
	for position in self.shown do
		if not wanted[position] then
			show(self, position, 0)
		end
	end
	for position, houses in wanted do
		if self.shown[position] ~= houses then
			show(self, position, houses)
		end
	end
end

return Buildings
```

(`show` mutates `self.shown` while `apply` iterates it in the first loop — only by setting existing keys to nil, which Luau allows during `for ... in` traversal.)

`src/client/GameClient.luau` — require `local Buildings = require(script.Parent.Buildings)`; after `local tokens = Tokens.new(workspace)` add `local buildings = Buildings.new(workspace)`; in the update handler after `tokens:apply(update)` add `buildings:apply(update.snapshot)`.

`src/client/Hud/HudView.luau`:

1. Require `local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)`. Constants: `local TOGGLE_COLOR = Color3.fromRGB(70, 90, 140)` and `local OTHER_SWATCH = Color3.fromRGB(150, 150, 150)`.
2. Type fields: `propertiesOpen: boolean, propertiesPanel: ScrollingFrame, snapshot: Protocol.Snapshot?, localId: string`; initialise `propertiesOpen = false, propertiesPanel = nil :: any, snapshot = nil, localId = "",` in the `setmetatable` literal.
3. Widen the action bar: `panel("ActionBar", UDim2.fromOffset(660, 100), ...)` (up to 3 action buttons + the toggle).
4. In `new`, before the card popup block:

```lua
	-- Your properties, right side under the log; opened from the action bar.
	local properties = Instance.new("ScrollingFrame")
	properties.Name = "Properties"
	properties.Size = UDim2.fromOffset(420, 360)
	properties.Position = UDim2.new(1, -12, 0, 224)
	properties.AnchorPoint = Vector2.new(1, 0)
	properties.BackgroundColor3 = PANEL_COLOR
	properties.BackgroundTransparency = 0.15
	properties.BorderSizePixel = 0
	properties.ScrollBarThickness = 6
	properties.CanvasSize = UDim2.new()
	properties.AutomaticCanvasSize = Enum.AutomaticSize.Y
	properties.Visible = false
	properties.Parent = gui
	corner(properties)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.Parent = properties
	local propertiesLayout = Instance.new("UIListLayout")
	propertiesLayout.Padding = UDim.new(0, 4)
	propertiesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	propertiesLayout.Parent = properties
	self.propertiesPanel = properties
```

5. Above `HudView.new`, add:

```lua
local function renderProperties(self: HudView, snapshot: Protocol.Snapshot, localId: string)
	local panel = self.propertiesPanel
	panel.Visible = self.propertiesOpen
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not self.propertiesOpen then
		return
	end

	local rows = HudModel.propertyRows(snapshot, localId)
	if #rows == 0 then
		local empty = text("Empty", panel, UDim2.new(1, -16, 0, 30), 16)
		empty.Text = "You don't own any property yet"
		return
	end
	for order, entry in rows do
		local row = Instance.new("Frame")
		row.Name = entry.name
		row.Size = UDim2.new(1, -16, 0, 34)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = panel
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.Size = UDim2.fromOffset(10, 26)
		swatch.BorderSizePixel = 0
		local group = ColorGroups[entry.group]
		swatch.BackgroundColor3 = if group then group.color else OTHER_SWATCH
		swatch.Parent = row

		local label = text("Name", row, UDim2.fromOffset(190, 26), 15)
		label.LayoutOrder = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = `{entry.name}  {HudModel.buildingText(entry)}`

		for i, entryButton in entry.buttons do
			local b = button(entryButton.label, row, function()
				self.callbacks.onAction(entryButton.action)
			end)
			b.Size = UDim2.fromOffset(92, 28)
			b.TextSize = 13
			b.LayoutOrder = 1 + i
		end
	end
end
```

6. In `render`: at the top store `self.snapshot = snapshot` and `self.localId = localId`. In the `if not snapshot then` block (the one clearing card items) also set `self.propertiesOpen = false` and `self.propertiesPanel.Visible = false`. After the action-button loop add:

```lua
	local toggle = button(if self.propertiesOpen then "Hide properties" else "Properties", self.buttonRow, function()
		self.propertiesOpen = not self.propertiesOpen
		self:render(self.snapshot, self.localId)
	end)
	toggle.LayoutOrder = 100
	toggle.BackgroundColor3 = TOGGLE_COLOR
	renderProperties(self, snapshot, localId)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: 160 + 4 = 164 passed.

- [ ] **Step 5: Playtest**

Rojo connected; `start_stop_play(true)`; click Start (2 seats: you + 1 bot, so sets complete sooner). Drive the human's routine turns with a client script firing the GameAction remote (as in the jail playtest), buying whatever the human lands on while money ≥ 300; click the property buttons for real. Don't force game state.
- Human panel: click **Properties** → panel lists the human's deeds (or "You don't own any property yet"). On the human's turn with any deed, click **Mortgage +$…** → money rises, row shows MORTGAGED, log line; click **Unmortgage $…** → reverts. If the human completes a set, click **+🏠** → a green house appears on that street's band. Clicking the toggle again closes the panel.
- Bots: within a few minutes the bot builds → green houses on its street's color band, log shows "… built a house on …". Capture with `screen_capture`.
- No errors in client `LogService` history (ignore MCP mouse-tool noise).

Anything not seen (e.g. the human never completes a set) goes in the ledger as "not observed", with the tests that cover it. `start_stop_play(false)`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/Board/BuildingLayout.luau src/client src/tests
git commit -m "feat: houses on the board and the Properties panel"
```

---

## After the tasks

- Write `docs/superpowers/plans/2026-09-28-buildings-and-mortgages.followups.txt` (rulings, deferred minors, not-observed playtest items).
- Whole-branch review (opus), fix Important findings with RED→GREEN tests, fast-forward `main` without checkout, push.
