--!strict
-- Tropical Island: the table stands on a beach deck on a white-sand island at sunset. Curving palms
-- sway in the breeze, tiki torches flicker, a thatched tiki bar, striped umbrellas and loungers,
-- a sandcastle, a dock with a moored sailboat, clear turquoise shallows, gulls wheeling overhead,
-- and a volcano smoking on a far island.

local Kit = require(script.Parent.Kit)
local Table = require(script.Parent.Table)

local G = Kit.GROUND
local SEA = G - 6
local SAND = G - 3 -- the beach surface, a little under the deck
local BAMBOO = Color3.fromRGB(196, 160, 96)
local THATCH = Color3.fromRGB(196, 160, 92)
local PLANK = Color3.fromRGB(176, 132, 90)
local WHITE = Color3.fromRGB(250, 248, 240)

-- Swaying fronds: every leaf part, its pivot (the frond's root) and its offset from it.
type Sway = { parts: { BasePart }, offsets: { CFrame }, pivots: { CFrame }, phases: { number }, cframes: { CFrame } }

local function island(random: Random)
	-- The sea, the sea bed, then the island rising in rings so the beach shelves into the water.
	Kit.fillBlock(CFrame.new(0, SEA - 30, 0), Vector3.new(2000, 60, 2000), Enum.Material.Water)
	Kit.fillBlock(CFrame.new(0, SEA - 62, 0), Vector3.new(2000, 4, 2000), Enum.Material.Sand)
	local bottom = SEA - 60
	for ring = 0, 7 do
		local radius = 240 - ring * 14
		local top = SEA - 10 + ring * 1.8
		Kit.fillCylinder(Vector3.new(0, (bottom + top) / 2, -20), top - bottom, radius, Enum.Material.Sand)
	end
	Kit.fillCylinder(Vector3.new(0, (bottom + SAND) / 2, -20), SAND - bottom, 150, Enum.Material.Sand)
	-- Dunes and grass behind the beach, rocks at the water's edge.
	for _ = 1, 10 do
		local a = random:NextNumber(math.rad(200), math.rad(340))
		local r = random:NextNumber(90, 150)
		Kit.mound(Vector3.new(math.cos(a) * r, SAND, math.sin(a) * r - 20), random:NextNumber(26, 40), random:NextNumber(3, 7), Enum.Material.LeafyGrass)
	end
	for _ = 1, 9 do
		local a = random:NextNumber(0, 2 * math.pi)
		local r = random:NextNumber(180, 215)
		Kit.mound(Vector3.new(math.cos(a) * r, SEA, math.sin(a) * r - 20), random:NextNumber(6, 12), random:NextNumber(3, 7), Enum.Material.Basalt)
	end
	-- Last: clear the sand under the deck so it never shows through the planks.
	Kit.fillBlock(CFrame.new(0, G + 4, 0), Vector3.new(126, 15.2, 126), Enum.Material.Air)
	workspace.Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 222, 176))
	workspace.Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(96, 150, 62))
end

