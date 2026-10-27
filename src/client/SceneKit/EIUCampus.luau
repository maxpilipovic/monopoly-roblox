--!strict
-- EIU Campus: the table stands on the Library Quad lawn at Eastern Illinois University on an
-- autumn evening. Old Main's limestone towers rise behind it with lit windows; Booth Library's
-- gothic front on one side, Doudna's angular glass on the other; the campus pond with a fountain,
-- the panther statue on its plinth, brick paths with iron lamps flying blue and grey banners,
-- trees in full autumn colour, O'Brien Field's light towers in the distance, and leaves drifting
-- down. No logos: the banners are plain colours.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Table = require(script.Parent.Table)

local G = Kit.GROUND
local LAWN_TOP = G + 2 -- terrain snaps to a 4-stud grid: the filled lawn's surface sits here
local LIMESTONE = Color3.fromRGB(214, 202, 176)
local LIMESTONE_DARK = Color3.fromRGB(184, 172, 148)
local SLATE = Color3.fromRGB(66, 74, 88)
local BRICK = Color3.fromRGB(150, 76, 58)
local IRON = Color3.fromRGB(30, 30, 36)
local WARM = Color3.fromRGB(255, 206, 140)
local EIU_BLUE = Color3.fromRGB(0, 62, 140)
local EIU_GREY = Color3.fromRGB(170, 176, 186)
local BRONZE = Color3.fromRGB(128, 100, 66)
local AUTUMN = {
	Color3.fromRGB(214, 96, 34),
	Color3.fromRGB(196, 54, 36),
	Color3.fromRGB(232, 164, 44),
	Color3.fromRGB(170, 70, 40),
	Color3.fromRGB(150, 120, 50),
}

local OLD_MAIN = Vector3.new(0, G, -165)
local LIBRARY = Vector3.new(-150, G, -30)
local DOUDNA = Vector3.new(155, G, -40)
local POND = Vector3.new(105, G, 105)
local PANTHER = Vector3.new(66, G, 140)

-- An uploaded Blender model from ReplicatedStorage.Assets.Scenery (tinted: uploads lose their colours), stood on `base` at `height`
-- studs tall facing `yaw`; nil when it hasn't loaded (the caller builds its own).
local function scenery(name: string, base: Vector3, height: number, yaw: number, color: Color3, material: Enum.Material, parent: Instance): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Scenery")
	local source = folder and folder:FindFirstChild(name)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.Color = color
			part.Material = material
		end
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
	model:ScaleTo(height / size.Y)
	model:PivotTo(CFrame.new(base) * CFrame.Angles(0, yaw, 0))
	model.Parent = parent
	return model
end

local function ground(random: Random)
	Kit.fillBlock(CFrame.new(0, G - 10, 0), Vector3.new(2600, 20, 2600), Enum.Material.Grass)
	for _ = 1, 14 do
		local a = random:NextNumber(0, 2 * math.pi)
		local r = random:NextNumber(330, 560)
		Kit.mound(Vector3.new(math.cos(a) * r, G, math.sin(a) * r), random:NextNumber(50, 110), random:NextNumber(4, 14), Enum.Material.Grass)
	end
end

-- Brick paths across the quad: one to Old Main's door, one from the library to Doudna.
local function paths(model: Instance)
	Kit.block("Path", Vector3.new(16, 0.6, 100), CFrame.new(0, LAWN_TOP + 0.3, -100), BRICK, Enum.Material.Brick, model)
	Kit.block("Path", Vector3.new(300, 0.6, 14), CFrame.new(0, LAWN_TOP + 0.3, -78), BRICK, Enum.Material.Brick, model)
	Kit.block("Path", Vector3.new(16, 0.6, 160), CFrame.new(0, LAWN_TOP + 0.3, 140), BRICK, Enum.Material.Brick, model)
	Kit.block("Path", Vector3.new(14, 0.6, 120), CFrame.new(POND.X - 40, LAWN_TOP + 0.3, POND.Z - 20) * CFrame.Angles(0, math.rad(-45), 0), BRICK, Enum.Material.Brick, model)
end

