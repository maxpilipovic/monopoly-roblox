# Physics Dice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every roll throws two 3D dice onto the board centre that tumble with recorded real physics and land on the server's numbers.

**Architecture:** The server keeps picking the numbers. Real Roblox physics throws are recorded once in Studio (`DiceRecorder`) into a data module (`Throws`). A pure module (`DiceThrow`) turns a recording into per-frame CFrames: rotated to the roller's side, each die turned inside the throw so the wanted face ends on top. A client view (`DiceView`) plays those frames on the Rounded die model, which the server loads at startup (`Assets`).

**Tech Stack:** Luau (`--!strict`), Rojo 7.7, Roblox Studio; tests are the repo's own runner (`src/tests/*.spec.luau`, `Expect`), run in a Studio playtest.

**Spec:** `docs/superpowers/specs/2026-10-17-physics-dice-design.md`

## Global Constraints

- `--!strict`, tabs, short "why" comments, the repo's existing module patterns.
- No new top-level node in `default.project.json` (it forces a Rojo restart); `ReplicatedStorage.Assets` is created at runtime.
- The recorder never runs outside Studio (`RunService:IsStudio()`).
- All existing tests keep passing (395 before this plan).
- The server still decides the roll: `GameService`'s `rollDice`, the engine and the rules do not change.
- Dice: Rounded model (asset 73288478231290, 1.2 studs), shown at 4 studs; ivory body, black pips.
- Timing: every recording settles within 1.6 s; `Pacing.DICE_SECONDS = 2`.
- Fallback: if the model or the recordings are missing, the 2D stage dice play exactly as today.

## Deviations from the spec (agreed when writing the plan)

