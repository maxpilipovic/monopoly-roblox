# Board & Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A code-generated 3D Monopoly board (40 tiles with colors, names, prices) and an overhead camera, visible when you press Play.

**Architecture:** Tile data lives in shared, frozen data modules (`Tiles`, `ColorGroups`). A pure `Layout` module maps a board position (0–39) to a CFrame and size. A server `BoardBuilder` turns data + layout into Parts in `Workspace.Board`. A client `BoardCamera` computes an overhead CFrame that fits the board to the viewport. Pure logic is unit-tested by an in-repo test runner executed inside a Studio playtest.

**Tech Stack:** Luau, Rojo 7.7 (live sync into Roblox Studio), Roblox Studio MCP (`start_stop_play`, `execute_luau`, `screen_capture`, `get_console_output`).

**Spec:** Design agreed in conversation on 2026-09-27 (captured in Global Constraints below). This plan is step 1 of the build order: "Board".

## Global Constraints

- Board positions are 0–39, clockwise-in-play order starting at Go (0), Jail (10), Free Parking (20), Go To Jail (30). All game code uses this numbering.
- Official US board data (names, prices, rents, house costs, taxes: Income Tax $200, Luxury Tax $100).
- All game state is server-authoritative; the board is built by the server so it replicates to all clients.
- Nothing is hand-built in Studio; the board is generated from code so it is versioned in git.
- Scripts are edited only as files under `src/` (Rojo overwrites edits made in Studio).
- Every new `.luau` file starts with `--!strict`.
- Tabs for indentation (matches the Rojo template).

## Review Focus

1. **Server restarts / builder called twice** — expect exactly one `Workspace.Board`, never duplicates. Pinned by `BoardBuilder.spec` "rebuilding replaces the existing board" (Task 3).
2. **Portrait / narrow screens (mobile)** — expect the whole board still in view. Pinned by `BoardCamera.spec` "narrower viewport moves the camera further away" (Task 4).
3. **Character respawn resets the camera** — expect the overhead view to come back after respawn. Handled by re-applying on `CharacterAdded` in `BoardCamera.start` and checked in the Task 4 playtest by resetting the character.
4. **Long tile names (e.g. "North Carolina Avenue")** — expect wrapped, scaled text that stays inside the tile. Uses `TextScaled` + `TextWrapped`; checked visually in Task 3's screenshot.
5. **Invalid board positions (-1, 40, 1.5)** — expect a loud error rather than a silent wrong tile, so later movement bugs surface. Pinned by `Tiles.spec` "at rejects invalid positions" (Task 1) and `Layout.spec` "rejects invalid positions" (Task 2).

## File Structure

```
default.project.json                 (modify) map src/tests -> ServerStorage.Tests
src/shared/Hello.luau                (delete) template placeholder
src/shared/Board/ColorGroups.luau    (create) color-group colors and house costs
src/shared/Board/Tiles.luau          (create) the 40 tiles as frozen data
src/shared/Board/Layout.luau         (create) position -> CFrame/size math, board constants
src/server/init.server.luau          (modify) build the board on server start
src/server/BoardBuilder.luau         (create) Parts/labels from Tiles + Layout
src/client/init.client.luau          (modify) start the board camera
src/client/BoardCamera.luau          (create) overhead camera math + apply
src/tests/TestRunner.luau            (create) runs every *.spec module
src/tests/Expect.luau                (create) tiny assertion helpers
src/tests/Tiles.spec.luau            (create)
src/tests/Layout.spec.luau           (create)
src/tests/BoardBuilder.spec.luau     (create)
src/tests/BoardCamera.spec.luau      (create)
```

## How to run the tests

Tests run inside a Studio playtest (fresh Lua state each time, so edited modules are never stale). `rojo serve` must be running and Studio connected to it.

1. `start_stop_play(is_start = true)`
2. `execute_luau(datamodel_type = "Server", code = 'return require(game.ServerStorage.Tests.TestRunner).run()')`
   - To run one file: `.run("Tiles")` (matches module names containing the text).
3. `start_stop_play(is_start = false)`

Output is `"<n> passed, <m> failed"` followed by one `FAIL ...` line per failure. A spec module that fails to load counts as one failure.

---

### Task 1: Test runner + tile data

**Files:**
- Modify: `default.project.json` (add `ServerStorage.Tests`)
- Delete: `src/shared/Hello.luau`
- Modify: `src/server/init.server.luau`, `src/client/init.client.luau` (drop the Hello demo)
- Create: `src/tests/TestRunner.luau`, `src/tests/Expect.luau`, `src/tests/Tiles.spec.luau`
- Create: `src/shared/Board/ColorGroups.luau`, `src/shared/Board/Tiles.luau`

