--!strict
-- The world around the board while a game is on, built on this client: a table under the board and,
-- depending on the scene, a city skyline and pier at night, a tropical island at sunset, or a snowy
-- lodge. Also lights it; the lobby's lighting comes back when the scene is cleared.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)

local SceneBuilder = {}

local TABLE_SIZE = Layout.BOARD_SIZE + 26

type Saved = { [string]: any }
local savedLighting: Saved? = nil
local savedAtmosphere: Saved? = nil
local hiddenBaseplate: BasePart? = nil
local hiddenTextures: { [Instance]: number } = {} -- the baseplate's grid texture and its own transparency

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function cylinder(name: string, radius: number, height: number, base: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	}, parent)
end

local function light(parentPart: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parentPart
end

-- A four-sided pyramid of wedges: a pine tree's tier.
local function pyramid(centre: Vector3, width: number, height: number, color: Color3, parent: Instance)
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		part({
			ClassName = "WedgePart",
			Name = "Needles",
			Size = Vector3.new(width, height, width / 2),
			CFrame = CFrame.new(centre) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, width / 4),
			Color = color,
			Material = Enum.Material.Grass,
		}, parent)
	end
end

-- The table the board sits on, common to every scene.
local function buildTable(scene: Scenes.Scene, model: Instance)
	part({
		Name = "TableTop",
		Size = Vector3.new(TABLE_SIZE, 2, TABLE_SIZE),
		CFrame = CFrame.new(0, -1.15, 0), -- top just under the board's base
		Color = scene.tableTop,
		Material = Enum.Material.Wood,
	}, model)
	part({
		Name = "TableTrim",
		Size = Vector3.new(TABLE_SIZE + 2, 1, TABLE_SIZE + 2),
		CFrame = CFrame.new(0, -2.3, 0),
		Color = Color3.fromRGB(214, 172, 84),
		Material = Enum.Material.Metal,
	}, model)
end

local function boardwalk(scene: Scenes.Scene, model: Instance, random: Random)
	-- The pier the table stands on, and the night sea all round.
	part({ Name = "Pier", Size = Vector3.new(170, 2, 170), CFrame = CFrame.new(0, -3.5, 0), Color = scene.ground, Material = Enum.Material.WoodPlanks }, model)
	part({ Name = "Sea", Size = Vector3.new(2000, 1, 2000), CFrame = CFrame.new(0, -12, 0), Color = Color3.fromRGB(14, 26, 54), Material = Enum.Material.SmoothPlastic, Reflectance = 0.25 }, model)
	-- Lamp posts along the pier's edge.
	for index = 0, 15 do
		local angle = index / 16 * 2 * math.pi
		local base = Vector3.new(math.cos(angle) * 80, -2.5, math.sin(angle) * 80)
		cylinder("Lamp", 0.4, 12, base, Color3.fromRGB(30, 30, 36), Enum.Material.Metal, model)
		local globe = part({ Name = "Globe", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = CFrame.new(base + Vector3.new(0, 13, 0)), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon }, model)
		light(globe, Color3.fromRGB(255, 200, 140), 30, 1.6)
	end
	-- A skyline across the bay, its windows lit in bands.
	for index = 1, 46 do
		local angle = -math.pi * 0.95 + (index / 46) * math.pi * 0.9 - math.pi * 0.05
		local radius = 260 + random:NextNumber(0, 120)
		local height = random:NextNumber(40, 170)
		local width = random:NextNumber(18, 34)
		local centre = Vector3.new(math.cos(angle) * radius, height / 2 - 12, math.sin(angle) * radius)
		local tower = part({ Name = "Tower", Size = Vector3.new(width, height, width), CFrame = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0)), Color = Color3.fromRGB(22, 24, 38), Material = Enum.Material.SmoothPlastic }, model)
		local tint = if random:NextNumber() < 0.5 then Color3.fromRGB(255, 214, 140) else Color3.fromRGB(150, 210, 255)
		for band = 1, math.floor(height / 14) do
			if random:NextNumber() < 0.7 then
				part({ Name = "Windows", Size = Vector3.new(width * 0.8, 1.2, 0.3), CFrame = tower.CFrame * CFrame.new(0, -height / 2 + band * 14, -width / 2 - 0.1), Color = tint, Material = Enum.Material.Neon }, model)
			end
		end
		if random:NextNumber() < 0.4 then
			local beacon = part({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = tower.CFrame * CFrame.new(0, height / 2 + 1, 0), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon }, model)
			light(beacon, Color3.fromRGB(255, 60, 60), 12, 1)
		end
	end
	-- A big lit Ferris wheel off to the side.
	local hub = Vector3.new(-170, 55, -150)
	for spoke = 0, 23 do
		local a = spoke / 24 * 2 * math.pi
		local rim = hub + CFrame.Angles(0, math.rad(35), 0):VectorToWorldSpace(Vector3.new(math.cos(a) * 48, math.sin(a) * 48, 0))
		part({ Name = "Rim", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(rim), Color = Color3.fromHSV(spoke / 24, 0.7, 1), Material = Enum.Material.Neon }, model)
		local mid = (hub + rim) / 2
		part({ Name = "Spoke", Size = Vector3.new(0.6, 0.6, 48), CFrame = CFrame.lookAt(mid, rim), Color = Color3.fromRGB(200, 200, 220), Material = Enum.Material.Neon, Transparency = 0.5 }, model)
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 4000
	sky.MoonAngularSize = 14
	sky.Parent = model
