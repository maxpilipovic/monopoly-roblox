--!strict
-- Loads, holds and saves each player's Profile, one DataStore key per player.
--
-- One server at a time owns a player's data (SessionLock): loading takes the lock, every save
-- refreshes it, leaving releases it, and a server that has lost it never writes again, so a player
-- hopping servers can't have newer data overwritten. Small changes (equipping) are saved by the
-- minute's autosave; results and purchases save at once; leaving and shutdown save too.
-- If a player's data can't be read, they play on a stand-in that is never saved over the real data.
-- Where DataStores aren't available (a Studio place without API access) profiles live in memory.
-- Clients are told their own profile whenever it changes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Profile = require(script.Parent.Profile)
local SessionLock = require(script.Parent.SessionLock)

local PlayerData = {}

PlayerData.STORE_NAME = "PlayerData_v1"
PlayerData.AUTOSAVE_SECONDS = 60
local RETRIES = 3
local LOCK_WAIT_SECONDS = 5 -- between tries while another server still holds the data
local LOCK_TRIES = 6 -- then take it anyway (that server is gone or stuck)

local store: DataStore? = nil
local disabled = false -- a Studio place without API access: stop trying (each try costs seconds)
local storeWarned = false
local profiles: { [Player]: Profile.Profile } = {}
local unreadable: { [Player]: boolean } = {} -- their stand-in must never be saved
local dirty: { [Player]: boolean } = {}
local loading: { [Player]: BindableEvent } = {}
local profileRemote: RemoteEvent? = nil
local changedListeners: { (Player, Profile.Profile) -> () } = {}

local function warnOnce(message: string)
	if not storeWarned then
		storeWarned = true
		warn(`PlayerData: {message}; profiles are kept in memory only this session`)
	end
end

local function getStore(): DataStore?
	if disabled then
		return nil
	end
	if not store then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, PlayerData.STORE_NAME)
		if ok then
			store = result
		else
			disabled = true
			warnOnce("DataStoreService is unavailable")
		end
	end
	return store
end

-- A Studio place without API access: nothing to load from or save to.
local function noAccess(err: any): boolean
	if tostring(err):find("Studio access", 1, true) then
		disabled = true
		warnOnce("Studio has no access to API services")
		return true
	end
	return false
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

function PlayerData.view(profile: Profile.Profile): Protocol.ProfileView
	return {
		stats = table.clone(profile.stats),
		inventory = table.clone(profile.inventory),
		equipped = { piece = profile.equipped.piece, rentEffect = profile.equipped.rentEffect },
	}
end

local function push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profileRemote and player.Parent then
		profileRemote:FireClient(player, PlayerData.view(profile))
	end
	for _, listener in changedListeners do
		task.spawn(listener, player, profile)
	end
end

-- Reads the player's data and takes the lock on it. Returns the profile and whether it really is
-- theirs (false: a stand-in after the store failed).
local function load(player: Player): (Profile.Profile, boolean)
	local dataStore = getStore()
	if not dataStore then
		return Profile.new(), true
	end
	local jobId = game.JobId
	local failures = 0
	for attempt = 1, LOCK_TRIES do
		local decision = "take"
		local ok, result = pcall(dataStore.UpdateAsync, dataStore, key(player), function(stored)
			decision = SessionLock.decide(stored, jobId, os.time(), attempt == LOCK_TRIES)
			if decision ~= "take" then
				return nil -- leave it alone; try again shortly
			end
			local record = if typeof(stored) == "table" then stored else {}
			record.lock = { job = jobId, at = os.time() }
			return record
		end)
		if ok and decision == "take" then
			return Profile.reconcile(result), true
		elseif not ok then
			if noAccess(result) then
				return Profile.new(), true
			end
			failures += 1
			warn(`PlayerData: reading {player.Name}'s data failed ({result})`)
			if failures >= RETRIES then
				break
			end
		end
		task.wait(if ok then LOCK_WAIT_SECONDS else failures)
		if not player.Parent then
			break
		end
	end
	warn(`PlayerData: could not read {player.Name}'s data; this session won't save over it`)
	return Profile.new(), false
end

local function write(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile then
		return false
	elseif unreadable[player] then
		return false -- saving the stand-in would wipe their real data
	end
	local dataStore = getStore()
	if not dataStore then
		return true -- nowhere to save in this place
	end
	local jobId = game.JobId
	for attempt = 1, RETRIES do
		local lost = false
		local ok, err = pcall(dataStore.UpdateAsync, dataStore, key(player), function(stored)
			if not SessionLock.canWrite(stored, jobId) then
				lost = true
				return nil
			end
			local record = table.clone(profile) :: any
			record.lock = if release then nil else { job = jobId, at = os.time() }
			return record
		end)
		if ok and lost then
			-- Another server has taken this player's data over; never write over it again.
			warn(`PlayerData: {player.Name}'s data is now held by another server; not saving here`)
			unreadable[player] = true
			return false
		elseif ok then
			dirty[player] = nil
			return true
		elseif noAccess(err) then
			return true
		end
		if attempt == RETRIES then
			warn(`PlayerData: could not save {player.Name}'s data ({err})`)
		else
			task.wait(attempt)
		end
	end
	return false
end

-- Saves now; returns whether the profile is safely stored.
function PlayerData.save(player: Player): boolean
	return write(player, false)
end

-- The player's profile, waiting for it to load (nil if they left first).
function PlayerData.get(player: Player): Profile.Profile?
	local signal = loading[player]
	if not profiles[player] and signal then
		signal.Event:Wait()
	end
	return profiles[player]
end

-- Already loaded, without waiting.
function PlayerData.peek(player: Player): Profile.Profile?
	return profiles[player]
end

-- True while the player is on a stand-in profile (their real data couldn't be read, or another
-- server took it over): nothing they earn or buy can be kept.
function PlayerData.isUnreadable(player: Player): boolean
	return unreadable[player] == true
end

-- Changes a profile and tells the client. `when`: "now" saves at once in the background, "soon"
-- leaves it to the autosave, nil doesn't mark it for saving.
function PlayerData.update(player: Player, change: (Profile.Profile) -> (), when: string?)
	local profile = profiles[player]
	if not profile then
		return
	end
	change(profile)
	push(player)
	if when == "now" then
		task.spawn(write, player, false)
	elseif when == "soon" then
		dirty[player] = true
	end
end

function PlayerData.onChanged(listener: (Player, Profile.Profile) -> ())
	table.insert(changedListeners, listener)
end

local function finishLoading(player: Player)
	local signal = loading[player]
	loading[player] = nil
	if signal then
		signal:Fire()
		signal:Destroy()
	end
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = Instance.new("BindableEvent")
	local profile, readable = load(player)
	if player.Parent then
		profiles[player] = profile
		unreadable[player] = if readable then nil else true
	end
	-- Always wake anyone waiting, even if the player left while loading.
	finishLoading(player)
	if player.Parent then
		push(player)
	end
end

local function onPlayerRemoving(player: Player)
	finishLoading(player)
	if profiles[player] then
		write(player, true)
	end
	profiles[player] = nil
	unreadable[player] = nil
	dirty[player] = nil
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
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- The autosave saves what changed and keeps everyone's lock fresh.
	task.spawn(function()
		while true do
			task.wait(PlayerData.AUTOSAVE_SECONDS)
			for player in profiles do
				if player.Parent and not unreadable[player] then
					task.spawn(write, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				write(player, true)
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
