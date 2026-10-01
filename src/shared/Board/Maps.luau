--!strict
-- Which board is in play. One game runs at a time, so the board data has a single active map that
-- the server sets when a game starts and each client sets from the snapshot.

local Cards = require(script.Parent.Cards)
local Tiles = require(script.Parent.Tiles)

local Maps = {}

Maps.IDS = Tiles.MAPS
Maps.DEFAULT = "Classic"

local current = Maps.DEFAULT

function Maps.use(mapId: string)
	assert(table.find(Maps.IDS, mapId), `unknown map {mapId}`)
	Tiles.use(mapId)
	Cards.use(mapId)
	current = mapId
end

function Maps.current(): string
	return current
end

return Maps
