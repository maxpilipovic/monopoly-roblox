--!strict
-- The settings a board can be played in: what surrounds it (SceneBuilder builds it on each client)
-- and how it's lit. Picked by a casual game's host; ranked games get one at random.

export type Scene = {
	id: string,
	name: string,
	blurb: string,
	clockTime: number,
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogColor: Color3,
	atmosphereColor: Color3,
	atmosphereDensity: number,
	ground: Color3, -- the floor under the board's table
	tableTop: Color3, -- the board's table
}

local Scenes = {}

Scenes.LIST = {
	{
		id = "Boardwalk",
		name = "Boardwalk Night",
		blurb = "A city skyline, a pier and the sea at night.",
		clockTime = 20.6,
		brightness = 1.4,
		ambient = Color3.fromRGB(60, 60, 90),
		outdoorAmbient = Color3.fromRGB(80, 80, 120),
		fogColor = Color3.fromRGB(20, 24, 50),
		atmosphereColor = Color3.fromRGB(120, 110, 170),
		atmosphereDensity = 0.32,
		ground = Color3.fromRGB(70, 56, 42),
		tableTop = Color3.fromRGB(58, 34, 24),
	},
	{
		id = "Tropical",
		name = "Tropical Island",
		blurb = "Palm trees, white sand and a sunset sea.",
		clockTime = 17.6,
		brightness = 2.6,
		ambient = Color3.fromRGB(120, 100, 90),
		outdoorAmbient = Color3.fromRGB(170, 150, 130),
		fogColor = Color3.fromRGB(255, 200, 160),
		atmosphereColor = Color3.fromRGB(255, 196, 150),
		atmosphereDensity = 0.26,
		ground = Color3.fromRGB(232, 214, 168),
		tableTop = Color3.fromRGB(120, 82, 50),
	},
	{
		id = "Winter",
		name = "Winter Lodge",
		blurb = "Snowy pines, a log cabin and falling snow.",
		clockTime = 14,
		brightness = 2.2,
		ambient = Color3.fromRGB(110, 120, 140),
		outdoorAmbient = Color3.fromRGB(170, 185, 210),
		fogColor = Color3.fromRGB(210, 225, 240),
		atmosphereColor = Color3.fromRGB(210, 225, 245),
		atmosphereDensity = 0.38,
		ground = Color3.fromRGB(236, 242, 248),
		tableTop = Color3.fromRGB(96, 64, 44),
	},
} :: { Scene }

Scenes.byId = {} :: { [string]: Scene }
Scenes.IDS = {} :: { string }
for _, scene in Scenes.LIST do
	Scenes.byId[scene.id] = scene
	table.insert(Scenes.IDS, scene.id)
end

function Scenes.random(random: Random): string
	return Scenes.IDS[random:NextInteger(1, #Scenes.IDS)]
end

return Scenes
