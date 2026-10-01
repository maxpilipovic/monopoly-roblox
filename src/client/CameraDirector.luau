--!strict
-- Owns the camera: an overhead view of the board at rest, and a chase view that follows every moving
-- token, holds on where it lands, then eases back. The state machine (`next`, `target`) is pure;
-- `start` feeds it frames and token events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local BoardCamera = require(script.Parent.BoardCamera)
local Tokens = require(script.Parent.Tokens)

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

local FOLLOW_SHARPNESS = 6 -- higher = the camera catches up with a hopping token faster
local ACTION_BAR_INSET = 0.16 -- share of the screen's height the action bar covers at the bottom

-- Takes over the camera for good and returns the hooks Tokens should call.
function CameraDirector.start(): Tokens.TokenHooks
	local state = CameraDirector.initial()

	local function overhead(camera: Camera): CFrame
		local viewport = camera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
		return BoardCamera.getOverheadCFrame(
			Layout.ORIGIN.Position,
			Layout.BOARD_SIZE,
			BoardCamera.FIELD_OF_VIEW,
			aspect,
			ACTION_BAR_INSET
		)
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

return CameraDirector