local function palm(ctx: Kit.Context, base: Vector3, lean: number, yaw: number, height: number, sway: Sway)
	local model, random = ctx.model, ctx.random
	local position = base
	local direction = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-lean, 0, 0)
	local segments = math.floor(height / 2.6)
	for segment = 1, segments do
		local f = segment / segments
		local step = direction:VectorToWorldSpace(Vector3.new(0, 2.6, 0))
		local radius = 1.15 - f * 0.45
		Kit.rod("Trunk", position, position + step, radius, if segment % 2 == 0 then Color3.fromRGB(150, 112, 74) else Color3.fromRGB(128, 94, 62), Enum.Material.Wood, model)
		Kit.rod("TrunkRing", position + step * 0.92, position + step, radius + 0.12, Color3.fromRGB(104, 76, 50), Enum.Material.Wood, model)
		position += step
		direction *= CFrame.Angles(lean * 0.07, 0, 0) -- the trunk curves back up toward the light
	end
	for nut = 0, 3 do
		local a = nut / 4 * 2 * math.pi
		Kit.ball("Coconut", position + Vector3.new(math.cos(a) * 0.9, -0.8, math.sin(a) * 0.9), 1.3, Color3.fromRGB(92, 62, 36), Enum.Material.Wood, model)
	end
	-- The fronds: arching leaves of five segments each, built in their own group to sway.
	local fronds = 10
	for frond = 0, fronds - 1 do
		local a = frond / fronds * 2 * math.pi + random:NextNumber(-0.15, 0.15)
		local old = random:NextNumber() < 0.2
		local green = if old then Color3.fromRGB(150, 150, 70) else Color3.fromHSV(random:NextNumber(0.27, 0.33), 0.6, random:NextNumber(0.5, 0.62))
		local root = CFrame.new(position) * CFrame.Angles(0, a, 0)
		local leafCf = root * CFrame.Angles(math.rad(random:NextNumber(20, 40)), 0, 0)
		local group = Kit.group("Frond", model)
		for leaf = 1, 6 do
			-- Each stretch of frond is a shallow V of two blades either side of the spine.
			local width = 2.9 - leaf * 0.36
			local length = 2.7
			for side = -1, 1, 2 do
				Kit.block("Leaf", Vector3.new(width, 0.12, length + 0.2), leafCf * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, 0, -side * math.rad(24)) * CFrame.new(side * width / 2, 0, 0), green, Enum.Material.Grass, group)
			end
			leafCf = leafCf * CFrame.new(0, 0, -length) * CFrame.Angles(math.rad(-14), 0, 0)
		end
		local phase = random:NextNumber(0, 2 * math.pi)
		for _, d in group:GetChildren() do
			if d:IsA("BasePart") then
				table.insert(sway.parts, d)
				table.insert(sway.offsets, root:ToObjectSpace(d.CFrame))
				table.insert(sway.pivots, root)
				table.insert(sway.phases, phase)
				table.insert(sway.cframes, d.CFrame)
			end
		end
	end
end