**Interfaces:**
- Produces:
  - `TestRunner.run(filter: string?): string`
  - `Expect.equal(actual: any, expected: any, label: string?)`, `Expect.near(actual: number, expected: number, label: string?, epsilon: number?)`, `Expect.vectorNear(actual: Vector3, expected: Vector3, label: string?, epsilon: number?)`
  - `ColorGroups: { [string]: { color: Color3, houseCost: number } }` — keys `Brown, LightBlue, Pink, Orange, Red, Yellow, Green, DarkBlue`
  - `Tiles.COUNT: number` (40), `Tiles.list: { Tile }` (1-based array, `list[i].position == i - 1`), `Tiles.at(position: number): Tile`
  - `type Tile = { position: number, name: string, kind: TileKind, price: number?, group: string?, rent: { number }?, amount: number? }`
  - `type TileKind = "Go" | "Property" | "Railroad" | "Utility" | "Tax" | "Chance" | "CommunityChest" | "Jail" | "FreeParking" | "GoToJail"`

- [ ] **Step 1: Wire tests into the project and remove the demo**

In `default.project.json`, add a `ServerStorage` entry next to `ServerScriptService`:

```json
    "ServerStorage": {
      "Tests": {
        "$path": "src/tests"
      }
    },
```

Delete `src/shared/Hello.luau`. Replace `src/server/init.server.luau` with:

```lua
--!strict
```

Replace `src/client/init.client.luau` with:

```lua
--!strict
```

(Both get real content in Tasks 3 and 4.)

- [ ] **Step 2: Write the runner and assertion helpers**

`src/tests/TestRunner.luau`:

```lua
--!strict
-- Runs every ModuleScript under this folder whose name ends in ".spec".
-- A spec module returns { [testName]: () -> () }; a test fails if it errors.

local TestRunner = {}

function TestRunner.run(filter: string?): string
	local passed, failed = 0, 0
	local failures = {}

	for _, module in script.Parent:GetDescendants() do
		if not module:IsA("ModuleScript") or not module.Name:match("%.spec$") then
			continue
		end
		if filter and not module.Name:find(filter, 1, true) then
			continue
		end

		local loaded, suite = pcall(require, module)
		if not loaded then
			failed += 1
			table.insert(failures, `FAIL {module.Name} (load): {suite}`)
			continue
		end

		local names = {}
		for name in suite do
			table.insert(names, name)
		end
		table.sort(names)

		for _, name in names do
			local ok, err = pcall(suite[name])
			if ok then
				passed += 1
			else
				failed += 1
				table.insert(failures, `FAIL {module.Name} > {name}: {err}`)
			end
		end
	end

	table.insert(failures, 1, `{passed} passed, {failed} failed`)
	return table.concat(failures, "\n")
end

return TestRunner
```

`src/tests/Expect.luau`:

```lua
--!strict
local Expect = {}

function Expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Expect.near(actual: number, expected: number, label: string?, epsilon: number?)
	if math.abs(actual - expected) > (epsilon or 1e-3) then
		error(`{label or "value"}: expected ~{expected}, got {actual}`, 2)
	end
end

function Expect.vectorNear(actual: Vector3, expected: Vector3, label: string?, epsilon: number?)
	if (actual - expected).Magnitude > (epsilon or 1e-3) then
		error(`{label or "vector"}: expected {expected}, got {actual}`, 2)
	end
end

return Expect
```

- [ ] **Step 3: Write the failing tile tests**

`src/tests/Tiles.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["has 40 tiles in position order"] = function()
	Expect.equal(Tiles.COUNT, 40, "COUNT")
	Expect.equal(#Tiles.list, 40, "#list")
	for i, tile in Tiles.list do
		Expect.equal(tile.position, i - 1, `list[{i}].position`)
		Expect.equal(Tiles.at(i - 1), tile, `at({i - 1})`)
	end
end

tests["corners are Go, Jail, Free Parking, Go To Jail"] = function()
	Expect.equal(Tiles.at(0).kind, "Go")
	Expect.equal(Tiles.at(10).kind, "Jail")
	Expect.equal(Tiles.at(20).kind, "FreeParking")
	Expect.equal(Tiles.at(30).kind, "GoToJail")
end

tests["kind counts match the official board"] = function()
	local counts = {}
	for _, tile in Tiles.list do
		counts[tile.kind] = (counts[tile.kind] or 0) + 1
	end
	Expect.equal(counts.Property, 22, "Property")
	Expect.equal(counts.Railroad, 4, "Railroad")
	Expect.equal(counts.Utility, 2, "Utility")
	Expect.equal(counts.Tax, 2, "Tax")
	Expect.equal(counts.Chance, 3, "Chance")
	Expect.equal(counts.CommunityChest, 3, "CommunityChest")
end

tests["color groups exist and have the right sizes"] = function()
	local sizes = {}
	for _, tile in Tiles.list do
		if tile.kind == "Property" then
			local group = assert(tile.group, `{tile.name} has no group`)
			assert(ColorGroups[group], `unknown group {group}`)
			sizes[group] = (sizes[group] or 0) + 1
		end
	end
	for group in ColorGroups do
		local expected = if group == "Brown" or group == "DarkBlue" then 2 else 3
		Expect.equal(sizes[group], expected, group)
	end
end

tests["properties have a price and six increasing rents"] = function()
	for _, tile in Tiles.list do
		if tile.kind == "Property" then
			assert((tile.price or 0) > 0, `{tile.name} price`)
			local rent = assert(tile.rent, `{tile.name} rent`)
			Expect.equal(#rent, 6, `{tile.name} #rent`)
			for i = 2, 6 do
				assert(rent[i] > rent[i - 1], `{tile.name} rent not increasing at {i}`)
			end
		end
	end
