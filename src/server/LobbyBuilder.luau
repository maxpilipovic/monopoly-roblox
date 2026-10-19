--!strict
-- Builds the lobby players spawn into: a marble plaza ringed in gold on a green island, a fountain
-- crowned by a giant turning die, statues of the game's buildings and emblems on plinths, lamp
-- posts and a colonnade, three leaderboard boards, and kiosks that open the games browser. It sits
-- far from the board's spot so nobody in the lobby ever sees a game. Built from code, so it lives
-- in git; LobbyFx on the client adds the motion and fills the boards.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyBuilder = {}

LobbyBuilder.CENTRE = Vector3.new(0, 0, 900)
LobbyBuilder.MODEL_NAME = "Lobby"
LobbyBuilder.SPIN_TAG = "LobbySpin" -- models LobbyFx turns slowly
LobbyBuilder.BOARD_TAG = "LobbyLeaderboard" -- parts LobbyFx draws a leaderboard on
LobbyBuilder.KIOSK_TAG = "LobbyKiosk" -- prompts that open the games browser

local MARBLE = Color3.fromRGB(238, 233, 222)
local MARBLE_DARK = Color3.fromRGB(206, 198, 184)
local GOLD = Color3.fromRGB(214, 172, 84)
local IRON = Color3.fromRGB(38, 40, 46)
local HEDGE = Color3.fromRGB(46, 104, 62)
local GRASS = Color3.fromRGB(88, 150, 84)
local WATER = Color3.fromRGB(92, 168, 222)
local PLAZA_RADIUS = 115
local HALL_RADIUS = PLAZA_RADIUS + 22 -- the enclosing wall
local WALL_HEIGHT = 46
local DOME_HEIGHT = 64

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- A flat disc lying on the ground, top at `top`.
local function disc(name: string, radius: number, height: number, top: number, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(LobbyBuilder.CENTRE + Vector3.new(0, top - height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	}, parent)
end

local function upright(name: string, radius: number, height: number, base: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	}, parent)
end

local function around(radius: number, angle: number, y: number): Vector3
	return LobbyBuilder.CENTRE + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- Faces the plaza's centre from `position`.
local function facingCentre(position: Vector3): CFrame
	local centre = Vector3.new(LobbyBuilder.CENTRE.X, position.Y, LobbyBuilder.CENTRE.Z)
	return CFrame.lookAt(position, centre)
end

local function buildGround(model: Model)
	disc("Island", 260, 6, -0.4, GRASS, Enum.Material.Grass, model)
	disc("HallFloor", HALL_RADIUS + 2, 1.2, 0.3, MARBLE_DARK, Enum.Material.Marble, model)
	disc("PlazaEdge", PLAZA_RADIUS + 1.5, 1.2, 0.2, MARBLE_DARK, Enum.Material.Marble, model)
	disc("Plaza", PLAZA_RADIUS, 1.2, 0.4, MARBLE, Enum.Material.Marble, model)
	-- Gold inlay rings: a gold disc with marble laid over all but its rim.
	for _, ring in { { 84, 82 }, { 52, 50.5 } } do
		disc("InlayGold", ring[1], 0.1, 0.45, GOLD, Enum.Material.Metal, model)
		disc("InlayMarble", ring[2], 0.1, 0.46, MARBLE, Enum.Material.Marble, model)
	end
	-- Paths of darker marble out to the colonnade, like a compass.
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local mid = around(PLAZA_RADIUS - 11, angle, 0.47)
		part({
			Name = "Path",
			Size = Vector3.new(8, 0.1, 22),
			CFrame = CFrame.lookAt(mid, LobbyBuilder.CENTRE + Vector3.new(0, 0.47, 0)),
			Color = MARBLE_DARK,
			Material = Enum.Material.Marble,
		}, model)
	end
end

local function buildFountain(model: Model)
	local base = LobbyBuilder.CENTRE + Vector3.new(0, 0.4, 0)
	upright("FountainRim", 15, 3, base, MARBLE_DARK, Enum.Material.Marble, model)
	upright("FountainGoldLip", 15.3, 0.4, base + Vector3.new(0, 3, 0), GOLD, Enum.Material.Metal, model)
	local water = upright("FountainWater", 13.5, 0.4, base + Vector3.new(0, 2.5, 0), WATER, Enum.Material.Glass, model)
	water.Transparency = 0.25
	upright("FountainPillar", 2.6, 9, base + Vector3.new(0, 2.5, 0), MARBLE, Enum.Material.Marble, model)
	upright("FountainBowl", 6, 1.2, base + Vector3.new(0, 9, 0), MARBLE_DARK, Enum.Material.Marble, model)
	local bowlWater = upright("FountainBowlWater", 5.3, 0.3, base + Vector3.new(0, 10, 0), WATER, Enum.Material.Glass, model)
	bowlWater.Transparency = 0.25

	-- Spray falling from the bowl into the basin.
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(210, 236, 255))
	spray.LightEmission = 0.6
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 60
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(180, 10)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.Parent = bowlWater
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 210, 255)
	glow.Range = 18
	glow.Brightness = 1
	glow.Parent = water