local function palms(ctx: Kit.Context)
	local sway: Sway = { parts = {}, offsets = {}, pivots = {}, phases = {}, cframes = {} }
	local spots = {
		{ -70, -70 }, { -95, -30 }, { -100, 25 }, { 95, -60 }, { 105, -10 }, { 80, 55 },
		{ -40, -115 }, { 15, -125 }, { 55, -105 }, { -130, -110 }, { 135, -100 }, { -150, 10 },
		{ 150, 30 }, { -75, 80 }, { -120, -160 }, { 110, -165 }, { -10, -170 }, { 160, -40 },
	}
	for _, spot in spots do
		local base = Vector3.new(spot[1], SAND, spot[2])
		local outward = math.atan2(spot[1], -spot[2]) -- lean away from the table
		palm(ctx, base, ctx.random:NextNumber(0.25, 0.5), -outward, ctx.random:NextNumber(20, 30), sway)
	end
	ctx.animate(function(t)
		for index, part in sway.parts do
			local phase = sway.phases[index]
			local gust = 0.05 + 0.04 * math.sin(t * 0.3)
			sway.cframes[index] = sway.pivots[index] * CFrame.Angles(math.sin(t * 1.4 + phase) * gust, math.sin(t * 0.9 + phase) * 0.03, 0) * sway.offsets[index]
		end
		workspace:BulkMoveTo(sway.parts, sway.cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

local function deck(ctx: Kit.Context)
	local model = ctx.model
	Kit.block("Deck", Vector3.new(120, 3.4, 120), CFrame.new(0, G - 1.7, 0), PLANK, Enum.Material.WoodPlanks, model)
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		local edge = CFrame.Angles(0, yaw, 0)
		Kit.block("DeckEdge", Vector3.new(121, 1, 1.2), edge * CFrame.new(0, G - 0.5, 60), Color3.fromRGB(130, 96, 64), Enum.Material.Wood, model)
		-- Tiki torches at the corners and halfway along each side.
		for _, along in { -58, 0 } do
			local at = edge * Vector3.new(along, 0, 58)
			local base = Vector3.new(at.X, G, at.Z)
			Kit.cylinder("TorchPole", 0.35, 9, base, BAMBOO, Enum.Material.Wood, model)
			for ring = 1, 3 do
				Kit.cylinder("TorchBand", 0.42, 0.25, base + Vector3.new(0, ring * 2.4, 0), Color3.fromRGB(90, 60, 36), Enum.Material.Wood, model)
			end
			Kit.cylinder("TorchCup", 0.8, 1.6, base + Vector3.new(0, 9, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Fabric, model)
			Kit.flame(ctx, base + Vector3.new(0, 11, 0), 1.6, model)
		end
	end
end

local function tikiBar(ctx: Kit.Context, at: CFrame)
	local model = ctx.model
	local function p(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, SAND + y, z)
	end
	for _, corner in { { -11, -8 }, { 11, -8 }, { -11, 8 }, { 11, 8 } } do
		Kit.cylinder("Post", 0.6, 12, p(corner[1], 0, corner[2]).Position, BAMBOO, Enum.Material.Wood, model)
	end
	Kit.block("Bar", Vector3.new(20, 4.4, 3), p(0, 2.2, 6), Color3.fromRGB(150, 100, 60), Enum.Material.Wood, model)
	for slat = -9, 9, 1.5 do
		Kit.cylinder("BarBamboo", 0.6, 4.4, p(slat, 0, 7.8).Position, BAMBOO, Enum.Material.Wood, model)
	end
	Kit.block("BarTop", Vector3.new(22, 0.6, 4.4), p(0, 4.7, 6.2), Color3.fromRGB(120, 76, 44), Enum.Material.Wood, model)
	Kit.block("Shelf", Vector3.new(18, 0.4, 2), p(0, 6, -7), Color3.fromRGB(120, 76, 44), Enum.Material.Wood, model)
	for bottle = -8, 8, 1.6 do
		local colour = Color3.fromHSV((bottle + 8) / 16, 0.6, 0.8)
		Kit.cylinder("Bottle", 0.35, 1.8, p(bottle, 6.2, -7).Position, colour, Enum.Material.Glass, model).Transparency = 0.25
	end
	-- A deep thatched roof, two layers, and a sign.
	local _, yaw = at:ToEulerAnglesYXZ()
	Kit.pyramid("Thatch", p(0, 11.6, 0).Position, 32, 9, THATCH, Enum.Material.Grass, model, yaw)
	Kit.pyramid("Thatch", p(0, 12.6, 0).Position, 26, 8.6, Color3.fromRGB(176, 140, 76), Enum.Material.Grass, model, yaw)
	local sign = Kit.block("Sign", Vector3.new(12, 3.2, 0.5), p(0, 10.4, 8.4), Color3.fromRGB(90, 60, 36), Enum.Material.Wood, model)
	Kit.sign(sign, Enum.NormalId.Back, "TIKI BAR", Color3.fromRGB(255, 220, 120))
	for _, x in { -6, 0, 6 } do
		Kit.cylinder("Stool", 0.25, 3.4, p(x, 0, 11).Position, BAMBOO, Enum.Material.Wood, model)
		Kit.cylinder("Seat", 1.1, 0.5, p(x, 3.4, 11).Position, Color3.fromRGB(200, 60, 50), Enum.Material.Fabric, model)
	end
	local lanterns = { p(-9, 9.6, 9).Position, p(9, 9.6, 9).Position }
	Kit.festoon(lanterns[1], lanterns[2], 1.5, 8, { Color3.fromRGB(255, 120, 80), Color3.fromRGB(255, 220, 110), Color3.fromRGB(120, 230, 160) }, model, 3)
end

local function umbrella(ctx: Kit.Context, base: Vector3, colour: Color3, lounger: boolean)
	local model = ctx.model
	Kit.cylinder("UmbrellaPole", 0.22, 9, base, WHITE, Enum.Material.SmoothPlastic, model)
	Kit.cone("Canopy", base + Vector3.new(0, 8.2, 0), 7, 2.2, 12, { colour, WHITE }, Enum.Material.Fabric, model)
	Kit.ball("Tip", base + Vector3.new(0, 10.6, 0), 0.5, WHITE, Enum.Material.SmoothPlastic, model)
	if lounger then
		for side = -1, 1, 2 do
			local spot = CFrame.new(base + Vector3.new(side * 3, 0, 1))
			Kit.block("LoungerBed", Vector3.new(2.4, 0.4, 7), spot * CFrame.new(0, 1.2, 0), WHITE, Enum.Material.SmoothPlastic, model)
			Kit.block("LoungerBack", Vector3.new(2.4, 0.4, 3), spot * CFrame.new(0, 2.2, -4.2) * CFrame.Angles(math.rad(50), 0, 0), WHITE, Enum.Material.SmoothPlastic, model)
			Kit.block("Towel", Vector3.new(2, 0.1, 5), spot * CFrame.new(0, 1.45, 0.5), colour, Enum.Material.Fabric, model)
			for _, leg in { { -1, -3 }, { 1, -3 }, { -1, 3 }, { 1, 3 } } do
				Kit.block("LoungerLeg", Vector3.new(0.3, 1.2, 0.3), spot * CFrame.new(leg[1], 0.6, leg[2]), WHITE, Enum.Material.SmoothPlastic, model)
			end
		end
	end
end

local function sandcastle(model: Instance, at: Vector3)
	local sand = Color3.fromRGB(226, 200, 150)
	Kit.block("CastleBase", Vector3.new(9, 3, 9), CFrame.new(at + Vector3.new(0, 1.5, 0)), sand, Enum.Material.Sand, model)
	for _, c in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		local base = at + Vector3.new(c[1], 0, c[2])
		Kit.cylinder("Tower", 1.4, 5, base, sand, Enum.Material.Sand, model)
		Kit.cone("TowerTop", base + Vector3.new(0, 5, 0), 1.7, 2, 8, { sand }, Enum.Material.Sand, model)
	end
	Kit.block("Keep", Vector3.new(4, 4, 4), CFrame.new(at + Vector3.new(0, 5, 0)), sand, Enum.Material.Sand, model)
	Kit.rod("FlagPole", at + Vector3.new(0, 7, 0), at + Vector3.new(0, 10, 0), 0.08, WHITE, Enum.Material.Wood, model)
	Kit.block("Flag", Vector3.new(0.05, 0.9, 1.4), CFrame.new(at + Vector3.new(0, 9.5, 0.7)), Color3.fromRGB(240, 70, 70), Enum.Material.Fabric, model)
	Kit.block("Bucket", Vector3.new(2, 2, 2), CFrame.new(at + Vector3.new(7, 1, 2)), Color3.fromRGB(60, 140, 240), Enum.Material.SmoothPlastic, model)
end

local function beachBits(ctx: Kit.Context)
	local model, random = ctx.model, ctx.random
	for _ = 1, 16 do
		local a = random:NextNumber(0, 2 * math.pi)
		local r = random:NextNumber(66, 140)
		local at = Vector3.new(math.cos(a) * r, SAND + 0.2, math.sin(a) * r - 10)
		if random:NextNumber() < 0.5 then
			-- A starfish.
			for arm = 0, 4 do
				Kit.block("Starfish", Vector3.new(0.5, 0.25, 1.4), CFrame.new(at) * CFrame.Angles(0, arm / 5 * 2 * math.pi, 0) * CFrame.new(0, 0, -0.6), Color3.fromRGB(240, 110, 70), Enum.Material.SmoothPlastic, model)
			end
		else
			Kit.part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 0.5, 1), CFrame = CFrame.new(at), Color = Color3.fromRGB(250, 220, 210), Material = Enum.Material.SmoothPlastic }, model)
		end
	end
	-- Flowering bushes behind the deck.
	for _ = 1, 14 do
		local a = random:NextNumber(math.rad(200), math.rad(340))
		local r = random:NextNumber(70, 110)
		local at = Vector3.new(math.cos(a) * r, SAND, math.sin(a) * r)
		local size = random:NextNumber(4, 7)
		Kit.ball("Bush", at + Vector3.new(0, size * 0.3, 0), size, Color3.fromRGB(56, 120, 56), Enum.Material.Grass, model)
		for _ = 1, 5 do
			local d = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0, 1), random:NextNumber(-1, 1)).Unit * size * 0.48
			Kit.ball("Hibiscus", at + Vector3.new(0, size * 0.3, 0) + d, 0.9, if random:NextNumber() < 0.5 then Color3.fromRGB(240, 60, 90) else Color3.fromRGB(255, 160, 60), Enum.Material.SmoothPlastic, model)
		end
	end
	-- A surfboard planted in the sand and a beach ball.
	Kit.part({ Name = "Surfboard", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 12, 0.6), CFrame = CFrame.new(-66, SAND + 4, 40) * CFrame.Angles(0, 0.4, 0.12), Color = Color3.fromRGB(60, 190, 220), Material = Enum.Material.SmoothPlastic }, model)
	Kit.part({ Name = "SurfStripe", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 11.6, 0.7), CFrame = CFrame.new(-66, SAND + 4, 40) * CFrame.Angles(0, 0.4, 0.12), Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.SmoothPlastic }, model)
	local ball = Kit.ball("BeachBall", Vector3.new(70, SAND + 1.3, 30), 2.6, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
	for index, colour in { Color3.fromRGB(240, 60, 60), Color3.fromRGB(60, 120, 240), Color3.fromRGB(250, 210, 60) } do
		Kit.part({ Name = "BallStripe", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 2.65, 2.65), CFrame = CFrame.new(ball.Position) * CFrame.Angles(0, index * math.pi / 3, 0), Color = colour, Material = Enum.Material.SmoothPlastic }, model)
	end
