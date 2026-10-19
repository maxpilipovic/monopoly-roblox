--!strict
-- Boardwalk Night: the table stands on a carnival pier over a moonlit sea. Victorian lamps strung
-- with festoon bulbs, food booths, a turning Ferris wheel and carousel at the far end, a lighthouse
-- sweeping the bay, boats bobbing at anchor, a little harbour town across the water, fireworks.

local Kit = require(script.Parent.Kit)
local Table = require(script.Parent.Table)

local G = Kit.GROUND
local SEA = G - 9 -- the water's surface
local DECK = Color3.fromRGB(118, 88, 62)
local PILING = Color3.fromRGB(58, 44, 34)
local WHITE = Color3.fromRGB(236, 232, 222)
local IRON = Color3.fromRGB(28, 30, 36)
local WARM = Color3.fromRGB(255, 206, 140)
local BULBS = { Color3.fromRGB(255, 214, 150), Color3.fromRGB(255, 120, 170), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 240, 120) }

-- The pier's planked decks (centre square, walkway, carnival end), with pilings into the sea.
local DECKS = {
	{ centre = Vector3.new(0, 0, 0), size = Vector3.new(170, 0, 150) },
	{ centre = Vector3.new(0, 0, -105), size = Vector3.new(40, 0, 60) },
	{ centre = Vector3.new(0, 0, -185), size = Vector3.new(260, 0, 100) },
}

local function decks(model: Instance)
	for _, deck in DECKS do
		local c, s = deck.centre, deck.size
		Kit.block("Deck", Vector3.new(s.X, 2, s.Z), CFrame.new(c.X, G - 1, c.Z), DECK, Enum.Material.WoodPlanks, model)
		Kit.block("DeckSkirt", Vector3.new(s.X + 1, 1.4, s.Z + 1), CFrame.new(c.X, G - 2.6, c.Z), PILING, Enum.Material.Wood, model)
		for x = -s.X / 2 + 4, s.X / 2 - 4, 16 do
			for _, z in { -s.Z / 2 + 2, s.Z / 2 - 2 } do
				Kit.cylinder("Piling", 1.3, G - 3 - (SEA - 30), Vector3.new(c.X + x, SEA - 30, c.Z + z), PILING, Enum.Material.Wood, model)
			end
		end
	end
end

-- White railings along the decks' outer edges (open where the decks join).
local function railing(a: Vector3, b: Vector3, model: Instance)
	local length = (b - a).Magnitude
	local posts = math.max(1, math.floor(length / 8))
	for index = 0, posts do
		local p = a:Lerp(b, index / posts)
		Kit.block("RailPost", Vector3.new(0.6, 4.2, 0.6), CFrame.new(p + Vector3.new(0, 2.1, 0)), WHITE, Enum.Material.Wood, model)
	end
	Kit.beam("Rail", a + Vector3.new(0, 4.2, 0), b + Vector3.new(0, 4.2, 0), 0.5, WHITE, Enum.Material.Wood, model)
	Kit.beam("Rail", a + Vector3.new(0, 2.2, 0), b + Vector3.new(0, 2.2, 0), 0.3, WHITE, Enum.Material.Wood, model)
end

local function railings(model: Instance)
	local y = G
	local function r(x1: number, z1: number, x2: number, z2: number)
		railing(Vector3.new(x1, y, z1), Vector3.new(x2, y, z2), model)
	end
	r(-85, 75, 85, 75) -- front
	r(-85, -75, -85, 75)
	r(85, -75, 85, 75)
	r(-85, -75, -20, -75)
	r(20, -75, 85, -75)
	r(-20, -75, -20, -135)
	r(20, -75, 20, -135)
	r(-130, -135, -20, -135)
	r(20, -135, 130, -135)
	r(-130, -235, 130, -235)
	r(-130, -135, -130, -235)
	r(130, -135, 130, -235)
end