end

local function palm(base: Vector3, lean: number, yaw: number, model: Instance, random: Random)
	local position = base
	local direction = CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0)
	for segment = 1, 7 do
		local step = direction:VectorToWorldSpace(Vector3.new(0, 3, 0))
		part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 1.6 - segment * 0.1, 1.6 - segment * 0.1), CFrame = CFrame.lookAt(position + step / 2, position + step) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(130, 96, 60), Material = Enum.Material.Wood }, model)
		position += step
		direction *= CFrame.Angles(0.05, 0, 0)
	end
	for frond = 0, 6 do
		local a = frond / 7 * 2 * math.pi + random:NextNumber(0, 0.4)
		part({
			ClassName = "WedgePart",
			Name = "Frond",
			Size = Vector3.new(0.4, 2.2, 10),
			CFrame = CFrame.new(position) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, -1, 5),
			Color = Color3.fromRGB(52, 140, 62),
			Material = Enum.Material.Grass,
		}, model)
	end
end

local function tropical(scene: Scenes.Scene, model: Instance, random: Random)
	part({ Name = "Island", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 340, 340), CFrame = CFrame.new(0, -7, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = scene.ground, Material = Enum.Material.Sand }, model)
	part({ Name = "Shallows", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 420, 420), CFrame = CFrame.new(0, -9.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(80, 210, 220), Material = Enum.Material.Glass, Transparency = 0.25 }, model)
	part({ Name = "Sea", Size = Vector3.new(2000, 1, 2000), CFrame = CFrame.new(0, -11, 0), Color = Color3.fromRGB(30, 120, 180), Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 }, model)
	for index = 0, 15 do
		local angle = index / 16 * 2 * math.pi + random:NextNumber(-0.15, 0.15)
		local radius = random:NextNumber(72, 140)
		palm(Vector3.new(math.cos(angle) * radius, -3, math.sin(angle) * radius), random:NextNumber(0.15, 0.35), angle + math.pi / 2, model, random)
	end
	-- Beach umbrellas and far-off islands.
	for index = 0, 5 do
		local angle = index / 6 * 2 * math.pi + 0.3
		local base = Vector3.new(math.cos(angle) * 64, -3, math.sin(angle) * 64)
		cylinder("Pole", 0.25, 8, base, Color3.fromRGB(240, 240, 235), Enum.Material.SmoothPlastic, model)
		part({ Name = "Canopy", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(base + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = if index % 2 == 0 then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(255, 220, 90), Material = Enum.Material.Fabric }, model)
	end
	for index = 1, 5 do
		local angle = -math.pi / 2 + (index - 3) * 0.45
		local centre = Vector3.new(math.cos(angle) * 520, -20, math.sin(angle) * 520)
		part({ Name = "FarIsland", Shape = Enum.PartType.Ball, Size = Vector3.new(160, 70, 110), CFrame = CFrame.new(centre), Color = Color3.fromRGB(70, 130, 70), Material = Enum.Material.Grass }, model)
	end
end

local function pine(base: Vector3, scale: number, model: Instance)
	cylinder("Trunk", 0.8 * scale, 4 * scale, base, Color3.fromRGB(90, 62, 40), Enum.Material.Wood, model)
	for tier = 0, 2 do
		local width = (11 - tier * 3) * scale
		pyramid(base + Vector3.new(0, (5 + tier * 4.5) * scale, 0), width, 7 * scale, Color3.fromRGB(38, 92, 60), model)
		pyramid(base + Vector3.new(0, (5.6 + tier * 4.5) * scale, 0), width * 0.8, 6 * scale, Color3.fromRGB(240, 246, 252), model)
	end
end

local function winter(scene: Scenes.Scene, model: Instance, random: Random)
	part({ Name = "Snow", Size = Vector3.new(1400, 4, 1400), CFrame = CFrame.new(0, -5.5, 0), Color = scene.ground, Material = Enum.Material.Snow }, model)
	part({ Name = "FrozenLake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 160, 220), CFrame = CFrame.new(150, -3.4, -120) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(170, 215, 240), Material = Enum.Material.Ice, Reflectance = 0.2 }, model)
	for index = 1, 42 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = random:NextNumber(85, 260)
		local base = Vector3.new(math.cos(angle) * radius, -3.5, math.sin(angle) * radius)
		if (base - Vector3.new(150, -3.5, -120)).Magnitude > 110 then
			pine(base, random:NextNumber(1.2, 2.4), model)
		end
	end
	-- A log cabin with a warm window and a smoking chimney.
	local cabin = Vector3.new(-120, -3.5, -110)
	for log = 0, 7 do
		for side = 0, 3 do
			local yaw = side * math.pi / 2
			local offset = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(0, 0, 14))
			part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, 2.2, 2.2), CFrame = CFrame.new(cabin + offset + Vector3.new(0, 1.1 + log * 2, 0)) * CFrame.Angles(0, yaw, 0), Color = Color3.fromRGB(120, 78, 48), Material = Enum.Material.Wood }, model)
		end
	end
	for side = -1, 1, 2 do
		part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(34, 10, 17), CFrame = CFrame.new(cabin + Vector3.new(0, 22, side * 8.5)) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0), Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow }, model)
	end
	local window = part({ Name = "Window", Size = Vector3.new(8, 6, 0.4), CFrame = CFrame.new(cabin + Vector3.new(0, 8, 15.2)), Color = Color3.fromRGB(255, 196, 110), Material = Enum.Material.Neon }, model)
	light(window, Color3.fromRGB(255, 170, 90), 30, 2)
	local chimney = part({ Name = "Chimney", Size = Vector3.new(4, 12, 4), CFrame = CFrame.new(cabin + Vector3.new(8, 26, -4)), Color = Color3.fromRGB(110, 100, 96), Material = Enum.Material.Cobblestone }, model)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 225))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(4, 6)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.Rate = 6
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = chimney
	-- Snow falling over the whole table.
	local cloud = part({ Name = "SnowCloud", Size = Vector3.new(220, 1, 220), CFrame = CFrame.new(0, 90, 0), Transparency = 1 }, model)
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.35)
	snow.Lifetime = NumberRange.new(10, 14)
	snow.Speed = NumberRange.new(6, 9)
	snow.Rate = 160
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Parent = cloud
end