end

local function buildPlinth(position: Vector3, model: Model): CFrame
	part({ Name = "Plinth", Size = Vector3.new(9, 4, 9), CFrame = facingCentre(position + Vector3.new(0, 2.4, 0)), Color = MARBLE_DARK, Material = Enum.Material.Marble }, model)
	part({ Name = "PlinthCap", Size = Vector3.new(10, 0.6, 10), CFrame = facingCentre(position + Vector3.new(0, 4.7, 0)), Color = GOLD, Material = Enum.Material.Metal }, model)
	return facingCentre(position + Vector3.new(0, 5, 0))
end

local function buildLamps(model: Model)
	for index = 0, 11 do
		local angle = (index + 0.5) / 12 * 2 * math.pi
		local base = around(PLAZA_RADIUS - 4, angle, 0.4)
		upright("LampPost", 0.35, 12, base, IRON, Enum.Material.Metal, model)
		upright("LampBase", 0.9, 1, base, IRON, Enum.Material.Metal, model)
		local globe = part({
			Name = "LampGlobe",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.new(base + Vector3.new(0, 13, 0)),
			Color = Color3.fromRGB(255, 224, 170),
			Material = Enum.Material.Neon,
		}, model)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 150)
		light.Range = 26
		light.Brightness = 1.4
		light.Shadows = true
		light.Parent = globe
	end
end

local function buildColonnade(model: Model)
	local count = 24
	for index = 0, count - 1 do
		local angle = index / count * 2 * math.pi
		-- Leave the four compass paths open.
		local nearPath = false
		for path = 0, 3 do
			local diff = math.abs(((angle - path * math.pi / 2) + math.pi) % (2 * math.pi) - math.pi)
			if diff < 0.12 then
				nearPath = true
			end
		end
		local base = around(PLAZA_RADIUS + 6, angle, 0.4)
		if nearPath then
			continue
		end
		upright("Column", 1.4, 16, base, MARBLE, Enum.Material.Marble, model)
		part({ Name = "ColumnBase", Size = Vector3.new(3.6, 1, 3.6), CFrame = facingCentre(base + Vector3.new(0, 0.5, 0)), Color = MARBLE_DARK, Material = Enum.Material.Marble }, model)
		part({ Name = "Capital", Size = Vector3.new(3.8, 1.2, 3.8), CFrame = facingCentre(base + Vector3.new(0, 16.6, 0)), Color = GOLD, Material = Enum.Material.Metal }, model)
		-- Hedges between columns.
		local nextAngle = (index + 0.5) / count * 2 * math.pi
		local hedge = around(PLAZA_RADIUS + 6, nextAngle, 2)
		part({ Name = "Hedge", Size = Vector3.new(14, 3.2, 3.2), CFrame = facingCentre(hedge) * CFrame.Angles(0, math.pi / 2, 0), Color = HEDGE, Material = Enum.Material.Grass }, model)
	end
end

local function buildBoards(model: Model)
	local boards = {
		{ id = "wins", title = "RANKED WINS", angle = -math.pi / 2 - 0.42 },
		{ id = "elo", title = "TOP ELO", angle = -math.pi / 2 },
		{ id = "streak", title = "BEST WIN STREAK", angle = -math.pi / 2 + 0.42 },
	}
	for _, info in boards do
		local position = around(PLAZA_RADIUS - 14, info.angle, 0.4)
		local frame = facingCentre(position + Vector3.new(0, 9.5, 0))
		part({ Name = "BoardPost", Size = Vector3.new(1, 9, 1), CFrame = frame * CFrame.new(-6.5, -5, 0.6), Color = IRON, Material = Enum.Material.Metal }, model)
		part({ Name = "BoardPost", Size = Vector3.new(1, 9, 1), CFrame = frame * CFrame.new(6.5, -5, 0.6), Color = IRON, Material = Enum.Material.Metal }, model)
		part({ Name = "BoardFrame", Size = Vector3.new(15.4, 11.4, 0.8), CFrame = frame * CFrame.new(0, 0, 0.3), Color = GOLD, Material = Enum.Material.Metal }, model)
		local board = part({ Name = `Leaderboard_{info.id}`, Size = Vector3.new(14.6, 10.6, 0.6), CFrame = frame, Color = Color3.fromRGB(20, 26, 42), Material = Enum.Material.SmoothPlastic }, model)
		board:SetAttribute("Board", info.id)
		board:SetAttribute("Title", info.title)
		CollectionService:AddTag(board, LobbyBuilder.BOARD_TAG)
	end
