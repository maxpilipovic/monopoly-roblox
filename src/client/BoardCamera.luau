--!strict
-- Camera math: the overhead view fitted to the screen, and the chase view behind a moving token.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local BoardCamera = {}

BoardCamera.PITCH = math.rad(60)
BoardCamera.FIELD_OF_VIEW = 70
BoardCamera.CHASE_BACK = 12
BoardCamera.CHASE_UP = 9
BoardCamera.CHASE_AHEAD = 6
local FIT_MARGIN = 1.04 -- a sliver of space around the board's corners

-- The overhead camera `distance` away, lowered so the board sits in the part of the screen above
-- `bottomInset` (a fraction of the screen's height kept free for the action bar).
local function overheadAt(focus: Vector3, tanV: number, distance: number, bottomInset: number): CFrame
	local offset = Vector3.new(0, math.sin(BoardCamera.PITCH), math.cos(BoardCamera.PITCH)) * distance
	local cf = CFrame.lookAt(focus + offset, focus)
	return cf - cf.UpVector * (distance * tanV * bottomInset)
end

-- Whether every board corner is inside the view (and above the bottom inset) from `distance` away.
local function cornersFit(focus: Vector3, boardSize: number, tanV: number, tanH: number, distance: number, bottomInset: number): boolean
	local cf = overheadAt(focus, tanV, distance, bottomInset)
	local half = boardSize / 2
	for _, corner in { Vector3.new(half, 0, half), Vector3.new(-half, 0, half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, -half) } do
		local p = cf:PointToObjectSpace(focus + corner)
		local depth = -p.Z
		if depth <= 0 or math.abs(p.X) > depth * tanH or p.Y > depth * tanV or p.Y < -depth * tanV * (1 - 2 * bottomInset) then
			return false
		end
	end
	return true
end

-- The overhead view: as close as possible while every corner of the board stays on screen, above
-- the bottom `bottomInset` of it (default none).
function BoardCamera.getOverheadCFrame(
	focus: Vector3,
	boardSize: number,
	fieldOfViewDegrees: number,
	aspect: number,
	bottomInset: number?
): CFrame
	local inset = bottomInset or 0
	local tanV = math.tan(math.rad(fieldOfViewDegrees) / 2)
	local tanH = tanV * aspect
	-- Binary search the distance; the far end (a bounding sphere inside the usable view) always fits.
	local narrowest = math.min(math.atan(tanV * (1 - 2 * inset)), math.atan(tanH))
	local near, far = 0, boardSize / 2 * math.sqrt(2) / math.sin(narrowest)
	for _ = 1, 30 do
		local middle = (near + far) / 2
		if cornersFit(focus, boardSize, tanV, tanH, middle, inset) then
			far = middle
		else
			near = middle
		end
	end
	return overheadAt(focus, tanV, far * FIT_MARGIN, inset)
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

return BoardCamera
