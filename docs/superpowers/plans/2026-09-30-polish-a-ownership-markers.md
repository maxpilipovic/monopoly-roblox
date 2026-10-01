# Ownership Markers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every owned tile shows a strip in its owner's seat color along its outer edge; mortgaged deeds show a gray strip with owner-colored caps.

**Architecture:** A pure shared layout module says where the strip lies on a tile; a client renderer (same pattern as `src/client/Buildings.luau`) diffs the snapshot's properties into strips. No server or protocol change.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Rojo 7.7 (`~/.aftman/bin/rojo.exe serve`), tests run inside Studio.

**Spec:** `docs/superpowers/specs/2026-09-30-polish-design.md`, section A.

## Global Constraints

- Every module starts with `--!strict`; tabs; short comments that say why; match the surrounding module patterns.
- All 293 existing tests keep passing.
- Client renderers tolerate a nil snapshot (lobby): it clears everything.
- Tests run in Studio, not a shell. Before each run: Rojo is serving and the user clicked Connect; after editing, stop any playtest, start a new one, and in the **Server** datamodel first `assert` the edited script's `.Source` contains a new line, then run `require(game.ServerStorage.Tests.TestRunner).run("<Spec>")` (one spec) or `.run()` (all).
- Never `git checkout`/`git switch` to a branch with different files while Rojo is connected (Studio crashes).

## Review Focus

1. A deed changing hands (trade, bankruptcy to a player) recolors its strip; a deed going back to the bank (bankruptcy to the bank) removes it. (Task 2 test "strips follow ownership changes".)
2. The strip never sits under a token standing on the tile, in any of the 6 seat spots. (Task 1 test "strip stays clear of the token spots".)
3. Back in the lobby (nil snapshot) every strip disappears, and a new game starts with none. (Task 2 test.)
4. Mortgage → unmortgage switches the strip back to solid without leaving the caps behind. (Task 2 test.)
5. Strips don't block clicks or the camera: `CanCollide`, `CanQuery`, `CanTouch` are all false. (Task 2 test.)

---

### Task 1: OwnerLayout — where the strip lies

**Files:**
- Create: `src/shared/Board/OwnerLayout.luau`
- Test: `src/tests/OwnerLayout.spec.luau`

**Interfaces:**
- Produces (used by Task 2): `OwnerLayout.SIZE: Vector3` (width along the edge, thickness, depth), `OwnerLayout.cframe(position: number): CFrame` (strip centre, oriented with the tile), `OwnerLayout.isOwnable(position: number): boolean`.

- [ ] **Step 1: Write the failing test** — create `src/tests/OwnerLayout.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local OwnerLayout = require(ReplicatedStorage.Shared.Board.OwnerLayout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local function tileTop(position: number): (CFrame, Vector3)
	local placement = Layout.getTilePlacement(position)
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0), placement.size
end

tests["the strip lies flat on the outer edge of every ownable tile"] = function()
	local size = OwnerLayout.SIZE
	for _, tile in Tiles.list do
		if not OwnerLayout.isOwnable(tile.position) then
			continue
		end
		local top, tileSize = tileTop(tile.position)
		local spot = top:PointToObjectSpace(OwnerLayout.cframe(tile.position).Position)
		local label = `tile {tile.position}`
		Expect.near(spot.Y, size.Y / 2, `{label} height`)
		Expect.near(spot.X, 0, `{label} centred`)
		assert(size.X <= tileSize.X, `{label} wider than the tile`)
		assert(spot.Z + size.Z / 2 <= tileSize.Z / 2, `{label} off the outer edge`)
		assert(spot.Z - size.Z / 2 > 0, `{label} not on the outer half`)
		-- Oriented with the tile: its long side runs along the edge.
		local along = top:VectorToObjectSpace(OwnerLayout.cframe(tile.position).RightVector)
		Expect.near(math.abs(along.X), 1, `{label} orientation`)
	end
end

tests["the strip stays clear of the token spots"] = function()
	local size = OwnerLayout.SIZE
	local radius = TokenLayout.TOKEN_DIAMETER / 2
	for seat = 1, TokenLayout.MAX_SEATS do
		local top = tileTop(1)
		local token = top:PointToObjectSpace(TokenLayout.spot(1, seat))
		local strip = top:PointToObjectSpace(OwnerLayout.cframe(1).Position)
		assert(token.Z + radius <= strip.Z - size.Z / 2, `seat {seat} token overlaps the strip`)
	end
end

tests["only streets, railroads and utilities get a strip"] = function()
	assert(OwnerLayout.isOwnable(1), "street")
	assert(OwnerLayout.isOwnable(5), "railroad")
	assert(OwnerLayout.isOwnable(12), "utility")
	for _, position in { 0, 2, 4, 7, 10, 20, 30, 38 } do
		assert(not OwnerLayout.isOwnable(position), `position {position} is not ownable`)
		assert(not pcall(OwnerLayout.cframe, position), `position {position} accepted`)
	end
end

return tests
```