end

tests["railroads cost 200, utilities 150, taxes 200 and 100"] = function()
	for _, tile in Tiles.list do
		if tile.kind == "Railroad" then
			Expect.equal(tile.price, 200, tile.name)
		elseif tile.kind == "Utility" then
			Expect.equal(tile.price, 150, tile.name)
		end
	end
	Expect.equal(Tiles.at(4).amount, 200, "Income Tax")
	Expect.equal(Tiles.at(38).amount, 100, "Luxury Tax")
	Expect.equal(Tiles.at(39).name, "Boardwalk")
end

tests["at rejects invalid positions"] = function()
	for _, bad in { -1, 40, 1.5 } do
		assert(not pcall(Tiles.at, bad), `at({bad}) should error`)
	end
end

tests["tile data is frozen"] = function()
	assert(table.isfrozen(Tiles.list), "list not frozen")
	assert(table.isfrozen(Tiles.at(1)), "tile not frozen")
	assert(table.isfrozen(Tiles.at(1).rent :: any), "rent not frozen")
end

return tests
```

- [ ] **Step 4: Run tests to verify they fail**

Run the tests (see "How to run the tests").
Expected: `0 passed, 1 failed` with `FAIL Tiles.spec (load): ... Board is not a valid member of Folder "ReplicatedStorage.Shared"`.

- [ ] **Step 5: Write the data modules**

`src/shared/Board/ColorGroups.luau`:

```lua
--!strict
export type ColorGroup = {
	color: Color3,
	houseCost: number,
}

local ColorGroups: { [string]: ColorGroup } = table.freeze({
	Brown = table.freeze({ color = Color3.fromRGB(149, 84, 54), houseCost = 50 }),
	LightBlue = table.freeze({ color = Color3.fromRGB(170, 224, 250), houseCost = 50 }),
	Pink = table.freeze({ color = Color3.fromRGB(217, 58, 150), houseCost = 100 }),
	Orange = table.freeze({ color = Color3.fromRGB(247, 148, 29), houseCost = 100 }),
	Red = table.freeze({ color = Color3.fromRGB(237, 27, 36), houseCost = 150 }),
	Yellow = table.freeze({ color = Color3.fromRGB(254, 242, 0), houseCost = 150 }),
	Green = table.freeze({ color = Color3.fromRGB(31, 178, 90), houseCost = 200 }),
	DarkBlue = table.freeze({ color = Color3.fromRGB(0, 114, 187), houseCost = 200 }),
})

return ColorGroups
```

`src/shared/Board/Tiles.luau`:

```lua
--!strict
-- The 40 board tiles in play order. Position 0 is Go; movement is (position + roll) % 40.

export type TileKind =
	"Go"
	| "Property"
	| "Railroad"
	| "Utility"
	| "Tax"
	| "Chance"
	| "CommunityChest"
	| "Jail"
	| "FreeParking"
	| "GoToJail"

export type Tile = {
	position: number,
	name: string,
	kind: TileKind,
	price: number?, -- Property, Railroad, Utility
	group: string?, -- Property only; key into ColorGroups
	rent: { number }?, -- Property only: { base, 1 house, 2, 3, 4, hotel }
	amount: number?, -- Tax only
}

local function property(name: string, group: string, price: number, rent: { number }): Tile
	return { position = -1, name = name, kind = "Property", group = group, price = price, rent = table.freeze(rent) }
end

local function railroad(name: string): Tile
	return { position = -1, name = name, kind = "Railroad", price = 200 }
end

local function utility(name: string): Tile
	return { position = -1, name = name, kind = "Utility", price = 150 }
end

local function tax(name: string, amount: number): Tile
	return { position = -1, name = name, kind = "Tax", amount = amount }
end

local function special(name: string, kind: TileKind): Tile
	return { position = -1, name = name, kind = kind }
end

