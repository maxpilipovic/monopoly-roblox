--!strict
-- The HUD's look in one place: "Boardwalk at night". Views take every colour, font and size from here.

local Theme = {}

Theme.color = table.freeze({
	panel = Color3.fromRGB(20, 26, 42),
	surface = Color3.fromRGB(30, 39, 64),
	surfaceHigh = Color3.fromRGB(44, 56, 90),
	stroke = Color3.fromRGB(255, 255, 255),
	shadow = Color3.fromRGB(0, 0, 0),
	accent = Color3.fromRGB(245, 197, 66),
	accentLip = Color3.fromRGB(184, 140, 28),
	primary = Color3.fromRGB(47, 191, 113),
	primaryLip = Color3.fromRGB(31, 138, 80),
	secondary = Color3.fromRGB(58, 70, 102),
	secondaryLip = Color3.fromRGB(40, 50, 80),
	danger = Color3.fromRGB(229, 72, 77),
	dangerLip = Color3.fromRGB(168, 48, 47),
	disabled = Color3.fromRGB(46, 52, 70),
	disabledLip = Color3.fromRGB(34, 39, 54),
	text = Color3.fromRGB(244, 246, 251),
	textDim = Color3.fromRGB(154, 166, 196),
	moneyUp = Color3.fromRGB(126, 226, 168),
	moneyDown = Color3.fromRGB(255, 139, 139),
	paper = Color3.fromRGB(251, 246, 233),
	ink = Color3.fromRGB(27, 31, 42),
	chance = Color3.fromRGB(247, 148, 29),
	chest = Color3.fromRGB(86, 164, 222),
})

Theme.font = table.freeze({
	display = Font.fromEnum(Enum.Font.FredokaOne),
	body = Font.fromEnum(Enum.Font.BuilderSansMedium),
	bodyBold = Font.fromEnum(Enum.Font.BuilderSansBold),
})

Theme.radius = table.freeze({ panel = 14, surface = 10, pill = 8 })
Theme.space = table.freeze({ xs = 4, s = 8, m = 12, l = 16 })
Theme.time = table.freeze({ fast = 0.12, pop = 0.2, slow = 0.35 })
Theme.textSize = table.freeze({ title = 30, heading = 22, body = 17, small = 14 })

Theme.panelTransparency = 0.06
Theme.strokeTransparency = 0.88

return Theme