-- Old Main: the turreted limestone castle, a tall central tower over the door, slate roofs.
local function oldMain(model: Instance)
	if scenery("OldMain", OLD_MAIN, 92, math.pi, LIMESTONE, Enum.Material.Limestone, model) then
		return
	end
	local group = Kit.group("OldMain", model)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(OLD_MAIN + Vector3.new(x, y, z))
	end
	local width, depth, height = 150, 34, 38
	Kit.block("Wing", Vector3.new(width, height, depth), at(0, height / 2, 0), LIMESTONE, Enum.Material.Limestone, group)
	Kit.block("Plinth", Vector3.new(width + 2, 3, depth + 2), at(0, 1.5, 0), LIMESTONE_DARK, Enum.Material.Limestone, group)
	-- The roof: a long slate ridge.
	Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(width, 18, depth / 2), CFrame = at(0, height + 9, -depth / 4) * CFrame.Angles(0, math.pi, 0), Color = SLATE, Material = Enum.Material.Slate }, group)
	Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(width, 18, depth / 2), CFrame = at(0, height + 9, depth / 4), Color = SLATE, Material = Enum.Material.Slate }, group)
	-- The central tower, crenellated, with a steep pyramid cap.
	local tower = 26
	local towerHeight = 72
	Kit.block("Tower", Vector3.new(tower, towerHeight, tower), at(0, towerHeight / 2, depth / 2), LIMESTONE, Enum.Material.Limestone, group)
	for i = 0, 4 do
		for _, side in { -1, 1 } do
			Kit.block("Merlon", Vector3.new(3.4, 4, 3.4), at(-tower / 2 + 1.7 + i * (tower - 3.4) / 4, towerHeight + 2, depth / 2 + side * (tower / 2 - 1.7)), LIMESTONE_DARK, Enum.Material.Limestone, group)
			Kit.block("Merlon", Vector3.new(3.4, 4, 3.4), at(side * (tower / 2 - 1.7), towerHeight + 2, depth / 2 - tower / 2 + 1.7 + i * (tower - 3.4) / 4), LIMESTONE_DARK, Enum.Material.Limestone, group)
		end
	end
	Kit.pyramid("TowerCap", OLD_MAIN + Vector3.new(0, towerHeight + 4, depth / 2), tower - 6, 22, SLATE, Enum.Material.Slate, group)
	-- Round turrets with conical caps at the corners and beside the tower.
	for _, x in { -width / 2, -tower / 2 - 6, tower / 2 + 6, width / 2 } do
		local turretHeight = if math.abs(x) > 50 then 52 else 60
		Kit.cylinder("Turret", 7, turretHeight, OLD_MAIN + Vector3.new(x, 0, depth / 2), LIMESTONE, Enum.Material.Limestone, group)
		Kit.cone("TurretCap", OLD_MAIN + Vector3.new(x, turretHeight, depth / 2), 8.5, 18, 12, { SLATE }, Enum.Material.Slate, group)
	end
	-- Warm windows in rows on the front face, and the arched door under the tower.
	for row = 0, 2 do
		for i = -6, 6 do
			if math.abs(i) > 1 then
				Kit.glow("Window", Vector3.new(3.4, 6, 0.4), at(i * 10.5, 8 + row * 11, depth / 2 + 0.2), WARM, group)
			end
		end
	end
	for row = 0, 4 do
		Kit.glow("Window", Vector3.new(4, 7, 0.4), at(0, 20 + row * 10, depth / 2 + tower / 2 + 0.2), WARM, group)
	end
	local door = Kit.glow("Door", Vector3.new(8, 12, 0.4), at(0, 6, depth / 2 + tower / 2 + 0.2), WARM, group)
	Kit.pointLight(door, WARM, 40, 1.4)
end

-- Booth Library: a gothic front with tall pointed windows and a steep gable.
local function library(model: Instance)
	local group = Kit.group("BoothLibrary", model)
	local yaw = math.rad(90)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(LIBRARY) * CFrame.Angles(0, yaw, 0) * CFrame.new(x, y, z)
	end
	Kit.block("Hall", Vector3.new(90, 30, 40), at(0, 15, 0), LIMESTONE, Enum.Material.Limestone, group)
	Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(90, 16, 20), CFrame = at(0, 38, 10), Color = SLATE, Material = Enum.Material.Slate }, group)
	Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(90, 16, 20), CFrame = at(0, 38, -10) * CFrame.Angles(0, math.pi, 0), Color = SLATE, Material = Enum.Material.Slate }, group)
	for i = -3, 3 do
		Kit.glow("Window", Vector3.new(5, 18, 0.4), at(i * 12, 16, 20.2), WARM, group)
		Kit.pyramid("Arch", (at(i * 12, 25, 20.4)).Position, 5, 4, LIMESTONE_DARK, Enum.Material.Limestone, group)
		Kit.block("Buttress", Vector3.new(2.4, 28, 3), at(i * 12 + 6, 14, 21.5), LIMESTONE_DARK, Enum.Material.Limestone, group)
	end
end