local BUILDERS = { Boardwalk = boardwalk, Tropical = tropical, Winter = winter }

local function remember(instance: Instance, keys: { string }): Saved
	local saved = {}
	for _, key in keys do
		saved[key] = (instance :: any)[key]
	end
	return saved
end

local LIGHTING_KEYS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogEnd", "FogStart" }
local ATMOSPHERE_KEYS = { "Density", "Color", "Decay", "Haze" }

local function applyLighting(scene: Scenes.Scene)
	if not savedLighting then
		savedLighting = remember(Lighting, LIGHTING_KEYS)
	end
	Lighting.ClockTime = scene.clockTime
	Lighting.Brightness = scene.brightness
	Lighting.Ambient = scene.ambient
	Lighting.OutdoorAmbient = scene.outdoorAmbient
	Lighting.FogColor = scene.fogColor
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		if not savedAtmosphere then
			savedAtmosphere = remember(atmosphere, ATMOSPHERE_KEYS)
		end
		atmosphere.Density = scene.atmosphereDensity
		atmosphere.Color = scene.atmosphereColor
		atmosphere.Decay = scene.fogColor
	end
end

local function restoreLighting()
	if savedLighting then
		for key, value in savedLighting do
			(Lighting :: any)[key] = value
		end
		savedLighting = nil
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and savedAtmosphere then
		for key, value in savedAtmosphere do
			(atmosphere :: any)[key] = value
		end
	end
	savedAtmosphere = nil
end

-- Builds `sceneId`'s world around the board (on this client only) and lights it.
function SceneBuilder.build(sceneId: string?, parent: Instance): Model
	local scene = Scenes.byId[sceneId or ""] or Scenes.LIST[1]
	local model = Instance.new("Model")
	model.Name = "Scene"
	local random = Random.new(7) -- the same layout every time for a scene
	buildTable(scene, model)
	BUILDERS[scene.id](scene, model, random)
	local sky = model:FindFirstChildOfClass("Sky")
	if sky then
		sky.Parent = Lighting
		sky.Name = "SceneSky"
	end
	model.Parent = parent
	applyLighting(scene)
	-- The grey baseplate would show through; hide it while a scene is up.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.LocalTransparencyModifier = 1
		hiddenBaseplate = baseplate
		-- Its grid texture doesn't follow the part's transparency; hide that too.
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				hiddenTextures[child] = child.Transparency
				child.Transparency = 1
			end
		end
	end
	return model
end

function SceneBuilder.clear(model: Model?)
	if model then
		model:Destroy()
	end
	local sky = Lighting:FindFirstChild("SceneSky")
	if sky then
		sky:Destroy()
	end
	restoreLighting()
	if hiddenBaseplate then
		hiddenBaseplate.LocalTransparencyModifier = 0
		hiddenBaseplate = nil
	end
	for texture, transparency in hiddenTextures do
		(texture :: any).Transparency = transparency
	end
	hiddenTextures = {}
end

return SceneBuilder
