--!strict
-- The settings a board can be played in: what surrounds it (SceneBuilder builds it on each client)
-- and how it's lit and graded. Picked by a casual game's host; ranked games get one at random. A scene
-- may belong to one map (`map`): that map always plays in it and no other map is offered it.

export type Scene = {
	id: string,
	name: string,
	blurb: string,
	map: string?, -- the one map this scene belongs to
	clockTime: number,
	latitude: number, -- where the sun and moon sit in the sky
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogColor: Color3,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	atmosphereDensity: number,
	glare: number,
	haze: number,
	bloom: { intensity: number, size: number, threshold: number },
	sunRays: number,
	grade: { brightness: number, contrast: number, saturation: number, tint: Color3 },
}

local Scenes = {}

Scenes.LIST = {
	{
		id = "Boardwalk",
		name = "Boardwalk Night",
		blurb = "A carnival pier on a moonlit sea: Ferris wheel, lighthouse, fireworks.",
		clockTime = 20.9,
		latitude = 30,
		brightness = 1,
		exposure = 0,
		ambient = Color3.fromRGB(56, 52, 84),
		outdoorAmbient = Color3.fromRGB(86, 80, 130),
		fogColor = Color3.fromRGB(26, 22, 56),
		atmosphereColor = Color3.fromRGB(60, 50, 100),
		atmosphereDecay = Color3.fromRGB(40, 30, 80),
		atmosphereDensity = 0.32,
		glare = 0,
		haze = 0.6,
		bloom = { intensity = 0.9, size = 36, threshold = 1.1 },
		sunRays = 0,
		grade = { brightness = 0.02, contrast = 0.12, saturation = 0.18, tint = Color3.fromRGB(240, 236, 255) },
	},
	{
		id = "Tropical",
		name = "Tropical Island",
		blurb = "Palm trees, white sand, turquoise shallows and a volcano at sunset.",
		clockTime = 17.85,
		latitude = 10,
		brightness = 2.8,
		exposure = 0.1,
		ambient = Color3.fromRGB(130, 104, 96),
		outdoorAmbient = Color3.fromRGB(180, 150, 136),
		fogColor = Color3.fromRGB(255, 196, 160),
		atmosphereColor = Color3.fromRGB(255, 214, 180),
		atmosphereDecay = Color3.fromRGB(230, 140, 140),
		atmosphereDensity = 0.26,
		glare = 0.4,
		haze = 1,
		bloom = { intensity = 0.6, size = 30, threshold = 1.5 },
		sunRays = 0.12,
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.22, tint = Color3.fromRGB(255, 240, 225) },
	},
	{
		id = "Winter",
		name = "Winter Lodge",
		blurb = "A log lodge in snowy pines at twilight, under the northern lights.",
		clockTime = 19.4,
		latitude = 60,
		brightness = 1,
		exposure = 0,
		ambient = Color3.fromRGB(70, 74, 96),
		outdoorAmbient = Color3.fromRGB(110, 116, 150),
		fogColor = Color3.fromRGB(60, 66, 100),
		atmosphereColor = Color3.fromRGB(120, 120, 150),
		atmosphereDecay = Color3.fromRGB(70, 60, 110),
		atmosphereDensity = 0.2,
		glare = 0,
		haze = 0.4,
		bloom = { intensity = 0.8, size = 34, threshold = 1.2 },
		sunRays = 0.04,
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.12, tint = Color3.fromRGB(235, 242, 255) },
	},
	{
		id = "City",
		name = "City Skyline",
		blurb = "A skyscraper rooftop at dusk, the city lit up all around.",
		clockTime = 18.3,
		latitude = 40,
		brightness = 2,
		exposure = 0.1,
		ambient = Color3.fromRGB(100, 86, 104),
		outdoorAmbient = Color3.fromRGB(150, 120, 140),
		fogColor = Color3.fromRGB(230, 150, 130),
		atmosphereColor = Color3.fromRGB(255, 170, 140),
		atmosphereDecay = Color3.fromRGB(110, 80, 150),
		atmosphereDensity = 0.28,
		glare = 0.3,
		haze = 0.8,
		bloom = { intensity = 0.7, size = 30, threshold = 1.4 },
		sunRays = 0.1,
		grade = { brightness = 0.01, contrast = 0.14, saturation = 0.15, tint = Color3.fromRGB(255, 236, 228) },
	},
	{
		id = "EIUCampus",
		name = "EIU Campus",
		blurb = "The Library Quad on an autumn evening: Old Main, the campus pond and the panther statue.",
		map = "College",
		clockTime = 18.15,
		latitude = 40,
		brightness = 1.5,
		exposure = 0.05,
		ambient = Color3.fromRGB(112, 96, 92),
		outdoorAmbient = Color3.fromRGB(160, 140, 130),
		fogColor = Color3.fromRGB(210, 170, 140),
		atmosphereColor = Color3.fromRGB(240, 200, 170),
		atmosphereDecay = Color3.fromRGB(150, 110, 120),
		atmosphereDensity = 0.3,
		glare = 0.3,
		haze = 1.2,
		bloom = { intensity = 0.6, size = 30, threshold = 1.5 },
		sunRays = 0.1,
		grade = { brightness = 0.02, contrast = 0.12, saturation = 0.18, tint = Color3.fromRGB(255, 236, 220) },
	},
} :: { Scene }

Scenes.byId = {} :: { [string]: Scene }
Scenes.IDS = {} :: { string }
for _, scene in Scenes.LIST do
	Scenes.byId[scene.id] = scene
	table.insert(Scenes.IDS, scene.id)
end

-- The scenes a map may be played in: the one that belongs to it, or else every scene that belongs
-- to no map.
function Scenes.forMap(mapId: string): { string }
	local own, open = {}, {}
	for _, scene in Scenes.LIST do
		if scene.map == mapId then
			table.insert(own, scene.id)
		elseif scene.map == nil then
			table.insert(open, scene.id)
		end
	end
	return if #own > 0 then own else open
end

function Scenes.random(random: Random, mapId: string?): string
	local ids = Scenes.forMap(mapId or "Classic")
	return ids[random:NextInteger(1, #ids)]
end

return Scenes
