--!strict
-- City Skyline: the table stands on a skyscraper's rooftop terrace at dusk. A glass-walled terrace
-- with planters, a lounge under string lights and an infinity pool; a giant neon MONOPOLY sign
-- behind; towers of every style all round with lit windows, billboards and blinking beacons; rivers
-- of headlights in the streets far below, a lit suspension bridge, a needle tower, and a helicopter
-- sweeping its searchlight over the city.

local Kit = require(script.Parent.Kit)
local Table = require(script.Parent.Table)

local G = Kit.GROUND
local STREET = G - 260 -- street level, far below the roof
local BLOCK = 110 -- city block pitch
local ROOF_HALF = Vector2.new(100, 90)
local CONCRETE = Color3.fromRGB(150, 146, 140)
local STEEL = Color3.fromRGB(60, 64, 72)
local WARM = Color3.fromRGB(255, 214, 150)
local COOL = Color3.fromRGB(170, 215, 255)
-- Lit windows: muted, so the towers glow rather than glare.
local WINDOW_WARM = Color3.fromRGB(196, 150, 92)
local WINDOW_COOL = Color3.fromRGB(120, 150, 186)
local WINDOW_WHITE = Color3.fromRGB(190, 180, 160)
local RIVER_Z = { -560, -470 }

-- Our own tower and its rooftop terrace ------------------------------------------------------------

local function ourTower(model: Instance)
	local w, d = ROOF_HALF.X * 2, ROOF_HALF.Y * 2
	Kit.block("Roof", Vector3.new(w, 2, d), CFrame.new(0, G - 1, 0), Color3.fromRGB(120, 116, 112), Enum.Material.Slate, model)
	Kit.block("RoofTiles", Vector3.new(w - 8, 0.2, d - 8), CFrame.new(0, G + 0.05, 0), Color3.fromRGB(168, 160, 150), Enum.Material.Pavement, model)
	Kit.block("Deck", Vector3.new(112, 0.4, 112), CFrame.new(0, G + 0.2, 0), Color3.fromRGB(150, 104, 70), Enum.Material.WoodPlanks, model)
	local height = G - 2 - STREET
	Kit.part({ Name = "Tower", Size = Vector3.new(w - 4, height, d - 4), CFrame = CFrame.new(0, STREET + height / 2, 0), Color = Color3.fromRGB(40, 60, 80), Material = Enum.Material.Glass, Reflectance = 0.25 }, model)
	for floor = 1, math.floor(height / 10) do
		local y = G - 2 - floor * 10
		for side = 0, 3 do
			local yaw = side * math.pi / 2
			local half = if side % 2 == 0 then d / 2 - 2 else w / 2 - 2
			local length = if side % 2 == 0 then w - 6 else d - 6
			Kit.block("FloorBand", Vector3.new(length, 1, 0.6), CFrame.Angles(0, yaw, 0) * CFrame.new(0, y, half + 0.2), Color3.fromRGB(90, 96, 104), Enum.Material.Metal, model)
		end
	end
end

