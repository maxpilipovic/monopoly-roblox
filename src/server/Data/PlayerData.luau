--!strict
-- Loads, holds and saves each player's Profile. One DataStore key per player; saved when they leave,
-- after every game and purchase, and on shutdown. Where DataStores aren't available (a Studio place
-- without API access) profiles live in memory for the session and a warning says so.
-- Clients are told their own profile (stats, inventory, equipped) whenever it changes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Profile = require(script.Parent.Profile)

local PlayerData = {}

PlayerData.STORE_NAME = "PlayerData_v1"
local RETRIES = 3

local store: DataStore? = nil
local storeWarned = false
local profiles: { [Player]: Profile.Profile } = {}
local loaded: { [Player]: BindableEvent } = {}
local profileRemote: RemoteEvent? = nil
local changedListeners: { (Player, Profile.Profile) -> () } = {}

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, PlayerData.STORE_NAME)
	if ok then
		store = result
	end
	return store
end

local function warnOnce(message: string)
	if not storeWarned then
		storeWarned = true
		warn(`PlayerData: {message}; profiles are kept in memory only this session`)
	end
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- The view a client gets of its own profile.
function PlayerData.view(profile: Profile.Profile): Protocol.ProfileView
	return {
		stats = table.clone(profile.stats),
		inventory = table.clone(profile.inventory),
		equipped = { piece = profile.equipped.piece, rentEffect = profile.equipped.rentEffect },
	}
end

local function push(player: Player)
	local profile = profiles[player]
	if profile and profileRemote and player.Parent then
		profileRemote:FireClient(player, PlayerData.view(profile))
	end
	for _, listener in changedListeners do
		if profile then
			task.spawn(listener, player, profile)
		end
	end
end

local function load(player: Player): Profile.Profile
	local dataStore = getStore()
	if dataStore then
		for attempt = 1, RETRIES do
			local ok, result = pcall(dataStore.GetAsync, dataStore, key(player))
			if ok then
				return Profile.reconcile(result)
			end
			if attempt == RETRIES then
				warnOnce(`could not read {player.Name}'s data ({result})`)
			else
				task.wait(attempt)
			end
		end
	else
		warnOnce("DataStoreService is unavailable")
	end
	return Profile.new()
end

-- Returns whether the profile is safely stored (true too when there's no DataStore to store it in).
function PlayerData.save(player: Player): boolean
	local profile = profiles[player]
	local dataStore = getStore()
	if not profile then
		return false
	elseif not dataStore then
		return true
	end
	for attempt = 1, RETRIES do
		local ok, err = pcall(dataStore.SetAsync, dataStore, key(player), profile, { player.UserId })
		if ok then
			return true
		end
		if attempt == RETRIES then
			warnOnce(`could not save {player.Name}'s data ({err})`)
		else
			task.wait(attempt)
		end
	end
	return false
end

-- The player's profile, waiting for it to load if need be (nil if they left first).
function PlayerData.get(player: Player): Profile.Profile?
	if profiles[player] then
		return profiles[player]
	end
	local signal = loaded[player]
	if signal and player.Parent then
		signal.Event:Wait()
	end
	return profiles[player]
end

-- Already loaded, without waiting.
function PlayerData.peek(player: Player): Profile.Profile?
	return profiles[player]
end

-- Changes a profile, tells the client, and (with `persist`) saves it in the background.
function PlayerData.update(player: Player, change: (Profile.Profile) -> (), persist: boolean?)
	local profile = profiles[player]
	if not profile then
		return
	end
	change(profile)
	push(player)
	if persist then
		task.spawn(PlayerData.save, player)
	end
end

function PlayerData.onChanged(listener: (Player, Profile.Profile) -> ())
	table.insert(changedListeners, listener)
end

local function onPlayerAdded(player: Player)
	local signal = Instance.new("BindableEvent")
	loaded[player] = signal
	local profile = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = profile
	loaded[player] = nil
	signal:Fire()
	signal:Destroy()
	push(player)
end

function PlayerData.start()
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local remote = Instance.new("RemoteEvent")
	remote.Name = Protocol.PROFILE
	remote.Parent = remotes
	profileRemote = remote
	-- A client asking again (its UI loaded after the first push) gets its profile.
	remote.OnServerEvent:Connect(function(player)
		push(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerData.save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.save(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.5)
		end
	end)
end

return PlayerData
