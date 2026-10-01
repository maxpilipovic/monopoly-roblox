--!strict
-- Client-side ownership strips: a bar in the owner's seat color along each owned tile's outer edge,
-- gray with owner-colored caps while mortgaged. Kept in step with the snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OwnerLayout = require(ReplicatedStorage.Shared.Board.OwnerLayout)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)

local CAP_LENGTH = 0.8

local OwnerMarkers = {}
OwnerMarkers.__index = OwnerMarkers

OwnerMarkers.MORTGAGED_COLOR = Color3.fromRGB(60, 60, 64)

export type Marker = { seat: number, mortgaged: boolean }

export type OwnerMarkersView = typeof(setmetatable({} :: { folder: Folder, shown: { [number]: string } }, OwnerMarkers))

function OwnerMarkers.new(parent: Instance): OwnerMarkersView
	local folder = Instance.new("Folder")
	folder.Name = "OwnerMarkers"
	folder.Parent = parent
	return setmetatable({ folder = folder, shown = {} }, OwnerMarkers)
end

-- Position -> owner's seat and mortgage state, for every owned deed.
function OwnerMarkers.wanted(snapshot: Protocol.Snapshot?): { [number]: Marker }
	local wanted = {}
	if snapshot then
		local seats = {}
		for _, player in snapshot.players do
			seats[player.id] = player.seat
		end
		for _, property in snapshot.properties do
			local seat = seats[property.owner]
			if seat then
				wanted[property.position] = { seat = seat, mortgaged = property.mortgaged }
			end
		end
	end
	return wanted
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
end

local function key(marker: Marker?): string?
	return if marker then `{marker.seat}:{marker.mortgaged}` else nil
end

local function show(self: OwnerMarkersView, position: number, marker: Marker?)
	local existing = self.folder:FindFirstChild(tostring(position))
	if existing then
		existing:Destroy()
	end
	self.shown[position] = key(marker)
	if not marker then
		return
	end
	local group = Instance.new("Folder")
	group.Name = tostring(position)
	group.Parent = self.folder
	local color = TokenLayout.SEAT_COLORS[marker.seat]
	local size = OwnerLayout.SIZE
	local centre = OwnerLayout.cframe(position)
	if not marker.mortgaged then
		makePart("Strip", size, centre, color, group)
		return
	end
	-- Mortgaged: gray in the middle, the owner's color only at the ends so it's still clear whose it is.
	local middle = size.X - 2 * CAP_LENGTH
	makePart("Mortgaged", Vector3.new(middle, size.Y, size.Z), centre, OwnerMarkers.MORTGAGED_COLOR, group)
	local capSize = Vector3.new(CAP_LENGTH, size.Y, size.Z)
	local offset = size.X / 2 - CAP_LENGTH / 2
	makePart("CapLeft", capSize, centre * CFrame.new(-offset, 0, 0), color, group)
	makePart("CapRight", capSize, centre * CFrame.new(offset, 0, 0), color, group)
end

function OwnerMarkers.apply(self: OwnerMarkersView, snapshot: Protocol.Snapshot?)
	local wanted = OwnerMarkers.wanted(snapshot)
	for position in self.shown do
		if not wanted[position] then
			show(self, position, nil)
		end
	end
	for position, marker in wanted do
		if self.shown[position] ~= key(marker) then
			show(self, position, marker)
		end
	end
end

return OwnerMarkers
