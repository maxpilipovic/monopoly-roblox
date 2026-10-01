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
	state = tick(state, 2.9) -- not 2.8: 2.8 - 2.0 lands a hair under 0.8 in floating point
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

tests["a jump to jail by the token being watched sends the camera home instead of chasing it"] = function()
	local part, other = token(), token()
	local camera = CFrame.new(1, 2, 3)
	-- Walked onto Go To Jail: the jump starts while the camera is still following the walk.
	local state = CameraDirector.next(CameraDirector.initial(), { kind = "MoveStarted", part = part }, 0)
	state = CameraDirector.next(state, { kind = "MoveStarted", part = part, style = "ToJail", camera = camera }, 1)
	Expect.equal(state.mode, "Returning", "from following")
	Expect.vectorNear((state.from :: CFrame).Position, camera.Position, "returns from where the camera was")
	state = CameraDirector.next(state, { kind = "Hopped", part = part, from = 30, to = 10 }, 1)
	Expect.equal(state.mode, "Returning", "the jump's hop is ignored")
	-- Third doubles: the jump starts during the hold on the same token.
	state = CameraDirector.next(CameraDirector.initial(), { kind = "MoveStarted", part = part }, 0)
	state = CameraDirector.next(state, { kind = "MoveFinished", part = part }, 1)
	state = CameraDirector.next(state, { kind = "MoveStarted", part = part, style = "ToJail", camera = camera }, 1.5)
	Expect.equal(state.mode, "Returning", "from holding")
	-- Someone else's jump leaves the token being followed alone.
	state = CameraDirector.next(CameraDirector.initial(), { kind = "MoveStarted", part = part }, 0)
	state = CameraDirector.next(state, { kind = "MoveStarted", part = other, style = "ToJail", camera = camera }, 0.5)
	Expect.equal(state.mode, "Following", "another token's jump")
	Expect.equal(state.part, part)
	part:Destroy()
	other:Destroy()
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