local list: { Tile } = {
	special("Go", "Go"),
	property("Mediterranean Avenue", "Brown", 60, { 2, 10, 30, 90, 160, 250 }),
	special("Community Chest", "CommunityChest"),
	property("Baltic Avenue", "Brown", 60, { 4, 20, 60, 180, 320, 450 }),
	tax("Income Tax", 200),
	railroad("Reading Railroad"),
	property("Oriental Avenue", "LightBlue", 100, { 6, 30, 90, 270, 400, 550 }),
	special("Chance", "Chance"),
	property("Vermont Avenue", "LightBlue", 100, { 6, 30, 90, 270, 400, 550 }),
	property("Connecticut Avenue", "LightBlue", 120, { 8, 40, 100, 300, 450, 600 }),
	special("Jail", "Jail"),
	property("St. Charles Place", "Pink", 140, { 10, 50, 150, 450, 625, 750 }),
	utility("Electric Company"),
	property("States Avenue", "Pink", 140, { 10, 50, 150, 450, 625, 750 }),
	property("Virginia Avenue", "Pink", 160, { 12, 60, 180, 500, 700, 900 }),
	railroad("Pennsylvania Railroad"),
	property("St. James Place", "Orange", 180, { 14, 70, 200, 550, 750, 950 }),
	special("Community Chest", "CommunityChest"),
	property("Tennessee Avenue", "Orange", 180, { 14, 70, 200, 550, 750, 950 }),
	property("New York Avenue", "Orange", 200, { 16, 80, 220, 600, 800, 1000 }),
	special("Free Parking", "FreeParking"),
	property("Kentucky Avenue", "Red", 220, { 18, 90, 250, 700, 875, 1050 }),
	special("Chance", "Chance"),
	property("Indiana Avenue", "Red", 220, { 18, 90, 250, 700, 875, 1050 }),
	property("Illinois Avenue", "Red", 240, { 20, 100, 300, 750, 925, 1100 }),
	railroad("B. & O. Railroad"),
	property("Atlantic Avenue", "Yellow", 260, { 22, 110, 330, 800, 975, 1150 }),
	property("Ventnor Avenue", "Yellow", 260, { 22, 110, 330, 800, 975, 1150 }),
	utility("Water Works"),
	property("Marvin Gardens", "Yellow", 280, { 24, 120, 360, 850, 1025, 1200 }),
	special("Go To Jail", "GoToJail"),
	property("Pacific Avenue", "Green", 300, { 26, 130, 390, 900, 1100, 1275 }),
	property("North Carolina Avenue", "Green", 300, { 26, 130, 390, 900, 1100, 1275 }),
	special("Community Chest", "CommunityChest"),
	property("Pennsylvania Avenue", "Green", 320, { 28, 150, 450, 1000, 1200, 1400 }),
	railroad("Short Line"),
	special("Chance", "Chance"),
	property("Park Place", "DarkBlue", 350, { 35, 175, 500, 1100, 1300, 1500 }),
	tax("Luxury Tax", 100),
	property("Boardwalk", "DarkBlue", 400, { 50, 200, 600, 1400, 1700, 2000 }),
}

for i, tile in list do
	tile.position = i - 1
	table.freeze(tile)
end
table.freeze(list)

local Tiles = {}

Tiles.COUNT = #list
Tiles.list = list

function Tiles.at(position: number): Tile
	assert(position % 1 == 0 and position >= 0 and position < Tiles.COUNT, `invalid board position {position}`)
	return list[position + 1]
end

return Tiles
```

- [ ] **Step 6: Run tests to verify they pass**

Run the tests. Expected: `8 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add default.project.json src/
git commit -m "feat: board tile data and in-Studio test runner"
```

---

### Task 2: Board layout math

**Files:**
- Create: `src/shared/Board/Layout.luau`
- Test: `src/tests/Layout.spec.luau`

**Interfaces:**
- Consumes: `Tiles.COUNT` (40)
- Produces:
  - Constants `Layout.TILE_WIDTH = 6`, `Layout.CORNER_SIZE = 10`, `Layout.TILE_THICKNESS = 1`, `Layout.BOARD_SIZE = 74`, `Layout.ORIGIN: CFrame` (board centre in world space; tiles rest on the baseplate top at y = 0)
  - `type TilePlacement = { cframe: CFrame, size: Vector3 }`
  - `Layout.getTilePlacement(position: number): TilePlacement` — `cframe` is relative to the board centre; the tile's `LookVector` points toward the board centre (so the color band / text top is on the inner edge); `size` is `(width along edge, thickness, depth)`.

Geometry: side tiles are 6 wide × 10 deep, corners 10 × 10, board side = 2·10 + 9·6 = 74. Go is at the +X/+Z corner (the "bottom right" as seen from the default camera side, +Z). Play runs along the bottom (+Z) edge toward −X, up the left (−X) edge, along the top (−Z) edge, down the right (+X) edge. Each side is the bottom side rotated about Y.

- [ ] **Step 1: Write the failing tests**

`src/tests/Layout.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["board size is two corners plus nine tiles"] = function()
	Expect.equal(Layout.BOARD_SIZE, 2 * Layout.CORNER_SIZE + 9 * Layout.TILE_WIDTH)
