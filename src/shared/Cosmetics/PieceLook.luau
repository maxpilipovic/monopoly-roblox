--!strict
-- How each piece's model is finished, part by part (Body, Trim, Glow). The defaults are cast pewter,
-- like the classic metal tokens; chest pieces carry their own colours. Shared so the board, the lobby
-- previews and the chest reveal all look the same.

export type PartFinish = { color: Color3, material: Enum.Material, transparency: number? }

local PieceLook = {}

local PEWTER = { color = Color3.fromRGB(176, 180, 188), material = Enum.Material.Metal }
local PEWTER_DARK = { color = Color3.fromRGB(122, 126, 134), material = Enum.Material.Metal }
local GOLD = { color = Color3.fromRGB(226, 182, 74), material = Enum.Material.Metal }
local SILVER = { color = Color3.fromRGB(205, 210, 220), material = Enum.Material.Metal }
local WHITE = { color = Color3.fromRGB(242, 242, 238), material = Enum.Material.SmoothPlastic }

PieceLook.FINISHES = table.freeze({
	TopHat = { Body = PEWTER, Trim = PEWTER_DARK },
	Battleship = { Body = PEWTER, Trim = PEWTER_DARK },
	RaceCar = { Body = PEWTER, Trim = PEWTER_DARK },
	Duck = {
		Body = { color = Color3.fromRGB(255, 212, 48), material = Enum.Material.SmoothPlastic },
		Trim = { color = Color3.fromRGB(255, 132, 30), material = Enum.Material.SmoothPlastic },
	},
	Cactus = {
		Body = { color = Color3.fromRGB(74, 150, 82), material = Enum.Material.SmoothPlastic },
		Trim = { color = Color3.fromRGB(190, 104, 64), material = Enum.Material.SmoothPlastic },
	},
	Anchor = { Body = { color = Color3.fromRGB(62, 68, 80), material = Enum.Material.Metal }, Trim = GOLD },
	Robot = { Body = SILVER, Trim = { color = Color3.fromRGB(64, 224, 255), material = Enum.Material.Neon } },
	Lighthouse = {
		Body = WHITE,
		Trim = { color = Color3.fromRGB(214, 40, 44), material = Enum.Material.SmoothPlastic },
		Glow = { color = Color3.fromRGB(255, 232, 140), material = Enum.Material.Neon },
	},
	Trophy = { Body = GOLD, Trim = { color = Color3.fromRGB(70, 44, 30), material = Enum.Material.Wood } },
	Rocket = { Body = WHITE, Trim = { color = Color3.fromRGB(220, 46, 46), material = Enum.Material.SmoothPlastic } },
	Ghost = {
		Body = { color = Color3.fromRGB(240, 244, 255), material = Enum.Material.SmoothPlastic, transparency = 0.3 },
		Trim = { color = Color3.fromRGB(20, 20, 28), material = Enum.Material.SmoothPlastic },
	},
	UFO = {
		Body = SILVER,
		Trim = { color = Color3.fromRGB(120, 255, 150), material = Enum.Material.Neon },
		Glow = { color = Color3.fromRGB(150, 230, 255), material = Enum.Material.Glass, transparency = 0.3 },
	},
	Crown = { Body = GOLD, Trim = { color = Color3.fromRGB(200, 20, 50), material = Enum.Material.Glass, transparency = 0.1 } },
	Diamond = { Body = { color = Color3.fromRGB(170, 230, 255), material = Enum.Material.Glass, transparency = 0.15 } },
	Skull = {
		Body = { color = Color3.fromRGB(232, 226, 210), material = Enum.Material.SmoothPlastic },
		Trim = { color = Color3.fromRGB(170, 70, 255), material = Enum.Material.Neon },
	},

	-- Challenge pieces (some on other pieces' models, some on the buildings and emblems).
	GoldenTopHat = { Body = GOLD, Trim = { color = Color3.fromRGB(150, 20, 40), material = Enum.Material.Fabric } },
	TreasureChest = {
		Body = { color = Color3.fromRGB(96, 56, 28), material = Enum.Material.Wood },
		Trim = GOLD,
	},
	LittleHouse = {
		Body = { color = Color3.fromRGB(40, 150, 76), material = Enum.Material.SmoothPlastic },
		Roof = { color = Color3.fromRGB(24, 96, 48), material = Enum.Material.SmoothPlastic },
		Trim = WHITE,
	},
	GrandHotel = {
		Body = { color = Color3.fromRGB(190, 20, 30), material = Enum.Material.SmoothPlastic },
		Roof = GOLD,
		Trim = GOLD,
	},
	MysteryBox = { Body = { color = Color3.fromRGB(255, 120, 220), material = Enum.Material.Neon } },
	GhostShip = {
		Body = { color = Color3.fromRGB(190, 230, 255), material = Enum.Material.Glass, transparency = 0.35 },
		Trim = { color = Color3.fromRGB(120, 255, 210), material = Enum.Material.Neon, transparency = 0.2 },
	},
	ShadowRacer = {
		Body = { color = Color3.fromRGB(20, 20, 26), material = Enum.Material.Glass },
		Trim = { color = Color3.fromRGB(255, 40, 40), material = Enum.Material.Neon },
	},
	WaterWorks = {
		Body = { color = Color3.fromRGB(220, 226, 236), material = Enum.Material.Metal },
		Trim = { color = Color3.fromRGB(70, 140, 255), material = Enum.Material.Metal },
		Drop = { color = Color3.fromRGB(90, 200, 255), material = Enum.Material.Neon, transparency = 0.1 },
	},
	ExpressTrain = {
		Body = { color = Color3.fromRGB(30, 60, 40), material = Enum.Material.Metal },
		Trim = GOLD,
	},
	Flagship = {
		Body = { color = Color3.fromRGB(28, 44, 96), material = Enum.Material.Metal },
		Trim = GOLD,
	},
	PlatinumTrophy = {
		Body = { color = Color3.fromRGB(228, 236, 248), material = Enum.Material.Metal },
		Trim = { color = Color3.fromRGB(60, 200, 255), material = Enum.Material.Neon },
	},
	BrightIdea = {
		Body = { color = Color3.fromRGB(255, 236, 150), material = Enum.Material.Neon, transparency = 0.1 },
		Trim = GOLD,
	},
}) :: { [string]: { [string]: PartFinish } }

-- Finishes a clone of a piece model, each part by its name.
function PieceLook.apply(model: Model, piece: string)
	local finish = PieceLook.FINISHES[piece] or PieceLook.FINISHES.TopHat
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local look = finish[part.Name] or finish.Body
			part.Color = look.color
			part.Material = look.material
			part.Transparency = look.transparency or 0
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = true
		end
	end
end

return PieceLook
