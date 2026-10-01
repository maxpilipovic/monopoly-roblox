--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local OwnerMarkers = require(StarterPlayer.StarterPlayerScripts.Client.OwnerMarkers)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["wanted lists each owned deed with its owner's seat and mortgage"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p2", 1)
	GameFixtures.own(state, "p3", 5)
	state.properties[5].mortgaged = true
	local wanted = OwnerMarkers.wanted(Snapshot.fromState(state))
	Expect.equal(wanted[1].seat, 2, "Mediterranean: p2's seat")
	Expect.equal(wanted[1].mortgaged, false)
	Expect.equal(wanted[5].seat, 3, "Reading: p3's seat")
	Expect.equal(wanted[5].mortgaged, true)
	Expect.equal(wanted[3], nil, "unowned")
	Expect.equal(next(OwnerMarkers.wanted(nil)), nil, "lobby: nothing")
end

local function parts(folder: Instance, position: number): { BasePart }
	local group = folder:FindFirstChild(tostring(position))
	local list = {}
	if group then
		for _, child in group:GetChildren() do
			table.insert(list, child :: BasePart)
		end
	end
	return list
end

tests["strips follow ownership changes, mortgages and the lobby"] = function()
	local holder = Instance.new("Folder")
	local view = OwnerMarkers.new(holder)
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	view:apply(Snapshot.fromState(state))
	local strip = parts(view.folder, 1)
	Expect.equal(#strip, 1, "one solid strip")
	Expect.equal(strip[1].Color, TokenLayout.SEAT_COLORS[1], "p1's color")
	assert(not strip[1].CanCollide and not strip[1].CanQuery and not strip[1].CanTouch, "strips are not solid")

	state.properties[1].owner = "p2" -- traded
	view:apply(Snapshot.fromState(state))
	Expect.equal(parts(view.folder, 1)[1].Color, TokenLayout.SEAT_COLORS[2], "recolored for p2")

	state.properties[1].mortgaged = true
	view:apply(Snapshot.fromState(state))
	local mortgaged = parts(view.folder, 1)
	Expect.equal(#mortgaged, 3, "gray middle and two caps")
	local grays, caps = 0, 0
	for _, part in mortgaged do
		if part.Color == OwnerMarkers.MORTGAGED_COLOR then
			grays += 1
		elseif part.Color == TokenLayout.SEAT_COLORS[2] then
			caps += 1
		end
	end
	Expect.equal(grays, 1, "gray middle")
	Expect.equal(caps, 2, "owner-colored caps")

	state.properties[1].mortgaged = false
	view:apply(Snapshot.fromState(state))
	Expect.equal(#parts(view.folder, 1), 1, "solid again, caps gone")

	state.properties[1] = nil -- back to the bank
	view:apply(Snapshot.fromState(state))
	Expect.equal(view.folder:FindFirstChild("1"), nil, "removed")

	GameFixtures.own(state, "p1", 3)
	view:apply(Snapshot.fromState(state))
	view:apply(nil)
	Expect.equal(#view.folder:GetChildren(), 0, "lobby clears everything")
	holder:Destroy()
end

return tests