- Throws are recorded from the **+Z** side (the board's side 0, where `Layout` lays out its bottom row) towards −Z, so side 0 needs no turn and sides 1–3 use `Layout`'s own side yaw. (The spec said −Z.)
- A throw stores frames only. The face that ended on top is computed from the last frame, so there's no `top` field.
- There's no overlap check: the recorded dice are solid physics parts and can't end up overlapping.
- `Throws.luau` is about 100 KB, not 40 KB: 7 numbers per die per frame.

## Running tests (read this first)

Studio MCP `execute_luau` can't `require` project modules. Tests run through a Studio-only hook:

1. Make sure `rojo serve` is running and Studio is connected. Then check that the newest edit reached Studio: read the edited module's `.Source` in the **Edit** datamodel and look for a line you just wrote.
2. Start a playtest (`start_stop_play` with `is_start = true`).
3. In the **Server** datamodel: `workspace:SetAttribute("TestResults", nil); workspace:SetAttribute("RunTests", "DiceThrow")`. Use `""` to run all tests.
4. Poll `return workspace:GetAttribute("TestResults")` until it's set. The first line is `N passed, M failed`, followed by one line per failure.
5. Stop the playtest when done.

"Run tests" below means exactly this procedure with the filter given.

## Review Focus

1. **A player rolls before the die model has loaded** (the server is still fetching it, or the network fails). The 2D stage dice must play and the game must not error. Covered by the `ready()` guard in Task 4 and the fallback step in Task 5's playtest.
2. **Two rolls in quick succession** (doubles, or the card roll that comes right after a move). A new roll must stop the previous playback cleanly, with no second `RenderStepped` connection left running. Covered by `DiceView.roll` calling `stop()` first (Task 4) and the doubles step in Task 5.
3. **A roll with no move after it** (a failed doubles attempt in jail, or the utility-card roll). The throw must still come from the roller's side. Covered by the `rollerPosition` fallback tests in Task 2.
4. **The game ends or returns to the lobby while dice are on the board.** The dice must disappear. Covered by `clear()` in `show()` (Task 4) and the game-over step in Task 5.
5. **Rounded quaternions in `Throws.luau`** (3 decimals) produce a slightly non-unit rotation. It must still give a clean rotation with the right face up. Covered by the round-trip test in Task 2 and the all-throws, all-targets test in Task 3.

---

### Task 1: Load the die model at startup

**Files:**
- Create: `src/server/Assets.luau`
- Modify: `src/server/init.server.luau` (call `Assets.load()` after `GameService.start()`)

**Interfaces:**
- Consumes: `src/shared/Cosmetics/AssetIds.luau`, which is `{ [Kind]: { [Shape]: number } }` (today `{ Dice = { Rounded = 73288478231290 } }`).
- Produces: at runtime, `ReplicatedStorage.Assets.<Kind>.<Shape>` is a `Model` whose children are the Blender parts (`Body`, `Pips` for the die). `Assets.load(): ()` returns at once and does the loading in a spawned thread.

This task touches only the live engine (`InsertService`), so it's checked in a playtest rather than with a spec.

- [ ] **Step 1: Write `src/server/Assets.luau`**

```lua
--!strict
-- Loads every uploaded model in AssetIds into ReplicatedStorage.Assets.<Kind>.<Shape> so clients
-- can clone them. Runs once at startup; a model that fails to load is logged and skipped, and the
-- client falls back to what it drew before models existed.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetIds = require(ReplicatedStorage.Shared.Cosmetics.AssetIds)

local Assets = {}

-- LoadAsset wraps the upload in a Model; the upload itself is the Model inside it.
local function fetch(id: number): Model?
	local ok, container = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok then
		warn(`Assets: could not load {id}: {container}`)
		return nil
	end
	local inner = (container :: Model):FindFirstChildWhichIsA("Model")
	if inner then
		inner.Parent = nil
	end
	container:Destroy()
	return inner
end

function Assets.load()
	local root = Instance.new("Folder")
	root.Name = "Assets"
	root.Parent = ReplicatedStorage
	-- Studio playtest aid: the NoModels attribute plays the game as if no model could be loaded.
	if RunService:IsStudio() and workspace:GetAttribute("NoModels") then
		return
	end
	task.spawn(function()
		for kind, shapes in AssetIds do
			local folder = Instance.new("Folder")
			folder.Name = kind
			folder.Parent = root
			for shape, id in shapes do
				local model = fetch(id)
				if model then
					model.Name = shape
					model.Parent = folder
				end
			end
		end
	end)
end

return Assets
```

- [ ] **Step 2: Call it from `src/server/init.server.luau`**

Add the require next to the others and the call after `GameService.start()`:

```lua
local Assets = require(script.Assets)
```

```lua
BoardBuilder.build(workspace)
GameService.start()
Assets.load()
```

- [ ] **Step 3: Check it in a playtest**

Start a playtest. In the **Client** datamodel run:

```lua
local m = game:GetService("ReplicatedStorage"):WaitForChild("Assets", 10)
m = m and m:WaitForChild("Dice", 10)
m = m and m:WaitForChild("Rounded", 10)
if not m then return "missing" end
local names = {}
for _, c in m:GetChildren() do table.insert(names, c.ClassName .. " " .. c.Name) end
table.sort(names)
return table.concat(names, ", ")
```

Expected: `MeshPart Body, MeshPart Pips`. Then run all tests (filter `""`). Expected: `395 passed, 0 failed`. Stop the playtest.

- [ ] **Step 4: Commit**

```bash
git add src/server/Assets.luau src/server/init.server.luau
git commit -m "feat: load uploaded models into ReplicatedStorage.Assets at startup"
```

---

### Task 2: DiceThrow — the throw maths

**Files:**
- Create: `src/shared/Dice/DiceThrow.luau`
- Modify: `src/shared/Board/Layout.luau` (export the side yaw)
- Test: `src/tests/DiceThrow.spec.luau`, `src/tests/Layout.spec.luau`

**Interfaces:**
- Consumes: `Layout` (`ORIGIN`, `TILE_THICKNESS`), `Tiles.COUNT`.
- Produces (used by Tasks 3 and 4):
  - `Layout.sideYaw(side: number): number`: the yaw that turns side 0 into `side` (0 bottom +Z, 1 left −X, 2 top −Z, 3 right +X).
  - `DiceThrow.FPS = 30`, `DiceThrow.MAX_SECONDS = 1.6`, `DiceThrow.MAX_TILT = 5`, `DiceThrow.SIZE = 4`, `DiceThrow.BOUNDS = 20`.
  - `export type Throw = { { number } }`: per die, frames flattened as `x, y, z, qx, qy, qz, qw`, relative to the board surface centre, thrown from the +Z side.
  - `export type Plan = { { CFrame } }`: per die, one CFrame per frame, relative to the board surface centre.
  - `DiceThrow.encode(cframe: CFrame, into: { number }): ()`: appends 7 numbers, rounded to 3 decimals.
  - `DiceThrow.frameCount(throw: Throw): number`.
  - `DiceThrow.frame(die: { number }, index: number): CFrame` (1-based).
  - `DiceThrow.faceUp(rotation: CFrame): number`, `DiceThrow.tilt(rotation: CFrame): number` (degrees).
  - `DiceThrow.plan(throw: Throw, dice: { number }, side: number, spin: { number }): Plan`.
  - `DiceThrow.side(position: number): number`.
  - `DiceThrow.rollerPosition(events: { { [string]: any } }, index: number, players: { { id: string, position: number } }): number`.
  - `DiceThrow.surface(): CFrame`: the board surface centre in world space.

- [ ] **Step 1: Write the failing Layout test**

Append to `src/tests/Layout.spec.luau`, before `return tests`:

```lua
tests["side yaw turns the bottom side onto each side"] = function()
	-- A point on the bottom side's edge (+Z) lands on each side's edge.
	local edge = Vector3.new(0, 0, Layout.BOARD_SIZE / 2)
	local expected = {
		[0] = Vector3.new(0, 0, Layout.BOARD_SIZE / 2),
		[1] = Vector3.new(-Layout.BOARD_SIZE / 2, 0, 0),
		[2] = Vector3.new(0, 0, -Layout.BOARD_SIZE / 2),
		[3] = Vector3.new(Layout.BOARD_SIZE / 2, 0, 0),
	}
	for side, point in expected do
		Expect.vectorNear(CFrame.Angles(0, Layout.sideYaw(side), 0) * edge, point, `side {side}`)
	end
end
```

- [ ] **Step 2: Write the failing DiceThrow tests**

Create `src/tests/DiceThrow.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Expect = require(script.Parent.Expect)

local tests = {}

-- A made-up throw: each die drops along a line and ends at an awkward resting rotation.
local function fakeThrow(): DiceThrow.Throw
	local ends = { CFrame.Angles(0, 0.7, 0) * CFrame.Angles(math.pi / 2, 0, 0), CFrame.Angles(math.pi, 2.1, 0) }
	local throw = {}
	for d = 1, 2 do
		local die = {}
		for i = 0, 4 do
			local t = i / 4
			local position = Vector3.new(d * 5 - 7.5, 2 + 8 * (1 - t), 18 * (1 - t))
			local rotation = CFrame.Angles(3 * (1 - t), 0, 2 * (1 - t)) * ends[d]
			DiceThrow.encode(CFrame.new(position) * rotation, die)
		end
		throw[d] = die
	end
	return throw
end

tests["faceUp reads every face of the model"] = function()
	-- Model layout: 1 = +Y, 2 = +Z, 3 = +X; opposites sum to 7.
	Expect.equal(DiceThrow.faceUp(CFrame.identity), 1)
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(math.pi, 0, 0)), 6)
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(-math.pi / 2, 0, 0)), 2, "+Z turned up")
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(math.pi / 2, 0, 0)), 5, "-Z turned up")
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(0, 0, math.pi / 2)), 3, "+X turned up")
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(0, 0, -math.pi / 2)), 4, "-X turned up")
end

tests["tilt is how far the top face leans from flat"] = function()
	Expect.near(DiceThrow.tilt(CFrame.identity), 0)
	Expect.near(DiceThrow.tilt(CFrame.Angles(math.rad(4), 0, 0)), 4, "a slight lean", 1e-2)
	Expect.near(DiceThrow.tilt(CFrame.Angles(0, 1.3, 0)), 0, "spinning flat is still flat")
end

tests["a frame survives encoding to 3 decimals"] = function()
	local original = CFrame.new(3.21, 4.5, -7.125) * CFrame.Angles(0.4, 2.2, -1.1)
	local packed = {}
	DiceThrow.encode(original, packed)
	Expect.equal(#packed, 7)
	local back = DiceThrow.frame(packed, 1)
	Expect.vectorNear(back.Position, original.Position, "position", 1e-3)
	Expect.vectorNear(back.LookVector, original.LookVector, "look", 5e-3)
	Expect.vectorNear(back.UpVector, original.UpVector, "up", 5e-3)
	Expect.near(back.LookVector.Magnitude, 1, "a clean rotation", 1e-6)
end

tests["the planned dice end showing the rolled numbers, from every side and spin"] = function()
	local throw = fakeThrow()
	local count = DiceThrow.frameCount(throw)
	Expect.equal(count, 5)
	for a = 1, 6 do
		for b = 1, 6 do
			for side = 0, 3 do
				for spin = 0, 3 do
					local plan = DiceThrow.plan(throw, { a, b }, side, { spin, 3 - spin })
					Expect.equal(DiceThrow.faceUp(plan[1][count]), a, `die 1 rolling {a},{b} side {side} spin {spin}`)
					Expect.equal(DiceThrow.faceUp(plan[2][count]), b, `die 2 rolling {a},{b} side {side} spin {spin}`)
				end
			end
		end
	end
end

tests["turning a die to show a number never moves it"] = function()
	local throw = fakeThrow()
	local plan = DiceThrow.plan(throw, { 4, 6 }, 0, { 0, 0 })
	for d = 1, 2 do
		for i = 1, DiceThrow.frameCount(throw) do
			Expect.vectorNear(plan[d][i].Position, DiceThrow.frame(throw[d], i).Position, `die {d} frame {i}`)
		end
	end
end

tests["a throw is turned to come from the roller's side"] = function()
	local throw = fakeThrow()
	for side = 0, 3 do
		local plan = DiceThrow.plan(throw, { 1, 1 }, side, { 0, 0 })
		local turn = CFrame.Angles(0, Layout.sideYaw(side), 0)
		Expect.vectorNear(plan[1][1].Position, turn * DiceThrow.frame(throw[1], 1).Position, `side {side}`)
	end
end

tests["the four spins give four different resting turns"] = function()
	local throw = fakeThrow()
	local count = DiceThrow.frameCount(throw)
	local looks = {}
	for spin = 0, 3 do
		local look = DiceThrow.plan(throw, { 5, 5 }, 0, { spin, spin })[1][count].LookVector
		for _, other in looks do
			Expect.equal((look - other).Magnitude > 0.5, true, `spin {spin} differs`)
		end
		table.insert(looks, look)
	end
end

tests["side follows the board's rows"] = function()
	Expect.equal(DiceThrow.side(0), 0)
	Expect.equal(DiceThrow.side(9), 0)
	Expect.equal(DiceThrow.side(10), 1)
	Expect.equal(DiceThrow.side(25), 2)
	Expect.equal(DiceThrow.side(39), 3)
end

tests["the roller is where they stood before the move"] = function()
	local players = { { id = "p1", position = 12 }, { id = "p2", position = 30 } }
	local events = {
		{ type = "Rolled", player = "p1", dice = { 3, 4 } },
		{ type = "Moved", player = "p1", from = 5, to = 12 },
	}
	Expect.equal(DiceThrow.rollerPosition(events, 1, players), 5, "the move's start")
end

tests["a roll with no move after it is thrown from where the roller is"] = function()
	local players = { { id = "p1", position = 10 }, { id = "p2", position = 28 } }
	local jailRoll = { { type = "Rolled", player = "p1", dice = { 2, 5 } } }
	Expect.equal(DiceThrow.rollerPosition(jailRoll, 1, players), 10, "failed doubles in jail")
	local cardRoll = {
		{ type = "Moved", player = "p2", from = 22, to = 28 },
		{ type = "Rolled", player = "p2", dice = { 6, 1 }, forCard = true },
	}
	Expect.equal(DiceThrow.rollerPosition(cardRoll, 2, players), 28, "a move before the roll doesn't count")
end

tests["the surface is the top of the board centre"] = function()
	Expect.vectorNear(DiceThrow.surface().Position, Layout.ORIGIN.Position + Vector3.new(0, Layout.TILE_THICKNESS / 2, 0))
end

return tests
```

- [ ] **Step 3: Run tests to verify they fail**

Run tests with filter `"DiceThrow"`. Expected: `FAIL DiceThrow.spec (load)`, because the module doesn't exist. Then run with filter `"Layout"`. Expected: the new side-yaw test fails with an error about `sideYaw`.

- [ ] **Step 4: Export the side yaw from `src/shared/Board/Layout.luau`**

Add after the `SIDE_YAW` table:

```lua
-- The turn about Y that carries the bottom side (side 0) onto `side`.
function Layout.sideYaw(side: number): number
	return SIDE_YAW[side % 4 + 1]
end
```

- [ ] **Step 5: Write `src/shared/Dice/DiceThrow.luau`**

```lua
--!strict
-- Turns a recorded physics throw into the frames for a roll. The whole throw is turned to come from
-- the roller's side, and each die is turned inside it so the rolled number ends on top. A cube
-- looks the same whichever way it's turned, so that second turn never shows.

local Layout = require(script.Parent.Parent.Board.Layout)
local Tiles = require(script.Parent.Parent.Board.Tiles)

local DiceThrow = {}

DiceThrow.FPS = 30 -- recorded frames per second
DiceThrow.MAX_SECONDS = 1.6 -- every throw settles within this; Pacing.DICE_SECONDS adds a beat to read it
DiceThrow.MAX_TILT = 5 -- degrees a resting die may lean and still read clearly
DiceThrow.SIZE = 4 -- studs; big enough to read from the overhead camera
DiceThrow.BOUNDS = 20 -- the dice rest within this many studs of the centre on both axes

local STRIDE = 7 -- x, y, z, qx, qy, qz, qw
local TILES_PER_SIDE = Tiles.COUNT // 4

export type Throw = { { number } } -- per die: frames flattened, STRIDE numbers each, thrown from +Z
export type Plan = { { CFrame } } -- per die: a CFrame per frame, relative to the board surface centre

-- The model's face normals: 1 = +Y, 2 = +Z, 3 = +X, opposite faces sum to 7.
local FACE_NORMALS: { [number]: Vector3 } = {
	[1] = Vector3.yAxis,
	[6] = -Vector3.yAxis,
	[2] = Vector3.zAxis,
	[5] = -Vector3.zAxis,
	[3] = Vector3.xAxis,
	[4] = -Vector3.xAxis,
}

-- The 24 turns that carry a cube onto itself, in a fixed order.
local CUBE_TURNS: { CFrame } = {}
do
	local seen = {}
	for x = 0, 3 do
		for y = 0, 3 do
			for z = 0, 3 do
				local turn = CFrame.Angles(x * math.pi / 2, y * math.pi / 2, z * math.pi / 2)
				local r, u = turn.RightVector, turn.UpVector
				local key = `{math.round(r.X)}{math.round(r.Y)}{math.round(r.Z)}{math.round(u.X)}{math.round(u.Y)}{math.round(u.Z)}`
				if not seen[key] then
					seen[key] = true
					table.insert(CUBE_TURNS, turn)
				end
			end
		end
	end
end

local function top(rotation: CFrame): (number, number)
	local best, bestY = 1, -math.huge
	for face, normal in FACE_NORMALS do
		local y = rotation:VectorToWorldSpace(normal).Y
		if y > bestY then
			best, bestY = face, y
		end
	end
	return best, bestY
end

function DiceThrow.faceUp(rotation: CFrame): number
	return (top(rotation))
end

function DiceThrow.tilt(rotation: CFrame): number
	local _, y = top(rotation)
	return math.deg(math.acos(math.clamp(y, -1, 1)))
end

local function round3(value: number): number
	return math.round(value * 1000) / 1000
end

function DiceThrow.encode(cframe: CFrame, into: { number })
	local axis, angle = cframe:ToAxisAngle()
	local s = math.sin(angle / 2)
	local p = cframe.Position
	for _, value in { p.X, p.Y, p.Z, axis.X * s, axis.Y * s, axis.Z * s, math.cos(angle / 2) } do
		table.insert(into, round3(value))
	end
end

function DiceThrow.frameCount(throw: Throw): number
	return #throw[1] // STRIDE
end

function DiceThrow.frame(die: { number }, index: number): CFrame
	local i = (index - 1) * STRIDE
	local qx, qy, qz, qw = die[i + 4], die[i + 5], die[i + 6], die[i + 7]
	-- Rounding leaves the quaternion slightly off unit length; normalise so the rotation stays clean.
	local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
	return CFrame.new(die[i + 1], die[i + 2], die[i + 3], qx / length, qy / length, qz / length, qw / length)
end

-- The turn (about the die's own centre) that puts `value` where the recorded top face was. Four
-- turns do, a quarter turn apart; `spin` picks one so resting dice don't always face the same way.
local function turnFor(final: CFrame, value: number, spin: number): CFrame
	local matches = {}
	for _, turn in CUBE_TURNS do
		if DiceThrow.faceUp(final * turn) == value then
			table.insert(matches, turn)
		end
	end
	return matches[spin % #matches + 1]
end

function DiceThrow.plan(throw: Throw, dice: { number }, side: number, spin: { number }): Plan
	local toSide = CFrame.Angles(0, Layout.sideYaw(side), 0)
	local count = DiceThrow.frameCount(throw)
	local plan: Plan = {}
	for d, die in throw do
		local final = DiceThrow.frame(die, count)
		local turn = turnFor(final.Rotation, dice[d], spin[d])
		local frames = table.create(count)
		for i = 1, count do
			frames[i] = toSide * DiceThrow.frame(die, i) * turn
		end
		plan[d] = frames
	end
	return plan
end

function DiceThrow.side(position: number): number
	return position // TILES_PER_SIDE
end

-- Where the roller stood when they threw: the start of their next move in this update, or, when
-- the roll moves nobody (a failed jail roll, a roll for a card), where they are now.
function DiceThrow.rollerPosition(
	events: { { [string]: any } },
	index: number,
	players: { { id: string, position: number } }
): number
	local roller = events[index].player
	for later = index + 1, #events do
		local event = events[later]
		if event.type == "Moved" and event.player == roller then
			return event.from
		end
	end
	for _, player in players do
		if player.id == roller then
			return player.position
		end
	end
	return 0
end

function DiceThrow.surface(): CFrame
	return Layout.ORIGIN * CFrame.new(0, Layout.TILE_THICKNESS / 2, 0)
end

return DiceThrow
```

- [ ] **Step 6: Run tests to verify they pass**

Run tests with filter `"DiceThrow"`, then `"Layout"`. Expected: all pass. Then run all tests (`""`). Expected: `407 passed, 0 failed` (395 plus 11 DiceThrow tests plus 1 Layout test).

- [ ] **Step 7: Commit**

```bash
git add src/shared/Dice/DiceThrow.luau src/shared/Board/Layout.luau src/tests/DiceThrow.spec.luau src/tests/Layout.spec.luau
git commit -m "feat: DiceThrow turns a recorded throw into a roll from any side showing any numbers"
```

---

### Task 3: Record real throws

**Files:**
- Create: `src/server/DevTools/DiceRecorder.luau`
- Create (generated from the recording): `src/shared/Dice/Throws.luau`
- Modify: `src/server/init.server.luau` (the Studio-only `RecordDice` hook)
- Test: `src/tests/Throws.spec.luau`

**Interfaces:**
- Consumes: `DiceThrow.encode`, `frame`, `frameCount`, `tilt`, `faceUp`, `plan`, `FPS`, `MAX_SECONDS`, `MAX_TILT`, `SIZE`, `BOUNDS` (Task 2).
- Produces: `Throws` is a module returning `{ DiceThrow.Throw }` with at least 20 entries. Task 4 indexes it as `Throws[i]`.

- [ ] **Step 1: Write the failing test**

Create `src/tests/Throws.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Throws = require(ReplicatedStorage.Shared.Dice.Throws)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["there are enough throws to look varied"] = function()
	Expect.equal(#Throws >= 20, true, `only {#Throws} throws`)
end

tests["every throw is two dice that settle in time, flat and inside the centre"] = function()
	for t, throw in Throws do
		Expect.equal(#throw, 2, `throw {t} dice`)
		Expect.equal(#throw[1], #throw[2], `throw {t}: both dice have every frame`)
		Expect.equal(#throw[1] % 7, 0, `throw {t}: whole frames`)
		local count = DiceThrow.frameCount(throw)
		Expect.equal((count - 1) / DiceThrow.FPS <= DiceThrow.MAX_SECONDS + 1e-6, true, `throw {t} lasts {(count - 1) / DiceThrow.FPS} s`)
		for d = 1, 2 do
			local last = DiceThrow.frame(throw[d], count)
			local before = DiceThrow.frame(throw[d], count - 1)
			Expect.equal(DiceThrow.tilt(last.Rotation) <= DiceThrow.MAX_TILT, true, `throw {t} die {d} rests flat`)
			Expect.equal((last.Position - before.Position).Magnitude < 0.05, true, `throw {t} die {d} is at rest`)
			Expect.equal(math.abs(last.Position.X) <= DiceThrow.BOUNDS and math.abs(last.Position.Z) <= DiceThrow.BOUNDS, true, `throw {t} die {d} inside the centre`)
		end
	end
end

tests["every throw can show every roll"] = function()
	for t, throw in Throws do
		local count = DiceThrow.frameCount(throw)
		for a = 1, 6 do
			for b = 1, 6 do
				local plan = DiceThrow.plan(throw, { a, b }, (a + b) % 4, { a % 4, b % 4 })
				Expect.equal(DiceThrow.faceUp(plan[1][count]), a, `throw {t} die 1 for {a},{b}`)
				Expect.equal(DiceThrow.faceUp(plan[2][count]), b, `throw {t} die 2 for {a},{b}`)
			end
		end
	end
end

return tests
```

- [ ] **Step 2: Run it to verify it fails**

Run tests with filter `"Throws"`. Expected: `FAIL Throws.spec (load)`, because `Throws` doesn't exist.

- [ ] **Step 3: Write `src/server/DevTools/DiceRecorder.luau`**

```lua
--!strict
-- Studio only: records real physics dice throws for src/shared/Dice/Throws.luau. Each kept throw
-- lands in ServerStorage.DiceThrows as a StringValue holding its Luau table text, ready to paste
-- into Throws.luau (Studio can't write files). Throws are made from the board's side 0 (+Z)
-- towards -Z, on a floor the size of the board centre, well away from the board itself.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)

local FLOOR_AT = CFrame.new(0, 300, 600) -- far from the board, so nothing else is in the way
local AREA = 54 -- the centre area inside the corner tiles
local SETTLE_SPEED = 0.05 -- studs (or radians) per second that counts as still
local STILL_SECONDS = 0.2 -- both dice still this long ends a throw
local GIVE_UP_SECONDS = 4

local DiceRecorder = {}

local function makeDie(name: string, parent: Instance): Part
	local die = Instance.new("Part")
	die.Name = name
	die.Size = Vector3.one * DiceThrow.SIZE
	die.CustomPhysicalProperties = PhysicalProperties.new(1.6, 0.4, 0.25) -- density, friction, elasticity
	die.Anchored = true
	die.Parent = parent
	return die
end

local function serialise(throw: DiceThrow.Throw): string
	local lines = { "\t{" }
	for _, die in throw do
		local numbers = table.create(#die)
		for i, value in die do
			numbers[i] = tostring(value)
		end
		table.insert(lines, "\t\t{ " .. table.concat(numbers, ", ") .. " },")
	end
	table.insert(lines, "\t},")
	return table.concat(lines, "\n")
end

-- One throw; returns its frames, or nil and why it was rejected.
local function throwOnce(surface: CFrame, dice: { Part }, random: Random): (DiceThrow.Throw?, string?)
	local startX = random:NextNumber(-10, 10)
	local push = Vector3.new(random:NextNumber(-6, 6), random:NextNumber(0, 5), -random:NextNumber(26, 38))
	for i, die in dice do
		local start = Vector3.new(startX + (if i == 1 then -2.6 else 2.6), random:NextNumber(6, 9), 24)
		local tumble = CFrame.Angles(random:NextNumber(0, 2 * math.pi), random:NextNumber(0, 2 * math.pi), random:NextNumber(0, 2 * math.pi))
		die.CFrame = surface * CFrame.new(start) * tumble
		die.Anchored = false
		die:SetNetworkOwner(nil)
		die.AssemblyLinearVelocity = surface:VectorToWorldSpace(push + Vector3.new(random:NextNumber(-2, 2), 0, random:NextNumber(-3, 3)))
		die.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-25, 25), random:NextNumber(-25, 25), random:NextNumber(-25, 25))
	end

	local throw: DiceThrow.Throw = { {}, {} }
	local elapsed, nextSample, stillFor = 0, 0, 0
	while stillFor < STILL_SECONDS and elapsed < GIVE_UP_SECONDS do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		while elapsed >= nextSample do
			for i, die in dice do
				DiceThrow.encode(surface:ToObjectSpace(die.CFrame), throw[i])
			end
			nextSample += 1 / DiceThrow.FPS
		end
		local moving = false
		for _, die in dice do
			if die.AssemblyLinearVelocity.Magnitude > SETTLE_SPEED or die.AssemblyAngularVelocity.Magnitude > SETTLE_SPEED then
				moving = true
			end
		end
		stillFor = if moving then 0 else stillFor + dt
	end
	for _, die in dice do
		die.Anchored = true
	end
	if stillFor < STILL_SECONDS then
		return nil, "never settled"
	end

	-- Keep frames up to the moment both dice went still, plus one to show them at rest.
	local count = math.min(DiceThrow.frameCount(throw), math.floor((elapsed - stillFor) * DiceThrow.FPS) + 2)
	if (count - 1) / DiceThrow.FPS > DiceThrow.MAX_SECONDS then
		return nil, "too slow"
	end
	for i = 1, 2 do
		throw[i] = table.move(throw[i], 1, count * 7, 1, {})
		local last = DiceThrow.frame(throw[i], count)
		if DiceThrow.tilt(last.Rotation) > DiceThrow.MAX_TILT then
			return nil, "cocked"
		end
		if math.abs(last.Position.X) > DiceThrow.BOUNDS or math.abs(last.Position.Z) > DiceThrow.BOUNDS then
			return nil, "out of bounds"
		end
	end
	return throw, nil
end

-- Records until `wanted` throws are kept. Progress goes to the workspace attribute RecordDiceStatus.
function DiceRecorder.record(wanted: number)
	assert(RunService:IsStudio(), "the dice recorder is a Studio tool")
	local stage = Instance.new("Model")
	stage.Name = "DiceRecorderStage"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(AREA, 1, AREA)
	floor.CFrame = FLOOR_AT
	floor.Anchored = true
	floor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.5, 0.2)
	floor.Parent = stage
	stage.Parent = workspace
	local surface = FLOOR_AT * CFrame.new(0, 0.5, 0)
	local dice = { makeDie("DieA", stage), makeDie("DieB", stage) }

	local out = ServerStorage:FindFirstChild("DiceThrows")
	if out then
		out:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "DiceThrows"
	folder.Parent = ServerStorage

	local random = Random.new()
	local kept, tried = 0, 0
	local reasons: { [string]: number } = {}
	while kept < wanted and tried < wanted * 10 do
		tried += 1
		local throw, why = throwOnce(surface, dice, random)
		if throw then
			kept += 1
			local value = Instance.new("StringValue")
			value.Name = string.format("Throw%02d", kept)
			value.Value = serialise(throw)
			value.Parent = folder
		elseif why then
			reasons[why] = (reasons[why] or 0) + 1
		end
		local summary = {}
		for reason, n in reasons do
			table.insert(summary, `{reason} {n}`)
		end
		workspace:SetAttribute("RecordDiceStatus", `kept {kept}/{tried}; rejected: {table.concat(summary, ", ")}`)
	end
	stage:Destroy()
end

return DiceRecorder
```

- [ ] **Step 4: Add the hook to `src/server/init.server.luau`**

Inside the existing `if RunService:IsStudio() then` block, after the `RunTests` connection, add:

```lua
	-- Studio only: setting RecordDice to a count records that many physics throws (see DiceRecorder).
	workspace:GetAttributeChangedSignal("RecordDice"):Connect(function()
		local wanted = workspace:GetAttribute("RecordDice")
		if typeof(wanted) ~= "number" then
			return
		end
		workspace:SetAttribute("RecordDice", nil)
		local recorder = require(script.DevTools.DiceRecorder) :: any
		task.spawn(recorder.record, wanted)
	end)
```

- [ ] **Step 5: Record**

Check that the recorder's source reached Studio (Edit datamodel: `game.ServerScriptService.Server.DevTools.DiceRecorder.Source`), then start a playtest. In the **Server** datamodel: `workspace:SetAttribute("RecordDice", 30)`. Poll `return workspace:GetAttribute("RecordDiceStatus")` until it reads `kept 30/...`.

Tuning: if more than half the tries are rejected, adjust the ranges in `throwOnce` and record again.
- **"out of bounds" dominates:** lower the push (for example `-random:NextNumber(20, 30)`) or raise the floor friction.
- **"too slow" dominates:** raise density or friction, or lower elasticity.
- **"cocked" is common:** lower elasticity.

Don't stop the playtest until Step 6 has read the data out. Recorded values live only in the running session.

- [ ] **Step 6: Generate `src/shared/Dice/Throws.luau`**

Still in the playtest, in the **Server** datamodel, read the throws in batches of 10:

```lua
local folder = game:GetService("ServerStorage").DiceThrows
local parts = {}
for i = 1, 10 do -- then 11-20, then 21-30
	local value = folder:FindFirstChild(string.format("Throw%02d", i))
	if value then table.insert(parts, value.Value) end
end
return table.concat(parts, "\n")
```

Write `src/shared/Dice/Throws.luau` with this wrapper, pasting the three batches in order where marked:

```lua
--!strict
-- Generated by src/server/DevTools/DiceRecorder.luau (Studio, RecordDice attribute). Do not edit:
-- re-record instead. Each throw is two dice; each die's frames are flattened as x, y, z, qx, qy,
-- qz, qw at DiceThrow.FPS, relative to the centre of the board's surface, thrown from the +Z side.

local DiceThrow = require(script.Parent.DiceThrow)

local Throws: { DiceThrow.Throw } = {
<the 30 serialised throws>
}

return Throws
```

Stop the playtest.

- [ ] **Step 7: Run tests to verify they pass**

Start a playtest and run tests with filter `"Throws"`. Expected: all 3 pass. Then run all tests (`""`). Expected: `410 passed, 0 failed`. Stop the playtest.

- [ ] **Step 8: Commit**

```bash
git add src/server/DevTools/DiceRecorder.luau src/server/init.server.luau src/shared/Dice/Throws.luau src/tests/Throws.spec.luau
git commit -m "feat: record real physics dice throws in Studio; 30 recorded throws"
```

---

### Task 4: Show the 3D dice on every roll

**Files:**
- Create: `src/client/DiceView.luau`
- Modify: `src/shared/Rules/Pacing.luau:9` (`DICE_SECONDS`), plus a new `DICE_READ_SECONDS`
- Modify: `src/client/Hud/HudView.luau` (new `showRoll`, next to `rollDice` at ~line 307)
- Modify: `src/client/GameClient.luau` (create the view, roll it on `Rolled`, clear it in `show`)
- Test: `src/tests/HudView.spec.luau`, `src/tests/Pacing.spec.luau`

**Interfaces:**
- Consumes: `DiceThrow.plan`, `frameCount`, `rollerPosition`, `side`, `surface`, `FPS`, `SIZE` (Task 2); `Throws` (Task 3); `ReplicatedStorage.Assets.Dice.Rounded` (Task 1).
- Produces:
  - `DiceView.new(parent: Instance): DiceView`, `DiceView:ready(): boolean`, `DiceView:roll(dice: { number }, side: number)`, `DiceView:clear()`.
  - `Pacing.DICE_SECONDS = 2`, `Pacing.DICE_READ_SECONDS = 0.4`.
  - `HudView:showRoll(dice: { number })`.

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/Pacing.spec.luau`, before `return tests`:

```lua
tests["the dice get time to tumble and then be read"] = function()
	Expect.near(Pacing.DICE_SECONDS, 2)
	Expect.near(Pacing.DICE_READ_SECONDS, 0.4)
	Expect.equal(Pacing.DICE_SECONDS - Pacing.DICE_READ_SECONDS >= 1.6, true, "every recorded throw settles before the read")
end
```

In `src/tests/HudView.spec.luau`, add after the test `"a roll shows on the dice before the snapshot that carries it"`:

```lua
tests["a roll the 3D dice are showing skips the stage dice and reads out once they settle"] = function()
	withHud(function(hud)
		hud:render(Snapshot.fromState(GameFixtures.newGame(2)), "p1")
		hud:showRoll({ 3, 5 })
		Expect.equal(hud.stageDice.frame.Visible, false, "the 3D dice take the stage")
		Expect.equal(hud.actionBar.dice.frame.Visible, false, "the readout waits for the dice to settle")
		task.wait(Pacing.DICE_SECONDS - Pacing.DICE_READ_SECONDS + 0.1)
		Expect.equal(hud.actionBar.dice.frame.Visible, true, "then the action bar shows the roll")
	end)
end
```

and add this require near the top of `HudView.spec.luau`, with the other requires:

```lua
local Pacing = require(game:GetService("ReplicatedStorage").Shared.Rules.Pacing)
```

- [ ] **Step 2: Run them to verify they fail**

Run tests with filter `"Pacing"`, then `"HudView"`. Expected: the new Pacing test fails (`expected ~2, got 1`). The new HudView test fails with an error about `showRoll`.

- [ ] **Step 3: Update `src/shared/Rules/Pacing.luau`**

Replace line 9:

```lua
Pacing.DICE_SECONDS = 2 -- the 3D dice tumble (at most 1.6 s, see DiceThrow) and are read before the token sets off
Pacing.DICE_READ_SECONDS = 0.4 -- the end of DICE_SECONDS, when the dice lie still to be read
```

In `src/client/Hud/Views/Dice.luau:12`, update the comment, which still says the dice take about 1 s:

```lua
local TUMBLE_STEPS = 10 -- ~0.7 s: settles well before the token sets off (Pacing.DICE_SECONDS)
```

- [ ] **Step 4: Add `showRoll` to `src/client/Hud/HudView.luau`**

After `HudView.rollDice`:

```lua
-- A roll the 3D dice are showing on the board: no stage dice, and the action bar reads it out
-- once the dice have settled.
function HudView.showRoll(self: HudView, dice: { number })
	self.rollGeneration += 1
	local generation = self.rollGeneration
	self.stageDice:show(nil, false)
	task.delay(Pacing.DICE_SECONDS - Pacing.DICE_READ_SECONDS, function()
		if self.rollGeneration == generation and self.gui.Parent then
			self.actionBar.dice:show(dice, false)
		end
	end)
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run tests with filter `"Pacing"`, then `"HudView"`. Expected: all pass.

- [ ] **Step 6: Write `src/client/DiceView.luau`**

```lua
--!strict
-- The 3D dice. Each roll plays a recorded physics throw (DiceThrow, Throws) on the board centre,
-- and the dice stay where they landed until the next roll. Not ready until the server has loaded
-- the die model; until then GameClient uses the 2D stage dice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Throws = require(ReplicatedStorage.Shared.Dice.Throws)

local BODY_COLOR = Color3.fromRGB(240, 234, 220) -- ivory
local PIP_COLOR = Color3.fromRGB(22, 22, 26)
local MODEL_SIZE = 1.2 -- studs, the Rounded die as uploaded
local WAIT_SECONDS = 30 -- for the server to load the model

local DiceView = {}
DiceView.__index = DiceView

export type DiceView = typeof(setmetatable(
	{} :: {
		parent: Instance,
		folder: Folder,
		dice: { Model },
		random: Random,
		playing: RBXScriptConnection?,
	},
	DiceView
))

local function build(template: Model): Model
	local die = template:Clone()
	local body = die:FindFirstChild("Body") :: BasePart
	local pips = die:FindFirstChild("Pips") :: BasePart
	die.PrimaryPart = body
	die.WorldPivot = body.CFrame -- frames place the die by its centre
	die:ScaleTo(DiceThrow.SIZE / MODEL_SIZE)
	for _, part in die:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	body.Color = BODY_COLOR
	body.Material = Enum.Material.SmoothPlastic
	pips.Color = PIP_COLOR
	pips.Material = Enum.Material.SmoothPlastic
	return die
end

function DiceView.new(parent: Instance): DiceView
	local folder = Instance.new("Folder")
	folder.Name = "Dice"
	local self = setmetatable({ parent = parent, folder = folder, dice = {}, random = Random.new(), playing = nil }, DiceView)
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", WAIT_SECONDS)
		local kind = assets and assets:WaitForChild("Dice", WAIT_SECONDS)
		local template = kind and kind:WaitForChild("Rounded", WAIT_SECONDS)
		if template and template:IsA("Model") and #Throws > 0 then
			self.dice = { build(template), build(template) }
			for _, die in self.dice do
				die.Parent = folder
			end
		end
	end)
	return self
end

function DiceView.ready(self: DiceView): boolean
	return #self.dice == 2
end

local function stop(self: DiceView)
	if self.playing then
		self.playing:Disconnect()
		self.playing = nil
	end
end

-- Throws the dice from the roller's side (0-3) so they land showing `dice`.
function DiceView.roll(self: DiceView, dice: { number }, side: number)
	stop(self)
	local throw = Throws[self.random:NextInteger(1, #Throws)]
	local spin = { self.random:NextInteger(0, 3), self.random:NextInteger(0, 3) }
	local plan = DiceThrow.plan(throw, dice, side, spin)
	local count = DiceThrow.frameCount(throw)
	local surface = DiceThrow.surface()
	local started = os.clock()

	-- Places the dice `elapsed` seconds into the throw, blending between recorded frames.
	local function place(elapsed: number)
		local at = math.clamp(elapsed * DiceThrow.FPS + 1, 1, count)
		local index = math.floor(at)
		local alpha = at - index
		local nextIndex = math.min(index + 1, count)
		for d, die in self.dice do
			die:PivotTo(surface * plan[d][index]:Lerp(plan[d][nextIndex], alpha))
		end
	end

	place(0)
	self.folder.Parent = self.parent
	self.playing = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		place(elapsed)
		if elapsed * DiceThrow.FPS + 1 >= count then
			stop(self) -- resting: leave them where they landed
		end
	end)
end

-- Takes the dice off the board (game over, back to the lobby).
function DiceView.clear(self: DiceView)
	stop(self)
	self.folder.Parent = nil
end

return DiceView
```

- [ ] **Step 7: Hook it into `src/client/GameClient.luau`**

Add requires, in alphabetical order with the others:

```lua
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
```

```lua
local DiceView = require(script.Parent.DiceView)
```

After `local markers = OwnerMarkers.new(workspace)`:

```lua
	local diceView = DiceView.new(workspace)
```

In `show`, as its first line:

```lua
		if not snapshot or snapshot.phase == "GameOver" then
			diceView:clear() -- nothing left to roll for
		end
```

Change the playback loop `for _, item in timeline.items do` (the one that calls `hud:rollDice`) to `for index, item in timeline.items do`, and replace

```lua
					if event.type == "Rolled" then
						hud:rollDice(event.dice)
					end
```

with

```lua
					if event.type == "Rolled" then
						if diceView:ready() then
							local players = if snapshot then snapshot.players else {}
							local position = DiceThrow.rollerPosition(update.events, index, players)
							diceView:roll(event.dice, DiceThrow.side(position))
							hud:showRoll(event.dice)
						else
							hud:rollDice(event.dice) -- no model yet: the 2D dice take the stage
						end
					end
```

(`timeline.items` has one item per event, in the same order, so `index` is the event's index in `update.events`.)

- [ ] **Step 8: Run all tests**

Check that `GameClient`, `DiceView`, `HudView` and `Pacing` all reached Studio, then run all tests (`""`). Expected: `412 passed, 0 failed`.

- [ ] **Step 9: Commit**

```bash
git add src/client/DiceView.luau src/client/GameClient.luau src/client/Hud/HudView.luau src/client/Hud/Views/Dice.luau src/shared/Rules/Pacing.luau src/tests/HudView.spec.luau src/tests/Pacing.spec.luau
git commit -m "feat: every roll throws two 3D dice onto the board centre"
```

---

### Task 5: Playtest

**Files:** none, unless fixes are needed. Commit any fix with the playtest finding in its message.

`screen_capture` only works in Edit mode and is too slow for motion, so check through numbers in the **Client** datamodel and use screenshots for the settled result.

- [ ] **Step 1: A normal roll.** Start a playtest, start a game with a bot (lobby buttons via `user_mouse_input`), and click "Roll dice". In the Client datamodel, sample `workspace.Dice` children's `GetPivot().Position` every 0.1 s for 2.5 s. Expected: the dice start high near the roller's edge of the centre, come down and travel across, and are still from about 1.6 s. They rest within 20 studs of the centre.
- [ ] **Step 2: The faces match.** After the roll settles, compare the top faces with the snapshot's `lastRoll`. Run this in the Client datamodel; it computes the top face inline, since `execute_luau` can't require modules:

```lua
local normals = { [1] = Vector3.yAxis, [6] = -Vector3.yAxis, [2] = Vector3.zAxis, [5] = -Vector3.zAxis, [3] = Vector3.xAxis, [4] = -Vector3.xAxis }
local out = {}
for _, die in workspace.Dice:GetChildren() do
	local r, best, bestY = die:GetPivot(), 0, -2
	for face, n in normals do local y = r:VectorToWorldSpace(n).Y; if y > bestY then best, bestY = face, y end end
	table.insert(out, best)
end
return table.concat(out, ",")
```

Check the result against the log line "… rolled a + b". Repeat for 3 rolls.
- [ ] **Step 3: Every side.** Keep playing until rolls have been thrown from all four board sides. Each time, confirm (from the sampled start position) that the dice start on the roller's side: side 0 +Z, 1 −X, 2 −Z, 3 +X.
- [ ] **Step 4: Doubles, jail and the card roll.** Set the Studio attribute `StartingMoney` high so the game lasts, and play until a doubles roll (the second roll replaces the first pair cleanly), a jail roll, and ideally a utility-card roll have happened. Confirm that `workspace.Dice` never holds more than 2 children.
- [ ] **Step 5: Game over clears them.** Edit datamodel: `workspace:SetAttribute("RoundLimit", 1)`. Play to game over and confirm `workspace:FindFirstChild("Dice")` is nil. Remove the attribute afterwards.
- [ ] **Step 6: The fallback.** Edit datamodel: `workspace:SetAttribute("NoModels", true)`. Playtest one roll. Expected: the 2D stage dice play, `workspace:FindFirstChild("Dice")` is nil on the client, and no errors appear in the output (`get_console_output`). Remove the attribute afterwards.
- [ ] **Step 7: Screenshots.** During a playtest, after a roll settles, copy both dice's `GetPivot()` components and `workspace.CurrentCamera.CFrame` from the Client datamodel. Stop the playtest. In the Edit datamodel, load the die with `InsertService:LoadAsset(73288478231290)`, build two copies the way `DiceView` does (scale 10/3, ivory and black), pivot them to the copied poses, and `screen_capture` from the copied camera position, looking at the board centre. Show the user, then delete the copies.
- [ ] **Step 8: Final run.** Run all tests (`""`). Expected: `412 passed, 0 failed`. Commit any fixes made during the playtest.
