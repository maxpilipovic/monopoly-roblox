--!strict
-- Chests and equipping. Chests are Developer Products: the purchase prompt is shown from here, and
-- Roblox calls ProcessReceipt once it's paid. A receipt is granted at most once (its id is kept in
-- the profile), and only reported granted once the profile is saved, so Roblox retries otherwise.
-- While a chest's product id is 0, Studio can test-open it for free; live servers refuse.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Chests = require(ReplicatedStorage.Shared.Store.Chests)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Profile = require(script.Parent.Parent.Data.Profile)
local Throttle = require(script.Parent.Parent.Game.Throttle)

local ShopService = {}

local random = Random.new()
local chestRemote: RemoteEvent
local requests = Throttle.new(0.3)

-- Rolls and grants one chest's item, and tells the player what came out.
local function open(player: Player, chest: Chests.Chest, purchaseId: string?): boolean
	local profile = PlayerData.get(player)
	if not profile or PlayerData.isUnreadable(player) then
		-- Their real data couldn't be read: anything granted now could never be kept, so leave the
		-- purchase pending for Roblox to retry once their data loads (next session).
		return false
	end
	if purchaseId and Profile.hasReceipt(profile, purchaseId) then
		-- Granted on an earlier attempt: report it only once that's safely saved.
		return PlayerData.save(player)
	end
	local item = Chests.roll(chest.id, random)
	local count = 0
	PlayerData.update(player, function(p)
		count = Profile.grant(p, item)
		if purchaseId then
			Profile.addReceipt(p, purchaseId)
		end
	end)
	-- A paid chest is only reported granted once it's saved; a Studio test open doesn't wait.
	if purchaseId then
		if not PlayerData.save(player) then
			return false
		end
	else
		task.spawn(PlayerData.save, player)
	end
	chestRemote:FireClient(player, { chest = chest.id, item = item, count = count } :: Protocol.ChestResult)
	return true
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local chest = Chests.forProduct(receipt.ProductId)
	if not player or not chest then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(open, player, chest, tostring(receipt.PurchaseId))
	if ok and granted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onRequest(player: Player, request: any)
	if typeof(request) ~= "table" or not Throttle.allow(requests, tostring(player.UserId), os.clock()) then
		return
	end
	if request.type == "Equip" and typeof(request.item) == "string" then
		PlayerData.update(player, function(profile)
			Profile.equip(profile, request.item)
		end, "soon")
	elseif request.type == "UnequipEffect" then
		PlayerData.update(player, Profile.unequipRentEffect, "soon")
	elseif request.type == "Buy" or request.type == "TestOpen" then
		local chest = typeof(request.chest) == "string" and Chests.byId[request.chest]
		if not chest then
			return
		end
		if chest.productId ~= 0 and request.type == "Buy" then
			MarketplaceService:PromptProductPurchase(player, chest.productId)
		elseif RunService:IsStudio() then
			open(player, chest, nil)
		end
	end
end

function ShopService.start()
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local storeRemote = Instance.new("RemoteEvent")
	storeRemote.Name = Protocol.STORE
	storeRemote.Parent = remotes
	chestRemote = Instance.new("RemoteEvent")
	chestRemote.Name = Protocol.CHEST
	chestRemote.Parent = remotes
	storeRemote.OnServerEvent:Connect(onRequest)
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		Throttle.forget(requests, tostring(player.UserId))
	end)
end

return ShopService
