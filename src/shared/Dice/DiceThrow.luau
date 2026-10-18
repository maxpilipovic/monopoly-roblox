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
