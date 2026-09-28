--!strict
-- Client-side houses and hotels, kept in step with the snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingLayout = require(ReplicatedStorage.Shared.Board.BuildingLayout)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)

local HOUSE_COLOR = Color3.fromRGB(46, 160, 67)
local HOTEL_COLOR = Color3.fromRGB(200, 40, 40)

local Buildings = {}
Buildings.__index = Buildings

export type BuildingsView = typeof(setmetatable({} :: { folder: Folder, shown: { [number]: number } }, Buildings))

function Buildings.new(parent: Instance): BuildingsView
	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = parent
	return setmetatable({ folder = folder, shown = {} }, Buildings)
end

-- Position -> houses (5 = hotel) for every built street.
function Buildings.wanted(snapshot: Protocol.Snapshot?): { [number]: number }
	local wanted = {}
	if snapshot then
		for _, property in snapshot.properties do
			if property.houses > 0 then
				wanted[property.position] = property.houses
			end
		end
	end
	return wanted
end

local function makePart(name: string, size: Vector3, base: CFrame, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = base * CFrame.new(0, size.Y / 2, 0)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
end

local function show(self: BuildingsView, position: number, houses: number)
	local existing = self.folder:FindFirstChild(tostring(position))
	if existing then
		existing:Destroy()
	end
	self.shown[position] = if houses > 0 then houses else nil
	if houses == 0 then
		return
	end
	local group = Instance.new("Folder")
	group.Name = tostring(position)
	group.Parent = self.folder
	if houses == BuildingLayout.HOTEL then
		makePart("Hotel", BuildingLayout.HOTEL_SIZE, BuildingLayout.cframe(position, BuildingLayout.HOTEL), HOTEL_COLOR, group)
	else
		for index = 1, houses do
			makePart(`House{index}`, BuildingLayout.HOUSE_SIZE, BuildingLayout.cframe(position, index), HOUSE_COLOR, group)
		end
	end
end

function Buildings.apply(self: BuildingsView, snapshot: Protocol.Snapshot?)
	local wanted = Buildings.wanted(snapshot)
	for position in self.shown do
		if not wanted[position] then
			show(self, position, 0)
		end
	end
	for position, houses in wanted do
		if self.shown[position] ~= houses then
			show(self, position, houses)
		end
	end
end

return Buildings