-- A Victorian lamp post; returns the lantern's position for stringing bulbs.
local function lamp(base: Vector3, model: Instance): Vector3
	Kit.cylinder("LampBase", 1.1, 1.6, base, IRON, Enum.Material.Metal, model)
	Kit.cylinder("LampPole", 0.4, 13, base + Vector3.new(0, 1.6, 0), IRON, Enum.Material.Metal, model)
	Kit.cylinder("LampRing", 0.7, 0.5, base + Vector3.new(0, 6, 0), IRON, Enum.Material.Metal, model)
	local top = base + Vector3.new(0, 14.6, 0)
	Kit.block("LanternCage", Vector3.new(1.8, 2.6, 1.8), CFrame.new(top + Vector3.new(0, 1.3, 0)), IRON, Enum.Material.Glass, model).Transparency = 0.6
	local bulb = Kit.ball("LanternBulb", top + Vector3.new(0, 1.3, 0), 1.3, WARM, Enum.Material.Neon, model)
	Kit.pointLight(bulb, Color3.fromRGB(255, 196, 130), 30, 1.4, true)
	Kit.pyramid("LanternRoof", top + Vector3.new(0, 2.6, 0), 2.4, 1.2, IRON, Enum.Material.Metal, model)
	Kit.ball("Finial", top + Vector3.new(0, 4, 0), 0.5, IRON, Enum.Material.Metal, model)
	return top + Vector3.new(0, 3.2, 0)
end