end

tests["corners sit at the four board corners"] = function()
	local expected = {
		[0] = Vector3.new(32, 0, 32),
		[10] = Vector3.new(-32, 0, 32),
		[20] = Vector3.new(-32, 0, -32),
		[30] = Vector3.new(32, 0, -32),
	}
	for position, pos in expected do
		local placement = Layout.getTilePlacement(position)
		Expect.vectorNear(placement.cframe.Position, pos, `corner {position}`)
		Expect.vectorNear(placement.size, Vector3.new(10, 1, 10), `corner {position} size`)
	end
end

tests["side tiles run clockwise from Go"] = function()
	Expect.vectorNear(Layout.getTilePlacement(1).cframe.Position, Vector3.new(24, 0, 32), "tile 1")
	Expect.vectorNear(Layout.getTilePlacement(9).cframe.Position, Vector3.new(-24, 0, 32), "tile 9")
	Expect.vectorNear(Layout.getTilePlacement(11).cframe.Position, Vector3.new(-32, 0, 24), "tile 11")
	Expect.vectorNear(Layout.getTilePlacement(21).cframe.Position, Vector3.new(-24, 0, -32), "tile 21")
	Expect.vectorNear(Layout.getTilePlacement(39).cframe.Position, Vector3.new(32, 0, 24), "tile 39")
	Expect.vectorNear(Layout.getTilePlacement(1).size, Vector3.new(6, 1, 10), "tile 1 size")
end

tests["every tile faces the board centre and touches the outer edge"] = function()
	local inward = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) }
	for position = 0, 39 do
		local placement = Layout.getTilePlacement(position)
		local side = position // 10
		Expect.vectorNear(placement.cframe.LookVector, inward[side + 1], `tile {position} look`)
		local outerEdge = placement.cframe.Position:Dot(-inward[side + 1]) + placement.size.Z / 2
		Expect.near(outerEdge, Layout.BOARD_SIZE / 2, `tile {position} outer edge`)
	end
end

tests["consecutive tiles touch without gaps or overlap"] = function()
	for position = 0, 39 do
		local a = Layout.getTilePlacement(position)
		local b = Layout.getTilePlacement((position + 1) % 40)
		local distance = (a.cframe.Position - b.cframe.Position).Magnitude
		Expect.near(distance, (a.size.X + b.size.X) / 2, `tiles {position}->{(position + 1) % 40}`)
	end
end

tests["rejects invalid positions"] = function()
	for _, bad in { -1, 40, 1.5 } do
		assert(not pcall(Layout.getTilePlacement, bad), `getTilePlacement({bad}) should error`)
	end
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run the tests with `.run("Layout")`.
Expected: `0 passed, 1 failed` with `FAIL Layout.spec (load): ... Layout is not a valid member ...`.

- [ ] **Step 3: Write the layout module**

`src/shared/Board/Layout.luau`:

```lua
--!strict
-- Maps a board position (0-39) to where its tile sits, relative to the board centre.

local Tiles = require(script.Parent.Tiles)

export type TilePlacement = {
	cframe: CFrame, -- LookVector points at the board centre
	size: Vector3, -- (width along the edge, thickness, depth)
}

local Layout = {}

Layout.TILE_WIDTH = 6
Layout.CORNER_SIZE = 10
Layout.TILE_THICKNESS = 1
Layout.BOARD_SIZE = 2 * Layout.CORNER_SIZE + 9 * Layout.TILE_WIDTH
-- Board centre in world space; tiles rest on the baseplate, whose top is at y = 0.
Layout.ORIGIN = CFrame.new(0, Layout.TILE_THICKNESS / 2, 0)

local TILES_PER_SIDE = Tiles.COUNT // 4
local EDGE_CENTER = Layout.BOARD_SIZE / 2 - Layout.CORNER_SIZE / 2
-- Bottom (+Z), left (-X), top (-Z), right (+X): each side is the bottom side rotated about Y.
local SIDE_YAW = { 0, -math.pi / 2, math.pi, math.pi / 2 }

function Layout.getTilePlacement(position: number): TilePlacement
	assert(position % 1 == 0 and position >= 0 and position < Tiles.COUNT, `invalid board position {position}`)

	local side = position // TILES_PER_SIDE
	local offset = position % TILES_PER_SIDE

	-- Distance from this side's starting corner centre, measured along the edge.
	local along, width
	if offset == 0 then
		along, width = 0, Layout.CORNER_SIZE
	else
		along = Layout.CORNER_SIZE / 2 + Layout.TILE_WIDTH * (offset - 1) + Layout.TILE_WIDTH / 2
		width = Layout.TILE_WIDTH
	end

	-- Laid out on the bottom side (starting corner at +X/+Z, running toward -X), then rotated into place.
	local bottomSidePosition = Vector3.new(EDGE_CENTER - along, 0, EDGE_CENTER)
	return {
		cframe = CFrame.Angles(0, SIDE_YAW[side + 1], 0) * CFrame.new(bottomSidePosition),
		size = Vector3.new(width, Layout.TILE_THICKNESS, Layout.CORNER_SIZE),
	}
end

return Layout
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: `14 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Board/Layout.luau src/tests/Layout.spec.luau
git commit -m "feat: board layout math"
```

---

### Task 3: Build the board in the world

**Files:**
- Create: `src/server/BoardBuilder.luau`
- Modify: `src/server/init.server.luau`
- Test: `src/tests/BoardBuilder.spec.luau`

**Interfaces:**
- Consumes: `Tiles.list`, `ColorGroups`, `Layout.getTilePlacement`, `Layout.ORIGIN`, `Layout.BOARD_SIZE`, `Layout.CORNER_SIZE`, `Layout.TILE_THICKNESS`
- Produces (later steps place tokens using these):
  - `BoardBuilder.MODEL_NAME = "Board"`
  - `BoardBuilder.build(parent: Instance): Model` — replaces any existing child named `Board`
  - World structure: `Board` (Model, PrimaryPart = `Center`) → `Base` (Part), `Center` (Part), `Tiles` (Folder) → `Tile00`..`Tile39` (Parts) with attributes `TilePosition: number`, `TileName: string`. Property tiles have a child Part `ColorStrip`. Every tile has a `SurfaceGui` (Top face) with a `TextLabel` named `Label`.

- [ ] **Step 1: Write the failing tests**

`src/tests/BoardBuilder.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local BoardBuilder = require(ServerScriptService.Server.BoardBuilder)
local Expect = require(script.Parent.Expect)