end

local function dockAndBoat(ctx: Kit.Context)
	local model = ctx.model
	local start, finish = Vector3.new(120, G, -120), Vector3.new(215, G, -215)
	local length = (finish - start).Magnitude
	local frame = CFrame.lookAt(start, finish)
	Kit.block("Dock", Vector3.new(10, 1, length), frame * CFrame.new(0, -0.5, -length / 2), PLANK, Enum.Material.WoodPlanks, model)
	for index = 0, math.floor(length / 12) do
		for side = -1, 1, 2 do
			local post = (frame * CFrame.new(side * 5.2, 0, -index * 12)).Position
			Kit.cylinder("DockPost", 0.6, 22, post - Vector3.new(0, 20, 0), Color3.fromRGB(110, 80, 56), Enum.Material.Wood, model)
		end
	end
	-- A sailboat moored at the end, bobbing.
	local boat = Kit.group("Sailboat", model)
	local pivot = CFrame.new(finish.X + 12, SEA, finish.Z - 2) * CFrame.Angles(0, math.rad(-45), 0)
	local function p(x: number, y: number, z: number): CFrame
		return pivot * CFrame.new(x, y, z)
	end
	Kit.block("Hull", Vector3.new(7, 3, 18), p(0, 0.4, 0), WHITE, Enum.Material.SmoothPlastic, boat)
	Kit.part({ ClassName = "WedgePart", Name = "Bow", Size = Vector3.new(7, 3, 7), CFrame = p(0, 0.4, -12.5), Color = WHITE, Material = Enum.Material.SmoothPlastic }, boat)
	Kit.block("Stripe", Vector3.new(7.1, 0.5, 18.1), p(0, 0.6, 0), Color3.fromRGB(30, 110, 170), Enum.Material.SmoothPlastic, boat)
	Kit.block("Deck", Vector3.new(6.4, 0.3, 17), p(0, 2, 0), Color3.fromRGB(200, 160, 110), Enum.Material.WoodPlanks, boat)
	Kit.rod("Mast", p(0, 2, -2).Position, p(0, 30, -2).Position, 0.3, WHITE, Enum.Material.Metal, boat)
	Kit.rod("Boom", p(0, 5, -2).Position, p(0, 5, 8).Position, 0.2, WHITE, Enum.Material.Metal, boat)
	Kit.part({ ClassName = "WedgePart", Name = "Mainsail", Size = Vector3.new(0.15, 24, 9.6), CFrame = p(0, 17.4, 3) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(250, 246, 236), Material = Enum.Material.Fabric }, boat)
	Kit.part({ ClassName = "WedgePart", Name = "Jib", Size = Vector3.new(0.15, 20, 9), CFrame = p(0, 13, -7) , Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.Fabric }, boat)
	local rig = Kit.rig(boat, pivot)
	ctx.animate(function(t)
		Kit.place(rig, pivot * CFrame.new(0, math.sin(t * 0.9) * 0.6, 0) * CFrame.Angles(math.sin(t * 0.7) * 0.03, 0, math.sin(t * 0.8) * 0.06))
	end)