local function lampsAndFestoons(model: Instance)
	-- Lamps round the table's square, then along the walkway and the carnival deck.
	local ring = {}
	for _, p in { { -80, 70 }, { 0, 70 }, { 80, 70 }, { 80, 0 }, { 80, -70 }, { 22, -70 }, { -22, -70 }, { -80, -70 }, { -80, 0 } } do
		table.insert(ring, lamp(Vector3.new(p[1], G, p[2]), model))
	end
	for index = 1, #ring do
		local a, b = ring[index], ring[index % #ring + 1]
		if (a - b).Magnitude < 100 then
			Kit.festoon(a, b, 5, math.floor((a - b).Magnitude / 4), BULBS, model, 4)
		end
	end
	local walk = { lamp(Vector3.new(-17, G, -100), model), lamp(Vector3.new(17, G, -100), model), lamp(Vector3.new(-17, G, -130), model), lamp(Vector3.new(17, G, -130), model) }
	Kit.festoon(walk[1], walk[3], 3, 7, BULBS, model)
	Kit.festoon(walk[2], walk[4], 3, 7, BULBS, model)
	Kit.festoon(walk[1], walk[2], 4, 8, BULBS, model)
	for _, x in { -120, -60, 60, 120 } do
		for _, z in { -140, -230 } do
			lamp(Vector3.new(x, G, z), model)
		end
	end
end

-- A striped-awning food booth with a glowing sign.
local function booth(at: CFrame, label: string, stripe: Color3, model: Instance)
	local function p(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, G + y, z)
	end
	Kit.block("Counter", Vector3.new(16, 4.5, 6), p(0, 2.25, 2), Color3.fromRGB(250, 244, 230), Enum.Material.Wood, model)
	Kit.block("CounterTop", Vector3.new(17, 0.5, 7), p(0, 4.7, 2), Color3.fromRGB(140, 90, 60), Enum.Material.Wood, model)
	Kit.block("Back", Vector3.new(16, 12, 1), p(0, 6, -3), Color3.fromRGB(250, 244, 230), Enum.Material.Wood, model)
	for _, x in { -7.6, 7.6 } do
		Kit.block("Post", Vector3.new(0.8, 11, 0.8), p(x, 5.5, 4.8), WHITE, Enum.Material.Wood, model)
	end
	for slat = 0, 7 do
		Kit.part({
			ClassName = "WedgePart",
			Name = "Awning",
			Size = Vector3.new(2.05, 2.4, 9),
			CFrame = p(-7 + slat * 2, 12.2, 1.5) * CFrame.Angles(0, math.pi, 0),
			Color = if slat % 2 == 0 then stripe else WHITE,
			Material = Enum.Material.Fabric,
		}, model)
	end
	local sign = Kit.block("Sign", Vector3.new(12, 3, 0.6), p(0, 15.4, -2.6), Color3.fromRGB(30, 20, 30), Enum.Material.SmoothPlastic, model)
	Kit.sign(sign, Enum.NormalId.Back, label, Color3.fromRGB(255, 230, 160))
	Kit.festoon((p(-8, 13.4, 6)).Position, (p(8, 13.4, 6)).Position, 1, 9, BULBS, model)
	local glow = Kit.part({ Name = "BoothLight", Size = Vector3.one, CFrame = p(0, 9, 3), Transparency = 1 }, model)
	Kit.pointLight(glow, Color3.fromRGB(255, 210, 160), 22, 1.2)
end

-- A Ferris wheel facing the board, turning slowly with its gondolas hanging level.
local function ferrisWheel(ctx: Kit.Context, centre: Vector3)
	local model = ctx.model
	local radius = 46
	local hub = centre + Vector3.new(0, radius + 10, 0)
	-- The A-frame legs and the platform.
	for _, side in { -1, 1 } do
		local z = hub.Z + side * 7
		Kit.beam("Leg", Vector3.new(hub.X - 26, G, z), Vector3.new(hub.X, hub.Y, z), 1.6, WHITE, Enum.Material.Metal, model)
		Kit.beam("Leg", Vector3.new(hub.X + 26, G, z), Vector3.new(hub.X, hub.Y, z), 1.6, WHITE, Enum.Material.Metal, model)
		Kit.beam("Brace", Vector3.new(hub.X - 13, (G + hub.Y) / 2, z), Vector3.new(hub.X + 13, (G + hub.Y) / 2, z), 0.8, WHITE, Enum.Material.Metal, model)
	end
	Kit.rod("Axle", hub - Vector3.new(0, 0, 9), hub + Vector3.new(0, 0, 9), 1.4, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, model)
	Kit.block("Platform", Vector3.new(30, 1.6, 22), CFrame.new(hub.X, G + 0.8, hub.Z), Color3.fromRGB(150, 40, 50), Enum.Material.Wood, model)

	-- The wheel itself (rims, spokes, bulbs), built at rest around the hub.
	local wheel = Kit.group("Wheel", model)
	local segments = 40
	local bulbs = {}
	for _, z in { -4, 4 } do
		for index = 0, segments - 1 do
			local a1, a2 = index / segments * 2 * math.pi, (index + 1) / segments * 2 * math.pi
			local p1 = hub + Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, z)
			local p2 = hub + Vector3.new(math.cos(a2) * radius, math.sin(a2) * radius, z)
			Kit.beam("Rim", p1, p2, 0.9, WHITE, Enum.Material.Metal, wheel)
			table.insert(bulbs, Kit.ball("RimBulb", p1 + Vector3.new(0, 0, z * 0.2), 1.3, BULBS[index % 4 + 1], Enum.Material.Neon, wheel))
			local inner = hub + Vector3.new(math.cos(a1) * radius * 0.55, math.sin(a1) * radius * 0.55, z)
			if index % 2 == 0 then
				Kit.beam("Spoke", hub + Vector3.new(0, 0, z), p1, 0.45, WHITE, Enum.Material.Metal, wheel)
				table.insert(bulbs, Kit.ball("SpokeBulb", inner, 0.9, BULBS[(index // 2) % 4 + 1], Enum.Material.Neon, wheel))
			end
		end
	end
	Kit.cylinder("Hub", 3, 10, Vector3.zero, Color3.fromRGB(220, 60, 70), Enum.Material.Metal, wheel).CFrame = CFrame.new(hub) * CFrame.Angles(0, math.pi / 2, 0)
	local wheelRig = Kit.rig(wheel, CFrame.new(hub))

	-- Gondolas: built hanging at the top of the hub, then hung from the rim each frame.
	local gondolas = {}
	local count = 16
	for index = 0, count - 1 do
		local g = Kit.group("Gondola", model)
		local pin = hub
		local color = Color3.fromHSV(index / count, 0.55, 0.95)
		Kit.rod("Hanger", pin, pin - Vector3.new(0, 3, 0), 0.2, IRON, Enum.Material.Metal, g)
		Kit.block("Cabin", Vector3.new(5, 3.6, 4.4), CFrame.new(pin - Vector3.new(0, 5.2, 0)), color, Enum.Material.Metal, g)
		Kit.block("CabinWindow", Vector3.new(5.1, 1.4, 4.5), CFrame.new(pin - Vector3.new(0, 4.6, 0)), Color3.fromRGB(255, 230, 180), Enum.Material.Neon, g)
		Kit.pyramid("CabinRoof", pin - Vector3.new(0, 3.4, 0), 5.6, 1.4, color, Enum.Material.Metal, g)
		table.insert(gondolas, { rig = Kit.rig(g, CFrame.new(pin)), angle = index / count * 2 * math.pi })
	end

	local chase = 0
	ctx.animate(function(t)
		local turn = t * 0.07
		Kit.place(wheelRig, CFrame.new(hub) * CFrame.Angles(0, 0, turn))
		for _, gondola in gondolas do
			local a = gondola.angle + turn
			Kit.place(gondola.rig, CFrame.new(hub + Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)))
		end
		-- The bulbs chase round in colour.
		local step = math.floor(t * 4)
		if step ~= chase then
			chase = step
			for index, bulb in bulbs do
				bulb.Color = BULBS[(index + step) % #BULBS + 1]
			end
		end
	end)
end

-- A carousel: a striped canopy and painted horses going round and up and down.
local function carousel(ctx: Kit.Context, centre: Vector3)
	local model = ctx.model
	local base = Vector3.new(centre.X, G, centre.Z)
	Kit.cylinder("CarouselBase", 17, 1.6, base, Color3.fromRGB(120, 30, 40), Enum.Material.Wood, model)
	Kit.cylinder("CarouselFloor", 16, 0.3, base + Vector3.new(0, 1.6, 0), Color3.fromRGB(240, 220, 170), Enum.Material.Wood, model)
	local ride = Kit.group("Ride", model)
	Kit.cylinder("CentrePole", 2.4, 12, base + Vector3.new(0, 1.9, 0), Color3.fromRGB(230, 200, 120), Enum.Material.Metal, ride)
	Kit.cylinder("Drum", 4, 4, base + Vector3.new(0, 4, 0), Color3.fromRGB(60, 120, 160), Enum.Material.Wood, ride)
	Kit.cylinder("CanopyRim", 18, 1.6, base + Vector3.new(0, 13.4, 0), Color3.fromRGB(240, 200, 90), Enum.Material.Wood, ride)
	Kit.cone("Canopy", base + Vector3.new(0, 15, 0), 18, 7, 16, { Color3.fromRGB(220, 50, 60), Color3.fromRGB(250, 240, 220) }, Enum.Material.Fabric, ride)
	Kit.ball("Finial", base + Vector3.new(0, 22.6, 0), 1.6, Color3.fromRGB(240, 200, 90), Enum.Material.Metal, ride)
	local rimBulbs = {}
	for index = 0, 31 do
		local a = index / 32 * 2 * math.pi
		table.insert(rimBulbs, Kit.ball("RimBulb", base + Vector3.new(math.cos(a) * 18.3, 13.4, math.sin(a) * 18.3), 0.8, WARM, Enum.Material.Neon, ride))
	end
	local glow = Kit.part({ Name = "CarouselLight", Size = Vector3.one, CFrame = CFrame.new(base + Vector3.new(0, 10, 0)), Transparency = 1 }, ride)
	Kit.pointLight(glow, Color3.fromRGB(255, 200, 150), 34, 1.6)
	local rideRig = Kit.rig(ride, CFrame.new(base))

	local horses = {}
	local colors = { Color3.fromRGB(250, 248, 240), Color3.fromRGB(150, 110, 80), Color3.fromRGB(240, 200, 220), Color3.fromRGB(70, 60, 60) }
	for index = 0, 9 do
		local a = index / 10 * 2 * math.pi
		local spot = base + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		local horse = Kit.group("Horse", model)
		local facing = CFrame.lookAt(spot, spot + Vector3.new(-math.sin(a), 0, math.cos(a)))
		local function at(x: number, y: number, z: number): CFrame
			return facing * CFrame.new(x, y, z)
		end
		local coat = colors[index % #colors + 1]
		Kit.rod("Pole", spot + Vector3.new(0, 1.9, 0), spot + Vector3.new(0, 13.4, 0), 0.25, Color3.fromRGB(235, 205, 120), Enum.Material.Metal, horse)
		Kit.block("Body", Vector3.new(1.8, 2, 4.6), at(0, 6, 0), coat, Enum.Material.SmoothPlastic, horse)
		Kit.block("Neck", Vector3.new(1.3, 2.6, 1.4), at(0, 7.6, -2.2) * CFrame.Angles(math.rad(-25), 0, 0), coat, Enum.Material.SmoothPlastic, horse)
		Kit.block("Head", Vector3.new(1.2, 1.2, 2.4), at(0, 8.8, -3.1), coat, Enum.Material.SmoothPlastic, horse)
		Kit.block("Saddle", Vector3.new(2, 0.5, 1.8), at(0, 7.1, 0.2), Color3.fromRGB(200, 40, 60), Enum.Material.Fabric, horse)
		Kit.block("Mane", Vector3.new(0.4, 2.4, 1), at(0, 8, -1.6), Color3.fromRGB(240, 200, 90), Enum.Material.SmoothPlastic, horse)
		for _, leg in { { -0.6, -1.7, 0.5 }, { 0.6, -1.7, -0.5 }, { -0.6, 1.7, -0.5 }, { 0.6, 1.7, 0.5 } } do
			Kit.block("Leg", Vector3.new(0.4, 2.6, 0.4), at(leg[1], 4.3, leg[2]) * CFrame.Angles(leg[3], 0, 0), coat, Enum.Material.SmoothPlastic, horse)
		end
		Kit.block("Tail", Vector3.new(0.4, 2, 0.6), at(0, 5.6, 2.5) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(240, 200, 90), Enum.Material.SmoothPlastic, horse)
		table.insert(horses, { rig = Kit.rig(horse, CFrame.new(base)), phase = index * 1.3 })
	end
	ctx.animate(function(t)
		local turn = CFrame.new(base) * CFrame.Angles(0, -t * 0.35, 0)
		Kit.place(rideRig, turn)
		for _, horse in horses do
			Kit.place(horse.rig, turn + Vector3.new(0, math.sin(t * 2 + horse.phase) * 0.9, 0))
		end
		for index, bulb in rimBulbs do
			bulb.Color = if (index + math.floor(t * 3)) % 2 == 0 then WARM else Color3.fromRGB(255, 140, 180)
		end
	end)
end

-- A striped lighthouse on a rocky islet, its beam sweeping the bay.
local function lighthouse(ctx: Kit.Context, at: Vector3)
	local model = ctx.model
	Kit.mound(Vector3.new(at.X, SEA, at.Z), 34, 12, Enum.Material.Rock)
	Kit.mound(Vector3.new(at.X + 18, SEA, at.Z + 10), 22, 6, Enum.Material.Basalt)
	local base = Vector3.new(at.X, SEA + 10, at.Z)
	local tiers = 8
	for tier = 0, tiers - 1 do
		local r = 7 - tier * 0.45
		Kit.cylinder("Tower", r, 5.2, base + Vector3.new(0, tier * 5, 0), if tier % 2 == 0 then Color3.fromRGB(240, 240, 235) else Color3.fromRGB(200, 40, 45), Enum.Material.Concrete, model)
	end
	local top = base + Vector3.new(0, tiers * 5, 0)
	Kit.cylinder("Gallery", 5.4, 0.8, top, IRON, Enum.Material.Metal, model)
	Kit.cylinder("LanternRoom", 3.4, 5, top + Vector3.new(0, 0.8, 0), Color3.fromRGB(255, 240, 200), Enum.Material.Glass, model).Transparency = 0.4
	local lamp = Kit.ball("Lamp", top + Vector3.new(0, 3.3, 0), 2.6, Color3.fromRGB(255, 240, 190), Enum.Material.Neon, model)
	Kit.pointLight(lamp, Color3.fromRGB(255, 230, 170), 40, 2)
	Kit.cone("Cap", top + Vector3.new(0, 5.8, 0), 4.2, 3.4, 10, { Color3.fromRGB(200, 40, 45) }, Enum.Material.Metal, model)
	local beam = Kit.group("Beam", model)
	local pivot = CFrame.new(lamp.Position)
	Kit.part({ Name = "LightBeam", Size = Vector3.new(4, 4, 220), CFrame = pivot * CFrame.new(0, 0, -112), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Transparency = 0.86, CastShadow = false }, beam)
	Kit.part({ Name = "LightBeam", Size = Vector3.new(2, 2, 220), CFrame = pivot * CFrame.new(0, 0, -112), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon, Transparency = 0.7, CastShadow = false }, beam)
	local beamRig = Kit.rig(beam, pivot)
	ctx.animate(function(t)
		Kit.place(beamRig, pivot * CFrame.Angles(0, t * 0.6, 0) * CFrame.Angles(math.rad(-4), 0, 0))
	end)
end

local function boat(ctx: Kit.Context, at: Vector3, yaw: number, hull: Color3)
	local g = Kit.group("Boat", ctx.model)
	local pivot = CFrame.new(at.X, SEA, at.Z) * CFrame.Angles(0, yaw, 0)
	local function p(x: number, y: number, z: number): CFrame
		return pivot * CFrame.new(x, y, z)
	end
	Kit.block("Hull", Vector3.new(7, 3, 16), p(0, 0.6, 0), hull, Enum.Material.Wood, g)
	Kit.part({ ClassName = "WedgePart", Name = "Bow", Size = Vector3.new(7, 3, 6), CFrame = p(0, 0.6, -11), Color = hull, Material = Enum.Material.Wood }, g)
	Kit.block("Stripe", Vector3.new(7.1, 0.5, 16.1), p(0, 1.6, 0), WHITE, Enum.Material.Wood, g)
	Kit.block("Cabin", Vector3.new(5, 3, 6), p(0, 3.6, 3), WHITE, Enum.Material.Wood, g)
	Kit.glow("Porthole", Vector3.new(5.1, 0.9, 4), p(0, 3.8, 3), WARM, g)
	Kit.rod("Mast", p(0, 2, -2).Position, p(0, 16, -2).Position, 0.25, Color3.fromRGB(200, 190, 170), Enum.Material.Wood, g)
	local mastLight = Kit.ball("MastLight", p(0, 16.4, -2).Position, 0.8, Color3.fromRGB(255, 250, 230), Enum.Material.Neon, g)
	Kit.pointLight(mastLight, WARM, 14, 0.8)
	Kit.festoon(p(0, 15.5, -2).Position, p(0, 2.5, -12).Position, 1, 6, BULBS, g)
	Kit.festoon(p(0, 15.5, -2).Position, p(0, 2.5, 7).Position, 1, 6, BULBS, g)
	local rig = Kit.rig(g, pivot)
	local seed = ctx.random:NextNumber(0, 10)
	ctx.animate(function(t)
		local bob = math.sin(t * 1.1 + seed) * 0.5
		Kit.place(rig, pivot * CFrame.new(0, bob, 0) * CFrame.Angles(math.sin(t * 0.8 + seed) * 0.05, 0, math.sin(t * 0.9 + seed * 2) * 0.07))
	end)
end

-- A harbour town across the bay: lit windows climbing a hillside, a church spire.
local function town(ctx: Kit.Context)
	local model, random = ctx.model, ctx.random
	Kit.fillBlock(CFrame.new(0, SEA - 6, -760), Vector3.new(1600, 24, 360), Enum.Material.Ground)
	for index = 1, 9 do
		Kit.mound(Vector3.new(-700 + index * 150 + random:NextNumber(-40, 40), SEA + 4, -820), random:NextNumber(110, 170), random:NextNumber(30, 80), Enum.Material.Grass)
	end
	for _ = 1, 70 do
		local x = random:NextNumber(-620, 620)
		local depth = random:NextNumber(0, 1)
		local z = -600 - depth * 160
		local height = random:NextNumber(10, 36) * (1 - math.abs(x) / 900)
		local width = random:NextNumber(10, 22)
		local y = SEA + 6 + depth * 30
		local colour = Color3.fromHSV(random:NextNumber(0, 1), 0.25, random:NextNumber(0.3, 0.55))
		Kit.block("House", Vector3.new(width, height, width * 0.8), CFrame.new(x, y + height / 2, z), colour, Enum.Material.Concrete, model)
		Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(width + 1, 5, width * 0.45), CFrame = CFrame.new(x, y + height + 2.5, z + width * 0.2) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(90, 40, 36), Material = Enum.Material.Slate }, model)
		Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(width + 1, 5, width * 0.45), CFrame = CFrame.new(x, y + height + 2.5, z - width * 0.2), Color = Color3.fromRGB(90, 40, 36), Material = Enum.Material.Slate }, model)
		for floor = 1, math.floor(height / 8) do
			for column = -1, 1 do
				if random:NextNumber() < 0.6 then
					Kit.glow("Window", Vector3.new(2.2, 2.6, 0.3), CFrame.new(x + column * width * 0.28, y + floor * 7, z + width * 0.4 + 0.1), if random:NextNumber() < 0.8 then WARM else Color3.fromRGB(170, 210, 255), model)
				end
			end
		end
	end
	-- The church on the hill.
	local church = Vector3.new(-120, SEA + 40, -760)
	Kit.block("Church", Vector3.new(20, 26, 34), CFrame.new(church + Vector3.new(0, 13, 0)), Color3.fromRGB(220, 210, 190), Enum.Material.Concrete, model)
	Kit.block("Steeple", Vector3.new(9, 30, 9), CFrame.new(church + Vector3.new(0, 15, 20)), Color3.fromRGB(230, 220, 200), Enum.Material.Concrete, model)
	Kit.pyramid("Spire", church + Vector3.new(0, 30, 20), 10, 22, Color3.fromRGB(70, 80, 90), Enum.Material.Slate, model)
	Kit.glow("ClockFace", Vector3.new(5, 5, 0.3), CFrame.new(church + Vector3.new(0, 24, 24.6)), Color3.fromRGB(255, 240, 200), model)
end

-- Fireworks over the bay: a spark climbs, then bursts in colour with a flash.
local function fireworks(ctx: Kit.Context)
	local random = ctx.random
	local shells = {}
	for index = 1, 4 do
		local rocket = Kit.ball("Rocket", Vector3.new(0, -500, 0), 1.2, Color3.fromRGB(255, 230, 180), Enum.Material.Neon, ctx.model)
		local burst = Kit.emitter(rocket, {
			Texture = Kit.SPARKLE,
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.2), NumberSequenceKeypoint.new(1, 0.4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.6, 2.4),
			Speed = NumberRange.new(38, 52),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1.6,
			Acceleration = Vector3.new(0, -14, 0),
			Enabled = false,
		})
		local trail = Kit.emitter(rocket, {
			Texture = Kit.SPARKLE,
			LightEmission = 1,
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 160)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.4, 0.7),
			Speed = NumberRange.new(1, 3),
			Rate = 60,
			Enabled = false,
		})
		local flash = Kit.pointLight(rocket, Color3.new(1, 1, 1), 160, 0)
		table.insert(shells, { rocket = rocket, burst = burst, trail = trail, flash = flash, flightStart = nil :: number?, launch = 1.5 + index * 1.7, from = Vector3.zero, to = Vector3.zero, burstAt = -10 })
	end
	ctx.animate(function(t)
		for _, shell in shells do
			if t >= shell.launch then
				shell.launch = t + random:NextNumber(4, 7)
				shell.from = Vector3.new(random:NextNumber(-220, 220), SEA, random:NextNumber(-420, -320))
				shell.to = shell.from + Vector3.new(random:NextNumber(-20, 20), random:NextNumber(110, 170), 0)
				shell.flightStart = t
				shell.trail.Enabled = true
				shell.rocket.Transparency = 0
			end
			local flightStart = shell.flightStart
			if flightStart then
				local f = (t - flightStart) / 1.3
				if f < 1 then
					shell.rocket.Position = shell.from:Lerp(shell.to, 1 - (1 - f) ^ 2)
				else
					shell.flightStart = nil
					shell.trail.Enabled = false
					shell.rocket.Transparency = 1
					shell.rocket.Position = shell.to
					local hue = random:NextNumber()
					local colour = Color3.fromHSV(hue, 0.65, 1)
					shell.burst.Color = ColorSequence.new(colour, Color3.fromHSV((hue + 0.12) % 1, 0.4, 1))
					shell.burst:Emit(140)
					shell.flash.Color = colour
					shell.burstAt = t
				end
			end
			shell.flash.Brightness = math.max(0, 3 * (1 - (t - shell.burstAt) / 0.9))
		end
	end)
