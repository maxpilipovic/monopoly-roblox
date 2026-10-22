--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Icons = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Icons)
local PlayerList = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Views.PlayerList)
local Expect = require(script.Parent.Expect)

local tests = {}

local function row(id: string, seat: number, isYou: boolean, isBot: boolean): any
	return {
		id = id,
		name = `Player {seat}`,
		seat = seat,
		money = 1500,
		bankrupt = false,
		inJail = false,
		isYou = isYou,
		isBot = isBot,
		isCurrent = seat == 1,
		deeds = 0,
	}
end

local ROWS = { row("101", 1, true, false), row("202", 2, false, false), row("bot1", 3, false, true) }

local function muteOf(list: any, id: string): ImageButton?
	local frame = list.rows:FindFirstChild(id)
	return frame and frame:FindFirstChild("Mute", true) :: ImageButton?
end

tests["only other people get a mute button, not you or the bots"] = function()
	local holder = Instance.new("Folder")
	local list = PlayerList.new(holder, function() end)
	list:render(ROWS, nil)
	Expect.equal(muteOf(list, "101"), nil, "you")
	assert(muteOf(list, "202"), "another person")
	Expect.equal(muteOf(list, "bot1"), nil, "bot")
	holder:Destroy()
end

tests["the mute button shows whether they're muted and follows the server's list"] = function()
	local holder = Instance.new("Folder")
	local list = PlayerList.new(holder, function() end)
	list:render(ROWS, nil)
	local button = muteOf(list, "202") :: ImageButton
	Expect.equal(button.Image, Icons.uri("Speaker"), "heard")
	list:setMuted({ [202] = true })
	Expect.equal(button.Image, Icons.uri("SpeakerMuted"), "muted")
	list:render(ROWS, nil)
	Expect.equal((muteOf(list, "202") :: ImageButton).Image, Icons.uri("SpeakerMuted"), "still muted after a rebuild")
	holder:Destroy()
end

tests["without a mute handler there are no mute buttons"] = function()
	local holder = Instance.new("Folder")
	local list = PlayerList.new(holder)
	list:render(ROWS, nil)
	Expect.equal(muteOf(list, "202"), nil)
	holder:Destroy()
end

return tests