end

local function farIslands(ctx: Kit.Context)
	local random = ctx.random
	for _, spot in { { -420, -520, 70 }, { 160, -640, 90 }, { 520, -380, 60 }, { -620, -200, 50 } } do
		local centre = Vector3.new(spot[1], SEA, spot[2])
		Kit.mound(centre, spot[3], spot[3] * 0.35, Enum.Material.LeafyGrass)
		Kit.mound(centre + Vector3.new(spot[3] * 0.5, 0, spot[3] * 0.2), spot[3] * 0.6, 4, Enum.Material.Sand)
		for _ = 1, 5 do
			local a = random:NextNumber(0, 2 * math.pi)
			local r = random:NextNumber(0, spot[3] * 0.6)
			local base = centre + Vector3.new(math.cos(a) * r, spot[3] * 0.2, math.sin(a) * r)
			Kit.cylinder("FarPalm", 1.4, 22, base, Color3.fromRGB(110, 86, 60), Enum.Material.Wood, ctx.model)
			Kit.ball("FarCrown", base + Vector3.new(0, 23, 0), 12, Color3.fromRGB(50, 110, 50), Enum.Material.Grass, ctx.model)
		end
	end
	-- The volcano, smoking.
	local volcano = Vector3.new(-200, SEA - 6, -760)
	Kit.mountain(volcano, 170, 150, Enum.Material.Basalt, random)
	Kit.mound(volcano + Vector3.new(0, 0, 0), 230, 30, Enum.Material.LeafyGrass)
	local vent = Kit.part({ Name = "Vent", Size = Vector3.new(20, 1, 20), CFrame = CFrame.new(volcano + Vector3.new(0, 150, 0)), Transparency = 1 }, ctx.model)
	Kit.emitter(vent, {
		Texture = Kit.SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(150, 130, 130), Color3.fromRGB(220, 200, 200)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 60) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(14, 20),
		Speed = NumberRange.new(10, 14),
		Rate = 3,
		Acceleration = Vector3.new(8, 0, 2),
		EmissionDirection = Enum.NormalId.Top,
	})
	local glow = Kit.glow("Lava", Vector3.new(16, 2, 16), CFrame.new(volcano + Vector3.new(0, 148, 0)), Color3.fromRGB(255, 110, 40), ctx.model)
	Kit.pointLight(glow, Color3.fromRGB(255, 120, 50), 60, 3)