end

local function tableProps(model: Instance)
	-- A striped popcorn box and a soda in one corner, a paper ticket roll in another.
	local corn = Table.cornerSpot(1)
	for slat = 0, 7 do
		local a = slat / 8 * 2 * math.pi
		Kit.block("PopcornBox", Vector3.new(1.2, 3.2, 0.2), CFrame.new(corn + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 1.3), if slat % 2 == 0 then Color3.fromRGB(220, 40, 50) else WHITE, Enum.Material.SmoothPlastic, model)
	end
	for _ = 1, 14 do
		local offset = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2.2
		Kit.ball("Popcorn", corn + offset + Vector3.new(0, 3.4 + math.random() * 0.8, 0), 0.7, Color3.fromRGB(255, 244, 200), Enum.Material.SmoothPlastic, model)
	end
	local soda = Table.cornerSpot(1, 4)
	Kit.cylinder("Cup", 1, 3.4, soda, Color3.fromRGB(60, 120, 220), Enum.Material.SmoothPlastic, model)
	Kit.cylinder("Lid", 1.1, 0.3, soda + Vector3.new(0, 3.4, 0), WHITE, Enum.Material.SmoothPlastic, model)
	Kit.rod("Straw", soda + Vector3.new(0, 3.5, 0), soda + Vector3.new(0.4, 5.6, 0.3), 0.15, Color3.fromRGB(240, 60, 80), Enum.Material.SmoothPlastic, model)
