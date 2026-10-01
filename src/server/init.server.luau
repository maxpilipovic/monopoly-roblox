--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BoardBuilder = require(script.BoardBuilder)
local GameService = require(script.GameService)

-- Tokens are the only thing on the board; no avatars.
Players.CharacterAutoLoads = false

BoardBuilder.build(workspace)
GameService.start()

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
end
