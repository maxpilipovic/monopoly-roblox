--!strict
local Players = game:GetService("Players")

local BoardBuilder = require(script.BoardBuilder)
local GameService = require(script.GameService)

-- Tokens are the only thing on the board; no avatars.
Players.CharacterAutoLoads = false

BoardBuilder.build(workspace)
GameService.start()
