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

return tests
