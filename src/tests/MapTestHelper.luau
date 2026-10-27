--!strict
-- Runs a test body on another map and always puts Classic back, so a failure can't leak.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.Shared.Board.Maps)

local MapTestHelper = {}

function MapTestHelper.onMap(mapId: string, body: () -> ())
	Maps.use(mapId)
	local ok, err = pcall(body)
	Maps.use("Classic")
	if not ok then
		error(err, 0)
	end
end

function MapTestHelper.onCollege(body: () -> ())
	MapTestHelper.onMap("College", body)
end

return MapTestHelper