- [ ] **Step 2: Run to verify it fails**

Run: `.run("OwnerLayout")`
Expected: `FAIL OwnerLayout.spec (load): Requested module experienced an error while loading` (the module doesn't exist).

- [ ] **Step 3: Implement** — create `src/shared/Board/OwnerLayout.luau`:

```lua
--!strict
-- Where a tile's ownership strip lies: flat along its outer (board-edge) side, opposite the color band
-- and the houses, clear of where tokens stand.

local Layout = require(script.Parent.Layout)
local Tiles = require(script.Parent.Tiles)

local OwnerLayout = {}

local MARGIN = 0.3 -- inset from the tile's sides and outer edge
local OWNABLE = { Property = true, Railroad = true, Utility = true }

OwnerLayout.SIZE = Vector3.new(Layout.TILE_WIDTH - 2 * MARGIN, 0.1, 0.6)

function OwnerLayout.isOwnable(position: number): boolean
	return OWNABLE[Tiles.at(position).kind] == true
end

-- Centre of the strip, oriented with the tile (+Z toward the board's outer edge).
function OwnerLayout.cframe(position: number): CFrame
	assert(OwnerLayout.isOwnable(position), `{Tiles.at(position).name} can't be owned`)
	local placement = Layout.getTilePlacement(position)
	local z = placement.size.Z / 2 - MARGIN - OwnerLayout.SIZE.Z / 2
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2 + OwnerLayout.SIZE.Y / 2, z)
end

