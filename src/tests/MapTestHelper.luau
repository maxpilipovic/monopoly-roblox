--!strict
-- Runs a test body on the College map and always puts Classic back, so a failure can't leak.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.Shared.Board.Maps)

local MapTestHelper = {}

function MapTestHelper.onCollege(body: () -> ())
	Maps.use("College")
	local ok, err = pcall(body)
	Maps.use("Classic")
	if not ok then
		error(err, 0)
	end
end

return MapTestHelper
