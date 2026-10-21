--!strict
-- Every sound in the game, played from one place.
--   Sheet sounds: synthesised by tools/audio/sfx.js into one uploaded "sound sheet"; each is a
--   slice of it (Sound.PlaybackRegion), so the whole set is a single asset.
--   Library sounds: recordings from the Roblox Creator Store (Pro Sound Effects' licensed library)
--   for things a synth can't fake well: the dice, the gavel, the jail bars, and each scene's ambience.
-- Sounds play through three SoundGroups (Interface, Effects, Ambience) so each can be turned down.
-- Nothing plays outside a client (the tests run these modules on the server).

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundSheet = require(script.Parent.SoundSheet)

local Sounds = {}

-- Everything is played at this share of its own volume (the groups' volume), so the whole game
-- can be turned up or down in one place.
Sounds.MASTER = 0.35

Sounds.SHEET = "rbxassetid://107013060354857"

-- Recorded sounds by name: id, volume, group.
Sounds.LIBRARY = table.freeze({
	Dice = { id = 9114073627, volume = 0.7 }, -- dice shaken and rolled (Pro Sound Effects)
	Gavel = { id = 9125573584, volume = 0.6 }, -- one gavel knock: a bid
	Sold = { id = 9125574353, volume = 0.7 }, -- three knocks: sold
	Jail = { id = 9117907161, volume = 0.6 }, -- prison bars rattling
})

-- Each scene's ambience: one or two loops under the game.
Sounds.AMBIENCE = table.freeze({
	Boardwalk = { { id = 136110984304606, volume = 0.17 } }, -- waves at night
	Tropical = { { id = 9112871354, volume = 0.2 } }, -- surf and gulls
	Winter = { { id = 9114057128, volume = 0.17 } }, -- whistling wind
	City = { { id = 9112772108, volume = 0.15 } }, -- distant traffic far below
})

-- A crackling fire, for a scene's campfire (played from the fire itself).
Sounds.FIRE = 109494611784143
-- The sound each rent effect makes as it plays over the payer.
Sounds.RENT_EFFECTS = table.freeze({
	CoinBurst = "Coins",
	ConfettiPop = "Pop",
	MoneyRain = "Coins",
	GoldenAura = "RevealRare",
	Lightning = "Thunder",
	Fireworks = "Firework",
	BlackHole = "Warp",
})

-- How loud each sheet sound is played and which group it's in.
local SHEET_MIX: { [string]: { volume: number, group: string } } = {
	Click = { volume = 0.5, group = "Interface" },
	Hover = { volume = 0.25, group = "Interface" },
	Open = { volume = 0.45, group = "Interface" },
	Close = { volume = 0.35, group = "Interface" },
	Tab = { volume = 0.4, group = "Interface" },
	Error = { volume = 0.45, group = "Interface" },
	Notify = { volume = 0.6, group = "Interface" },
	Equip = { volume = 0.55, group = "Interface" },
	Claim = { volume = 0.7, group = "Interface" },
	ChestShake = { volume = 0.6, group = "Interface" },
	ChestOpen = { volume = 0.75, group = "Interface" },
	RevealCommon = { volume = 0.6, group = "Interface" },
	RevealRare = { volume = 0.65, group = "Interface" },
	RevealEpic = { volume = 0.7, group = "Interface" },
	RevealLegendary = { volume = 0.8, group = "Interface" },
	SpinTick = { volume = 0.35, group = "Interface" },
	SpinDing = { volume = 0.6, group = "Interface" },
	Tick = { volume = 0.45, group = "Interface" },
}

local active = RunService:IsClient()
local groups: { [string]: SoundGroup } = {}
local pool: { [string]: { Sound } } = {}
local ambience: { Sound } = {}

local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local new = Instance.new("SoundGroup")
	new.Name = name
	new.Volume = Sounds.MASTER
	new.Parent = SoundService
	groups[name] = new
	return new
end

-- A free Sound for `key` (one that isn't playing), made the first time it's needed. A few of each
-- can overlap (coins tumbling, quick clicks).
local function voice(key: string, build: () -> Sound): Sound?
	local list = pool[key]
	if not list then
		list = {}
		pool[key] = list
	end
	for _, sound in list do
		if not sound.IsPlaying then
			return sound
		end
	end
	if #list >= 4 then
		return list[1] -- reuse the oldest rather than pile up
	end
	local sound = build()
	sound.Parent = SoundService
	table.insert(list, sound)
	return sound
end

export type Options = { volume: number?, pitch: number? }

-- Plays a sound by name (a sheet sound or a library one). `pitch` varies it (1 = as recorded).
function Sounds.play(name: string, options: Options?)
	if not active then
		return
	end
	local region = SoundSheet[name]
	local library = Sounds.LIBRARY[name]
	local sound: Sound?
	if region then
		sound = voice(name, function()
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = Sounds.SHEET
			s.PlaybackRegionsEnabled = true
			s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
			local mix = SHEET_MIX[name]
			s.SoundGroup = group(if mix then mix.group else "Effects")
			return s
		end)
	elseif library then
		sound = voice(name, function()
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = `rbxassetid://{library.id}`
			s.SoundGroup = group("Effects")
			return s
		end)
	end
	if not sound then
		return
	end
	local mix = SHEET_MIX[name]
	local base = if library then library.volume elseif mix then mix.volume else 0.6
	sound.Volume = base * (if options and options.volume then options.volume else 1)
	sound.PlaybackSpeed = if options and options.pitch then options.pitch else 1
	-- A sheet slice plays from its region's start; TimePosition is relative to the whole file.
	sound.TimePosition = if region then region[1] else 0
	sound:Play()
end

-- Fades the scene's ambience in (nil fades whatever is playing out).
function Sounds.ambience(sceneId: string?)
	if not active then
		return
	end
	for _, old in ambience do
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function()
			old:Destroy()
		end)
	end
	table.clear(ambience)
	local layers = if sceneId then Sounds.AMBIENCE[sceneId] else nil
	if not layers then
		return
	end
	for _, layer in layers do
		local s = Instance.new("Sound")
		s.Name = `Ambience{sceneId}`
		s.SoundId = `rbxassetid://{layer.id}`
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = group("Ambience")
		s.Parent = SoundService
		s:Play()
		TweenService:Create(s, TweenInfo.new(3), { Volume = layer.volume }):Play()
		table.insert(ambience, s)
	end
end

-- A looping sound placed in the world (heard louder up close), e.g. a campfire.
function Sounds.attach(parent: Instance, id: number, volume: number, range: number?): Sound
	local s = Instance.new("Sound")
	s.Name = "Spot"
	s.SoundId = `rbxassetid://{id}`
	s.Looped = true
	s.Volume = volume
	s.RollOffMaxDistance = range or 120
	s.RollOffMinDistance = 10
	s.SoundGroup = group("Ambience")
	s.Parent = parent
	if active then
		s:Play()
	end
	return s
end

-- Loads everything up front so the first click isn't silent. (Preloaded as Sounds: a bare id
-- would be fetched as an image and fail.)
function Sounds.preload()
	if not active then
		return
	end
	task.spawn(function()
		local ids = { Sounds.SHEET }
		for _, entry in Sounds.LIBRARY do
			table.insert(ids, `rbxassetid://{entry.id}`)
		end
		local list = {}
		for _, id in ids do
			local s = Instance.new("Sound")
			s.SoundId = id
			table.insert(list, s)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, s in list do
			s:Destroy()
		end
	end)
end

return Sounds
