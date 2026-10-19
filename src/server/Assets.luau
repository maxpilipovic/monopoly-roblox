--!strict
-- Loads every uploaded model in AssetIds into ReplicatedStorage.Assets.<Kind>.<Shape> so clients
-- can clone them. Runs once at startup; a model that fails to load is logged and skipped, and the
-- client falls back to what it drew before models existed.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetIds = require(ReplicatedStorage.Shared.Cosmetics.AssetIds)

local Assets = {}

-- Blender keeps object names unique across a file ("Body", "Body.001", ...); the game looks parts up
-- by their plain names.
function Assets.cleanName(name: string): string
	return (name:gsub("%.%d+$", ""))
end

-- LoadAsset wraps the upload in a Model; the upload itself is the Model inside it.
local function fetch(id: number): Model?
	local ok, container = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok then
		warn(`Assets: could not load {id}: {container}`)
		return nil
	end
	local inner = (container :: Model):FindFirstChildWhichIsA("Model")
	if inner then
		inner.Parent = nil
	end
	container:Destroy()
	return inner
end

function Assets.load()
	local root = Instance.new("Folder")
	root.Name = "Assets"
	root.Parent = ReplicatedStorage
	-- Studio playtest aid: the NoModels attribute plays the game as if no model could be loaded.
	if RunService:IsStudio() and workspace:GetAttribute("NoModels") then
		return
	end
	task.spawn(function()
		for kind, shapes in AssetIds do
			local folder = Instance.new("Folder")
			folder.Name = kind
			folder.Parent = root
			-- Loaded side by side: two dozen one after another made the lobby wait.
			for shape, id in shapes do
				task.spawn(function()
					local model = fetch(id)
					if model then
						model.Name = shape
						for _, part in model:GetDescendants() do
							part.Name = Assets.cleanName(part.Name)
						end
						model.Parent = folder
					end
				end)
			end
		end
	end)
end

return Assets
