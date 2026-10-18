--!strict
-- Client-side houses and hotels, kept in step with the snapshot. They're the red cottage and inn
-- models (block parts until the models load), and they animate: houses drop in with a puff of dust,
-- a hotel rises as its four houses sink away, and sold buildings sink into the board. Only changes
-- between two snapshots on screen animate; a game joined or left mid-way just appears or clears.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BuildingChanges = require(ReplicatedStorage.Shared.Board.BuildingChanges)
local BuildingLayout = require(ReplicatedStorage.Shared.Board.BuildingLayout)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)

-- Both red, as asked; set HOUSE_BODY to green (46, 160, 67) for the classic look.
local HOUSE_BODY = Color3.fromRGB(196, 28, 32)
local HOTEL_BODY = Color3.fromRGB(176, 18, 26)
local ROOF = Color3.fromRGB(110, 12, 18)
local TRIM = Color3.fromRGB(240, 230, 208)

local DROP_HEIGHT = 3
local DROP_SECONDS = 0.45
local STAGGER_SECONDS = 0.08
local SINK_SECONDS = 0.3
local RISE_SECONDS = 0.5

local Buildings = {}
Buildings.__index = Buildings

export type BuildingsView = typeof(setmetatable(
	{} :: { folder: Folder, shown: { [number]: number }, live: boolean },
	Buildings
))

function Buildings.new(parent: Instance): BuildingsView
	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = parent
	return setmetatable({ folder = folder, shown = {}, live = false }, Buildings)
end

-- Position -> houses (5 = hotel) for every built street.
function Buildings.wanted(snapshot: Protocol.Snapshot?): { [number]: number }
	local wanted = {}
	if snapshot then
		for _, property in snapshot.properties do
			if property.houses > 0 then
				wanted[property.position] = property.houses
			end
		end
	end
	return wanted
end

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function template(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local kind = assets and assets:FindFirstChild("Buildings")
	local model = kind and kind:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

-- A house or hotel standing on `base` (the centre of its footprint, on the board).
local function build(hotel: boolean, base: CFrame, name: string, parent: Instance): Model
	local source = template(if hotel then "Hotel" else "House")
	local model: Model
	if source then
		model = source:Clone()
		-- The models' origin is the centre of their base; pivot there so `base` places them.
		local box, size = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				inert(part)
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = 0.04 -- a hint of lacquer
				if part.Name == "Body" then
					part.Color = if hotel then HOTEL_BODY else HOUSE_BODY
				elseif part.Name == "Roof" then
					part.Color = ROOF
				else
					part.Color = TRIM
				end
			end
		end
	else
		model = Instance.new("Model")
		local size = if hotel then BuildingLayout.HOTEL_SIZE else BuildingLayout.HOUSE_SIZE
		local block = Instance.new("Part")
		block.Name = "Body"
		block.Size = size
		block.Color = if hotel then HOTEL_BODY else HOUSE_BODY
		block.Material = Enum.Material.SmoothPlastic
		block.CFrame = CFrame.new(0, size.Y / 2, 0)
		inert(block)
		block.Parent = model
		model.WorldPivot = CFrame.new()
	end
	model.Name = name
	model:PivotTo(base)
	model.Parent = parent
	return model
end

-- Tweens a model's pivot (models have no tweenable pivot, so drive one through a CFrameValue).
local function tweenPivot(model: Model, goal: CFrame, info: TweenInfo)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cframe)
		if model.Parent then
			model:PivotTo(cframe)
		end
	end)
	TweenService:Create(value, info, { Value = goal }):Play()
	task.delay(info.Time + 0.05, function()
		value:Destroy()
	end)
end

local function tweenScale(model: Model, from: number, to: number, info: TweenInfo)
	local value = Instance.new("NumberValue")
	value.Value = from
	model:ScaleTo(from)
	value.Changed:Connect(function(scale)
		if model.Parent then
			model:ScaleTo(math.max(scale, 0.01))
		end
	end)
	TweenService:Create(value, info, { Value = to }):Play()
	task.delay(info.Time + 0.05, function()
		value:Destroy()
	end)
