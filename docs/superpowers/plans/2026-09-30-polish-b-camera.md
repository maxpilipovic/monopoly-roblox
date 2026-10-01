# Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A closer overhead view, and a camera that swoops behind every moving token, follows it hop by hop, holds on the landing tile for a second, then eases back to the overhead view.

**Architecture:** Camera math stays pure in `BoardCamera` (overhead fit, heading between tiles, chase framing). A new `CameraDirector` owns the camera: its state machine is a pure `CameraDirector.next(state, event, now)`, and a thin runtime feeds it `RenderStepped` ticks plus token events. `Tokens` reports moves through optional hooks; `GameClient` wires them to the director.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Rojo 7.7, tests run inside Studio.

**Spec:** `docs/superpowers/specs/2026-09-30-polish-design.md`, section B.

## Global Constraints

- Every module starts with `--!strict`; tabs; short comments that say why; match the surrounding module patterns.
- All existing tests keep passing (293 plus whatever plan A added).
- Hold on the landing tile: 1 second. Return to overhead: 0.8 seconds. `ToJail` moves never chase.
- Every token's move chases (human and bot); no setting.
- Field of view is pinned to 70.
- Tests run in Studio, not a shell (stop playtest → start playtest → assert the edited script's `.Source` has a new line → `require(game.ServerStorage.Tests.TestRunner).run("<Spec>")` on the **Server** datamodel). Never `git checkout`/`git switch` to a branch with different files while Rojo is connected.

## Ruling against the spec (record in the ledger at Task 1)

The spec says "zoom in about 15% (`OVERHEAD_ZOOM = 0.85`)". The old fit wraps the board in a sphere, which is what made it small (followup: "camera fit conservative (sphere) — board small on phones"). Fitting the board's four corners exactly gets the board closer on every screen *and* keeps it fully visible, which a flat 0.85 factor can't promise on portrait phones. This plan fits the corners with a 4% margin; Task 1 checks it ends up at least 10% closer than the sphere fit at 16:9.

## Review Focus

1. Two moves in one update (a card sends the token on after it lands, or doubles then a bot's turn): the camera follows the newest moving token and never gets stuck in `Holding` on a token that's no longer moving. (Task 2 test "a new move during the hold or the return follows the new token".)
2. A token destroyed mid-move (back to the lobby) leaves the camera following nothing: it must return to overhead, not error on a destroyed part. (Task 2 test "a destroyed token sends the camera home".)
3. Portrait phone (9:16): the overhead view still shows all four corners. (Task 1 test.)
4. Corner hops (9 → 10, 19 → 20, …): the chase heading turns with the board instead of pointing off it. (Task 1 test.)
5. The default camera scripts or a FieldOfView change never leave the camera unscripted or at a different FOV. (Task 3 playtest step.)

---

### Task 1: BoardCamera — tighter overhead fit, heading, chase framing

**Files:**
- Modify: `src/client/BoardCamera.luau` (pure functions only in this task; `start` moves to the director in Task 3)
- Test: `src/tests/BoardCamera.spec.luau`

**Interfaces:**
- Produces (used by Tasks 2–3):
  - `BoardCamera.FIELD_OF_VIEW = 70`
  - `BoardCamera.getOverheadCFrame(focus: Vector3, boardSize: number, fieldOfViewDegrees: number, aspect: number): CFrame` — same signature, now fits the corners.
  - `BoardCamera.tileCentre(position: number): Vector3` — top centre of a tile in world space.
  - `BoardCamera.heading(fromPosition: number, toPosition: number): Vector3` — flat unit direction of travel.
  - `BoardCamera.chaseCFrame(target: Vector3, heading: Vector3): CFrame` — behind and above `target`, looking ahead of it.
  - `BoardCamera.CHASE_BACK = 12`, `BoardCamera.CHASE_UP = 9`, `BoardCamera.CHASE_AHEAD = 6`.

- [ ] **Step 1: Write the failing tests** — append to `src/tests/BoardCamera.spec.luau` before `return tests` (keep the existing tests; "whole board fits inside the view" must still pass):

```lua
local function sphereDistance(boardSize: number, fov: number, aspect: number): number
	local radius = boardSize / 2 * math.sqrt(2)
	local halfV = math.rad(fov) / 2
	local halfH = math.atan(math.tan(halfV) * aspect)
	return radius / math.sin(math.min(halfV, halfH))
end

tests["the overhead view is at least 10% closer than the old sphere fit"] = function()
	for _, aspect in { 16 / 9, 9 / 16 } do
		local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, aspect)
		local distance = (cf.Position - FOCUS).Magnitude
		assert(distance <= 0.9 * sphereDistance(74, 70, aspect), `aspect {aspect}: {distance} not closer`)
	end
end

tests["heading points along the board and turns at corners"] = function()
	local function flat(v: Vector3)
		Expect.near(v.Y, 0, "flat")
		Expect.near(v.Magnitude, 1, "unit")
	end
	local first = BoardCamera.heading(1, 2) -- bottom side runs toward -X
	flat(first)
	Expect.vectorNear(first, Vector3.new(-1, 0, 0), "bottom side")
	local left = BoardCamera.heading(11, 12) -- left side runs toward -Z
	flat(left)
	Expect.vectorNear(left, Vector3.new(0, 0, -1), "left side")
	local corner = BoardCamera.heading(10, 11) -- leaving the Jail corner up the left side
	Expect.vectorNear(corner, Vector3.new(0, 0, -1), "turns at the corner")
	local wrap = BoardCamera.heading(39, 0) -- right side into Go runs toward +Z
	Expect.vectorNear(wrap, Vector3.new(0, 0, 1), "wraps past Go")
end

tests["the chase camera sits behind and above the token, looking ahead of it"] = function()
	local target = BoardCamera.tileCentre(3)
	local heading = BoardCamera.heading(3, 4)
	local cf = BoardCamera.chaseCFrame(target, heading)
	local offset = cf.Position - target
	Expect.near(offset.Y, BoardCamera.CHASE_UP, "height")
	Expect.near(offset:Dot(heading), -BoardCamera.CHASE_BACK, "behind")
	local lookAt = target + heading * BoardCamera.CHASE_AHEAD
	Expect.vectorNear(cf.LookVector, (lookAt - cf.Position).Unit, "looks ahead")
	local inView = cf:PointToObjectSpace(target)
	assert(inView.Z < 0, "token is in front of the camera")
end
```

- [ ] **Step 2: Run to verify they fail**

Run: `.run("BoardCamera")`
Expected: 3 failures — "not closer" for the first, `attempt to call a nil value` for the other two.

- [ ] **Step 3: Implement** — replace `getOverheadCFrame` and add the new functions in `src/client/BoardCamera.luau` (leave `start` as it is for now):

```lua
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local BoardCamera = {}

BoardCamera.PITCH = math.rad(60)
BoardCamera.FIELD_OF_VIEW = 70
BoardCamera.CHASE_BACK = 12
BoardCamera.CHASE_UP = 9
BoardCamera.CHASE_AHEAD = 6
local FIT_MARGIN = 1.04 -- a sliver of space around the board's corners

-- Whether every board corner is inside the view from `distance` away.
local function cornersFit(focus: Vector3, boardSize: number, tanV: number, tanH: number, distance: number): boolean
	local offset = Vector3.new(0, math.sin(BoardCamera.PITCH), math.cos(BoardCamera.PITCH)) * distance
	local cf = CFrame.lookAt(focus + offset, focus)
	local half = boardSize / 2
	for _, corner in { Vector3.new(half, 0, half), Vector3.new(-half, 0, half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, -half) } do
		local p = cf:PointToObjectSpace(focus + corner)
		local depth = -p.Z
		if depth <= 0 or math.abs(p.X) > depth * tanH or math.abs(p.Y) > depth * tanV then
			return false
		end
	end
	return true
end

-- The overhead view: as close as possible while every corner of the board stays on screen.
function BoardCamera.getOverheadCFrame(focus: Vector3, boardSize: number, fieldOfViewDegrees: number, aspect: number): CFrame
	local tanV = math.tan(math.rad(fieldOfViewDegrees) / 2)
	local tanH = tanV * aspect
	-- Binary search the distance; the far end (the old bounding-sphere fit) always fits.
	local near, far = 0, boardSize / 2 * math.sqrt(2) / math.sin(math.min(math.atan(tanV), math.atan(tanH)))
	for _ = 1, 30 do
		local middle = (near + far) / 2
		if cornersFit(focus, boardSize, tanV, tanH, middle) then
			far = middle
		else
			near = middle
		end
	end
	local offset = Vector3.new(0, math.sin(BoardCamera.PITCH), math.cos(BoardCamera.PITCH)) * far * FIT_MARGIN
	return CFrame.lookAt(focus + offset, focus)
end

-- Top centre of a tile in world space.
function BoardCamera.tileCentre(position: number): Vector3
	local placement = Layout.getTilePlacement(position)
	return (Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)).Position
end

-- Flat direction of travel from one tile to the next (turns at corners because tile centres do).
function BoardCamera.heading(fromPosition: number, toPosition: number): Vector3
	local delta = BoardCamera.tileCentre(toPosition % Tiles.COUNT) - BoardCamera.tileCentre(fromPosition % Tiles.COUNT)
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(-1, 0, 0)
end

-- Low behind-the-token view: CHASE_BACK behind, CHASE_UP above, looking CHASE_AHEAD past it.
function BoardCamera.chaseCFrame(target: Vector3, heading: Vector3): CFrame
	local position = target - heading * BoardCamera.CHASE_BACK + Vector3.new(0, BoardCamera.CHASE_UP, 0)
	return CFrame.lookAt(position, target + heading * BoardCamera.CHASE_AHEAD)
end
```

Note on the "turns at corners" test: the Jail corner's centre and tile 11's centre share the same X (both sit on the left side's centre line, `Layout.getTilePlacement`), so `heading(10, 11)` is exactly `(0, 0, -1)`.

- [ ] **Step 4: Run to verify they pass**

Run: `.run("BoardCamera")` then `.run()`
Expected: all BoardCamera tests pass (including the existing "whole board fits inside the view"); full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/client/BoardCamera.luau src/tests/BoardCamera.spec.luau
git commit -m "feat: overhead camera fits the board's corners; heading and chase framing helpers"
```

---

### Task 2: CameraDirector — the state machine

**Files:**
- Create: `src/client/CameraDirector.luau` (pure part only in this task: types, `initial`, `next`, `target`)
- Test: `src/tests/CameraDirector.spec.luau`

**Interfaces:**
- Consumes: `BoardCamera.heading`, `BoardCamera.chaseCFrame` (Task 1).
- Produces (used by Task 3):
  - `export type Mode = "Overhead" | "Following" | "Holding" | "Returning"`
  - `export type State = { mode: Mode, part: BasePart?, heading: Vector3, since: number, from: CFrame? }`
  - `export type Event = { kind: "MoveStarted", part: BasePart, style: string? } | { kind: "Hopped", part: BasePart, from: number, to: number } | { kind: "MoveFinished", part: BasePart } | { kind: "Tick", camera: CFrame }`
  - `CameraDirector.HOLD_SECONDS = 1`, `CameraDirector.RETURN_SECONDS = 0.8`
  - `CameraDirector.initial(): State`
  - `CameraDirector.next(state: State, event: Event, now: number): State`
  - `CameraDirector.target(state: State, now: number, overhead: CFrame): CFrame` — where the camera should be.

- [ ] **Step 1: Write the failing tests** — create `src/tests/CameraDirector.spec.luau`:

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local CameraDirector = require(StarterPlayer.StarterPlayerScripts.Client.CameraDirector)
local Expect = require(script.Parent.Expect)

local tests = {}

local OVERHEAD = CFrame.new(0, 80, 40)

local function token(): BasePart
	local part = Instance.new("Part")
	part.Parent = workspace -- parented: the director treats an unparented part as destroyed
	return part
end

local function tick(state, now: number)
	return CameraDirector.next(state, { kind = "Tick", camera = CFrame.new(1, 2, 3) }, now)
end

tests["a move is followed, held, then the camera returns overhead"] = function()
	local part = token()
	local state = CameraDirector.initial()
	Expect.equal(state.mode, "Overhead")
	state = CameraDirector.next(state, { kind = "MoveStarted", part = part, style = nil }, 0)
	Expect.equal(state.mode, "Following")
	state = CameraDirector.next(state, { kind = "Hopped", part = part, from = 1, to = 2 }, 0.2)
	Expect.vectorNear(state.heading, Vector3.new(-1, 0, 0), "heading from the hop")
	state = CameraDirector.next(state, { kind = "MoveFinished", part = part }, 1)
	Expect.equal(state.mode, "Holding")
	state = tick(state, 1.9)
	Expect.equal(state.mode, "Holding", "still holding before 1 s")
	state = tick(state, 2.0)
	Expect.equal(state.mode, "Returning")
	Expect.vectorNear((state.from :: CFrame).Position, Vector3.new(1, 2, 3), "returns from where the camera was")
	state = tick(state, 2.7)
	Expect.equal(state.mode, "Returning", "still returning before 0.8 s")
	state = tick(state, 2.8)
	Expect.equal(state.mode, "Overhead")
	part:Destroy()
end

tests["a new move during the hold or the return follows the new token"] = function()
	local a, b = token(), token()
	local state = CameraDirector.next(CameraDirector.initial(), { kind = "MoveStarted", part = a }, 0)
	state = CameraDirector.next(state, { kind = "MoveFinished", part = a }, 1)
	state = CameraDirector.next(state, { kind = "MoveStarted", part = b }, 1.5)
	Expect.equal(state.mode, "Following", "from the hold")
	Expect.equal(state.part, b)
	state = CameraDirector.next(state, { kind = "MoveFinished", part = a }, 1.6)
	Expect.equal(state.mode, "Following", "another token finishing doesn't stop the follow")
	state = CameraDirector.next(state, { kind = "MoveFinished", part = b }, 2)
	state = tick(state, 3)
	Expect.equal(state.mode, "Returning")
	state = CameraDirector.next(state, { kind = "MoveStarted", part = a }, 3.2)
	Expect.equal(state.mode, "Following", "from the return")
	Expect.equal(state.part, a)
	a:Destroy()
	b:Destroy()
end

tests["a jump to jail never takes the camera off the overhead view"] = function()
	local part = token()
	local state = CameraDirector.next(CameraDirector.initial(), { kind = "MoveStarted", part = part, style = "ToJail" }, 0)
	Expect.equal(state.mode, "Overhead")
	part:Destroy()
end

tests["a destroyed token sends the camera home"] = function()
	local part = token()
	local state = CameraDirector.next(CameraDirector.initial(), { kind = "MoveStarted", part = part }, 0)
	part:Destroy()
	state = tick(state, 0.1)
	Expect.equal(state.mode, "Returning")
end

tests["the target is the chase view while following and the overhead view at rest"] = function()
	local part = token()
	part.Position = Vector3.new(10, 1, 30)
	local state = CameraDirector.initial()
	Expect.equal(CameraDirector.target(state, 0, OVERHEAD), OVERHEAD, "overhead")
	state = CameraDirector.next(state, { kind = "MoveStarted", part = part }, 0)
	local chase = CameraDirector.target(state, 0, OVERHEAD)
	assert((chase.Position - part.Position).Magnitude < (OVERHEAD.Position - part.Position).Magnitude, "chase is close")
	state = CameraDirector.next(state, { kind = "MoveFinished", part = part }, 0)
	state = tick(state, 1)
	local halfway = CameraDirector.target(state, 1 + CameraDirector.RETURN_SECONDS / 2, OVERHEAD)
	local start = (state.from :: CFrame).Position
	local between = (halfway.Position - start).Magnitude
	assert(between > 0 and between < (OVERHEAD.Position - start).Magnitude, "halfway back")
	part:Destroy()
end

return tests
```

- [ ] **Step 2: Run to verify they fail**

Run: `.run("CameraDirector")`
Expected: `FAIL CameraDirector.spec (load): …` (module missing).

- [ ] **Step 3: Implement** — create `src/client/CameraDirector.luau`:

```lua
--!strict
-- Owns the camera: an overhead view of the board at rest, and a chase view that follows every moving
-- token, holds on where it lands, then eases back. The state machine (`next`, `target`) is pure;
-- `start` (Task 3) feeds it frames and token events.

local BoardCamera = require(script.Parent.BoardCamera)

local CameraDirector = {}

CameraDirector.HOLD_SECONDS = 1
CameraDirector.RETURN_SECONDS = 0.8

export type Mode = "Overhead" | "Following" | "Holding" | "Returning"

export type State = {
	mode: Mode,
	part: BasePart?, -- the token being watched (Following, Holding)
	heading: Vector3, -- its direction of travel
	since: number, -- when this mode began
	from: CFrame?, -- where the camera was when Returning began
}

export type Event =
	{ kind: "MoveStarted", part: BasePart, style: string? }
	| { kind: "Hopped", part: BasePart, from: number, to: number }
	| { kind: "MoveFinished", part: BasePart }
	| { kind: "Tick", camera: CFrame }

function CameraDirector.initial(): State
	return { mode = "Overhead", part = nil, heading = Vector3.new(-1, 0, 0), since = 0, from = nil }
end

local function returning(state: State, camera: CFrame, now: number): State
	return { mode = "Returning", part = nil, heading = state.heading, since = now, from = camera }
end

function CameraDirector.next(state: State, event: Event, now: number): State
	if event.kind == "MoveStarted" then
		if event.style == "ToJail" then
			return state -- a jump, not a walk: nothing to follow
		end
		return { mode = "Following", part = event.part, heading = state.heading, since = now, from = nil }
	elseif event.kind == "Hopped" then
		if state.mode == "Following" and state.part == event.part then
			return { mode = "Following", part = state.part, heading = BoardCamera.heading(event.from, event.to), since = state.since, from = nil }
		end
		return state
	elseif event.kind == "MoveFinished" then
		if state.mode == "Following" and state.part == event.part then
			return { mode = "Holding", part = state.part, heading = state.heading, since = now, from = nil }
		end
		return state
	end
	-- Tick
	local part = state.part
	if (state.mode == "Following" or state.mode == "Holding") and (not part or not part.Parent) then
		return returning(state, event.camera, now) -- the token was removed (back to the lobby)
	elseif state.mode == "Holding" and now - state.since >= CameraDirector.HOLD_SECONDS then
		return returning(state, event.camera, now)
	elseif state.mode == "Returning" and now - state.since >= CameraDirector.RETURN_SECONDS then
		return { mode = "Overhead", part = nil, heading = state.heading, since = now, from = nil }
	end
	return state
end

local function easeInOut(t: number): number
	return t * t * (3 - 2 * t)
end

-- Where the camera should be right now.
function CameraDirector.target(state: State, now: number, overhead: CFrame): CFrame
	local part = state.part
	if (state.mode == "Following" or state.mode == "Holding") and part then
		return BoardCamera.chaseCFrame(part.Position, state.heading)
	elseif state.mode == "Returning" and state.from then
		local t = math.clamp((now - state.since) / CameraDirector.RETURN_SECONDS, 0, 1)
		return state.from:Lerp(overhead, easeInOut(t))
	end
	return overhead
end

return CameraDirector
```

- [ ] **Step 4: Run to verify they pass**

Run: `.run("CameraDirector")` then `.run()`
Expected: `5 passed, 0 failed`; full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/client/CameraDirector.luau src/tests/CameraDirector.spec.luau
git commit -m "feat: camera director state machine — follow, hold, return"
```

---

### Task 3: Wire it up — Tokens hooks, director runtime, label sizes

**Files:**
- Modify: `src/client/Tokens.luau` (`Tokens.new`, `runQueue`)
- Modify: `src/client/CameraDirector.luau` (add `start`)
- Modify: `src/client/BoardCamera.luau` (remove `start`; the director takes over)
- Modify: `src/client/init.client.luau`, `src/client/GameClient.luau`
- Modify: `src/server/BoardBuilder.luau` (`addLabel`: `UITextSizeConstraint`)
- Test: `src/tests/BoardBuilder.spec.luau`

**Interfaces:**
- Consumes: `CameraDirector.initial/next/target` (Task 2), `BoardCamera.getOverheadCFrame`, `BoardCamera.FIELD_OF_VIEW` (Task 1).
- Produces:
  - `export type TokenHooks = { onMoveStarted: (part: BasePart, style: string?) -> (), onHop: (part: BasePart, from: number, to: number) -> (), onMoveFinished: (part: BasePart) -> () }` in `Tokens`; `Tokens.new(parent: Instance, hooks: TokenHooks?)`.
  - `CameraDirector.start(): TokenHooks` — takes the camera, returns the hooks to give `Tokens`.
  - `GameClient.start(hooks: Tokens.TokenHooks?)`.
  - `BoardBuilder.LABEL_MAX_TEXT_SIZE = 40`.

- [ ] **Step 1: Write the failing test** — append to `src/tests/BoardBuilder.spec.luau` before `return tests` (check the file's existing requires; it already requires `BoardBuilder` from `ServerScriptService.Server.BoardBuilder` — reuse that local):

```lua
tests["tile labels share one maximum text size"] = function()
	local holder = Instance.new("Folder")
	local model = BoardBuilder.build(holder)
	local labels = 0
	for _, label in model:GetDescendants() do
		if label:IsA("TextLabel") and label.Name == "Label" then
			labels += 1
			local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
			assert(constraint, `{label:GetFullName()} has no size constraint`)
			Expect.equal(constraint.MaxTextSize, BoardBuilder.LABEL_MAX_TEXT_SIZE, "max size")
		end
	end
	Expect.equal(labels, 40, "every tile has a label")
	holder:Destroy()
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `.run("BoardBuilder")`
Expected: FAIL `… has no size constraint`.

- [ ] **Step 3: Implement the label constraint** — in `BoardBuilder.luau` add `BoardBuilder.LABEL_MAX_TEXT_SIZE = 40` next to the module's other constants (after `local BoardBuilder = {}`), and at the end of `addLabel`:

```lua
	-- TextScaled alone makes short names huge and long ones tiny; cap it so the board reads evenly.
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = BoardBuilder.LABEL_MAX_TEXT_SIZE
	sizeLimit.Parent = label
```

Run `.run("BoardBuilder")` → passes.

- [ ] **Step 4: Tokens hooks** — in `src/client/Tokens.luau`:
- Add the type next to the other exported types:

```lua
-- Optional listeners for the camera: a move begins, each hop, and the token's queue runs dry.
export type TokenHooks = {
	onMoveStarted: (part: BasePart, style: string?) -> (),
	onHop: (part: BasePart, from: number, to: number) -> (),
	onMoveFinished: (part: BasePart) -> (),
}
```

- Add `hooks: TokenHooks?` to the `TokensView` fields, `Tokens.new(parent: Instance, hooks: TokenHooks?)` stores it (`hooks = hooks` in the table passed to `setmetatable`).
- `runQueue(token)` becomes `runQueue(self: TokensView, token: Token)` (update its one call site in `Tokens.apply` to `runQueue(self, token)`), and its loop becomes:

```lua
		local hooks = self.hooks
		while #token.queue > 0 and token.part.Parent do
			local move = table.remove(token.queue, 1) :: Move
			if hooks then
				hooks.onMoveStarted(token.part, move.style)
			end
			local previous = move.from
			for _, position in Tokens.path(move) do
				if not token.part.Parent then
					break -- the token was removed (back to the lobby) mid-move
				end
				if hooks then
					hooks.onHop(token.part, previous, position)
				end
				hop(token, standingCFrame(position, token.seat, move.style == "ToJail"))
				previous = position
			end
		end
		token.moving = false
		if hooks then
			hooks.onMoveFinished(token.part)
		end
```

`runQueue` is a local defined above `Tokens.apply`; since it now takes `self`, make sure `TokensView` is declared above it (it is: the export type sits at the top of the file).

- [ ] **Step 5: Director runtime** — append to `src/client/CameraDirector.luau` (before `return CameraDirector`), adding `local ReplicatedStorage = game:GetService("ReplicatedStorage")`, `local RunService = game:GetService("RunService")`, `local Layout = require(ReplicatedStorage.Shared.Board.Layout)` and the `Tokens` type import `local Tokens = require(script.Parent.Tokens)` at the top:

```lua
local FOLLOW_SHARPNESS = 6 -- higher = the camera catches up with a hopping token faster

-- Takes over the camera for good and returns the hooks Tokens should call.
function CameraDirector.start(): Tokens.TokenHooks
	local state = CameraDirector.initial()

	local function overhead(camera: Camera): CFrame
		local viewport = camera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
		return BoardCamera.getOverheadCFrame(Layout.ORIGIN.Position, Layout.BOARD_SIZE, BoardCamera.FIELD_OF_VIEW, aspect)
	end

	RunService:BindToRenderStep("BoardCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		-- Re-read every frame: CurrentCamera can be replaced, and default scripts may grab it back.
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = BoardCamera.FIELD_OF_VIEW
		local now = os.clock()
		state = CameraDirector.next(state, { kind = "Tick", camera = camera.CFrame }, now)
		local goal = CameraDirector.target(state, now, overhead(camera))
		if state.mode == "Following" or state.mode == "Holding" then
			camera.CFrame = camera.CFrame:Lerp(goal, 1 - math.exp(-FOLLOW_SHARPNESS * dt))
		else
			camera.CFrame = goal -- Returning eases on its own; Overhead stays put
		end
	end)

	return {
		onMoveStarted = function(part, style)
			state = CameraDirector.next(state, { kind = "MoveStarted", part = part, style = style }, os.clock())
		end,
		onHop = function(part, from, to)
			state = CameraDirector.next(state, { kind = "Hopped", part = part, from = from, to = to }, os.clock())
		end,
		onMoveFinished = function(part)
			state = CameraDirector.next(state, { kind = "MoveFinished", part = part }, os.clock())
		end,
	}
end
```

Delete `BoardCamera.start` from `BoardCamera.luau` (and its now-unused requires, if any).

`src/client/init.client.luau` becomes:

```lua
--!strict
local CameraDirector = require(script.CameraDirector)
local GameClient = require(script.GameClient)

GameClient.start(CameraDirector.start())
```

In `GameClient.luau`: `function GameClient.start(hooks: Tokens.TokenHooks?)` and `local tokens = Tokens.new(workspace, hooks)`.

Check for a require cycle before running: `CameraDirector` requires `Tokens` only for its type; `Tokens` must not require `CameraDirector`. (It doesn't.)

- [ ] **Step 6: Run the suite**

Run: `.run()`
Expected: all green (BoardBuilder +1).

- [ ] **Step 7: Playtest with screenshots**

Play Solo, start a 3-seat game, roll. Take screenshots (MCP `screen_capture` after a `task.wait`, or from the Client datamodel read `workspace.CurrentCamera.CFrame` at intervals):
1. At rest: overhead, the whole board visible, closer than before.
2. Mid-move: behind your token, low, looking along the board; a corner hop turns with the board.
3. ~0.5 s after landing: still on the landed token; ~2 s after landing: back overhead.
4. A bot's move: the camera follows the bot too.
5. Go to Jail (roll or card): the camera stays overhead for the jump.
6. From the Client datamodel set `workspace.CurrentCamera.FieldOfView = 40` and `CameraType = Enum.CameraType.Custom`: within a frame both are back (70, Scriptable).
7. Shrink the Studio viewport to a phone shape (Device emulator, portrait): overhead still shows all four corners.
Tune `CHASE_BACK` / `CHASE_UP` / `CHASE_AHEAD` / `FOLLOW_SHARPNESS` only if a screenshot shows the token off-screen or the view clipping into the board; ledger any change as a ruling.

- [ ] **Step 8: Commit**

```bash
git add src/client/Tokens.luau src/client/CameraDirector.luau src/client/BoardCamera.luau src/client/init.client.luau src/client/GameClient.luau src/server/BoardBuilder.luau src/tests/BoardBuilder.spec.luau
git commit -m "feat: chase camera follows every move, holds, returns overhead; even tile label sizes"
```