-- Doudna Fine Arts Center: leaning glass and stone volumes, lit from inside.
local function doudna(model: Instance)
	local group = Kit.group("Doudna", model)
	local base = CFrame.new(DOUDNA) * CFrame.Angles(0, math.rad(-80), 0)
	Kit.block("Stone", Vector3.new(80, 26, 44), base * CFrame.new(0, 13, 0), Color3.fromRGB(176, 150, 120), Enum.Material.Sandstone, group)
	local glass = Kit.block("Glass", Vector3.new(40, 34, 30), base * CFrame.new(-18, 17, 14) * CFrame.Angles(math.rad(-8), 0, math.rad(6)), Color3.fromRGB(150, 190, 210), Enum.Material.Glass, group)
	glass.Transparency = 0.35
	Kit.glow("Lobby", Vector3.new(36, 22, 26), base * CFrame.new(-18, 12, 13), WARM, group).Transparency = 0.5
	Kit.block("Blade", Vector3.new(6, 46, 30), base * CFrame.new(26, 21, 4) * CFrame.Angles(0, 0, math.rad(-10)), Color3.fromRGB(120, 104, 90), Enum.Material.Slate, group)
	Kit.pointLight(glass, WARM, 50, 1.2)
end

-- The campus pond, with a fountain at its centre.
local function pond(ctx: Kit.Context)
	-- Water only fills air: dig the pond out of the lawn first.
	Kit.fillCylinder(Vector3.new(POND.X, LAWN_TOP - 2, POND.Z), 4, 46, Enum.Material.Air)
	Kit.fillCylinder(Vector3.new(POND.X, LAWN_TOP - 3, POND.Z), 2, 46, Enum.Material.Water)
	Kit.fillCylinder(Vector3.new(POND.X, LAWN_TOP - 6, POND.Z), 4, 48, Enum.Material.Mud)
	ctx.water({ WaterColor = Color3.fromRGB(40, 80, 90), WaterReflectance = 0.5, WaterTransparency = 0.6, WaterWaveSize = 0.08, WaterWaveSpeed = 6 })
	local jet = Kit.block("Fountain", Vector3.new(1, 1, 1), CFrame.new(POND.X, LAWN_TOP, POND.Z), LIMESTONE, Enum.Material.Limestone, ctx.model)
	Kit.emitter(jet, {
		Texture = Kit.SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 1.8),
		Speed = NumberRange.new(16, 20),
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, -24, 0),
		Rate = 80,
		EmissionDirection = Enum.NormalId.Top,
	})
end

-- The panther on its plinth (the Blender model when it has loaded; a simple crouching cat if not).
local function panther(model: Instance)
	Kit.block("Plinth", Vector3.new(12, 6, 8), CFrame.new(PANTHER + Vector3.new(0, 3, 0)), LIMESTONE_DARK, Enum.Material.Limestone, model)
	local top = PANTHER + Vector3.new(0, 6, 0)
	if scenery("Panther", top, 9, math.rad(200), BRONZE, Enum.Material.Metal, model) then -- facing the table
		return
	end
	local group = Kit.group("Panther", model)
	Kit.ball("Body", top + Vector3.new(0, 3, 0), 6, BRONZE, Enum.Material.Metal, group).Size = Vector3.new(9, 4.5, 4.5)
	Kit.ball("Head", top + Vector3.new(-4.8, 5.4, 0), 3.4, BRONZE, Enum.Material.Metal, group)
	for _, x in { -3, 3 } do
		for _, z in { -1.4, 1.4 } do
			Kit.cylinder("Leg", 0.7, 2.5, top + Vector3.new(x, 0, z), BRONZE, Enum.Material.Metal, group)
		end
	end
	Kit.rod("Tail", top + Vector3.new(4.4, 3, 0), top + Vector3.new(6.5, 6.5, 0.5), 0.5, BRONZE, Enum.Material.Metal, group)
end

local function tree(model: Instance, base: Vector3, random: Random)
	local height = random:NextNumber(26, 42)
	Kit.cylinder("Trunk", random:NextNumber(1, 1.6), height * 0.6, base, Color3.fromRGB(80, 58, 40), Enum.Material.Wood, model)
	local colour = AUTUMN[random:NextInteger(1, #AUTUMN)]
	for _ = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-4, 4), height * random:NextNumber(0.62, 0.85), random:NextNumber(-4, 4))
		Kit.ball("Leaves", base + offset, random:NextNumber(14, 22), colour, Enum.Material.Grass, model)
	end
end