end

-- A short burst of particles at `where`: dust for a landing, sparkles for a hotel.
local function burst(where: CFrame, sparkle: boolean)
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = where
	inert(anchor)
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	if sparkle then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 140))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.Speed = NumberRange.new(4, 7)
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	else
		emitter.Color = ColorSequence.new(Color3.fromRGB(230, 222, 205))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.7) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		emitter.Speed = NumberRange.new(1.5, 3)
		emitter.Acceleration = Vector3.new(0, -2, 0)
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	end
	emitter.Parent = anchor
	emitter:Emit(if sparkle then 24 else 10)
	task.delay(1, function()
		anchor:Destroy()
	end)
end

local function drop(model: Model, base: CFrame, delay: number)
	model:PivotTo(base * CFrame.new(0, DROP_HEIGHT, 0))
	task.delay(delay, function()
		if not model.Parent then
			return
		end
		tweenPivot(model, base, TweenInfo.new(DROP_SECONDS, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out))
		task.delay(DROP_SECONDS * 0.4, function()
			burst(base, false)
		end)
	end)
end

local function sink(model: Model)
	model.Name ..= "Leaving"
	local info = TweenInfo.new(SINK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tweenPivot(model, model:GetPivot() * CFrame.new(0, -0.6, 0), info)
	tweenScale(model, 1, 0.05, info)
	task.delay(SINK_SECONDS + 0.05, function()
		model:Destroy()
	end)
end

local function rise(model: Model, base: CFrame, delay: number)
	model:ScaleTo(0.05)
	task.delay(delay, function()
		if not model.Parent then
			return
		end
		tweenScale(model, 0.05, 1, TweenInfo.new(RISE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		burst(base * CFrame.new(0, 1, 0), true)
	end)
end

local function groupFor(self: BuildingsView, position: number): Folder
	local group = self.folder:FindFirstChild(tostring(position))
	if group and group:IsA("Folder") then
		return group
	end
	local folder = Instance.new("Folder")
	folder.Name = tostring(position)
	folder.Parent = self.folder
	return folder
end

local function houseName(index: number): string
	return `House{index}`
end

-- Plays one street's change (houses, 5 = hotel), animated or not.
local function change(self: BuildingsView, position: number, from: number, to: number, animate: boolean)
	local group = groupFor(self, position)
	local hotel = BuildingLayout.HOTEL
	local function leave(name: string)
		local model = group:FindFirstChild(name)
		if model and model:IsA("Model") then
			if animate then
				sink(model)
			else
				model:Destroy()
			end
		end
	end

	-- Take down what goes.
	if from == hotel and to ~= hotel then
		leave("Hotel")
	elseif to == hotel then
		for index = 1, math.min(from, 4) do
			leave(houseName(index))
		end
	elseif to < from then
		for index = to + 1, from do
			leave(houseName(index))
		end
	end

	-- Put up what comes.
	local wait = if animate and (from == hotel or to == hotel) and from > 0 then SINK_SECONDS else 0
	if to == hotel and from ~= hotel then
		local base = BuildingLayout.cframe(position, hotel)
		local model = build(true, base, "Hotel", group)
		if animate then
			rise(model, base, wait)
		end
	elseif to ~= hotel then
		local first = if from == hotel then 1 else from + 1
		for index = first, to do
			local base = BuildingLayout.cframe(position, index)
			local model = build(false, base, houseName(index), group)
			if animate then
				drop(model, base, wait + (index - first) * STAGGER_SECONDS)
			end
		end
	end

	self.shown[position] = if to > 0 then to else nil
end

function Buildings.apply(self: BuildingsView, snapshot: Protocol.Snapshot?)
	local wanted = Buildings.wanted(snapshot)
	local animate = self.live and snapshot ~= nil
	for _, step in BuildingChanges.diff(self.shown, wanted) do
		change(self, step.position, step.from, step.to, animate)
	end
	self.live = snapshot ~= nil
end

return Buildings
