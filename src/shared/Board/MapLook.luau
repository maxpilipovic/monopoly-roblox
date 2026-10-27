--!strict
-- What changes from map to map besides the names: what a map calls its railroads and utilities,
-- and which map a card id belongs to. Card ids carry their map as a prefix ("college.chest.go",
-- "eiu.chance.go"); classic cards have none.

local MapLook = {}

local PREFIXES = { college = "College", eiu = "EIU" }

-- What each map calls the tiles a "nearest" card sends you to.
local NOUNS: { [string]: { [string]: string } } = {
	Classic = { Railroad = "railroad", Utility = "utility" },
	College = { Railroad = "shuttle", Utility = "utility" },
	EIU = { Railroad = "hangout", Utility = "delivery" },
}

-- The card's map, and the classic card it was written from. A map's own crazy cards
-- ("eiu.crazy.ghost") have no classic twin, so they keep their whole id.
function MapLook.forCard(cardId: string): (string, string)
	local prefix, rest = cardId:match("^(%a+)%.(.+)$")
	local map = prefix and PREFIXES[prefix]
	if not map then
		return "Classic", cardId
	end
	if rest:sub(1, 6) == "crazy." then
		return map, cardId
	end
	return map, rest :: string
end

function MapLook.noun(mapId: string, tileKind: string): string
	local nouns = NOUNS[mapId] or NOUNS.Classic
	return nouns[tileKind] or "stop"
end

export type BoardColors = { tile: Color3, base: Color3, center: Color3 }

-- The board's own colours (the colour sets stay classic so streets read the same on every map).
local BOARDS: { [string]: BoardColors } = {
	Classic = { tile = Color3.fromRGB(214, 234, 214), base = Color3.fromRGB(35, 35, 35), center = Color3.fromRGB(196, 226, 200) },
	-- EIU blue and grey.
	EIU = { tile = Color3.fromRGB(226, 229, 234), base = Color3.fromRGB(0, 42, 102), center = Color3.fromRGB(188, 198, 214) },
}

function MapLook.board(mapId: string): BoardColors
	return BOARDS[mapId] or BOARDS.Classic
end

return MapLook