local function trees(ctx: Kit.Context)
	local group = Kit.group("Trees", ctx.model)
	local random = ctx.random
	local placed = 0
	while placed < 90 do
		local a = random:NextNumber(0, 2 * math.pi)
		local r = random:NextNumber(90, 420)
		local spot = Vector3.new(math.cos(a) * r, G, math.sin(a) * r)
		-- Keep clear of the buildings, the pond, the paths and the view over the board.
		local clear = (spot - OLD_MAIN).Magnitude > 110
			and (spot - LIBRARY).Magnitude > 60
			and (spot - DOUDNA).Magnitude > 60
			and (spot - POND).Magnitude > 58
			and (math.abs(spot.X) > 75 or math.abs(spot.Z) > 75)
			and math.abs(spot.X) > 20
		if clear then
			tree(group, spot, random)
			placed += 1
		end
	end
end

-- A far ring of trees closing the quad in, so the horizon is woods rather than open ground.
local function treeLine(ctx: Kit.Context)
	local group = Kit.group("TreeLine", ctx.model)
	local random = ctx.random
	for i = 1, 110 do
		local a = (i + random:NextNumber(-0.4, 0.4)) / 110 * 2 * math.pi
		local r = random:NextNumber(470, 620)
		tree(group, Vector3.new(math.cos(a) * r, G, math.sin(a) * r), random)
	end
end

-- Iron lamp posts along the paths, each flying an EIU blue and a grey banner; they flicker gently.
local function lamps(ctx: Kit.Context)
	local group = Kit.group("Lamps", ctx.model)
	local lights: { PointLight } = {}
	local spots = { { -66, 66 }, { 66, 66 }, { -66, -66 }, { 66, -66 }, { -14, -105 }, { 14, -105 }, { -14, -135 }, { 14, -135 }, { -110, -86 }, { 110, -86 }, { -14, 110 }, { 14, 110 } }
	for index, spot in spots do
		local base = Vector3.new(spot[1], G, spot[2])
		Kit.cylinder("Post", 0.5, 16, base, IRON, Enum.Material.Metal, group)
		local head = Kit.glow("Lamp", Vector3.new(2.2, 2.6, 2.2), CFrame.new(base + Vector3.new(0, 17, 0)), WARM, group)
		table.insert(lights, Kit.pointLight(head, WARM, 30, 1.1))
		local side = if index % 2 == 0 then 1 else -1
		Kit.block("Banner", Vector3.new(0.2, 5, 2.4), CFrame.new(base + Vector3.new(0, 11, side * 1.4)), if index % 2 == 0 then EIU_BLUE else EIU_GREY, Enum.Material.Fabric, group)
	end
	ctx.animate(function(t)
		for index, light in lights do
			light.Brightness = 1.05 + math.noise(index * 3.1, t * 1.5) * 0.25
		end
	end)
end

-- O'Brien Field's light towers glowing over the trees in the distance.
local function stadiumLights(model: Instance)
	local group = Kit.group("OBrienField", model)
	local centre = Vector3.new(-330, G, 300)
	for _, offset in { Vector3.new(-90, 0, -50), Vector3.new(90, 0, -50), Vector3.new(-90, 0, 50), Vector3.new(90, 0, 50) } do
		local base = centre + offset
		Kit.cylinder("Pole", 1.6, 80, base, Color3.fromRGB(90, 92, 100), Enum.Material.Metal, group)
		local bank = Kit.glow("Lights", Vector3.new(14, 7, 2), CFrame.lookAt(base + Vector3.new(0, 84, 0), centre + Vector3.new(0, 40, 0)), Color3.fromRGB(240, 248, 255), group)
		Kit.pointLight(bank, Color3.fromRGB(240, 248, 255), 60, 1.5)
	end
end

local function leaves(model: Instance)
	local cloud = Kit.block("LeafCloud", Vector3.new(220, 1, 220), CFrame.new(0, G + 60, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, model)
	cloud.Transparency = 1
	Kit.emitter(cloud, {
		Texture = Kit.SPARKLE,
		Color = ColorSequence.new(AUTUMN[1], AUTUMN[3]),
		Size = NumberSequence.new(0.5),
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(2, 4),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Acceleration = Vector3.new(1.5, -1.2, 0.6),
		Rate = 14,
		EmissionDirection = Enum.NormalId.Bottom,
	})
end

return function(ctx: Kit.Context)
	local model = ctx.model
	Table.build({ top = Color3.fromRGB(96, 64, 44), edge = Color3.fromRGB(78, 52, 36), legs = Color3.fromRGB(70, 46, 32), inlay = EIU_GREY, keyLight = 1.4 }, model)
	ground(ctx.random)
	paths(model)
	oldMain(model)
	library(model)
	doudna(model)
	pond(ctx)
	panther(model)
	trees(ctx)
	treeLine(ctx)
	lamps(ctx)
	stadiumLights(model)
	leaves(model)
	local sky = Instance.new("Sky")
	sky.StarCount = 1500
	sky.Parent = model
end
