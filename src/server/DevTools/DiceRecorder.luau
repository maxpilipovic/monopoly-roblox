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
local MAX_GAP = 16 -- studs between the resting dice; further apart reads as two separate throws

local DiceRecorder = {}

local function makeDie(name: string, parent: Instance): Part
	local die = Instance.new("Part")
	die.Name = name
	die.Size = Vector3.one * DiceThrow.SIZE
	die.CustomPhysicalProperties = PhysicalProperties.new(1.6, 0.25, 0.35) -- density, friction, elasticity
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
local function throwOnce(surface: CFrame, stage: Instance, random: Random): (DiceThrow.Throw?, string?)
	-- Fresh dice each throw: one that bounced off the floor may have fallen out of the world.
	local dice = { makeDie("DieA", stage), makeDie("DieB", stage) }
	local startX = random:NextNumber(-10, 10)
	local push = Vector3.new(random:NextNumber(-4, 4), random:NextNumber(0, 5), -random:NextNumber(30, 40))
	for i, die in dice do
		local start = Vector3.new(startX + (if i == 1 then -2.6 else 2.6), random:NextNumber(8, 11), 24)
		local tumble = CFrame.Angles(random:NextNumber(0, 2 * math.pi), random:NextNumber(0, 2 * math.pi), random:NextNumber(0, 2 * math.pi))
		die.CFrame = surface * CFrame.new(start) * tumble
		die.Anchored = false
		die:SetNetworkOwner(nil)
		die.AssemblyLinearVelocity = surface:VectorToWorldSpace(push + Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-3, 3)))
		die.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-25, 25), random:NextNumber(-25, 25), random:NextNumber(-25, 25))
	end

	local throw: DiceThrow.Throw = { {}, {} }
	local elapsed, nextSample, stillFor = 0, 0, 0
	local fell = false
	while stillFor < STILL_SECONDS and elapsed < GIVE_UP_SECONDS and not fell do
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
			if surface:PointToObjectSpace(die.Position).Y < 0 then
				fell = true
			end
			if die.AssemblyLinearVelocity.Magnitude > SETTLE_SPEED or die.AssemblyAngularVelocity.Magnitude > SETTLE_SPEED then
				moving = true
			end
		end
		stillFor = if moving then 0 else stillFor + dt
	end
	for _, die in dice do
		die:Destroy()
	end
	if fell then
		return nil, "fell off"
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
	local gap = DiceThrow.frame(throw[1], count).Position - DiceThrow.frame(throw[2], count).Position
	if gap.Magnitude > MAX_GAP then
		return nil, "too far apart"
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
	floor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.35)
	floor.Parent = stage
	stage.Parent = workspace
	local surface = FLOOR_AT * CFrame.new(0, 0.5, 0)
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
		local throw, why = throwOnce(surface, stage, random)
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
