--!strict
-- Challenges on the server: deals each player's daily challenges (on joining, and at midnight UTC
-- for whoever is on), and handles claims (dailies, achievement tiers, Empire Tree nodes) and the
-- daily swap. The rules are in Shared.Progress.Progress; the counters they read are kept by
-- RoomService (game events and results) and ShopService (chests). Every claim is checked here
-- against the saved profile, so a client can only ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Progress.Achievements)
local Dailies = require(ReplicatedStorage.Shared.Progress.Dailies)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Stats = require(ReplicatedStorage.Shared.Progress.Stats)
local Tree = require(ReplicatedStorage.Shared.Progress.Tree)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Throttle = require(script.Parent.Parent.Game.Throttle)

local ProgressService = {}

ProgressService.CHECK_SECONDS = 30 -- how often to look for the day turning

local rewardRemote: RemoteEvent
local requests = Throttle.new(0.2)

local function today(): number
	return Dailies.dayOf(os.time())
end

-- Deals today's dailies if this player's are from another day.
local function refresh(player: Player)
	local profile = PlayerData.peek(player)
	if profile and not PlayerData.isUnreadable(player) and profile.daily.day ~= today() then
		PlayerData.update(player, function(p)
			Progress.refreshDaily(p, player.UserId, today())
		end, "soon")
	end
end

local function tell(player: Player, view: Protocol.RewardView)
	rewardRemote:FireClient(player, view)
end

local function refuse(player: Player, why: string)
	tell(player, { source = "", title = "", notice = why })
end

local function onRequest(player: Player, request: any)
	if typeof(request) ~= "table" or not Throttle.allow(requests, tostring(player.UserId), os.clock()) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	elseif PlayerData.isUnreadable(player) then
		refuse(player, "your progress couldn't be loaded, so rewards can't be kept right now")
		return
	end
	refresh(player)
	local kind = request.type
	local ok, result: any = false, "unknown request"
	local view: Protocol.RewardView? = nil
	PlayerData.update(player, function(p)
		if kind == "ClaimDaily" and typeof(request.slot) == "number" then
			local line = Progress.dailies(p)[request.slot]
			ok, result = Progress.claimDaily(p, request.slot)
			if ok and line then
				view = { source = "Daily challenge", title = Stats.goal(line.daily.stat, line.daily.target), coins = result }
			end
		elseif kind == "SwapDaily" and typeof(request.slot) == "number" then
			ok, result = Progress.swapDaily(p, player.UserId, request.slot)
		elseif kind == "ClaimAchievement" and typeof(request.track) == "string" then
			local track = Achievements.byId[request.track]
			local line = if track then Progress.achievement(p, track.id) else nil
			ok, result = Progress.claimAchievement(p, request.track)
			if ok and track and line then
				view = {
					source = `{Achievements.TIER_NAMES[line.claimed + 1]} achievement`,
					title = track.name,
					coins = result.coins,
					item = result.item,
					key = result.key,
				}
			end
		elseif kind == "ClaimNode" and typeof(request.node) == "string" then
			local node = Tree.byId[request.node]
			ok, result = Progress.claimNode(p, request.node)
			if ok and node then
				local branch = if node.branch then Tree.branchById[node.branch] else nil
				view = {
					source = if branch then `Empire Tree · {branch.name}` else "Empire Tree",
					title = Stats.goal(node.stat, node.target),
					coins = result.coins,
					item = result.item,
					key = result.key,
				}
			end
		end
	end, "soon")
	if ok and view then
		tell(player, view)
		task.spawn(PlayerData.save, player)
	elseif not ok and typeof(result) == "string" then
		refuse(player, result)
	end
end

function ProgressService.start()
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = Protocol.PROGRESS
	requestRemote.Parent = remotes
	rewardRemote = Instance.new("RemoteEvent")
	rewardRemote.Name = Protocol.REWARD
	rewardRemote.Parent = remotes
	requestRemote.OnServerEvent:Connect(onRequest)

	-- A profile is dealt its dailies as soon as it's loaded (and whenever it changes on a new day).
	-- Hooked to profile changes rather than PlayerAdded: handlers there run in no set order, so the
	-- profile may not even be loading yet.
	PlayerData.onChanged(function(player, profile)
		if profile.tree.starts[Tree.ROOT] == nil then
			Progress.ensureTree(profile)
		end
		refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		Throttle.forget(requests, tostring(player.UserId))
	end)
	task.spawn(function()
		while true do
			task.wait(ProgressService.CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return ProgressService
