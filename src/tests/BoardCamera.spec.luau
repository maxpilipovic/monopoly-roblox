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