end

local function buildKiosks(model: Model)
	for _, angle in { math.pi / 2 - 0.5, math.pi / 2 + 0.5 } do
		local position = around(PLAZA_RADIUS - 20, angle, 0.4)
		local frame = facingCentre(position + Vector3.new(0, 2.5, 0))
		part({ Name = "KioskBase", Size = Vector3.new(5, 5, 3), CFrame = frame, Color = MARBLE_DARK, Material = Enum.Material.Marble }, model)
		local screen = part({ Name = "KioskScreen", Size = Vector3.new(4.4, 2.6, 0.3), CFrame = frame * CFrame.new(0, 3.6, -0.6) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(47, 191, 113), Material = Enum.Material.Neon }, model)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		gui.Parent = screen
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "PLAY"
		label.Parent = gui
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Find a game"
		prompt.ObjectText = "Casual games"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.Parent = screen
		CollectionService:AddTag(prompt, LobbyBuilder.KIOSK_TAG)
	end
end

local function buildSpawn(model: Model)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = facingCentre(around(PLAZA_RADIUS - 24, math.pi / 2, 0.6))
	spawn.Color = MARBLE_DARK
	spawn.Material = Enum.Material.Marble
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

-- Statues: the game's own models, scaled up on plinths (placed when Assets has loaded them).
local function buildStatues(model: Model)
	local statues = {
		{ kind = "Buildings", shape = "Hotel", height = 14, color = { Body = Color3.fromRGB(176, 18, 26), Roof = Color3.fromRGB(110, 12, 18), Trim = Color3.fromRGB(240, 230, 208) } },
		{ kind = "Emblems", shape = "Locomotive", height = 9 },
		{ kind = "Emblems", shape = "Question", height = 12 },
		{ kind = "Buildings", shape = "House", height = 10, color = { Body = Color3.fromRGB(196, 28, 32), Roof = Color3.fromRGB(110, 12, 18), Trim = Color3.fromRGB(240, 230, 208) } },
		{ kind = "Emblems", shape = "Chest", height = 9 },
		{ kind = "Emblems", shape = "Bulb", height = 12 },
	}
	local stands = {}
	for index, _ in statues do
		local angle = (index - 1) / #statues * 2 * math.pi + math.pi / 6
		table.insert(stands, buildPlinth(around(64, angle, 0), model))
	end
	task.spawn(function()
		local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
		local assets = ReplicatedStorage:WaitForChild("Assets", 60)
		if not assets then
			return
		end
		for index, statue in statues do
			local folder = assets:WaitForChild(statue.kind, 60)
			local source = folder and folder:WaitForChild(statue.shape, 30)
			if not (source and source:IsA("Model")) then
				continue
			end
			local clone = source:Clone()
			if statue.kind == "Emblems" then
				EmblemLook.apply(clone, statue.shape)
			else
				for _, child in clone:GetDescendants() do
					if child:IsA("BasePart") then
						child.Anchored = true
						child.Color = (statue.color :: any)[child.Name] or child.Color
						child.Material = Enum.Material.SmoothPlastic
					end
				end
			end
			local box, size = clone:GetBoundingBox()
			clone.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
			clone:ScaleTo(statue.height / size.Y)
			clone:PivotTo(stands[index])
			clone.Name = `Statue{statue.shape}`
			clone.Parent = model
		end
		-- The giant die atop the fountain, turned by LobbyFx.
		local dice = assets:WaitForChild("Dice", 60)
		local die = dice and dice:WaitForChild("Rounded", 30)
		if die and die:IsA("Model") then
			local clone = die:Clone()
			for _, child in clone:GetDescendants() do
				if child:IsA("BasePart") then
					child.Anchored = true
					child.Color = if child.Name == "Body" then Color3.fromRGB(250, 246, 236) else Color3.fromRGB(22, 22, 26)
					child.Material = Enum.Material.SmoothPlastic
				end
			end
			local box = clone:GetBoundingBox()
			clone.WorldPivot = box
			clone:ScaleTo(6 / 1.2)
			clone:PivotTo(CFrame.new(LobbyBuilder.CENTRE + Vector3.new(0, 16, 0)) * CFrame.Angles(math.rad(35), 0, math.rad(45)))
			clone.Name = "GiantDie"
			clone.Parent = model
			CollectionService:AddTag(clone, LobbyBuilder.SPIN_TAG)
		end
	end)