end

return function(ctx: Kit.Context)
	local model = ctx.model
	Table.build({ top = Color3.fromRGB(92, 52, 36), edge = Color3.fromRGB(70, 38, 26), legs = Color3.fromRGB(64, 34, 24), inlay = Color3.fromRGB(214, 172, 84), keyLight = 2.4 }, model)
	tableProps(model)
	-- The sea, and the sea bed under it.
	Kit.fillBlock(CFrame.new(0, SEA - 40, 0), Vector3.new(2000, 80, 2000), Enum.Material.Water)
	Kit.fillBlock(CFrame.new(0, SEA - 82, 0), Vector3.new(2000, 4, 2000), Enum.Material.Sand)
	ctx.water({ WaterColor = Color3.fromRGB(16, 34, 66), WaterReflectance = 1, WaterTransparency = 0.2, WaterWaveSize = 0.18, WaterWaveSpeed = 8 })
	decks(model)
	railings(model)
	lampsAndFestoons(model)
	booth(CFrame.new(-55, 0, -60) * CFrame.Angles(0, math.rad(25), 0), "POPCORN", Color3.fromRGB(220, 40, 50), model)
	booth(CFrame.new(55, 0, -60) * CFrame.Angles(0, math.rad(-25), 0), "COTTON CANDY", Color3.fromRGB(240, 120, 180), model)
	booth(CFrame.new(-95, 0, -205) * CFrame.Angles(0, math.rad(15), 0), "RING TOSS", Color3.fromRGB(60, 140, 230), model)
	ferrisWheel(ctx, Vector3.new(55, G, -200))
	carousel(ctx, Vector3.new(-50, G, -185))
	lighthouse(ctx, Vector3.new(300, 0, -330))
	boat(ctx, Vector3.new(-150, 0, -40), math.rad(70), Color3.fromRGB(40, 90, 150))
	boat(ctx, Vector3.new(160, 0, 40), math.rad(-20), Color3.fromRGB(170, 50, 50))
	boat(ctx, Vector3.new(-190, 0, -300), math.rad(200), Color3.fromRGB(240, 240, 230))
	boat(ctx, Vector3.new(210, 0, -150), math.rad(120), Color3.fromRGB(40, 120, 90))
	town(ctx)
	fireworks(ctx)
	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.MoonAngularSize = 16
	sky.SunAngularSize = 0
	sky.Parent = model
end