end

-- Gulls circling high over the beach, wings flapping.
local function gulls(ctx: Kit.Context)
	local birds = {}
	for index = 1, 7 do
		local body = Kit.part({ Name = "Gull", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 2.6), Color = WHITE, Material = Enum.Material.SmoothPlastic }, ctx.model)
		local left = Kit.block("Wing", Vector3.new(3.4, 0.15, 1.2), CFrame.new(), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic, ctx.model)
		local right = Kit.block("Wing", Vector3.new(3.4, 0.15, 1.2), CFrame.new(), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic, ctx.model)
		table.insert(birds, {
			parts = { body, left, right },
			cframes = { CFrame.new(), CFrame.new(), CFrame.new() },
			centre = Vector3.new(ctx.random:NextNumber(-120, 120), ctx.random:NextNumber(55, 85), ctx.random:NextNumber(-220, -60)),
			radius = ctx.random:NextNumber(30, 70),
			speed = ctx.random:NextNumber(0.15, 0.3) * (if index % 2 == 0 then 1 else -1),
			phase = ctx.random:NextNumber(0, 2 * math.pi),
		})
	end
	ctx.animate(function(t)
		for _, bird in birds do
			local a = bird.phase + t * bird.speed
			local position = bird.centre + Vector3.new(math.cos(a) * bird.radius, math.sin(t * 0.5 + bird.phase) * 4, math.sin(a) * bird.radius)
			local ahead = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(bird.speed)
			local frame = CFrame.lookAt(position, position + ahead) * CFrame.Angles(0, 0, math.sign(bird.speed) * 0.25)
			local flap = math.sin(t * 5 + bird.phase) * 0.45
			bird.cframes[1] = frame
			bird.cframes[2] = frame * CFrame.Angles(0, 0, flap) * CFrame.new(-1.7, 0, 0)
			bird.cframes[3] = frame * CFrame.Angles(0, 0, -flap) * CFrame.new(1.7, 0, 0)
			workspace:BulkMoveTo(bird.parts, bird.cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

local function tableProps(model: Instance)
	-- A coconut drink with a straw and a paper umbrella, sunglasses, a conch shell.
	local drink = Table.cornerSpot(1)
	Kit.ball("Coconut", drink + Vector3.new(0, 1.4, 0), 3, Color3.fromRGB(100, 68, 40), Enum.Material.Wood, model)
	Kit.cylinder("CoconutMilk", 1.1, 0.1, drink + Vector3.new(0, 2.75, 0), Color3.fromRGB(250, 246, 236), Enum.Material.SmoothPlastic, model)
	Kit.rod("Straw", drink + Vector3.new(0, 2.6, 0), drink + Vector3.new(0.6, 5.2, 0.4), 0.14, Color3.fromRGB(255, 90, 140), Enum.Material.SmoothPlastic, model)
	Kit.rod("UmbrellaStick", drink + Vector3.new(-0.3, 2.6, -0.2), drink + Vector3.new(-1, 5.4, -0.8), 0.06, WHITE, Enum.Material.Wood, model)
	Kit.cone("PaperUmbrella", drink + Vector3.new(-1, 5.1, -0.8), 1.6, 0.7, 8, { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 100, 90) }, Enum.Material.Fabric, model)
	local glasses = Table.cornerSpot(3)
	for side = -1, 1, 2 do
		Kit.part({ Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.6, 1.6), CFrame = CFrame.new(glasses + Vector3.new(side * 1, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.Glass }, model)
	end
	Kit.block("Bridge", Vector3.new(0.6, 0.15, 0.15), CFrame.new(glasses + Vector3.new(0, 0.2, 0)), Color3.fromRGB(240, 90, 120), Enum.Material.SmoothPlastic, model)
	local shell = Table.cornerSpot(0)
	Kit.cone("Conch", shell + Vector3.new(0, 0.1, 0), 1.4, 2.6, 7, { Color3.fromRGB(250, 220, 200), Color3.fromRGB(240, 180, 160) }, Enum.Material.SmoothPlastic, model)
end

return function(ctx: Kit.Context)
	local model = ctx.model
	Table.build({ top = Color3.fromRGB(150, 104, 64), edge = Color3.fromRGB(120, 82, 50), legs = Color3.fromRGB(110, 76, 46), inlay = Color3.fromRGB(240, 220, 170) }, model)
	tableProps(model)
	island(ctx.random)
	ctx.water({ WaterColor = Color3.fromRGB(24, 150, 170), WaterReflectance = 0.6, WaterTransparency = 0.75, WaterWaveSize = 0.3, WaterWaveSpeed = 12 })
	deck(ctx)
	palms(ctx)
	tikiBar(ctx, CFrame.new(-82, 0, -92) * CFrame.Angles(0, math.rad(35), 0))
	for index, spot in { { 85, 25 }, { 92, -35 }, { -85, 40 }, { 50, 95 }, { -45, 100 } } do
		local colours = { Color3.fromRGB(240, 80, 70), Color3.fromRGB(60, 160, 230), Color3.fromRGB(255, 190, 60), Color3.fromRGB(80, 200, 140), Color3.fromRGB(240, 110, 180) }
		umbrella(ctx, Vector3.new(spot[1], SAND, spot[2]), colours[index], index % 2 == 1)
	end
	sandcastle(model, Vector3.new(-70, SAND, 62))
	beachBits(ctx)
	dockAndBoat(ctx)
	farIslands(ctx)
	gulls(ctx)
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 18
	sky.StarCount = 0
	sky.Parent = model
end
