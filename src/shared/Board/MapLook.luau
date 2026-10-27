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

return MapLook