local tests = {}

local function withBoard(fn: (Model) -> ())
	local scratch = Instance.new("Folder")
	local ok, err = pcall(function()
		fn(BoardBuilder.build(scratch))
	end)
	scratch:Destroy()
	if not ok then
		error(err, 0)
	end
end

tests["builds one part per tile with position attributes"] = function()
	withBoard(function(board)
		Expect.equal(board.Name, "Board")
		local tileParts = board:FindFirstChild("Tiles") :: Folder
		Expect.equal(#tileParts:GetChildren(), 40, "tile count")
		for _, tile in Tiles.list do
			local part = tileParts:FindFirstChild(string.format("Tile%02d", tile.position)) :: BasePart
			assert(part, `missing Tile{tile.position}`)
			Expect.equal(part:GetAttribute("TilePosition"), tile.position, "TilePosition")
			Expect.equal(part:GetAttribute("TileName"), tile.name, "TileName")
			local expected = (Layout.ORIGIN * Layout.getTilePlacement(tile.position).cframe).Position
			Expect.vectorNear(part.Position, expected, `Tile{tile.position} position`)
			assert(part.Anchored, `Tile{tile.position} not anchored`)
		end
	end)
end

tests["property tiles have a color strip in their group color"] = function()
	withBoard(function(board)
		for _, tile in Tiles.list do
			local part = (board:FindFirstChild("Tiles") :: Folder):FindFirstChild(string.format("Tile%02d", tile.position)) :: BasePart
			local strip = part:FindFirstChild("ColorStrip") :: BasePart?
			if tile.kind == "Property" then
				assert(strip, `{tile.name} has no ColorStrip`)
				Expect.equal(strip.Color, ColorGroups[tile.group :: string].color, `{tile.name} strip color`)
			else
				assert(strip == nil, `{tile.name} should not have a ColorStrip`)
			end
		end
	end)
end

tests["every tile has a label with its name"] = function()
	withBoard(function(board)
		for _, tile in Tiles.list do
			local part = (board:FindFirstChild("Tiles") :: Folder):FindFirstChild(string.format("Tile%02d", tile.position)) :: BasePart
			local label = part:FindFirstChild("Label", true) :: TextLabel
			assert(label, `{tile.name} has no Label`)
			assert(label.Text:find(tile.name, 1, true), `{tile.name} label text is "{label.Text}"`)
		end
	end)
end

tests["rebuilding replaces the existing board"] = function()
	local scratch = Instance.new("Folder")
	BoardBuilder.build(scratch)
	BoardBuilder.build(scratch)
	Expect.equal(#scratch:GetChildren(), 1, "boards in parent")
	scratch:Destroy()
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run the tests with `.run("BoardBuilder")`.
Expected: `0 passed, 1 failed` with `FAIL BoardBuilder.spec (load): ... BoardBuilder is not a valid member ...`.

- [ ] **Step 3: Write the builder**

`src/server/BoardBuilder.luau`:

```lua
--!strict
-- Builds the 3D board from tile data. Server-side so it replicates to every client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local BoardBuilder = {}

BoardBuilder.MODEL_NAME = "Board"

local TILE_COLOR = Color3.fromRGB(214, 234, 214)
local BASE_COLOR = Color3.fromRGB(35, 35, 35)
local CENTER_COLOR = Color3.fromRGB(196, 226, 200)
local TEXT_COLOR = Color3.fromRGB(25, 25, 25)
local TILE_GAP = 0.15 -- tiles are shrunk by this much so the dark base shows as grid lines
local STRIP_DEPTH = 2.5 -- depth of the color band on property tiles
local PIXELS_PER_STUD = 40

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function labelText(tile: Tiles.Tile): string
	if tile.price then
		return `{tile.name}\n${tile.price}`
	elseif tile.amount then
		return `{tile.name}\nPay ${tile.amount}`
	end
	return tile.name
end

-- Text on the tile's top face, reading upright for someone sitting outside the board.
local function addLabel(part: BasePart, text: string, topInset: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.TextColor3 = TEXT_COLOR
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(topInset, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = label
end

local function buildTile(tile: Tiles.Tile, parent: Instance)
	local placement = Layout.getTilePlacement(tile.position)
	local size = placement.size - Vector3.new(TILE_GAP, 0, TILE_GAP)
	local part = makePart(
		string.format("Tile%02d", tile.position),
		size,
		Layout.ORIGIN * placement.cframe,
		TILE_COLOR,
		parent
	)
	part:SetAttribute("TilePosition", tile.position)
	part:SetAttribute("TileName", tile.name)

	local topInset = 0
	if tile.group then
		-- Band along the inner edge (the tile's -Z side), sitting just on top of the tile.
		local strip = makePart(
			"ColorStrip",
			Vector3.new(size.X, 0.1, STRIP_DEPTH),
			part.CFrame * CFrame.new(0, size.Y / 2 + 0.05, -(size.Z / 2 - STRIP_DEPTH / 2)),
			ColorGroups[tile.group].color,
			part
		)
		strip.CanCollide = false
		topInset = STRIP_DEPTH / size.Z
	end

	addLabel(part, labelText(tile), topInset)
end

function BoardBuilder.build(parent: Instance): Model
	local existing = parent:FindFirstChild(BoardBuilder.MODEL_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = BoardBuilder.MODEL_NAME

	-- Dark slab under everything; slightly lower so tile tops sit above it.
	makePart(
		"Base",
		Vector3.new(Layout.BOARD_SIZE, Layout.TILE_THICKNESS, Layout.BOARD_SIZE),
		Layout.ORIGIN * CFrame.new(0, -0.1, 0),
		BASE_COLOR,
		model
	)

	local innerSize = Layout.BOARD_SIZE - 2 * Layout.CORNER_SIZE - TILE_GAP
	local center = makePart(
		"Center",
		Vector3.new(innerSize, Layout.TILE_THICKNESS, innerSize),
		Layout.ORIGIN,
		CENTER_COLOR,
		model
	)
	model.PrimaryPart = center

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = model
	for _, tile in Tiles.list do
		buildTile(tile, tileFolder)
	end

	model.Parent = parent
	return model
end

return BoardBuilder
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: `18 passed, 0 failed`.

- [ ] **Step 5: Build the board on server start**

Replace `src/server/init.server.luau` with:

```lua
--!strict
local BoardBuilder = require(script.BoardBuilder)

BoardBuilder.build(workspace)
```

- [ ] **Step 6: Visual check**

1. `start_stop_play(true)`, then `get_console_output` — expect no errors.
2. `screen_capture` from above the Go corner: `camera_position = {60, 60, 60}`, `look_at_position = {0, 0, 0}`. Then one looking straight down the bottom row: `camera_position = {0, 40, 70}`, `look_at_position = {0, 0, 30}`.
3. Check: 40 tiles with dark grid lines; color bands on the **inner** edge of property tiles; Go in the corner nearest +X/+Z; text on the bottom row reads upright from the +Z side and does not overlap the color band; long names ("North Carolina Avenue") wrap inside their tile.
4. If the text is upside down (top toward the outer edge), the SurfaceGui's up direction is the opposite of what we assumed: in `addLabel`, set `label.Rotation = 180`, move the strip inset from `PaddingTop` to `PaddingBottom`, re-check. If the text is rotated 90°, report it instead of guessing.
5. `start_stop_play(false)`.

- [ ] **Step 7: Commit**

```bash
git add src/server src/tests/BoardBuilder.spec.luau
git commit -m "feat: build the 3D board from tile data"
```

---

### Task 4: Overhead board camera

**Files:**
- Create: `src/client/BoardCamera.luau`
- Modify: `src/client/init.client.luau`
- Test: `src/tests/BoardCamera.spec.luau`

**Interfaces:**
- Consumes: `Layout.ORIGIN`, `Layout.BOARD_SIZE`
- Produces:
  - `BoardCamera.PITCH: number` (radians below horizontal, `math.rad(60)`)
  - `BoardCamera.getOverheadCFrame(focus: Vector3, boardSize: number, fieldOfViewDegrees: number, aspect: number): CFrame` — pure; camera sits on the +Z (Go row) side, tilted down by `PITCH`, far enough that a sphere around the board fits both vertically and horizontally.
  - `BoardCamera.start()` — client only; applies the camera and keeps it applied on viewport resize and respawn.

- [ ] **Step 1: Write the failing tests**

`src/tests/BoardCamera.spec.luau`:

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local BoardCamera = require(StarterPlayer.StarterPlayerScripts.Client.BoardCamera)
local Expect = require(script.Parent.Expect)

local tests = {}

local FOCUS = Vector3.new(0, 0.5, 0)

tests["camera looks at the board centre"] = function()
	local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, 16 / 9)
	Expect.vectorNear(cf.LookVector, (FOCUS - cf.Position).Unit, "look direction")
end

tests["camera sits above the Go-row side at the configured pitch"] = function()
	local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, 16 / 9)
	local offset = cf.Position - FOCUS
	Expect.near(offset.X, 0, "x offset")
	assert(offset.Z > 0, "camera should be on the +Z side")
	Expect.near(math.asin(offset.Unit.Y), BoardCamera.PITCH, "pitch")
end

tests["narrower viewport moves the camera further away"] = function()
	local wide = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, 16 / 9)
	local portrait = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, 9 / 16)
	assert(
		(portrait.Position - FOCUS).Magnitude > (wide.Position - FOCUS).Magnitude,
		"portrait camera should be further away"
	)
end

tests["whole board fits inside the view"] = function()
	for _, aspect in { 16 / 9, 4 / 3, 9 / 16 } do
		local fov = 70
		local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, fov, aspect)
		local tanV = math.tan(math.rad(fov) / 2)
		local tanH = tanV * aspect
		for _, corner in { Vector3.new(37, 0, 37), Vector3.new(-37, 0, 37), Vector3.new(37, 0, -37), Vector3.new(-37, 0, -37) } do
			local p = cf:PointToObjectSpace(FOCUS + corner)
			local depth = -p.Z
			assert(depth > 0, "corner behind camera")
			assert(math.abs(p.X) / depth <= tanH, `corner {corner} outside horizontally at aspect {aspect}`)
			assert(math.abs(p.Y) / depth <= tanV, `corner {corner} outside vertically at aspect {aspect}`)
		end
	end
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run the tests with `.run("BoardCamera")`.
Expected: `0 passed, 1 failed` with `FAIL BoardCamera.spec (load): ... BoardCamera is not a valid member ...`.

- [ ] **Step 3: Write the camera module**

`src/client/BoardCamera.luau`:

```lua
--!strict
-- Fixed overhead view of the board, fitted to the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Board.Layout)

local BoardCamera = {}

BoardCamera.PITCH = math.rad(60)

function BoardCamera.getOverheadCFrame(focus: Vector3, boardSize: number, fieldOfViewDegrees: number, aspect: number): CFrame
	-- Fit a sphere around the board so every corner is visible from any angle.
	local radius = boardSize / 2 * math.sqrt(2)
	local halfVertical = math.rad(fieldOfViewDegrees) / 2
	local halfHorizontal = math.atan(math.tan(halfVertical) * aspect)
	local distance = radius / math.sin(math.min(halfVertical, halfHorizontal))

	local offset = Vector3.new(0, math.sin(BoardCamera.PITCH), math.cos(BoardCamera.PITCH)) * distance
	return CFrame.lookAt(focus + offset, focus)
end

function BoardCamera.start()
	local camera = workspace.CurrentCamera

	local function apply()
		local viewport = camera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = BoardCamera.getOverheadCFrame(Layout.ORIGIN.Position, Layout.BOARD_SIZE, camera.FieldOfView, aspect)
	end

	apply()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	-- The default camera scripts reset the camera when a character spawns; re-apply after them.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
end

return BoardCamera
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: `22 passed, 0 failed`.

- [ ] **Step 5: Start the camera on the client**

Replace `src/client/init.client.luau` with:

```lua
--!strict
local BoardCamera = require(script.BoardCamera)

BoardCamera.start()
```

- [ ] **Step 6: Playtest check**

1. `start_stop_play(true)`, `get_console_output` — expect no errors.
2. `screen_capture` (no camera override) — expect the whole board centered, viewed from the Go-row side, tilted, nothing cut off.
3. Respawn check: `execute_luau(datamodel_type = "Server", code = 'for _, p in game:GetService("Players"):GetPlayers() do p:LoadCharacter() end')`, wait for respawn, `screen_capture` again — expect the same overhead view.
4. `start_stop_play(false)`.

- [ ] **Step 7: Commit**

```bash
git add src/client src/tests/BoardCamera.spec.luau
git commit -m "feat: overhead board camera"
```
