--!strict
local CameraDirector = require(script.CameraDirector)
local GameClient = require(script.GameClient)

GameClient.start(CameraDirector.start())
