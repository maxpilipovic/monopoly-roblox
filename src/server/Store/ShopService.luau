--!strict
-- Chests, coin packs and equipping. A chest is opened with coins or with a chest key (a challenge
-- reward); an item already owned turns into coins instead (Rewards.DUPLICATE_COINS). Robux buys only
-- coin packs: Developer Products, the purchase prompt is shown from here, and Roblox calls
-- ProcessReceipt once it's paid. A receipt is granted at most once (its id is kept in the profile),
-- and only reported granted once the profile is saved, so Roblox retries otherwise. While a pack's
-- product id is 0, Studio can test-buy it for free; live servers refuse.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Chests = require(ReplicatedStorage.Shared.Store.Chests)
local CoinPacks = require(ReplicatedStorage.Shared.Store.CoinPacks)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Rewards = require(ReplicatedStorage.Shared.Progress.Rewards)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Profile = require(script.Parent.Parent.Data.Profile)
local Throttle = require(script.Parent.Parent.Game.Throttle)

local ShopService = {}

local random = Random.new()
local chestRemote: RemoteEvent
local requests = Throttle.new(0.3)

-- Rolls and grants one chest's item, and tells the player what came out. `pay` takes the price
-- (coins or a key) inside the same change, and refuses by returning false.
local function open(player: Player, chest: Chests.Chest, pay: (Profile.Profile) -> boolean): boolean
	local profile = PlayerData.get(player)
	if not profile or PlayerData.isUnreadable(player) then
		-- Their real data couldn't be read: anything granted now could never be kept.
		return false
	end
	if not pay(profile) then
		return false
	end
	local item = Chests.roll(chest.id, random)
	local count = 0
	local refund: number? = nil
	PlayerData.update(player, function(p)
		if Profile.owns(p, item) then
			refund = Rewards.DUPLICATE_COINS[Catalog.byId[item].rarity]
			Progress.addCoins(p, refund :: number)
			count = p.inventory[item] or 1
		else
			count = Profile.grant(p, item)
		end
		Progress.add(p, { chestsOpened = 1 })
	end)
	task.spawn(PlayerData.save, player)
	chestRemote:FireClient(player, { chest = chest.id, item = item, count = count, refund = refund } :: Protocol.ChestResult)
	return true
end

-- Adds a coin pack's coins (the wallet updates with the profile). A paid pack (`purchaseId`) is
-- granted at most once and only reported granted once saved, so Roblox retries otherwise.
local function grantCoins(player: Player, pack: CoinPacks.Pack, purchaseId: string?): boolean
	local profile = PlayerData.get(player)
	if not profile or PlayerData.isUnreadable(player) then
		-- Their real data couldn't be read: leave the purchase pending for Roblox to retry once their
		-- data loads (next session).
		return false
	end
	if purchaseId and Profile.hasReceipt(profile, purchaseId) then
		return PlayerData.save(player)
	end
	PlayerData.update(player, function(p)
		Progress.addCoins(p, pack.coins)
		if purchaseId then
			Profile.addReceipt(p, purchaseId)
		end
	end)
	if purchaseId then
		if not PlayerData.save(player) then
			return false
		end
	else
		task.spawn(PlayerData.save, player)
	end
	return true
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local pack = CoinPacks.forProduct(receipt.ProductId)
	if not player or not pack then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantCoins, player, pack, tostring(receipt.PurchaseId))
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
	elseif request.type == "Unequip" and typeof(request.kind) == "string" then
		PlayerData.update(player, function(profile)
			Profile.unequip(profile, request.kind)
		end, "soon")
	elseif request.type == "BuyWithCoins" or request.type == "UseKey" then
		local chest = typeof(request.chest) == "string" and Chests.byId[request.chest]
		if not chest then
			return
		end
		local withKey = request.type == "UseKey"
		open(player, chest, function(profile)
			if withKey then
				if (profile.keys[chest.id] or 0) <= 0 then
					return false
				end
				profile.keys[chest.id] -= 1
				if profile.keys[chest.id] <= 0 then
					profile.keys[chest.id] = nil
				end
			else
				local price = Rewards.CHEST_COINS[chest.id]
				if not price or profile.coins < price then
					return false
				end
				profile.coins -= price
			end
			return true
		end)
	elseif request.type == "BuyCoins" or request.type == "TestBuyCoins" then
		local pack = typeof(request.pack) == "string" and CoinPacks.byId[request.pack]
		if not pack then
			return
		end
		if pack.productId ~= 0 and request.type == "BuyCoins" then
			MarketplaceService:PromptProductPurchase(player, pack.productId)
		elseif RunService:IsStudio() then
			grantCoins(player, pack, nil)
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
