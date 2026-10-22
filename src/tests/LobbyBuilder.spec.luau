--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TableLayout = require(ReplicatedStorage.Shared.Lobby.TableLayout)
local LobbyBuilder = require(ServerScriptService.Server.LobbyBuilder)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Builds the lobby in a scratch folder, runs the body, and always tears it down.
local function withLobby(body: (Model) -> ())
	local scratch = Instance.new("Folder")
	scratch.Parent = workspace -- tags only show in GetTagged inside the DataModel
	local ok, err = pcall(function()
		body(LobbyBuilder.build(scratch))
	end)
	scratch:Destroy()
	if not ok then
		error(err, 0)
	end
end

local function tagged(model: Model, tag: string): { Instance }
	local found = {}
	for _, item in CollectionService:GetTagged(tag) do
		if item:IsDescendantOf(model) then
			table.insert(found, item)
		end
	end
	return found
end

tests["builds twelve tables with six chairs each, where TableLayout puts them"] = function()
	withLobby(function(lobby)
		local tables = tagged(lobby, LobbyBuilder.TABLE_TAG)
		Expect.equal(#tables, TableLayout.COUNT, "tables")
		for _, item in tables do
			local model = item :: Model
			local id = model:GetAttribute("TableId") :: number
			Expect.equal(model:GetAttribute("Ranked"), TableLayout.kind(id) == "Ranked", `table {id} kind`)
			local top = model:FindFirstChild("Top") :: BasePart
			local expected = LobbyBuilder.CENTRE + TableLayout.offset(id)
			Expect.near(top.Position.X, expected.X, `table {id} x`, 0.1)
			Expect.near(top.Position.Z, expected.Z, `table {id} z`, 0.1)
			local chairs = model:FindFirstChild("Chairs") :: Folder
			Expect.equal(#chairs:GetChildren(), TableLayout.CHAIRS, `table {id} chairs`)
			for index = 1, TableLayout.CHAIRS do
				local seat = chairs:FindFirstChild(`Chair{index}`) :: Seat
				assert(seat and seat:IsA("Seat"), `table {id} chair {index} missing`)
				Expect.equal(seat.CanTouch, false, "no sitting by bumping into it")
				assert(seat:FindFirstChild("SitPrompt"), `table {id} chair {index} has no prompt`)
			end
			local sign = model:FindFirstChild("Sign", true)
			assert(sign and sign:FindFirstChild("Title", true) and sign:FindFirstChild("Status", true), `table {id} sign`)
		end
	end)
end

tests["the hall keeps its spawn, leaderboards and the ranked arch"] = function()
	withLobby(function(lobby)
		local spawns = 0
		for _, item in lobby:GetDescendants() do
			if item:IsA("SpawnLocation") then
				spawns += 1
			end
		end
		Expect.equal(spawns, 1, "spawns")
		Expect.equal(#tagged(lobby, LobbyBuilder.BOARD_TAG), 3, "leaderboards")
		assert(lobby:FindFirstChild("RankedSign", true), "no RANKED sign")
	end)
end

return tests
