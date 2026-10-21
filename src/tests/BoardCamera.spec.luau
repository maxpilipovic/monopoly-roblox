--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local BoardCamera = require(StarterPlayer.StarterPlayerScripts.Client.BoardCamera)
local Expect = require(script.Parent.Expect)

local tests = {}

local FOCUS = Vector3.new(0, 0.5, 0)

tests["camera looks down at the configured pitch from above the Go-row side, square to the board"] = function()
	local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, 16 / 9)
	Expect.near(math.asin(-cf.LookVector.Y), BoardCamera.PITCH, "pitch")
	Expect.near(cf.LookVector.X, 0, "square to the board")
	Expect.near(cf.Position.X, FOCUS.X, "centred across")
	assert(cf.Position.Z > FOCUS.Z, "camera should be on the +Z side")
end

tests["the board sits between the top of the screen and the action bar, with room at both"] = function()
	local inset = 0.16
	local fov = 70
	local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, fov, 16 / 9, inset)
	local tanV = math.tan(math.rad(fov) / 2)
	local top, bottom = -math.huge, math.huge
	for _, corner in { Vector3.new(37, 0, 37), Vector3.new(-37, 0, 37), Vector3.new(37, 0, -37), Vector3.new(-37, 0, -37) } do
		local p = cf:PointToObjectSpace(FOCUS + corner)
		local y = p.Y / (-p.Z * tanV)
		top = math.max(top, y)
		bottom = math.min(bottom, y)
	end
	-- Normalised screen height: +1 is the top edge, -1 + 2 * inset the top of the bar.
	assert(top <= 1, `board above the screen ({top})`)
	assert(bottom >= -1 + 2 * inset - 1e-6, `board under the bar ({bottom})`)
	-- Room at both ends: neither crammed against the top nor left with all the space up there.
	assert(1 - top > 0.03 and bottom - (-1 + 2 * inset) > 0.03, `room above {1 - top}, below {bottom - (-1 + 2 * inset)}`)
	assert(math.abs((1 - top) - (bottom - (-1 + 2 * inset))) < 0.4, "the room is shared out, not all at one end")
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

local function sphereDistance(boardSize: number, fov: number, aspect: number): number
	local radius = boardSize / 2 * math.sqrt(2)
	local halfV = math.rad(fov) / 2
	local halfH = math.atan(math.tan(halfV) * aspect)
	return radius / math.sin(math.min(halfV, halfH))
end

tests["on landscape screens the overhead view is never farther back than a fit of the board's bounding sphere"] = function()
	for _, aspect in { 16 / 9, 4 / 3 } do
		local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, aspect)
		local distance = (cf.Position - FOCUS).Magnitude
		assert(distance <= sphereDistance(74, 70, aspect), `aspect {aspect}: {distance} farther than the sphere fit`)
	end
end

tests["a bottom inset keeps the whole board above the action bar"] = function()
	local inset = 0.16
	for _, aspect in { 16 / 9, 4 / 3, 9 / 16 } do
		local cf = BoardCamera.getOverheadCFrame(FOCUS, 74, 70, aspect, inset)
		local tanV = math.tan(math.rad(70) / 2)
		local tanH = tanV * aspect
		for _, corner in { Vector3.new(37, 0, 37), Vector3.new(-37, 0, 37), Vector3.new(37, 0, -37), Vector3.new(-37, 0, -37) } do
			local p = cf:PointToObjectSpace(FOCUS + corner)
			local depth = -p.Z
			assert(depth > 0, "corner behind camera")
			assert(math.abs(p.X) / depth <= tanH, `corner {corner} outside horizontally at aspect {aspect}`)
			assert(p.Y / depth <= tanV, `corner {corner} above the screen at aspect {aspect}`)
			assert(p.Y / depth >= -tanV * (1 - 2 * inset), `corner {corner} under the action bar at aspect {aspect}`)
		end
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

tests["the chase camera looks down on the token from outside the board, a little behind it"] = function()
	-- One hop on each side of the board, and one backwards.
	for _, hop in { { 3, 4 }, { 13, 14 }, { 23, 24 }, { 33, 34 }, { 36, 35 } } do
		local target = BoardCamera.tileCentre(hop[1])
		local heading = BoardCamera.heading(hop[1], hop[2])
		local cf = BoardCamera.chaseCFrame(target, heading)
		local offset = cf.Position - target
		local label = `from tile {hop[1]}`
		Expect.near(offset.Y, BoardCamera.CHASE_UP, `{label} height`)
		Expect.near(offset:Dot(heading), -BoardCamera.CHASE_BACK, `{label} behind`)
		-- To the side: square to the direction of travel, on the side away from the board's centre.
		local side = Vector3.new(offset.X, 0, offset.Z) + heading * BoardCamera.CHASE_BACK
		Expect.near(side.Magnitude, BoardCamera.CHASE_SIDE, `{label} side distance`)
		Expect.near(side:Dot(heading), 0, `{label} square to the heading`)
		local outward = Vector3.new(target.X, 0, target.Z) -- the board is centred on the origin
		assert(side:Dot(outward) > 0, `{label} camera must be outside the board, not over its middle`)
		-- A high angle: it looks down at 40 degrees or steeper.
		assert(-cf.LookVector.Y >= math.sin(math.rad(40)), `{label} too shallow`)
		local lookAt = target + heading * BoardCamera.CHASE_AHEAD
		Expect.vectorNear(cf.LookVector, (lookAt - cf.Position).Unit, `{label} looks just ahead of the token`)
		assert(cf:PointToObjectSpace(target).Z < 0, `{label} token is in front of the camera`)
	end
end

return tests
