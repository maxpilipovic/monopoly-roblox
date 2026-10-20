--!strict
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Assets = require(script.Assets)
local Leaderboards = require(script.Data.Leaderboards)
local LobbyBuilder = require(script.LobbyBuilder)
local Nameplates = require(script.Nameplates)
local PlayerData = require(script.Data.PlayerData)
local ProgressService = require(script.Store.ProgressService)
local RoomService = require(script.RoomService)
local ShopService = require(script.Store.ShopService)

-- Players spawn into the lobby; each client builds the board itself while it's in a game.
LobbyBuilder.build(workspace)
Assets.load()
RoomService.start() -- makes the Remotes folder the other services add to
PlayerData.start()
Leaderboards.start()
ShopService.start()
ProgressService.start()
Nameplates.start()

-- Studio only: tooling that can't require our modules runs the tests by setting the workspace
-- attribute RunTests to a spec filter ("" for all); the report lands in TestResults.
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("RunTests"):Connect(function()
		local filter = workspace:GetAttribute("RunTests")
		if typeof(filter) ~= "string" then
			return
		end
		local runner = require(ServerStorage:WaitForChild("Tests"):WaitForChild("TestRunner")) :: any
		local ok, report = pcall(runner.run, if filter == "" then nil else filter)
		workspace:SetAttribute("TestResults", if ok then report else `runner error: {report}`)
		workspace:SetAttribute("RunTests", nil)
	end)

	-- Studio only: setting RecordDice to a count records that many physics throws (see DiceRecorder).
	workspace:GetAttributeChangedSignal("RecordDice"):Connect(function()
		local wanted = workspace:GetAttribute("RecordDice")
		if typeof(wanted) ~= "number" then
			return
		end
		workspace:SetAttribute("RecordDice", nil)
		local recorder = require(script.DevTools.DiceRecorder) :: any
		task.spawn(recorder.record, wanted)
	end)
end
