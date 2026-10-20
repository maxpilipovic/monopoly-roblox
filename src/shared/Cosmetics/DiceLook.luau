--!strict
-- How each dice skin (Catalog kind "Dice") finishes the die model's two parts, Body and Pips, plus
-- an optional glow and sparkle. Shared so the board's dice and the collection's previews match.

export type Finish = { color: Color3, material: Enum.Material, transparency: number? }
export type Skin = { body: Finish, pips: Finish, glow: Color3?, sparkle: Color3? }

local DiceLook = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function finish(r: number, g: number, b: number, material: Enum.Material?, transparency: number?): Finish
	return { color = Color3.fromRGB(r, g, b), material = material or Enum.Material.SmoothPlastic, transparency = transparency }
end

local INK = finish(22, 22, 26)
local WHITE = finish(246, 246, 242)
local GOLD = finish(232, 186, 70, Enum.Material.Metal)

DiceLook.SKINS = table.freeze({
	DiceIvory = { body = finish(240, 234, 220), pips = INK },
	DiceMidnight = { body = finish(28, 30, 40), pips = finish(210, 214, 226, Enum.Material.Metal) },
	DiceRuby = { body = finish(170, 20, 36), pips = WHITE },
	DiceEmerald = { body = finish(24, 120, 64), pips = WHITE },
	DiceSapphire = { body = finish(40, 90, 210, Enum.Material.Glass, 0.1), pips = WHITE },
	DiceMarble = { body = finish(236, 236, 240, Enum.Material.Marble), pips = finish(40, 44, 60) },
	DiceWalnut = { body = finish(92, 58, 34, Enum.Material.Wood), pips = finish(236, 214, 170) },
	DiceNeon = { body = finish(30, 20, 40), pips = finish(255, 70, 200, Enum.Material.Neon), glow = Color3.fromRGB(255, 70, 200) },
	DiceCrystal = { body = finish(210, 240, 255, Enum.Material.Glass, 0.35), pips = finish(120, 200, 255, Enum.Material.Neon) },
	DiceGold = { body = GOLD, pips = INK, sparkle = Color3.fromRGB(255, 226, 130) },
	DiceBrick = { body = finish(170, 72, 52, Enum.Material.Brick), pips = finish(230, 224, 210, Enum.Material.Concrete) },
	DiceClover = { body = finish(40, 150, 70), pips = GOLD, sparkle = Color3.fromRGB(160, 255, 140) },
	DiceLava = {
		body = finish(34, 26, 24, Enum.Material.Basalt),
		pips = finish(255, 110, 20, Enum.Material.Neon),
		glow = Color3.fromRGB(255, 120, 40),
	},
	DiceBone = { body = finish(232, 224, 200), pips = finish(170, 16, 24) },
	DiceMoney = { body = finish(120, 170, 110, Enum.Material.Fabric), pips = finish(30, 70, 40) },
	DiceChampion = { body = WHITE, pips = GOLD, sparkle = Color3.fromRGB(255, 236, 170) },
	DiceGalaxy = {
		body = finish(30, 16, 70, Enum.Material.Glass, 0.05),
		pips = finish(200, 220, 255, Enum.Material.Neon),
		sparkle = Color3.fromRGB(190, 170, 255),
		glow = Color3.fromRGB(130, 90, 255),
	},
	DiceFrozen = { body = finish(190, 230, 255, Enum.Material.Ice), pips = finish(60, 110, 180) },
	DiceDiamond = {
		body = finish(230, 248, 255, Enum.Material.Glass, 0.25),
		pips = finish(255, 255, 255, Enum.Material.Neon),
		sparkle = Color3.fromRGB(230, 250, 255),
	},
	DiceCandy = { body = finish(255, 170, 210), pips = WHITE },
}) :: { [string]: Skin }

local function paint(part: BasePart, look: Finish)
	part.Color = look.color
	part.Material = look.material
	part.Transparency = look.transparency or 0
end

-- Finishes a die model in `skin` (unknown skins are ivory), replacing any earlier skin's effects.
function DiceLook.apply(die: Model, skin: string?)
	local look = DiceLook.SKINS[skin or ""] or DiceLook.SKINS.DiceIvory
	local body = die:FindFirstChild("Body", true)
	local pips = die:FindFirstChild("Pips", true)
	if body and body:IsA("BasePart") then
		paint(body, look.body)
		for _, child in body:GetChildren() do
			if child:GetAttribute("SkinFx") then
				child:Destroy()
			end
		end
		if look.glow then
			local light = Instance.new("PointLight")
			light.Color = look.glow
			light.Range = 6
			light.Brightness = 1.2
			light:SetAttribute("SkinFx", true)
			light.Parent = body
		end
		if look.sparkle then
			local attachment = Instance.new("Attachment")
			attachment:SetAttribute("SkinFx", true)
			attachment.Parent = body
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = SPARKLE
			emitter.Color = ColorSequence.new(look.sparkle)
			emitter.LightEmission = 1
			emitter.Rate = 6
			emitter.Lifetime = NumberRange.new(0.4, 0.8)
			emitter.Speed = NumberRange.new(0.5, 1.5)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new(0.18, 0)
			emitter.Parent = attachment
		end
	end
	if pips and pips:IsA("BasePart") then
		paint(pips, look.pips)
	end
end

return DiceLook