end

local function setLighting()
	Lighting.ClockTime = 16.6
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.Ambient = Color3.fromRGB(118, 108, 112) -- the hall is roofed: lift the shade
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 165)
	local function ensure(className: string): Instance
		local existing = Lighting:FindFirstChildOfClass(className)
		if existing then
			return existing
		end
		local effect = Instance.new(className)
		effect.Parent = Lighting
		return effect
	end
	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(255, 226, 196)
	atmosphere.Decay = Color3.fromRGB(120, 140, 190)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2
	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 1.6
	local rays = ensure("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local grade = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	grade.Saturation = 0.08
	grade.Contrast = 0.06
	grade.TintColor = Color3.fromRGB(255, 248, 238)
end

-- The grand hall around the plaza: a ring of marble wall with tall windows between gold
-- pilasters, a ribbed dome with a glass oculus, chandeliers, wall sconces and red carpet runners.
local function buildEnclosure(model: Model)
	local segments = 40
	local segmentWidth = 2 * math.pi * HALL_RADIUS / segments + 0.6
	for index = 0, segments - 1 do
		local angle = (index + 0.5) / segments * 2 * math.pi
		local base = around(HALL_RADIUS, angle, 0.4)
		local face = facingCentre(base)
		local isDoor = index % 10 == 0 -- four grand doorways (closed, decorative)
		part({ Name = "WallBase", Size = Vector3.new(segmentWidth, 8, 3), CFrame = face * CFrame.new(0, 4, 0), Color = MARBLE_DARK, Material = Enum.Material.Marble }, model)
		if isDoor then
			part({ Name = "Door", Size = Vector3.new(segmentWidth - 4, 26, 1.5), CFrame = face * CFrame.new(0, 8 + 13, 0.6), Color = Color3.fromRGB(92, 52, 34), Material = Enum.Material.Wood }, model)
			part({ Name = "DoorFrame", Size = Vector3.new(segmentWidth, 4, 3.2), CFrame = face * CFrame.new(0, 8 + 28, 0), Color = GOLD, Material = Enum.Material.Metal }, model)
		else
			part({ Name = "Window", Size = Vector3.new(segmentWidth - 2, 30, 0.6), CFrame = face * CFrame.new(0, 8 + 15, 0), Color = Color3.fromRGB(190, 220, 240), Material = Enum.Material.Glass, Transparency = 0.55 }, model)
		end
		part({ Name = "WallTop", Size = Vector3.new(segmentWidth, 8, 3), CFrame = face * CFrame.new(0, WALL_HEIGHT - 4, 0), Color = MARBLE, Material = Enum.Material.Marble }, model)
		-- A gold pilaster on the seam to the next segment, with a sconce on it.
		local seam = facingCentre(around(HALL_RADIUS - 0.4, (index + 1) / segments * 2 * math.pi, 0.4))
		part({ Name = "Pilaster", Size = Vector3.new(2, WALL_HEIGHT, 3.6), CFrame = seam * CFrame.new(0, WALL_HEIGHT / 2, 0), Color = GOLD, Material = Enum.Material.Metal }, model)
		if index % 2 == 0 then
			local sconce = part({ Name = "Sconce", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = seam * CFrame.new(0, 18, -2.4), Color = Color3.fromRGB(255, 226, 170), Material = Enum.Material.Neon }, model)
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 205, 150)
			glow.Range = 20
			glow.Brightness = 1.2
			glow.Parent = sconce
		end
	end

	-- The dome: rings of panels rising from the wall to an open glass oculus, with gold ribs.
	local rings = 7
	local panels = 32
	local oculus = 0.2 -- of the hall's radius left open at the top
	for ring = 0, rings - 1 do
		local t0, t1 = ring / rings, (ring + 1) / rings
		local a0, a1 = t0 * math.acos(oculus), t1 * math.acos(oculus)
		local r0, r1 = HALL_RADIUS * math.cos(a0), HALL_RADIUS * math.cos(a1)
		local y0, y1 = WALL_HEIGHT + DOME_HEIGHT * math.sin(a0), WALL_HEIGHT + DOME_HEIGHT * math.sin(a1)
		local width = 2 * math.pi * (r0 + r1) / 2 / panels + 0.8
		for index = 0, panels - 1 do
			local angle = (index + 0.5) / panels * 2 * math.pi
			local low = Vector3.new(LobbyBuilder.CENTRE.X + math.cos(angle) * r0, y0, LobbyBuilder.CENTRE.Z + math.sin(angle) * r0)
			local high = Vector3.new(LobbyBuilder.CENTRE.X + math.cos(angle) * r1, y1, LobbyBuilder.CENTRE.Z + math.sin(angle) * r1)
			local length = (high - low).Magnitude + 0.6
			part({
				Name = "Dome",
				Size = Vector3.new(width, 1.2, length),
				CFrame = CFrame.lookAt((low + high) / 2, high),
				Color = if ring % 2 == 0 then Color3.fromRGB(246, 240, 228) else Color3.fromRGB(236, 228, 214),
				Material = Enum.Material.SmoothPlastic,
			}, model)
			if index % 4 == 0 then
				part({ Name = "Rib", Size = Vector3.new(1.2, 1.6, length), CFrame = CFrame.lookAt((low + high) / 2, high) * CFrame.Angles(0, math.pi / panels, 0), Color = GOLD, Material = Enum.Material.Metal }, model)
			end
		end
	end
	local top = WALL_HEIGHT + DOME_HEIGHT * math.sin(math.acos(oculus))
	local skylight = part({
		Name = "Oculus",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, HALL_RADIUS * oculus * 2 + 2, HALL_RADIUS * oculus * 2 + 2),
		CFrame = CFrame.new(LobbyBuilder.CENTRE + Vector3.new(0, top, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
	}, model)
	skylight.CastShadow = false

	-- Chandeliers: one over the fountain, four over the plaza.
	local spots = { Vector3.new(0, 0, 0) }
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		table.insert(spots, Vector3.new(math.cos(angle) * 62, 0, math.sin(angle) * 62))
	end
	for index, spot in spots do
		local hang = if index == 1 then 52 else 34
		local centre = LobbyBuilder.CENTRE + spot + Vector3.new(0, hang, 0)
		part({ Name = "Chain", Size = Vector3.new(0.3, top - hang, 0.3), CFrame = CFrame.new(centre + Vector3.new(0, (top - hang) / 2, 0)), Color = GOLD, Material = Enum.Material.Metal }, model)
		local ringSize = if index == 1 then 9 else 6
		for bulb = 0, 11 do
			local a = bulb / 12 * 2 * math.pi
			part({ Name = "Crystal", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * ringSize, 0, math.sin(a) * ringSize)), Color = Color3.fromRGB(255, 236, 190), Material = Enum.Material.Neon }, model)
		end
		local core = part({ Name = "ChandelierCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(centre), Color = GOLD, Material = Enum.Material.Metal }, model)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 218, 170)
		glow.Range = 60
		glow.Brightness = if index == 1 then 2.4 else 1.8
		glow.Shadows = true
		glow.Parent = core
	end

	-- Red carpet runners from each doorway to the fountain.
	for index = 0, 3 do
		local angle = (index * 10 + 0.5) / segments * 2 * math.pi
		local outer = around(HALL_RADIUS - 2, angle, 0.5)
		local inner = around(18, angle, 0.5)
		part({ Name = "Carpet", Size = Vector3.new(10, 0.15, (outer - inner).Magnitude), CFrame = CFrame.lookAt((outer + inner) / 2, inner), Color = Color3.fromRGB(150, 22, 34), Material = Enum.Material.Fabric }, model)
		part({ Name = "CarpetEdge", Size = Vector3.new(11.2, 0.12, (outer - inner).Magnitude), CFrame = CFrame.lookAt((outer + inner) / 2, inner) * CFrame.new(0, -0.02, 0), Color = GOLD, Material = Enum.Material.Metal }, model)
	end
end

function LobbyBuilder.build(parent: Instance): Model
	local existing = parent:FindFirstChild(LobbyBuilder.MODEL_NAME)
	if existing then
		existing:Destroy()
	end
	-- The place's default spawn sat under the board's centre (its star showed through); the lobby
	-- has its own.
	for _, child in parent:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = LobbyBuilder.MODEL_NAME
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	buildGround(model)
	buildFountain(model)
	buildLamps(model)
	buildColonnade(model)
	buildEnclosure(model)
	buildBoards(model)
	buildKiosks(model)
	buildSpawn(model)
	buildStatues(model)
	setLighting()
	model.Parent = parent
	return model
end

return LobbyBuilder