return OwnerLayout
```

- [ ] **Step 4: Run to verify it passes**

Run: `.run("OwnerLayout")` then `.run()`
Expected: `3 passed, 0 failed`; full suite `296 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Board/OwnerLayout.luau src/tests/OwnerLayout.spec.luau
git commit -m "feat: ownership strip layout along each ownable tile's outer edge"
```

---

### Task 2: OwnerMarkers — the strips on the board

**Files:**
- Create: `src/client/OwnerMarkers.luau`
- Modify: `src/client/GameClient.luau` (create the view next to `Buildings.new`, apply next to `buildings:apply`)
- Test: `src/tests/OwnerMarkers.spec.luau`

**Interfaces:**
- Consumes: `OwnerLayout.SIZE`, `OwnerLayout.cframe(position)` (Task 1); `TokenLayout.SEAT_COLORS`; `Protocol.Snapshot` (`players[i].id/seat`, `properties[i].position/owner/mortgaged`).
- Produces: `OwnerMarkers.new(parent: Instance): OwnerMarkersView`, `OwnerMarkers.wanted(snapshot: Protocol.Snapshot?): { [number]: Marker }`, `OwnerMarkers.apply(self, snapshot: Protocol.Snapshot?)`, `export type Marker = { seat: number, mortgaged: boolean }`. `OwnerMarkers.MORTGAGED_COLOR: Color3`.

- [ ] **Step 1: Write the failing test** — create `src/tests/OwnerMarkers.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local OwnerMarkers = require(StarterPlayer.StarterPlayerScripts.Client.OwnerMarkers)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["wanted lists each owned deed with its owner's seat and mortgage"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p2", 1)
	GameFixtures.own(state, "p3", 5)
	state.properties[5].mortgaged = true
	local wanted = OwnerMarkers.wanted(Snapshot.fromState(state))
	Expect.equal(wanted[1].seat, 2, "Mediterranean: p2's seat")
	Expect.equal(wanted[1].mortgaged, false)
	Expect.equal(wanted[5].seat, 3, "Reading: p3's seat")
	Expect.equal(wanted[5].mortgaged, true)
	Expect.equal(wanted[3], nil, "unowned")
	Expect.equal(next(OwnerMarkers.wanted(nil)), nil, "lobby: nothing")
end

local function parts(folder: Instance, position: number): { BasePart }
	local group = folder:FindFirstChild(tostring(position))
	local list = {}
	if group then
		for _, child in group:GetChildren() do
			table.insert(list, child :: BasePart)
		end
	end
	return list
end

tests["strips follow ownership changes, mortgages and the lobby"] = function()
	local holder = Instance.new("Folder")
	local view = OwnerMarkers.new(holder)
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	view:apply(Snapshot.fromState(state))
	local strip = parts(view.folder, 1)
	Expect.equal(#strip, 1, "one solid strip")
	Expect.equal(strip[1].Color, TokenLayout.SEAT_COLORS[1], "p1's color")
	assert(not strip[1].CanCollide and not strip[1].CanQuery and not strip[1].CanTouch, "strips are not solid")

	state.properties[1].owner = "p2" -- traded
	view:apply(Snapshot.fromState(state))
	Expect.equal(parts(view.folder, 1)[1].Color, TokenLayout.SEAT_COLORS[2], "recolored for p2")

	state.properties[1].mortgaged = true
	view:apply(Snapshot.fromState(state))
	local mortgaged = parts(view.folder, 1)
	Expect.equal(#mortgaged, 3, "gray middle and two caps")
	local grays, caps = 0, 0
	for _, part in mortgaged do
		if part.Color == OwnerMarkers.MORTGAGED_COLOR then
			grays += 1
		elseif part.Color == TokenLayout.SEAT_COLORS[2] then
			caps += 1
		end
	end
	Expect.equal(grays, 1, "gray middle")
	Expect.equal(caps, 2, "owner-colored caps")

	state.properties[1].mortgaged = false
	view:apply(Snapshot.fromState(state))
	Expect.equal(#parts(view.folder, 1), 1, "solid again, caps gone")

	state.properties[1] = nil -- back to the bank
	view:apply(Snapshot.fromState(state))
	Expect.equal(view.folder:FindFirstChild("1"), nil, "removed")

	GameFixtures.own(state, "p1", 3)
	view:apply(Snapshot.fromState(state))
	view:apply(nil)
	Expect.equal(#view.folder:GetChildren(), 0, "lobby clears everything")
	holder:Destroy()
end

return tests
```

Before writing it, check `GameFixtures.own(state, playerId, position, houses?)` exists in `src/tests/GameFixtures.luau` (it does; Bankruptcy and TradeBuilder specs use it).

- [ ] **Step 2: Run to verify it fails**

Run: `.run("OwnerMarkers")`
Expected: `FAIL OwnerMarkers.spec (load): …` (module missing).

- [ ] **Step 3: Implement** — create `src/client/OwnerMarkers.luau`:

```lua
--!strict
-- Client-side ownership strips: a bar in the owner's seat color along each owned tile's outer edge,
-- gray with owner-colored caps while mortgaged. Kept in step with the snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OwnerLayout = require(ReplicatedStorage.Shared.Board.OwnerLayout)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)

local CAP_LENGTH = 0.8

local OwnerMarkers = {}
OwnerMarkers.__index = OwnerMarkers

OwnerMarkers.MORTGAGED_COLOR = Color3.fromRGB(60, 60, 64)

export type Marker = { seat: number, mortgaged: boolean }

export type OwnerMarkersView = typeof(setmetatable({} :: { folder: Folder, shown: { [number]: string } }, OwnerMarkers))

function OwnerMarkers.new(parent: Instance): OwnerMarkersView
	local folder = Instance.new("Folder")
	folder.Name = "OwnerMarkers"
	folder.Parent = parent
	return setmetatable({ folder = folder, shown = {} }, OwnerMarkers)
end

-- Position -> owner's seat and mortgage state, for every owned deed.
function OwnerMarkers.wanted(snapshot: Protocol.Snapshot?): { [number]: Marker }
	local wanted = {}
	if snapshot then
		local seats = {}
		for _, player in snapshot.players do
			seats[player.id] = player.seat
		end
		for _, property in snapshot.properties do
			local seat = seats[property.owner]
			if seat then
				wanted[property.position] = { seat = seat, mortgaged = property.mortgaged }
			end
		end
	end
	return wanted
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
end

local function key(marker: Marker?): string?
	return if marker then `{marker.seat}:{marker.mortgaged}` else nil
end

local function show(self: OwnerMarkersView, position: number, marker: Marker?)
	local existing = self.folder:FindFirstChild(tostring(position))
	if existing then
		existing:Destroy()
	end
	self.shown[position] = key(marker)
	if not marker then
		return
	end
	local group = Instance.new("Folder")
	group.Name = tostring(position)
	group.Parent = self.folder
	local color = TokenLayout.SEAT_COLORS[marker.seat]
	local size = OwnerLayout.SIZE
	local centre = OwnerLayout.cframe(position)
	if not marker.mortgaged then
		makePart("Strip", size, centre, color, group)
		return
	end
	-- Mortgaged: gray in the middle, the owner's color only at the ends so it's still clear whose it is.
	local middle = size.X - 2 * CAP_LENGTH
	makePart("Mortgaged", Vector3.new(middle, size.Y, size.Z), centre, OwnerMarkers.MORTGAGED_COLOR, group)
	local capSize = Vector3.new(CAP_LENGTH, size.Y, size.Z)
	local offset = size.X / 2 - CAP_LENGTH / 2
	makePart("CapLeft", capSize, centre * CFrame.new(-offset, 0, 0), color, group)
	makePart("CapRight", capSize, centre * CFrame.new(offset, 0, 0), color, group)
end

function OwnerMarkers.apply(self: OwnerMarkersView, snapshot: Protocol.Snapshot?)
	local wanted = OwnerMarkers.wanted(snapshot)
	for position in self.shown do
		if not wanted[position] then
			show(self, position, nil)
		end
	end
	for position, marker in wanted do
		if self.shown[position] ~= key(marker) then
			show(self, position, marker)
		end
	end
end

return OwnerMarkers
```

In `src/client/GameClient.luau`:
- Add `local OwnerMarkers = require(script.Parent.OwnerMarkers)` after the `HudView` require (keep requires alphabetical within the client group: `Buildings`, `EventText`, `HudModel`, `HudView`, `OwnerMarkers`, `Tokens`).
- After `local buildings = Buildings.new(workspace)` add `local markers = OwnerMarkers.new(workspace)`.
- After `buildings:apply(update.snapshot)` add `markers:apply(update.snapshot)`.

- [ ] **Step 4: Run to verify it passes**

Run: `.run("OwnerMarkers")` then `.run()`
Expected: `2 passed, 0 failed`; full suite `298 passed, 0 failed`.

- [ ] **Step 5: Playtest and screenshot**

Set the Edit-datamodel workspace attribute `StartingMoney` to `3000` (remove it afterwards). Play Solo, start a 3-seat game from the lobby, and play a few rounds (buy everything you land on; the bots buy too). Then from the Client datamodel mortgage one of your deeds (`game.ReplicatedStorage.Remotes.GameAction:FireServer({ type = "Mortgage", position = <pos> })` on your turn). Take a screenshot (MCP `screen_capture`) of the overhead view.
Expected: strips in the right seat colors on each owned tile's outer edge, the mortgaged one gray with colored caps, no strip under a token, labels still readable. Return to lobby at the end of a game: strips disappear.

- [ ] **Step 6: Commit**

```bash
git add src/client/OwnerMarkers.luau src/client/GameClient.luau src/tests/OwnerMarkers.spec.luau
git commit -m "feat: ownership strips in the owner's color, gray with caps when mortgaged"
```
