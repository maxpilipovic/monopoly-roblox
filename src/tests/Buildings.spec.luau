--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Buildings = require(StarterPlayer.StarterPlayerScripts.Client.Buildings)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["wanted lists only built positions"] = function()
	local snapshot = {
		properties = {
			{ position = 1, owner = "p1", houses = 2, mortgaged = false },
			{ position = 3, owner = "p1", houses = 0, mortgaged = false },
			{ position = 39, owner = "p2", houses = 5, mortgaged = false },
		},
	} :: any
	local wanted = Buildings.wanted(snapshot)
	Expect.equal(wanted[1], 2, "two houses")
	Expect.equal(wanted[3], nil, "bare lot")
	Expect.equal(wanted[39], 5, "hotel")
	Expect.equal(next(Buildings.wanted(nil)), nil, "lobby: nothing")
end

local function streets(houses: { [number]: number }): any
	local properties = {}
	for position, count in houses do
		table.insert(properties, { position = position, owner = "p1", houses = count, mortgaged = false })
	end
	return { properties = properties }
end

local function names(folder: Instance?): string
	if not folder then
		return ""
	end
	local list = {}
	for _, child in folder:GetChildren() do
		table.insert(list, child.Name)
	end
	table.sort(list)
	return table.concat(list, ",")
end

tests["houses go up, become a hotel, and come down again"] = function()
	local holder = Instance.new("Folder")
	holder.Parent = workspace
	local view = Buildings.new(holder)
	view:apply(streets({}))
	view:apply(streets({ [1] = 2 }))
	local street = view.folder:FindFirstChild("1")
	Expect.equal(names(street), "House1,House2", "two houses")
	view:apply(streets({ [1] = 4 }))
	Expect.equal(names(street), "House1,House2,House3,House4", "four")
	view:apply(streets({ [1] = 5 }))
	task.wait(0.5) -- the houses sink away as the hotel rises
	Expect.equal(names(street), "Hotel", "a hotel in their place")
	view:apply(streets({ [1] = 0 }))
	task.wait(0.5)
	Expect.equal(names(street), "", "sold off")
	holder:Destroy()
end

tests["a game joined mid-way shows its buildings at once"] = function()
	local holder = Instance.new("Folder")
	holder.Parent = workspace
	local view = Buildings.new(holder)
	view:apply(streets({ [39] = 5, [37] = 3 }))
	Expect.equal(names(view.folder:FindFirstChild("39")), "Hotel")
	Expect.equal(names(view.folder:FindFirstChild("37")), "House1,House2,House3")
	local hotel = view.folder:FindFirstChild("39"):FindFirstChild("Hotel") :: Model
	local _, size = hotel:GetBoundingBox()
	Expect.equal(size.Y > 0.9, true, `full size at once, got height {size.Y}`)
	view:apply(nil)
	Expect.equal(names(view.folder:FindFirstChild("39")), "", "back to the lobby clears it")
	holder:Destroy()
end

return tests