local function balustrade(model: Instance)
	local hx, hz = ROOF_HALF.X - 1, ROOF_HALF.Y - 1
	local sides = { { Vector3.new(-hx, G, hz), Vector3.new(hx, G, hz) }, { Vector3.new(-hx, G, -hz), Vector3.new(hx, G, -hz) }, { Vector3.new(-hx, G, -hz), Vector3.new(-hx, G, hz) }, { Vector3.new(hx, G, -hz), Vector3.new(hx, G, hz) } }
	for _, side in sides do
		local a, b = side[1], side[2]
		local length = (b - a).Magnitude
		local frame = CFrame.lookAt((a + b) / 2, b)
		Kit.part({ Name = "GlassRail", Size = Vector3.new(0.3, 4.4, length), CFrame = frame * CFrame.new(0, 2.4, 0), Color = Color3.fromRGB(180, 220, 240), Material = Enum.Material.Glass, Transparency = 0.7 }, model)
		Kit.block("HandRail", Vector3.new(0.6, 0.4, length), frame * CFrame.new(0, 4.7, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, model)
		Kit.glow("RailGlow", Vector3.new(0.2, 0.15, length), frame * CFrame.new(0, 0.3, 0), WARM, model)
	end
end

-- A planter with a bushy little tree or grasses.
local function planter(model: Instance, at: Vector3, size: Vector2, random: Random)
	Kit.block("Planter", Vector3.new(size.X, 3, size.Y), CFrame.new(at + Vector3.new(0, 1.5, 0)), Color3.fromRGB(70, 66, 64), Enum.Material.Concrete, model)
	Kit.block("Soil", Vector3.new(size.X - 1, 0.3, size.Y - 1), CFrame.new(at + Vector3.new(0, 3, 0)), Color3.fromRGB(60, 44, 32), Enum.Material.Ground, model)
	local count = math.max(1, math.floor(math.max(size.X, size.Y) / 8))
	for index = 1, count do
		local f = (index - 0.5) / count
		local spot = at + Vector3.new((f - 0.5) * (size.X - 2) * (if size.X > size.Y then 1 else 0), 3, (f - 0.5) * (size.Y - 2) * (if size.Y >= size.X then 1 else 0))
		if random:NextNumber() < 0.5 then
			Kit.cylinder("TreeTrunk", 0.35, 5, spot, Color3.fromRGB(90, 66, 46), Enum.Material.Wood, model)
			Kit.ball("TreeCrown", spot + Vector3.new(0, 7, 0), random:NextNumber(5, 6.5), Color3.fromHSV(random:NextNumber(0.25, 0.33), 0.55, 0.5), Enum.Material.Grass, model)
		else
			for _ = 1, 4 do
				Kit.ball("Shrub", spot + Vector3.new(random:NextNumber(-2, 2), 1, random:NextNumber(-1, 1)), random:NextNumber(2.4, 3.4), Color3.fromHSV(random:NextNumber(0.24, 0.32), 0.5, 0.45), Enum.Material.Grass, model)
			end
			Kit.ball("Flowers", spot + Vector3.new(0, 2.2, 0), 1.2, Color3.fromRGB(240, 120, 170), Enum.Material.SmoothPlastic, model)
		end
	end
end

local function lounge(ctx: Kit.Context)
	local model = ctx.model
	local function sofa(at: CFrame)
		Kit.block("SofaBase", Vector3.new(14, 2, 5), at * CFrame.new(0, 1, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Fabric, model)
		Kit.block("SofaBack", Vector3.new(14, 3.4, 1.4), at * CFrame.new(0, 3, 2.1), Color3.fromRGB(60, 60, 66), Enum.Material.Fabric, model)
		for x = -4.5, 4.5, 4.5 do
			Kit.block("Cushion", Vector3.new(4.2, 0.8, 3.6), at * CFrame.new(x, 2.4, -0.3), Color3.fromRGB(230, 226, 214), Enum.Material.Fabric, model)
		end
		Kit.block("Pillow", Vector3.new(2, 2, 0.6), at * CFrame.new(-5, 3.5, 1.1) * CFrame.Angles(0.2, 0, 0.1), Color3.fromRGB(230, 120, 60), Enum.Material.Fabric, model)
	end
	sofa(CFrame.new(-80, G, -20) * CFrame.Angles(0, -math.pi / 2, 0))
	sofa(CFrame.new(-80, G, 20) * CFrame.Angles(0, -math.pi / 2, 0))
	Kit.block("CoffeeTable", Vector3.new(6, 1.6, 12), CFrame.new(-72, G + 0.8, 0), Color3.fromRGB(40, 36, 34), Enum.Material.Wood, model)
	Kit.cylinder("FirePit", 3, 1.6, Vector3.new(-66, G, -50), Color3.fromRGB(50, 50, 54), Enum.Material.Concrete, model)
	Kit.flame(ctx, Vector3.new(-66, G + 2, -50), 1.4, model)
	-- String lights on posts round the terrace.
	local posts = {}
	for _, p in { { -96, -86 }, { -96, 0 }, { -96, 86 }, { 0, -86 }, { 96, -86 }, { 96, 0 }, { 96, 86 } } do
		local base = Vector3.new(p[1], G, p[2])
		Kit.cylinder("LightPost", 0.3, 14, base, STEEL, Enum.Material.Metal, model)
		table.insert(posts, base + Vector3.new(0, 14, 0))
	end
	for _, pair in { { 1, 2 }, { 2, 3 }, { 1, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 } } do
		local a, b = posts[pair[1]], posts[pair[2]]
		Kit.festoon(a, b, 4, math.floor((a - b).Magnitude / 4.5), { WARM }, model, 5)
	end
end

local function pool(model: Instance)
	local centre = Vector3.new(80, G, 0)
	Kit.block("PoolCoping", Vector3.new(26, 1, 76), CFrame.new(centre + Vector3.new(0, 0.5, 0)), Color3.fromRGB(235, 232, 226), Enum.Material.Marble, model)
	Kit.part({ Name = "PoolWater", Size = Vector3.new(22, 0.6, 72), CFrame = CFrame.new(centre + Vector3.new(0, 0.85, 0)), Color = Color3.fromRGB(40, 180, 230), Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.3 }, model)
	local glow = Kit.glow("PoolGlow", Vector3.new(21, 0.2, 70), CFrame.new(centre + Vector3.new(0, 0.5, 0)), Color3.fromRGB(60, 200, 255), model)
	Kit.pointLight(glow, Color3.fromRGB(80, 200, 255), 30, 1.5)
	for z = -24, 24, 16 do
		Kit.block("SunBed", Vector3.new(3, 0.6, 8), CFrame.new(centre + Vector3.new(-16, 1.2, z)), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, model)
		Kit.block("SunBedBack", Vector3.new(3, 0.6, 3), CFrame.new(centre + Vector3.new(-16, 2.2, z - 4.6)) * CFrame.Angles(math.rad(55), 0, 0), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, model)
	end
end

-- The big neon MONOPOLY sign on a steel frame behind the terrace, facing the board.
local function roofSign(ctx: Kit.Context)
	local model = ctx.model
	local z = -ROOF_HALF.Y + 4
	for x = -36, 36, 12 do
		Kit.beam("SignLeg", Vector3.new(x, G, z - 3), Vector3.new(x, G + 30, z), 0.9, STEEL, Enum.Material.Metal, model)
	end
	Kit.beam("SignTruss", Vector3.new(-40, G + 22, z), Vector3.new(40, G + 22, z), 1, STEEL, Enum.Material.Metal, model)
	local board = Kit.block("SignBoard", Vector3.new(84, 16, 1), CFrame.new(0, G + 32, z), Color3.fromRGB(16, 14, 20), Enum.Material.SmoothPlastic, model)
	Kit.sign(board, Enum.NormalId.Back, "MONOPOLY", Color3.fromRGB(255, 60, 70), Enum.Font.LuckiestGuy)
	local border = {}
	for index = 0, 41 do
		local x = -41 + index * 2
		table.insert(border, Kit.ball("SignBulb", Vector3.new(x, G + 40.6, z + 0.8), 0.9, WARM, Enum.Material.Neon, model))
		table.insert(border, Kit.ball("SignBulb", Vector3.new(x, G + 23.4, z + 0.8), 0.9, WARM, Enum.Material.Neon, model))
	end
	local wash = Kit.part({ Name = "SignWash", Size = Vector3.one, CFrame = CFrame.new(0, G + 32, z + 8), Transparency = 1 }, model)
	Kit.pointLight(wash, Color3.fromRGB(255, 90, 90), 50, 1.2)
	ctx.animate(function(t)
		local step = math.floor(t * 5)
		for index, bulb in border do
			bulb.Transparency = if (index // 2 + step) % 3 == 0 then 0.8 else 0
		end
	end)
end

local function waterTower(model: Instance, at: Vector3)
	for _, c in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		Kit.rod("TowerLeg", at + Vector3.new(c[1], 0, c[2]), at + Vector3.new(c[1] * 0.8, 12, c[2] * 0.8), 0.4, STEEL, Enum.Material.Metal, model)
	end
	Kit.cylinder("Tank", 6, 12, at + Vector3.new(0, 12, 0), Color3.fromRGB(120, 86, 60), Enum.Material.WoodPlanks, model)
	for ring = 1, 3 do
		Kit.cylinder("Hoop", 6.15, 0.4, at + Vector3.new(0, 12 + ring * 3, 0), STEEL, Enum.Material.Metal, model)
	end
	Kit.cone("TankRoof", at + Vector3.new(0, 24, 0), 6.6, 4, 10, { Color3.fromRGB(90, 70, 56) }, Enum.Material.Wood, model)
end

-- The city -------------------------------------------------------------------------------------

type Building = { top: Vector3, height: number }

local function windows(model: Instance, centre: Vector3, size: Vector3, random: Random, every: number, tint: Color3)
	for floor = 1, math.floor(size.Y / every) - 1 do
		local y = centre.Y - size.Y / 2 + floor * every
		for side = 0, 3 do
			if random:NextNumber() < 0.45 then
				local wide = if side % 2 == 0 then size.X else size.Z
				local out = if side % 2 == 0 then size.Z / 2 else size.X / 2
				local lit = if random:NextNumber() < 0.8 then tint else WINDOW_COOL
				Kit.glow("Windows", Vector3.new(wide * random:NextNumber(0.4, 0.85), 1.3, 0.4), CFrame.new(centre.X, y, centre.Z) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(random:NextNumber(-0.05, 0.05) * wide, 0, out + 0.1), lit, model)
			end
		end
	end
end

local function building(ctx: Kit.Context, centre: Vector2, footprint: number, height: number, far: boolean): Building
	local model, random = ctx.model, ctx.random
	local style = random:NextInteger(1, 4)
	local every = if far then 18 else 9
	local base = Vector3.new(centre.X, STREET, centre.Y)
	local tint = if random:NextNumber() < 0.7 then WINDOW_WARM else WINDOW_WHITE
	if style == 1 then
		-- A glass tower with a crown.
		local size = Vector3.new(footprint, height, footprint * random:NextNumber(0.7, 1))
		local body = base + Vector3.new(0, height / 2, 0)
		Kit.part({ Name = "GlassTower", Size = size, CFrame = CFrame.new(body), Color = Color3.fromHSV(random:NextNumber(0.52, 0.6), 0.45, random:NextNumber(0.25, 0.4)), Material = Enum.Material.Glass, Reflectance = 0.2 }, model)
		windows(model, body, size, random, every, tint)
		Kit.block("Crown", Vector3.new(size.X * 0.7, 8, size.Z * 0.7), CFrame.new(base + Vector3.new(0, height + 4, 0)), STEEL, Enum.Material.Metal, model)
		Kit.glow("CrownLight", Vector3.new(size.X * 0.72, 0.8, size.Z * 0.72), CFrame.new(base + Vector3.new(0, height + 7, 0)), Color3.fromHSV(random:NextNumber(), 0.5, 1), model)
		return { top = base + Vector3.new(0, height + 8, 0), height = height + 8 }
	elseif style == 2 then
		-- An art-deco setback tower with a gold spire.
		local stone = Color3.fromHSV(0.09, random:NextNumber(0.1, 0.25), random:NextNumber(0.55, 0.75))
		local y = 0
		local w = footprint
		for stage = 1, 3 do
			local h = height * ({ 0.55, 0.3, 0.15 })[stage]
			local body = base + Vector3.new(0, y + h / 2, 0)
			local size = Vector3.new(w, h, w)
			Kit.block("Stage", size, CFrame.new(body), stone, Enum.Material.Limestone, model)
			windows(model, body, size, random, every, tint)
			y += h
			w *= 0.72
		end
		local tip = base + Vector3.new(0, y, 0)
		Kit.pyramid("Spire", tip, w, height * 0.12, Color3.fromRGB(214, 172, 84), Enum.Material.Metal, model)
		Kit.glow("SpireLight", Vector3.new(0.6, height * 0.06, 0.6), CFrame.new(tip + Vector3.new(0, height * 0.12 + height * 0.03, 0)), WARM, model)
		return { top = tip + Vector3.new(0, height * 0.18, 0), height = y + height * 0.18 }
	elseif style == 3 then
		-- A round tower ringed with light.
		local radius = footprint / 2
		Kit.part({ Name = "RoundTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(50, 70, 90), Material = Enum.Material.Glass, Reflectance = 0.25 }, model)
		for floor = 1, math.floor(height / (every * 1.5)) do
			if random:NextNumber() < 0.6 then
				Kit.part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, radius * 2 + 0.6, radius * 2 + 0.6), CFrame = CFrame.new(base + Vector3.new(0, floor * every * 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = tint, Material = Enum.Material.Neon, CastShadow = false }, model)
			end
		end
		Kit.cylinder("Cap", radius * 0.8, 4, base + Vector3.new(0, height, 0), STEEL, Enum.Material.Metal, model)
		return { top = base + Vector3.new(0, height + 4, 0), height = height + 4 }
	else
		-- A plain block of offices or flats, with a rooftop box.
		local size = Vector3.new(footprint, height, footprint * random:NextNumber(0.6, 1))
		local body = base + Vector3.new(0, height / 2, 0)
		Kit.block("Block", size, CFrame.new(body), Color3.fromHSV(random:NextNumber(0, 0.1), random:NextNumber(0.05, 0.3), random:NextNumber(0.3, 0.55)), Enum.Material.Concrete, model)
		windows(model, body, size, random, every, tint)
		Kit.block("RoofBox", Vector3.new(size.X * 0.3, 6, size.Z * 0.3), CFrame.new(base + Vector3.new(size.X * 0.2, height + 3, 0)), CONCRETE, Enum.Material.Concrete, model)
		return { top = base + Vector3.new(0, height + 6, 0), height = height + 6 }
	end
end

local BILLBOARDS = { "PASS GO  COLLECT $200", "PARK PLACE", "FREE PARKING", "BOARDWALK HOTELS", "READING RAILROAD" }

local function city(ctx: Kit.Context)
	local model, random = ctx.model, ctx.random
	-- The ground, cut by the river.
	Kit.block("Ground", Vector3.new(2600, 4, 650 - RIVER_Z[2]), CFrame.new(0, STREET - 2, (650 + RIVER_Z[2]) / 2), Color3.fromRGB(44, 44, 48), Enum.Material.Asphalt, model)
	Kit.block("GroundFar", Vector3.new(2600, 4, RIVER_Z[1] + 1300), CFrame.new(0, STREET - 2, (RIVER_Z[1] - 1300) / 2), Color3.fromRGB(44, 44, 48), Enum.Material.Asphalt, model)
	Kit.fillBlock(CFrame.new(0, STREET - 10, (RIVER_Z[1] + RIVER_Z[2]) / 2), Vector3.new(2600, 16, RIVER_Z[2] - RIVER_Z[1] + 8), Enum.Material.Water)
	local beacons = {}
	local billboard = 0
	for i = -7, 7 do
		for j = -9, 5 do
			local centre = Vector2.new(i * BLOCK, j * BLOCK)
			local inRiver = centre.Y > RIVER_Z[1] - 50 and centre.Y < RIVER_Z[2] + 50
			local distance = centre.Magnitude
			if not (i == 0 and j == 0) and not inRiver and distance < 1000 then
				local near = math.max(math.abs(i), math.abs(j)) <= 1
				local roof = G - STREET
				local height = if near then random:NextNumber(roof * 0.35, roof * 0.85) -- below us: the terrace looks out over them
					elseif distance < 450 then random:NextNumber(roof * 0.6, roof + 180)
					else random:NextNumber(90, roof + 120) * (1 - distance / 2000)
				local footprint = random:NextNumber(46, 74)
				local b = building(ctx, centre + Vector2.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8)), footprint, height, distance > 600)
				if b.height > roof + 60 or random:NextNumber() < 0.15 then
					table.insert(beacons, Kit.ball("Beacon", b.top + Vector3.new(0, 1.5, 0), 2.2, Color3.fromRGB(255, 40, 40), Enum.Material.Neon, model))
				end
				-- Billboards on some of the nearer towers, facing in toward us.
				if near and billboard < #BILLBOARDS and random:NextNumber() < 0.6 then
					billboard += 1
					local facing = CFrame.lookAt(Vector3.new(centre.X, 0, centre.Y), Vector3.zero)
					local y = math.min(G + 10, STREET + b.height - 20)
					local panel = Kit.block("Billboard", Vector3.new(34, 12, 1), CFrame.new(centre.X, y, centre.Y) * (facing - facing.Position) * CFrame.new(0, 0, -footprint / 2 - 2), Color3.fromRGB(14, 14, 20), Enum.Material.SmoothPlastic, model)
					Kit.sign(panel, Enum.NormalId.Front, BILLBOARDS[billboard], Color3.fromHSV(billboard / #BILLBOARDS, 0.6, 1))
				end
			end
		end
	end
	ctx.animate(function(t)
		local on = math.sin(t * 2.4) > 0.3
		for _, beacon in beacons do
			beacon.Transparency = if on then 0 else 0.85
		end
	end)
end

-- Streams of headlights and tail lights along the avenues far below.
local function traffic(ctx: Kit.Context)
	local model, random = ctx.model, ctx.random
	local cars = {}
	local lanes = {}
	for index = -7, 7 do
		local x = index * BLOCK + BLOCK / 2
		table.insert(lanes, { from = Vector3.new(x - 4, STREET + 0.6, -1000), to = Vector3.new(x - 4, STREET + 0.6, 600), colour = Color3.fromRGB(255, 250, 230) })
		table.insert(lanes, { from = Vector3.new(x + 4, STREET + 0.6, 600), to = Vector3.new(x + 4, STREET + 0.6, -1000), colour = Color3.fromRGB(255, 50, 40) })
		Kit.glow("StreetLights", Vector3.new(0.8, 0.4, 1600), CFrame.new(x - 12, STREET + 0.4, -200), Color3.fromRGB(255, 170, 80), model)
		Kit.glow("StreetLights", Vector3.new(0.8, 0.4, 1600), CFrame.new(x + 12, STREET + 0.4, -200), Color3.fromRGB(255, 170, 80), model)
	end
	for index = -9, 5 do
		local z = index * BLOCK + BLOCK / 2
		if z < RIVER_Z[1] - 20 or z > RIVER_Z[2] + 20 then
			table.insert(lanes, { from = Vector3.new(-900, STREET + 0.6, z - 4), to = Vector3.new(900, STREET + 0.6, z - 4), colour = Color3.fromRGB(255, 250, 230) })
			table.insert(lanes, { from = Vector3.new(900, STREET + 0.6, z + 4), to = Vector3.new(-900, STREET + 0.6, z + 4), colour = Color3.fromRGB(255, 50, 40) })
		end
	end
	local parts, cframes = {}, {}
	for _, lane in lanes do
		for _ = 1, 6 do
			local p = Kit.glow("Car", Vector3.new(2.4, 1, 4), CFrame.new(lane.from), lane.colour, model)
			table.insert(parts, p)
			table.insert(cframes, p.CFrame)
			table.insert(cars, { lane = lane, offset = random:NextNumber(), speed = random:NextNumber(0.012, 0.022) })
		end
	end
	ctx.animate(function(t)
		for index, car in cars do
			local f = (car.offset + t * car.speed) % 1
			local lane = car.lane
			cframes[index] = CFrame.lookAt(lane.from:Lerp(lane.to, f), lane.to)
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

-- A suspension bridge over the river, its cables strung with lights.
local function bridge(model: Instance)
	local x = 2 * BLOCK + BLOCK / 2
	local deckY = STREET + 14
	local z1, z2 = RIVER_Z[1] - 40, RIVER_Z[2] + 40
	Kit.block("BridgeDeck", Vector3.new(24, 3, z2 - z1), CFrame.new(x, deckY, (z1 + z2) / 2), Color3.fromRGB(70, 70, 76), Enum.Material.Concrete, model)
	local towerZ = { RIVER_Z[1] + 15, RIVER_Z[2] - 15 }
	for _, z in towerZ do
		for _, side in { -11, 11 } do
			Kit.block("BridgeTower", Vector3.new(3.5, 110, 3.5), CFrame.new(x + side, STREET + 55, z), Color3.fromRGB(150, 60, 50), Enum.Material.Metal, model)
		end
		Kit.block("TowerBeam", Vector3.new(26, 3, 3.5), CFrame.new(x, STREET + 100, z), Color3.fromRGB(150, 60, 50), Enum.Material.Metal, model)
		Kit.glow("TowerLight", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, STREET + 111, z), Color3.fromRGB(255, 40, 40), model)
	end
	for _, side in { -11, 11 } do
		local a = Vector3.new(x + side, STREET + 108, towerZ[1])
		local b = Vector3.new(x + side, STREET + 108, towerZ[2])
		Kit.festoon(a, b, 80, 40, { Color3.fromRGB(255, 250, 230) }, model)
		Kit.festoon(Vector3.new(x + side, deckY + 2, z1), a, -8, 10, { Color3.fromRGB(255, 250, 230) }, model)
		Kit.festoon(b, Vector3.new(x + side, deckY + 2, z2), -8, 10, { Color3.fromRGB(255, 250, 230) }, model)
	end
end

-- A needle tower with a saucer observation deck ringed in light.
local function needle(model: Instance, at: Vector3)
	local height = 480
	for _, c in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
		Kit.rod("NeedleLeg", at + Vector3.new(c[1] * 3, 0, c[2] * 3), at + Vector3.new(c[1] * 0.5, height * 0.8, c[2] * 0.5), 2, Color3.fromRGB(230, 230, 225), Enum.Material.Concrete, model)
	end
	local deck = at + Vector3.new(0, height * 0.8, 0)
	Kit.part({ Name = "Saucer", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 60, 60), CFrame = CFrame.new(deck) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(230, 230, 225), Material = Enum.Material.Concrete }, model)
	Kit.part({ Name = "SaucerGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 61, 61), CFrame = CFrame.new(deck) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CastShadow = false }, model)
	Kit.part({ Name = "SaucerTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 40, 40), CFrame = CFrame.new(deck + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(214, 172, 84), Material = Enum.Material.Metal }, model)
	Kit.rod("Spire", deck + Vector3.new(0, 10, 0), deck + Vector3.new(0, 80, 0), 1.2, Color3.fromRGB(230, 230, 225), Enum.Material.Metal, model)
	Kit.glow("SpireTip", Vector3.new(2.4, 2.4, 2.4), CFrame.new(deck + Vector3.new(0, 82, 0)), Color3.fromRGB(255, 40, 40), model)
end

-- A helicopter circling the city, its searchlight sweeping the streets.
local function helicopter(ctx: Kit.Context)
	local heli = Kit.group("Helicopter", ctx.model)
	local pivot = CFrame.new(0, 0, 0)
	Kit.part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 5, 10), CFrame = pivot, Color = Color3.fromRGB(30, 34, 44), Material = Enum.Material.Metal }, heli)
	Kit.block("Tail", Vector3.new(1, 1, 12), pivot * CFrame.new(0, 0.6, 9), Color3.fromRGB(30, 34, 44), Enum.Material.Metal, heli)
	Kit.glow("NavRed", Vector3.new(0.6, 0.6, 0.6), pivot * CFrame.new(-3, 0, 0), Color3.fromRGB(255, 40, 40), heli)
	Kit.glow("NavGreen", Vector3.new(0.6, 0.6, 0.6), pivot * CFrame.new(3, 0, 0), Color3.fromRGB(40, 255, 80), heli)
	Kit.part({ Name = "Searchlight", Size = Vector3.new(6, 6, 180), CFrame = pivot * CFrame.Angles(math.rad(-60), 0, 0) * CFrame.new(0, 0, -92), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon, Transparency = 0.9, CastShadow = false }, heli)
	local rig = Kit.rig(heli, pivot)
	local rotor = Kit.block("Rotor", Vector3.new(16, 0.2, 0.8), CFrame.new(), Color3.fromRGB(20, 20, 24), Enum.Material.Metal, ctx.model)
	ctx.animate(function(t)
		local a = t * 0.08
		local position = Vector3.new(math.cos(a) * 340, G + 70 + math.sin(t * 0.3) * 8, math.sin(a) * 340 - 120)
		local frame = CFrame.lookAt(position, position + Vector3.new(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(math.rad(-6), 0, math.rad(8))
		Kit.place(rig, frame * CFrame.Angles(0, math.pi, 0))
		rotor.CFrame = frame * CFrame.new(0, 3, 0) * CFrame.Angles(0, t * 25, 0)
	end)
end

local function tableProps(model: Instance)
	-- A takeaway coffee, a phone glowing face up, a little succulent.
	local coffee = Table.cornerSpot(1)
	Kit.cylinder("Cup", 1.05, 3.6, coffee, Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic, model)
	Kit.cylinder("Sleeve", 1.12, 1.4, coffee + Vector3.new(0, 1, 0), Color3.fromRGB(150, 100, 60), Enum.Material.Cardboard, model)
	Kit.cylinder("Lid", 1.15, 0.4, coffee + Vector3.new(0, 3.6, 0), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, model)
	local phone = Table.cornerSpot(3)
	Kit.block("Phone", Vector3.new(2, 0.2, 4), CFrame.new(phone + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, model)
	Kit.glow("Screen", Vector3.new(1.8, 0.05, 3.7), CFrame.new(phone + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(120, 180, 255), model)
	local pot = Table.cornerSpot(0)
	Kit.cylinder("Pot", 1, 1.6, pot, Color3.fromRGB(220, 110, 80), Enum.Material.Concrete, model)
	for index = 0, 6 do
		local a = index / 7 * 2 * math.pi
		Kit.part({ Name = "Succulent", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.5, 1.4), CFrame = CFrame.new(pot + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.5) * CFrame.Angles(0.5, 0, 0), Color = Color3.fromRGB(110, 170, 120), Material = Enum.Material.SmoothPlastic }, model)
	end
end

return function(ctx: Kit.Context)
	local model = ctx.model
	Table.build({ top = Color3.fromRGB(46, 40, 38), edge = Color3.fromRGB(30, 28, 28), legs = Color3.fromRGB(26, 24, 24), inlay = Color3.fromRGB(214, 172, 84), material = Enum.Material.Wood, keyLight = 1.2 }, model)
	tableProps(model)
	ctx.water({ WaterColor = Color3.fromRGB(30, 50, 70), WaterReflectance = 1, WaterTransparency = 0.3, WaterWaveSize = 0.1, WaterWaveSpeed = 6 })
	ourTower(model)
	balustrade(model)
	for _, p in { { -60, -82, 40, 6 }, { 20, -82, 30, 6 }, { -94, 50, 6, 40 }, { 0, 84, 70, 6 }, { 94, -60, 6, 30 } } do
		planter(model, Vector3.new(p[1], G, p[2]), Vector2.new(p[3], p[4]), ctx.random)
	end
	lounge(ctx)
	pool(model)
	roofSign(ctx)
	waterTower(model, Vector3.new(70, G, -66))
	city(ctx)
	traffic(ctx)
	bridge(model)
	needle(model, Vector3.new(-3.5 * BLOCK, STREET, -3.5 * BLOCK))
	helicopter(ctx)
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 6
	sky.StarCount = 1500
	sky.Parent = model
end
