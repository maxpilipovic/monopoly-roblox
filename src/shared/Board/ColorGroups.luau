--!strict
export type ColorGroup = {
	color: Color3,
	houseCost: number,
}

local ColorGroups: { [string]: ColorGroup } = table.freeze({
	Brown = table.freeze({ color = Color3.fromRGB(149, 84, 54), houseCost = 50 }),
	LightBlue = table.freeze({ color = Color3.fromRGB(170, 224, 250), houseCost = 50 }),
	Pink = table.freeze({ color = Color3.fromRGB(217, 58, 150), houseCost = 100 }),
	Orange = table.freeze({ color = Color3.fromRGB(247, 148, 29), houseCost = 100 }),
	Red = table.freeze({ color = Color3.fromRGB(237, 27, 36), houseCost = 150 }),
	Yellow = table.freeze({ color = Color3.fromRGB(254, 242, 0), houseCost = 150 }),
	Green = table.freeze({ color = Color3.fromRGB(31, 178, 90), houseCost = 200 }),
	DarkBlue = table.freeze({ color = Color3.fromRGB(0, 114, 187), houseCost = 200 }),
})

return ColorGroups
