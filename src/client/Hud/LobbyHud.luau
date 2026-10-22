--!strict
-- The lobby's screen: your stats card (Elo, wins, streaks, title), your coins and chest keys, a
-- dock (Play, Challenges, Collection, Chests), and the panels those open: the casual games browser
-- (list, create, your room), challenges (ChallengesPanel), your collection of pieces, auras, dice,
-- rent effects and titles, and the chest shop with its opening reveal; plus the reward celebration
-- when a challenge is claimed. Hidden while you're at a board.
-- Nothing here goes under a ClipsDescendants frame where a 3D preview is shown: Roblox doesn't
-- draw ViewportFrames there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Chests = require(ReplicatedStorage.Shared.Store.Chests)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Rewards = require(ReplicatedStorage.Shared.Progress.Rewards)
local Stats = require(ReplicatedStorage.Shared.Progress.Stats)
local Unlocks = require(ReplicatedStorage.Shared.Progress.Unlocks)
local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Ranks = require(ReplicatedStorage.Shared.Rules.Ranks)
local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local TableLayout = require(ReplicatedStorage.Shared.Lobby.TableLayout)
local ChallengesPanel = require(script.Parent.Lobby.ChallengesPanel)
local Icons = require(script.Parent.Icons)
local ItemArt = require(script.Parent.Lobby.ItemArt)
local ModelView = require(script.Parent.ModelView)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local LobbyHud = {}
local roomById: (any, number?) -> any
LobbyHud.__index = LobbyHud

LobbyHud.GUI_NAME = "LobbyHud"

local GOLD = Color3.fromRGB(222, 190, 110)
local DESIGN_HEIGHT = 720 -- the lobby HUD is laid out for at least this tall a screen

local function clockText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local COLLECTION_TABS = {
	{ kind = "Piece", label = "Pieces" },
	{ kind = "Aura", label = "Auras" },
	{ kind = "Dice", label = "Dice" },
	{ kind = "RentEffect", label = "Rent effects" },
	{ kind = "Title", label = "Titles" },
}
local SLOTS = { Piece = "piece", RentEffect = "rentEffect", Aura = "aura", Dice = "dice", Title = "title" }
local PAGE_SIZE = 15 -- five by three; the collection pages rather than scrolls (3D previews don't draw in a scrolling frame)
local CHEST_LOOKS = {
	Silver = { Body = { Color3.fromRGB(58, 62, 72), Enum.Material.SmoothPlastic }, Trim = { Color3.fromRGB(210, 214, 224), Enum.Material.Metal } },
	Gold = { Body = { Color3.fromRGB(46, 30, 18), Enum.Material.Wood }, Trim = { Color3.fromRGB(230, 184, 70), Enum.Material.Metal } },
	Diamond = { Body = { Color3.fromRGB(26, 36, 70), Enum.Material.SmoothPlastic }, Trim = { Color3.fromRGB(150, 230, 255), Enum.Material.Glass } },
}

export type Callbacks = {
	onLobby: (request: { [string]: any }) -> (),
	onStore: (request: { [string]: any }) -> (),
	onProgress: (request: { [string]: any }) -> (),
}

export type LobbyHud = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		root: Frame,
		callbacks: Callbacks,
		profile: Protocol.ProfileView?,
		rooms: Protocol.RoomsUpdate?,
		statsCard: Frame,
		statLabels: { [string]: TextLabel },
		dock: Frame,
		panels: { [string]: Frame },
		open: string?,
		draft: RoomSettings.Settings, -- the create form's settings
		creating: boolean,
		creatingRanked: boolean, -- the create form is for a ranked game
		piecesTab: string, -- the collection's tab: a Catalog kind
		collectionPage: number,
		playTab: string, -- "Ranked" | "Casual"
		challengesTab: string,
		treeState: { zoom: number, canvas: Vector2?, selected: string? },
		dailyClock: TextLabel?,
		wallet: Frame,
		walletCoins: TextLabel,
		walletKeys: TextLabel,
		titleTag: TextLabel,
		dockButtons: { [string]: TextButton },
		chestDetail: string?, -- the chest whose full item list is open
		queueLabel: TextLabel?, -- the "Searching…" line, ticked every frame
		titleLabel: TextLabel,
		toast: TextLabel,
		reveal: Frame,
		revealChest: ModelView.ModelView,
		revealItem: ModelView.ModelView,
	},
	LobbyHud
))

local function finishChest(chestId: string): (Model) -> ()
	return function(model: Model)
		local look = CHEST_LOOKS[chestId] or CHEST_LOOKS.Silver
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local finish = (look :: any)[part.Name] or look.Body
				part.Color = finish[1]
				part.Material = finish[2]
			end
		end
	end
end

local function heading(text: string, parent: Instance, size: number?): TextLabel
	local label = Ui.label("Heading", parent, UDim2.new(1, -60, 0, 40), size or 26, Theme.font.display)
	label.Position = UDim2.fromOffset(20, 12)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	return label
end

local function panel(self: LobbyHud, name: string, size: Vector2): Frame
	local frame = Ui.panel(name, UDim2.fromOffset(size.X, size.Y), UDim2.fromScale(0.5, 0.47), Vector2.new(0.5, 0.5), self.root)
	frame.Visible = false
	frame.ZIndex = 5
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(34, 34)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.BackgroundColor3 = Theme.color.surfaceHigh
	close.FontFace = Theme.font.display
	close.TextSize = 18
	close.TextColor3 = Theme.color.text
	close.Text = "X"
	close.AutoButtonColor = true
	close.Parent = frame
	Ui.corner(close, 17)
	close.Activated:Connect(function()
		self:close()
	end)
	self.panels[name] = frame
	return frame
end

local function body(frame: Frame, top: number): Frame
	local content = Ui.frame("Body", UDim2.new(1, -40, 1, -top - 20), frame)
	content.Position = UDim2.fromOffset(20, top)
	return content
end

-- A settings row: a label on the left, a control built by `control` on the right.
local function settingRow(parent: Instance, order: number, label: string): Frame
	local row = Ui.frame(label, UDim2.new(1, 0, 0, 38), parent)
	row.LayoutOrder = order
	local text = Ui.label("Label", row, UDim2.new(0.45, 0, 1, 0), 17, Theme.font.bodyBold)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = label
	return row
end

local function valueLabel(row: Frame, text: string, x: number, width: number): TextLabel
	local value = Ui.label("Value", row, UDim2.fromOffset(width, 40), 18, Theme.font.display)
	value.Position = UDim2.new(0.45, x, 0, 0)
	value.Text = text
	return value
end

local function smallButton(row: Frame, text: string, x: number, width: number, onClick: () -> (), style: Ui.Style?): TextButton
	local button = Ui.button(text, row, onClick, style or "secondary")
	button.Size = UDim2.fromOffset(width, 36)
	button.Position = UDim2.new(0.45, x, 0, 2)
	Ui.setTextSize(button, 16)
	return button
end

function LobbyHud.new(playerGui: Instance, callbacks: Callbacks): LobbyHud
	local gui = Instance.new("ScreenGui")
	gui.Name = LobbyHud.GUI_NAME
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local root = Ui.frame("Root", UDim2.fromScale(1, 1), gui)
	-- On short screens everything shrinks together so panels never cover the dock: the root is laid
	-- out at DESIGN_HEIGHT and scaled to the real height.
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	local fitScale = Instance.new("UIScale")
	fitScale.Parent = root
	local function fit()
		local height = gui.AbsoluteSize.Y
		local scale = if height > 0 then math.min(1, height / DESIGN_HEIGHT) else 1
		fitScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local self = setmetatable({
		gui = gui,
		root = root,
		callbacks = callbacks,
		profile = nil,
		rooms = nil,
		statsCard = nil :: any,
		statLabels = {},
		dock = nil :: any,
		panels = {},
		open = nil,
		draft = RoomSettings.validate(nil),
		creating = false,
		creatingRanked = false,
		piecesTab = "Piece",
		collectionPage = 1,
		playTab = "Ranked",
		challengesTab = "Daily",
		treeState = { zoom = 0.5, canvas = nil, selected = nil },
		dailyClock = nil,
		wallet = nil :: any,
		walletCoins = nil :: any,
		walletKeys = nil :: any,
		titleTag = nil :: any,
		dockButtons = {},
		chestDetail = nil,
		queueLabel = nil,
		titleLabel = nil :: any,
		toast = nil :: any,
		reveal = nil :: any,
		revealChest = nil :: any,
		revealItem = nil :: any,
	}, LobbyHud)

	-- Stats card, top left.
	local card = Ui.panel("StatsCard", UDim2.fromOffset(330, 184), UDim2.fromOffset(16, 16), Vector2.zero, root)
	self.statsCard = card
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.fromOffset(72, 72)
	avatar.Position = UDim2.fromOffset(16, 16)
	avatar.BackgroundColor3 = Theme.color.surfaceHigh
	avatar.Parent = card
	Ui.corner(avatar, 36)
	Ui.stroke(avatar, GOLD, 2, 0.1)
	local player = Players.LocalPlayer
	if player and RunService:IsClient() then
		task.spawn(function()
			local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok then
				avatar.Image = image
			end
		end)
	end
	local name = Ui.label("Name", card, UDim2.new(1, -110, 0, 30), 22, Theme.font.display)
	name.Position = UDim2.fromOffset(100, 16)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	name.Text = if player then player.DisplayName else "Player"
	-- The equipped title, in its rarity's colour.
	local titleTag = Ui.label("TitleTag", card, UDim2.new(1, -110, 0, 18), 15, Theme.font.display)
	titleTag.Position = UDim2.fromOffset(100, 46)
	titleTag.Visible = false
	titleTag.TextXAlignment = Enum.TextXAlignment.Left
	titleTag.TextTruncate = Enum.TextTruncate.AtEnd
	titleTag.TextWrapped = false
	self.titleTag = titleTag
	local eloCaption = Ui.label("EloCaption", card, UDim2.fromOffset(60, 18), 13, Theme.font.bodyBold)
	eloCaption.Position = UDim2.fromOffset(100, 64)
	eloCaption.TextXAlignment = Enum.TextXAlignment.Left
	eloCaption.TextColor3 = Theme.color.textDim
	eloCaption.Text = "ELO"
	local elo = Ui.label("Elo", card, UDim2.fromOffset(160, 34), 32, Theme.font.display)
	elo.Position = UDim2.fromOffset(100, 78)
	elo.TextXAlignment = Enum.TextXAlignment.Left
	elo.TextColor3 = GOLD
	elo.Text = "1000"
	self.statLabels.elo = elo
	-- The chess-style title for that rating, e.g. "Novice" or "Grandmaster".
	local title = Ui.label("Title", card, UDim2.fromOffset(150, 20), 15, Theme.font.display)
	title.Position = UDim2.fromOffset(176, 88)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextWrapped = false
	self.titleLabel = title
	local stats = Ui.frame("Stats", UDim2.new(1, -32, 0, 52), card)
	stats.Position = UDim2.fromOffset(16, 120)
	Ui.list(stats, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for index, info in { { "wins", "Total wins" }, { "bestStreak", "Best streak" }, { "streak", "Streak" }, { "peakElo", "Peak Elo" } } do
		local tile = Ui.surface(info[1], UDim2.fromOffset(68, 52), stats)
		tile.LayoutOrder = index
		local value = Ui.label("Value", tile, UDim2.new(1, 0, 0, 28), 22, Theme.font.display)
		value.Text = "0"
		local caption = Ui.label("Caption", tile, UDim2.new(1, 0, 0, 18), 11, Theme.font.bodyBold)
		caption.Position = UDim2.fromOffset(0, 30)
		caption.TextColor3 = Theme.color.textDim
		caption.Text = info[2]
		self.statLabels[info[1]] = value
	end

	-- The wallet, top right: coins and chest keys; tapping it opens the chests.
	local wallet = Ui.panel("Wallet", UDim2.fromOffset(250, 56), UDim2.new(1, -16, 0, 16), Vector2.new(1, 0), root)
	self.wallet = wallet
	local coinIcon = Icons.image(wallet, "Coin", UDim2.fromOffset(46, 46))
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.new(0, 6, 0.5, 0)
	local coins = Ui.label("Coins", wallet, UDim2.new(1, -164, 1, 0), 26, Theme.font.display)
	coins.Position = UDim2.fromOffset(54, 0)
	coins.TextXAlignment = Enum.TextXAlignment.Left
	coins.TextColor3 = Color3.fromRGB(255, 210, 80)
	coins.Text = "0"
	self.walletCoins = coins
	local keys = Ui.label("Keys", wallet, UDim2.fromOffset(40, 22), 16, Theme.font.display)
	keys.AnchorPoint = Vector2.new(1, 0.5)
	keys.Position = UDim2.new(1, -54, 0.5, 0)
	keys.TextXAlignment = Enum.TextXAlignment.Left
	keys.TextColor3 = Theme.color.text
	self.walletKeys = keys
	local keyIcon = Icons.image(wallet, "Key", UDim2.fromOffset(34, 34))
	keyIcon.Name = "KeyIcon"
	keyIcon.AnchorPoint = Vector2.new(1, 0.5)
	keyIcon.Position = UDim2.new(1, -94, 0.5, 0)
	local more = Ui.button("+", wallet, function()
		self:toggle("Chests")
	end, "primary")
	more.Size = UDim2.fromOffset(40, 40)
	more.AnchorPoint = Vector2.new(1, 0.5)
	more.Position = UDim2.new(1, -8, 0.5, 0)
	Ui.setTextSize(more, 24)

	-- The dock, bottom centre.
	local dock = Ui.frame("Dock", UDim2.fromOffset(660, 64), root)
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -20)
	Ui.list(dock, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	self.dock = dock
	for index, info in { { "Play", "primary", "Games" }, { "Challenges", "secondary", "Challenges" }, { "Collection", "secondary", "Pieces" }, { "Chests", "accent", "Chests" } } do
		local button = Ui.button(info[1], dock, function()
			self:toggle(info[3])
		end, info[2] :: Ui.Style)
		button.Size = UDim2.fromOffset(150, 58)
		button.LayoutOrder = index
		Ui.setTextSize(button, if #info[1] > 8 then 19 else 22)
		self.dockButtons[info[1]] = button
	end

	panel(self, "Games", Vector2.new(560, 580))
	panel(self, "Challenges", ChallengesPanel.SIZE)
	panel(self, "Pieces", Vector2.new(660, 600))
	panel(self, "Chests", Vector2.new(720, 540))

	local toast = Ui.label("Toast", root, UDim2.fromOffset(420, 40), 17, Theme.font.bodyBold)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 18)
	toast.BackgroundTransparency = 0
	toast.BackgroundColor3 = Theme.color.panel
	toast.Visible = false
	toast.ZIndex = 30
	Ui.corner(toast, 10)
	self.toast = toast

	-- The chest reveal: a full-screen dim with the chest, then the prize.
	local reveal = Instance.new("Frame")
	reveal.Name = "ChestReveal"
	-- Reaches up under the top bar too, so the whole screen dims.
	reveal.Size = UDim2.new(1, 0, 1, 80)
	reveal.Position = UDim2.fromOffset(0, -80)
	reveal.BackgroundColor3 = Color3.new(0, 0, 0)
	reveal.BackgroundTransparency = 0.35
	reveal.Visible = false
	reveal.ZIndex = 40
	reveal.Active = true
	reveal.Parent = root
	self.reveal = reveal
	self.revealChest = ModelView.new("Chest", reveal, UDim2.fromOffset(300, 300))
	self.revealChest.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.revealChest.frame.Position = UDim2.fromScale(0.5, 0.45)
	self.revealChest.frame.ZIndex = 41
	self.revealItem = ModelView.new("Item", reveal, UDim2.fromOffset(240, 240))
	self.revealItem.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.revealItem.frame.Position = UDim2.fromScale(0.5, 0.38)
	self.revealItem.frame.ZIndex = 42

	-- The ranked queue's clock ticks while you search.
	if RunService:IsClient() then
		RunService.Heartbeat:Connect(function()
			ChallengesPanel.tick(self)
			local label = self.queueLabel
			local queued = if self.rooms then self.rooms.queue else nil
			if label and label.Parent and queued then
				local waited = workspace:GetServerTimeNow() - queued.since
				label.Text = `Searching for a {queued.mode} opponent… {clockText(waited)}`
			end
		end)
	end

	self:render()
	return self
end

function LobbyHud.notice(self: LobbyHud, text: string)
	Sounds.play("Notify", { volume = 0.7 })
	self.toast.Text = text
	self.toast.Visible = true
	local shown = text
	task.delay(3, function()
		if self.toast.Text == shown then
			self.toast.Visible = false
		end
	end)
end

function LobbyHud.close(self: LobbyHud)
	if self.open then
		Sounds.play("Close")
	end
	self.open = nil
	self.creating = false
	self:render()
end

function LobbyHud.toggle(self: LobbyHud, name: string)
	if self.open == name then
		self:close()
	else
		Sounds.play("Open")
		self.open = name
		self.creating = false
		self:render()
	end
end

function LobbyHud.openPanel(self: LobbyHud, name: string)
	if self.open ~= name then
		Sounds.play("Open")
	end
	self.open = name
	self:render()
end

function LobbyHud.setInGame(self: LobbyHud, inGame: boolean)
	self.root.Visible = not inGame
	if inGame then
		self.open = nil
		self.reveal.Visible = false
	end
	self:render()
end

function LobbyHud.setProfile(self: LobbyHud, profile: Protocol.ProfileView)
	self.profile = profile
	self:render()
end

function LobbyHud.setRooms(self: LobbyHud, update: Protocol.RoomsUpdate)
	-- Someone joining your room chimes.
	local before = roomById(self, if self.rooms then self.rooms.mine else nil)
	local after = nil
	for _, room in update.rooms do
		if room.id == update.mine then
			after = room
		end
	end
	if before and after and before.id == after.id and #after.members > #before.members then
		Sounds.play("Notify")
	end
	self.rooms = update
	if update.notice then
		self:notice(update.notice)
	end
	-- Joining or creating a room shows it.
	if update.mine and self.open ~= "Games" then
		self.open = "Games"
	end
	if update.mine then
		self.creating = false
	end
	self:render()
end

function roomById(self: LobbyHud, id: number?): any
	if not id or not self.rooms then
		return nil
	end
	for _, room in self.rooms.rooms do
		if room.id == id then
			return room
		end
	end
	return nil
end

-- The lobby table a room sits at, as its sign names it ("Table 2", "Ranked table 1").
local function tableName(room: any): string?
	local id = room.tableId
	if typeof(id) ~= "number" then
		return nil
	end
	return if TableLayout.kind(id) == "Ranked" then `Ranked table {TableLayout.number(id)}` else `Table {id}`
end

-- The settings form, editable (each change goes through `onChange`) or read-only.
local function settingsForm(parent: Instance, settings: RoomSettings.Settings, editable: boolean, onChange: (RoomSettings.Settings) -> ())
	local form = Ui.frame("Settings", UDim2.new(1, 0, 0, 9 * 42), parent)
	Ui.list(form, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	local function changed(key: string, value: any)
		local copy = table.clone(settings) :: any
		copy[key] = value
		onChange(RoomSettings.validate(copy))
	end
	local function stepper(order: number, label: string, text: string, key: string, current: number, step: number)
		local row = settingRow(form, order, label)
		if editable then
			smallButton(row, "−", 0, 40, function()
				changed(key, current - step)
			end)
			valueLabel(row, text, 44, 110)
			smallButton(row, "+", 158, 40, function()
				changed(key, current + step)
			end)
		else
			valueLabel(row, text, 0, 200).TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	local function toggle(order: number, label: string, key: string, on: boolean)
		local row = settingRow(form, order, label)
		if editable then
			smallButton(row, if on then "On" else "Off", 0, 198, function()
				changed(key, not on)
			end, if on then "primary" else "secondary")
		else
			valueLabel(row, if on then "On" else "Off", 0, 200).TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	local function cycle(order: number, label: string, text: string, key: string, nextValue: string)
		local row = settingRow(form, order, label)
		if editable then
			smallButton(row, text, 0, 198, function()
				changed(key, nextValue)
			end)
		else
			valueLabel(row, text, 0, 200).TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	stepper(1, "Players", tostring(settings.maxPlayers), "maxPlayers", settings.maxPlayers, 1)
	stepper(2, "Starting money", `${settings.startingMoney}`, "startingMoney", settings.startingMoney, RoomSettings.MONEY_STEP)
	toggle(3, "Auctions", "auctions", settings.auctions)
	toggle(4, "Free Parking pot", "freeParking", settings.freeParking)
	toggle(5, "Bots fill empty seats", "bots", settings.bots)
	cycle(6, "Turn timer", (MatchSettings.timerLabel(settings.timer):gsub("^Timer: ", "")), "timer", MatchSettings.nextTimer(settings.timer))
	cycle(7, "Game length", (MatchSettings.lengthLabel(settings.length):gsub("^Length: ", "")), "length", MatchSettings.nextLength(settings.length))
	cycle(8, "Board names", settings.map, "map", MatchSettings.nextMap(settings.map))
	local sceneIndex = table.find(Scenes.IDS, settings.scene) or 1
	local scene = Scenes.byId[settings.scene] or Scenes.LIST[1]
	cycle(9, "Scene", scene.name, "scene", Scenes.IDS[sceneIndex % #Scenes.IDS + 1])
end

local function footer(parent: Instance): Frame
	local bar = Ui.frame("Footer", UDim2.new(1, 0, 0, 52), parent)
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	Ui.list(bar, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	return bar
end

-- The open games of one kind (ranked or casual), from `top` down, and a button to host one.
local function renderBrowse(self: LobbyHud, content: Frame, ranked: boolean, top: number)
	-- Its own line under the tabs, never over them.
	local note = Ui.label("CasualNote", content, UDim2.new(1, 0, 0, 20), 14, Theme.font.body)
	note.Position = UDim2.fromOffset(0, top)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextColor3 = Theme.color.textDim
	note.Text = if ranked
		then "Ranked games are rated: any settings, at least two players. Leaving counts as a loss."
		else "Casual games never change your rating, but still earn coins."
	local list = Instance.new("ScrollingFrame")
	list.Name = "Rooms"
	list.Position = UDim2.fromOffset(0, top + 28)
	list.Size = UDim2.new(1, 0, 1, -92 - top)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Ui.list(list, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local rooms = {}
	for _, room in (if self.rooms then self.rooms.rooms else {}) do
		if (room.ranked == true) == ranked then
			table.insert(rooms, room)
		end
	end
	if #rooms == 0 then
		local empty = Ui.label("Empty", list, UDim2.new(1, 0, 0, 120), 18, Theme.font.body)
		empty.TextColor3 = Theme.color.textDim
		empty.Text = if ranked then "No ranked games yet.\nCreate one and others can join!" else "No games yet.\nCreate one and others can join!"
	end
	for index, room in rooms do
		local card = Ui.surface(`Room{room.id}`, UDim2.new(1, -12, 0, 84), list)
		card.LayoutOrder = index
		local title = Ui.label("Name", card, UDim2.new(1, -150, 0, 26), 19, Theme.font.display)
		title.Position = UDim2.fromOffset(14, 8)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = room.name
		local sub = Ui.label("Players", card, UDim2.new(1, -150, 0, 18), 14, Theme.font.bodyBold)
		sub.Position = UDim2.fromOffset(14, 34)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Theme.color.textDim
		local at = tableName(room)
		sub.Text = (if at then `{at} · ` else "") .. `{room.players}/{room.maxPlayers} players · {room.status}`
		local chips = Ui.frame("Chips", UDim2.new(1, -150, 0, 22), card)
		chips.Position = UDim2.fromOffset(14, 56)
		Ui.list(chips, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		for _, chip in RoomSettings.chips(room.settings) do
			local pill = Ui.pill(chip, chips, Theme.color.surfaceHigh)
			pill.TextColor3 = GOLD
		end
		local open = room.status == "Waiting" and room.players < room.maxPlayers
		local join = Ui.button(if open then "Join" elseif room.status == "Playing" then "Playing" else "Full", card, function()
			if open then
				self.callbacks.onLobby({ type = "Join", room = room.id })
			end
		end, if open then "primary" else "disabled")
		join.Size = UDim2.fromOffset(120, 46)
		join.AnchorPoint = Vector2.new(1, 0.5)
		join.Position = UDim2.new(1, -14, 0.5, 0)
	end
	local bar = footer(content)
	Ui.button(if ranked then "Create ranked game" else "Create game", bar, function()
		self.creating = true
		self.creatingRanked = ranked
		self.draft = RoomSettings.validate(nil)
		self:render()
	end, "primary").Size = UDim2.fromOffset(if ranked then 240 else 190, 50)
end

local function renderCreate(self: LobbyHud, content: Frame)
	settingsForm(content, self.draft, true, function(settings)
		self.draft = settings
		self:render()
	end)
	local bar = footer(content)
	Ui.button("Back", bar, function()
		self.creating = false
		self:render()
	end, "secondary").LayoutOrder = 1
	local create = Ui.button("Create", bar, function()
		self.callbacks.onLobby({ type = "Create", settings = self.draft, ranked = self.creatingRanked })
	end, "primary")
	create.LayoutOrder = 2
end

local function renderRoom(self: LobbyHud, content: Frame, room: any)
	local isHost = self.rooms ~= nil and self.rooms.hostOf == room.id
	local members = Ui.frame("Members", UDim2.new(1, 0, 0, 30), content)
	Ui.list(members, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	if room.ranked then
		local badge = Ui.pill("RANKED", members, GOLD, Theme.color.ink)
		badge.LayoutOrder = 0
	end
	for index, member in room.members do
		local pill = Ui.pill(if index == 1 then `{member.name} (host)` else member.name, members, Theme.color.surfaceHigh)
		pill.LayoutOrder = index
	end
	local seats = room.maxPlayers - #room.members
	if seats > 0 then
		local open = Ui.pill(if room.settings.bots then `+{seats} bot{if seats > 1 then "s" else ""}` else `{seats} open`, members, Theme.color.secondary)
		open.TextColor3 = Theme.color.textDim
		open.LayoutOrder = 99
	end
	local formHolder = Ui.frame("FormHolder", UDim2.new(1, 0, 1, -100), content)
	formHolder.Position = UDim2.fromOffset(0, 38)
	settingsForm(formHolder, room.settings, isHost, function(settings)
		self.callbacks.onLobby({ type = "Settings", settings = settings })
	end)
	local bar = footer(content)
	local leave = Ui.button("Leave", bar, function()
		self.callbacks.onLobby({ type = "Leave" })
	end, "danger")
	leave.LayoutOrder = 1
	local needsPlayer = room.ranked and #room.members < 2
	local start = Ui.button(if needsPlayer then "Need 2 players" elseif isHost then "Start game" else "Host starts", bar, function()
		if isHost and not needsPlayer then
			self.callbacks.onLobby({ type = "Start" })
		end
	end, if isHost and not needsPlayer then "primary" else "disabled")
	start.LayoutOrder = 2
	start.Size = UDim2.fromOffset(180, 50)
end

-- Ranked: your rating like a chess site shows it, then the ranked games open to join.
local function renderRanked(self: LobbyHud, content: Frame)
	local profile = self.profile
	local stats = if profile then profile.stats else nil
	local elo = if stats then stats.elo else Ranks.START
	local rank = Ranks.titleFor(elo)
	local card = Ui.surface("Rating", UDim2.new(1, 0, 0, 72), content)
	local number = Ui.label("Elo", card, UDim2.fromOffset(130, 56), 44, Theme.font.display)
	number.Position = UDim2.fromOffset(16, 8)
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.TextColor3 = GOLD
	number.Text = tostring(math.floor(elo))
	local games = if stats then stats.rankedGames else 0
	local title = Ui.label("Title", card, UDim2.new(1, -170, 0, 26), 20, Theme.font.display)
	title.Position = UDim2.fromOffset(150, 10)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = rank.color
	title.Text = rank.name .. (if Ranks.isProvisional(games) then ` · provisional ({Ranks.PROVISIONAL_GAMES - games} to go)` else "")
	local record = Ui.label("Record", card, UDim2.new(1, -170, 0, 20), 14, Theme.font.bodyBold)
	record.Position = UDim2.fromOffset(150, 40)
	record.TextXAlignment = Enum.TextXAlignment.Left
	record.TextColor3 = Theme.color.textDim
	record.Text = if stats then `{stats.rankedWins} W · {games - stats.rankedWins} L · peak {math.floor(stats.peakElo)}` else ""
	renderBrowse(self, content, true, 82)
end

local function renderGames(self: LobbyHud)
	local frame = self.panels.Games
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	self.queueLabel = nil
	local mine = roomById(self, if self.rooms then self.rooms.mine else nil)
	if mine or self.creating then
		local at = if mine then tableName(mine) else nil
		heading(if mine then (if at then `{mine.name} · {at}` else mine.name) elseif self.creatingRanked then "Create a ranked game" else "Create a game", frame)
		local content = body(frame, 64)
		if mine then
			renderRoom(self, content, mine)
		else
			renderCreate(self, content)
		end
		return
	end
	heading("Play", frame)
	-- The quickest way in: a seat at the fullest open casual table, or a new game at a free one.
	local quick = Ui.button("Quick Play", frame, function()
		self.callbacks.onLobby({ type = "QuickPlay" })
	end, "primary")
	quick.Size = UDim2.fromOffset(200, 46)
	quick.Position = UDim2.fromOffset(20, 56)
	local hint = Ui.label("TablesHint", frame, UDim2.new(1, -250, 0, 46), 15, Theme.font.body)
	hint.Position = UDim2.fromOffset(234, 56)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Theme.color.textDim
	hint.Text = "Or walk up to any table in the hall and sit down."
	local tabs = Ui.frame("Tabs", UDim2.fromOffset(330, 40), frame)
	tabs.Position = UDim2.fromOffset(20, 112)
	Ui.list(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for index, tab in { "Ranked", "Casual" } do
		local button = Ui.button(tab, tabs, function()
			self.playTab = tab
			self:render()
		end, if self.playTab == tab then "accent" else "secondary")
		button.Size = UDim2.fromOffset(150, 38)
		button.LayoutOrder = index
		Ui.setTextSize(button, 16)
	end
	local content = body(frame, 162)
	if self.playTab == "Ranked" then
		renderRanked(self, content)
	else
		renderBrowse(self, content, false, 0)
	end
end

local function itemTile(self: LobbyHud, parent: Instance, order: number, item: Catalog.Item, owned: boolean, equipped: boolean)
	local tile = Instance.new("TextButton")
	tile.Name = item.id
	tile.LayoutOrder = order
	tile.BackgroundColor3 = if equipped then Theme.color.surfaceHigh else Theme.color.surface
	tile.AutoButtonColor = owned
	tile.Text = ""
	tile.Parent = parent
	Ui.corner(tile, Theme.radius.surface)
	local rarityColor = Catalog.RARITY_COLORS[item.rarity]
	if equipped then
		Ui.stroke(tile, GOLD, 2.5, 0)
	elseif owned and item.rarity == "Legendary" then
		Ui.stroke(tile, rarityColor, 1.5, 0.3)
	end
	local bar = Instance.new("Frame")
	bar.Name = "Rarity"
	bar.Size = UDim2.new(1, -16, 0, 4)
	bar.Position = UDim2.fromOffset(8, 6)
	bar.BackgroundColor3 = rarityColor
	bar.BorderSizePixel = 0
	bar.Parent = tile
	Ui.corner(bar, 2)
	local art = ItemArt.build(tile, item.id, UDim2.new(1, 0, 0, 78))
	art.Position = UDim2.fromOffset(0, 12)
	if not owned then
		if art:IsA("ViewportFrame") then
			art.ImageTransparency = 0.25
			art.ImageColor3 = Color3.fromRGB(185, 185, 200)
		elseif art:IsA("TextLabel") then
			art.TextTransparency = 0.55
		else
			for _, image in art:GetChildren() do
				if image:IsA("ImageLabel") then
					image.ImageTransparency = 0.45
				end
			end
		end
		local lock = Icons.image(tile, "Lock", UDim2.fromOffset(28, 28))
		lock.AnchorPoint = Vector2.new(1, 0)
		lock.Position = UDim2.new(1, -2, 0, 10)
	end
	local name = Ui.label("Name", tile, UDim2.new(1, -8, 0, 20), 14, Theme.font.bodyBold)
	name.Position = UDim2.fromOffset(4, 92)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	name.Text = item.name
	local status = Ui.label("Status", tile, UDim2.new(1, -8, 0, 18), 12, Theme.font.bodyBold)
	status.Position = UDim2.fromOffset(4, 112)
	status.TextColor3 = if equipped then GOLD elseif owned then rarityColor elseif item.exclusive then Color3.fromRGB(255, 170, 90) else Theme.color.textDim
	status.Text = if equipped then "EQUIPPED"
		elseif owned then string.upper(item.rarity)
		elseif item.exclusive then "CHALLENGE"
		else "IN CHESTS"
	if not owned then
		tile.BackgroundTransparency = 0.3
	end
	tile.Activated:Connect(function()
		Sounds.play(if owned then "Click" else "Tab")
		if not owned then
			local source = Unlocks.sourceOf(item.id)
			if source then
				self:notice(`Unlock it: {source}`)
				local node = Unlocks.nodeFor(item.id)
				if node then
					self.challengesTab = "Empire Tree"
					self.treeState.selected = node
					self.treeState.canvas = nil
				end
			else
				self:notice(`Win {item.name} from a chest`)
			end
		elseif equipped then
			self.callbacks.onStore({ type = "Unequip", kind = item.kind })
		else
			self.callbacks.onStore({ type = "Equip", item = item.id })
		end
	end)
end

local function renderPieces(self: LobbyHud)
	local frame = self.panels.Pieces
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	heading("Your collection", frame)
	local profile = self.profile
	local data = profile :: any
	local equipped = if profile then profile.equipped else { piece = Catalog.DEFAULT_PIECE }
	local kind = self.piecesTab

	-- Owned out of how many, across everything.
	local owned, total = 0, 0
	for _, item in Catalog.ITEMS do
		total += 1
		if data and Progress.owns(data, item.id) then
			owned += 1
		end
	end
	local count = Ui.label("Count", frame, UDim2.fromOffset(200, 24), 15, Theme.font.bodyBold)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -60, 0, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextColor3 = Theme.color.textDim
	count.Text = `{owned} / {total} collected`

	local tabs = Ui.frame("Tabs", UDim2.new(1, -40, 0, 40), frame)
	tabs.Position = UDim2.fromOffset(20, 58)
	Ui.list(tabs, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for index, tab in COLLECTION_TABS do
		local button = Ui.button(tab.label, tabs, function()
			self.piecesTab = tab.kind
			self.collectionPage = 1
			self:render()
		end, if kind == tab.kind then "accent" else "secondary")
		button.Size = UDim2.fromOffset(if tab.kind == "RentEffect" then 128 else 112, 36)
		button.LayoutOrder = index
		Ui.setTextSize(button, 15)
	end

	-- This tab's items: equipped first, then owned, then the rest; each by rarity.
	local items = {}
	for index, item in Catalog.ITEMS do
		if item.kind == kind then
			local isOwned = data ~= nil and Progress.owns(data, item.id)
			local slot = (equipped :: any)[SLOTS[kind]]
			local isOn = slot == item.id or (kind == "Dice" and slot == nil and item.id == Catalog.DEFAULT_DICE)
			local rank = (if isOn then 0 elseif isOwned then 1 else 2) * 10000
				+ (table.find(Catalog.RARITIES, item.rarity) or 0) * 100
				+ index
			table.insert(items, { item = item, owned = isOwned, on = isOn, rank = rank })
		end
	end
	table.sort(items, function(a, b)
		return a.rank < b.rank
	end)
	local pages = math.max(1, math.ceil(#items / PAGE_SIZE))
	self.collectionPage = math.clamp(self.collectionPage, 1, pages)

	local grid = Ui.frame("Grid", UDim2.fromOffset(5 * 118, 3 * 142), frame)
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.new(0.5, 0, 0, 108)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(110, 134)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local first = (self.collectionPage - 1) * PAGE_SIZE
	for index = first + 1, math.min(first + PAGE_SIZE, #items) do
		local entry = items[index]
		itemTile(self, grid, index, entry.item, entry.owned, entry.on)
	end

	local footerBar = Ui.frame("Pager", UDim2.new(1, -40, 0, 40), frame)
	footerBar.Position = UDim2.new(0, 20, 1, -52)
	local hint = Ui.label("Hint", footerBar, UDim2.new(1, -220, 1, 0), 13, Theme.font.body)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Theme.color.textDim
	hint.Text = if kind == "Piece" or kind == "Dice"
		then "Click to equip. Locked ones show how to unlock them."
		else "Click to equip; click again to take it off."
	local pager = Ui.frame("Buttons", UDim2.fromOffset(210, 40), footerBar)
	pager.AnchorPoint = Vector2.new(1, 0)
	pager.Position = UDim2.fromScale(1, 0)
	Ui.list(pager, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local back = Ui.button("‹", pager, function()
		self.collectionPage -= 1
		self:render()
	end, if self.collectionPage > 1 then "secondary" else "disabled")
	back.Size = UDim2.fromOffset(44, 38)
	back.LayoutOrder = 1
	local pageLabel = Ui.label("Page", pager, UDim2.fromOffset(90, 38), 15, Theme.font.bodyBold)
	pageLabel.LayoutOrder = 2
	pageLabel.Text = `Page {self.collectionPage} / {pages}`
	local forward = Ui.button("›", pager, function()
		self.collectionPage += 1
		self:render()
	end, if self.collectionPage < pages then "secondary" else "disabled")
	forward.Size = UDim2.fromOffset(44, 38)
	forward.LayoutOrder = 3
end

local function renderChests(self: LobbyHud)
	local frame = self.panels.Chests
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	local detail = if self.chestDetail then Chests.byId[self.chestDetail] else nil
	if detail then
		-- Every item this chest can give, with its own chance, most likely first.
		heading(`{detail.name}: every item and its odds`, frame, 22)
		local list = Instance.new("ScrollingFrame")
		list.Name = "Items"
		list.Size = UDim2.new(1, -40, 1, -140)
		list.Position = UDim2.fromOffset(20, 64)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.Parent = frame
		Ui.list(list, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
		for index, line in Chests.itemOdds(detail) do
			local item = Catalog.byId[line.id]
			local row = Ui.surface(line.id, UDim2.new(1, -12, 0, 32), list)
			row.LayoutOrder = index
			local swatch = Instance.new("Frame")
			swatch.Size = UDim2.fromOffset(6, 22)
			swatch.Position = UDim2.fromOffset(8, 5)
			swatch.BackgroundColor3 = Catalog.RARITY_COLORS[line.rarity]
			swatch.BorderSizePixel = 0
			swatch.Parent = row
			local name = Ui.label("Name", row, UDim2.new(0.55, -24, 1, 0), 15, Theme.font.bodyBold)
			name.Position = UDim2.fromOffset(22, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Text = `{line.name}  ·  {if item then string.lower(Catalog.KIND_NAMES[item.kind]) else ""}`
			local rarity = Ui.label("Rarity", row, UDim2.new(0.25, 0, 1, 0), 14, Theme.font.bodyBold)
			rarity.Position = UDim2.fromScale(0.55, 0)
			rarity.TextColor3 = Catalog.RARITY_COLORS[line.rarity]
			rarity.Text = line.rarity
			local chance = Ui.label("Chance", row, UDim2.new(0.2, -12, 1, 0), 15, Theme.font.display)
			chance.Position = UDim2.fromScale(0.8, 0)
			chance.TextXAlignment = Enum.TextXAlignment.Right
			chance.Text = string.format("%.2f%%", line.chance * 100)
		end
		local back = Ui.button("Back to chests", frame, function()
			self.chestDetail = nil
			self:render()
		end, "secondary")
		back.Size = UDim2.fromOffset(200, 48)
		back.AnchorPoint = Vector2.new(1, 1)
		back.Position = UDim2.new(1, -20, 1, -16)
		return
	end
	heading("Chests", frame)
	local profile = self.profile
	local coins = if profile then profile.coins else 0
	local note = Ui.label("Note", frame, UDim2.new(1, -40, 0, 18), 13, Theme.font.body)
	note.Position = UDim2.fromOffset(20, 50)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextColor3 = Theme.color.textDim
	note.Text = `Pieces, auras, dice skins and rent effects. Duplicates turn into coins. Odds are on each chest.`
	local row = Ui.frame("Row", UDim2.new(1, -40, 1, -90), frame)
	row.Position = UDim2.fromOffset(20, 78)
	Ui.list(row, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for index, chest in Chests.LIST do
		local card = Ui.surface(chest.id, UDim2.fromOffset(212, 440), row)
		card.LayoutOrder = index
		local view = ModelView.new("Preview", card, UDim2.new(1, 0, 0, 110))
		view:set("Emblems", "Chest", finishChest(chest.id), "?", chest.id)
		local title = Ui.label("Name", card, UDim2.new(1, 0, 0, 28), 20, Theme.font.display)
		title.Position = UDim2.fromOffset(0, 108)
		title.Text = chest.name
		local blurb = Ui.label("Blurb", card, UDim2.new(1, -20, 0, 36), 13, Theme.font.body)
		blurb.Position = UDim2.fromOffset(10, 134)
		blurb.TextColor3 = Theme.color.textDim
		blurb.Text = chest.blurb
		local odds = Ui.frame("Odds", UDim2.new(1, -24, 0, 88), card)
		odds.Position = UDim2.fromOffset(12, 174)
		Ui.list(odds, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
		for line, text in Chests.oddsLines(chest) do
			local rarity = Catalog.RARITIES[line]
			local label = Ui.label(rarity, odds, UDim2.new(1, 0, 0, 20), 14, Theme.font.bodyBold)
			label.LayoutOrder = line
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Catalog.RARITY_COLORS[rarity]
			label.Text = text
		end
		local items = Instance.new("TextButton")
		items.Name = "ItemOdds"
		items.Size = UDim2.new(1, -24, 0, 18)
		items.Position = UDim2.fromOffset(12, 266)
		items.BackgroundTransparency = 1
		items.FontFace = Theme.font.bodyBold
		items.TextSize = 13
		items.TextColor3 = GOLD
		items.Text = "See every item's odds ›"
		items.Parent = card
		items.Activated:Connect(function()
			Sounds.play("Click")
			self.chestDetail = chest.id
			self:render()
		end)

		-- Ways to open it: a key you've won, coins, or Robux.
		local buttons = Ui.frame("Buttons", UDim2.new(1, -24, 0, 150), card)
		buttons.Position = UDim2.new(0, 12, 1, -158)
		Ui.list(buttons, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
		local keys = if profile then profile.keys[chest.id] or 0 else 0
		if keys > 0 then
			local useKey = Ui.button(`Open with key ({keys})`, buttons, function()
				self.callbacks.onStore({ type = "UseKey", chest = chest.id })
			end, "primary")
			useKey.Size = UDim2.new(1, 0, 0, 44)
			useKey.LayoutOrder = 1
			Ui.setTextSize(useKey, 16)
			Icons.onButton(useKey, "Key", 30)
		end
		local price = Rewards.CHEST_COINS[chest.id]
		local affordable = coins >= price
		local withCoins = Ui.button(Stats.commas(price), buttons, function()
			if affordable then
				self.callbacks.onStore({ type = "BuyWithCoins", chest = chest.id })
			else
				self:notice(`You need {Stats.commas(price - coins)} more coins. Play games and finish challenges to earn them!`)
			end
		end, if affordable then "accent" else "disabled")
		withCoins.Size = UDim2.new(1, 0, 0, 48)
		withCoins.LayoutOrder = 2
		Icons.onButton(withCoins, "Coin", 34)
		local live = chest.productId ~= 0
		local robux = Ui.button(if live then `R$ {chest.price}` elseif RunService:IsStudio() then "Test open (Studio)" else "Robux: coming soon", buttons, function()
			self.callbacks.onStore({ type = if live then "Buy" else "TestOpen", chest = chest.id })
		end, if live or RunService:IsStudio() then "secondary" else "disabled")
		robux.Size = UDim2.new(1, 0, 0, 38)
		robux.LayoutOrder = 3
		Ui.setTextSize(robux, 15)
	end
end

function LobbyHud.render(self: LobbyHud)
	local profile = self.profile
	if profile then
		self.statLabels.elo.Text = tostring(math.floor(profile.stats.elo))
		for _, key in { "wins", "bestStreak", "streak", "peakElo" } do
			self.statLabels[key].Text = tostring(math.floor((profile.stats :: any)[key] or 0))
		end
		local rank = Ranks.titleFor(profile.stats.elo)
		self.titleLabel.Text = rank.name .. (if Ranks.isProvisional(profile.stats.rankedGames) then " ?" else "")
		self.titleLabel.TextColor3 = rank.color
		local title = if profile.equipped.title then Catalog.byId[profile.equipped.title] else nil
		-- The title gets its own line under the name; without one, the card keeps its plain layout.
		self.titleTag.Visible = title ~= nil
		if title then
			self.titleTag.Text = title.name
			self.titleTag.TextColor3 = Catalog.RARITY_COLORS[title.rarity]
		end
		local shift = if title then 16 else 0
		local card = self.statsCard
		card.Size = UDim2.fromOffset(330, 168 + shift)
		;(card:FindFirstChild("EloCaption") :: TextLabel).Position = UDim2.fromOffset(100, 50 + shift)
		self.statLabels.elo.Position = UDim2.fromOffset(100, 64 + shift)
		self.titleLabel.Position = UDim2.fromOffset(176, 74 + shift)
		;(card:FindFirstChild("Stats") :: Frame).Position = UDim2.fromOffset(16, 104 + shift)
		self.walletCoins.Text = Stats.commas(profile.coins or 0)
		local keyCount = 0
		for _, n in profile.keys or {} do
			keyCount += n
		end
		self.walletKeys.Text = if keyCount > 0 then `{keyCount}` else ""
		local keyIcon = self.wallet:FindFirstChild("KeyIcon")
		if keyIcon then
			(keyIcon :: ImageLabel).Visible = keyCount > 0
		end
		local challenges = self.dockButtons.Challenges
		if challenges then
			local old = challenges:FindFirstChild("Badge")
			if old then
				old:Destroy()
			end
			ChallengesPanel.badge(challenges, Progress.claimable(profile :: any).total)
		end
	end
	for name, frame in self.panels do
		if name == self.open then
			if name == "Games" then
				renderGames(self)
			elseif name == "Pieces" then
				renderPieces(self)
			elseif name == "Challenges" then
				ChallengesPanel.render(self, frame)
			else
				renderChests(self)
			end
			Ui.show(frame)
		else
			Ui.hide(frame)
		end
	end
end

-- The prize on the dimmed screen: a glow in its colour, its art, what it is, and the buttons.
-- `itemId` (optional) is shown turning or as its glyph; otherwise `glyph`.
local function presentPrize(
	self: LobbyHud,
	options: {
		color: Color3,
		itemId: string?,
		glyph: string?,
		kicker: string,
		title: string,
		blurb: string,
		extra: string?,
		equip: string?,
	}
)
	local reveal = self.reveal
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.fromOffset(320, 320)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.36)
	glow.BackgroundColor3 = options.color
	glow.BackgroundTransparency = 0.55
	glow.ZIndex = 41
	glow.Parent = reveal
	Ui.corner(glow, 200)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = glow
	TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = UDim2.fromOffset(370, 370),
	}):Play()
	local item = if options.itemId then Catalog.byId[options.itemId] else nil
	if item and (item.kind == "Piece" or item.kind == "Dice") then
		ItemArt.setModel(self.revealItem, item.id)
		self.revealItem.frame.Visible = true
		self.revealItem.speed = 1.2
	else
		if item and item.kind == "Title" then
			local glyph = Ui.label("Glyph", reveal, UDim2.fromOffset(560, 200), 64, Theme.font.display)
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.36)
			glyph.ZIndex = 42
			glyph.Text = item.name
			glyph.TextColor3 = options.color
			glyph.TextStrokeTransparency = 0.4
		else
			local icon = Icons.image(reveal, options.glyph or (if item then ItemArt.ICONS[item.id] else nil) or "Star", UDim2.fromOffset(230, 230))
			icon.Name = "Glyph"
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.36)
			icon.ZIndex = 42
		end
	end
	local kicker = Ui.label("Kicker", reveal, UDim2.fromOffset(600, 30), 22, Theme.font.display)
	kicker.AnchorPoint = Vector2.new(0.5, 0)
	kicker.Position = UDim2.fromScale(0.5, 0.58)
	kicker.TextColor3 = options.color
	kicker.ZIndex = 43
	kicker.Text = options.kicker
	local title = Ui.label("Title", reveal, UDim2.fromOffset(700, 50), 42, Theme.font.display)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.58, 30)
	title.ZIndex = 43
	title.Text = options.title
	local blurb = Ui.label("Blurb", reveal, UDim2.fromOffset(640, 26), 18, Theme.font.body)
	blurb.AnchorPoint = Vector2.new(0.5, 0)
	blurb.Position = UDim2.new(0.5, 0, 0.58, 82)
	blurb.TextColor3 = Theme.color.textDim
	blurb.ZIndex = 43
	blurb.Text = options.blurb
	local offset = 116
	if options.extra then
		local extra = Ui.label("Extra", reveal, UDim2.fromOffset(640, 28), 22, Theme.font.display)
		extra.AnchorPoint = Vector2.new(0.5, 0)
		extra.Position = UDim2.new(0.5, 0, 0.58, offset)
		extra.TextColor3 = GOLD
		extra.ZIndex = 43
		extra.Text = options.extra
		offset += 36
	end
	local buttons = Ui.frame("Buttons", UDim2.fromOffset(340, 56), reveal)
	buttons.AnchorPoint = Vector2.new(0.5, 0)
	buttons.Position = UDim2.new(0.5, 0, 0.58, offset)
	buttons.ZIndex = 43
	Ui.list(buttons, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if options.equip then
		local equipId = options.equip
		local equip = Ui.button("Equip", buttons, function()
			self.callbacks.onStore({ type = "Equip", item = equipId })
			reveal.Visible = false
		end, "accent")
		equip.LayoutOrder = 1
	end
	local done = Ui.button("Awesome!", buttons, function()
		reveal.Visible = false
	end, if options.equip then "secondary" else "accent")
	done.LayoutOrder = 2
end

local function clearReveal(self: LobbyHud)
	Ui.clear(self.reveal, function(child)
		return child == self.revealChest.frame or child == self.revealItem.frame
	end)
	self.revealChest.frame.Visible = false
	self.revealItem.frame.Visible = false
	self.reveal.Visible = true
end

-- Plays the chest opening: the chest shakes harder and harder, bursts, and the prize appears.
function LobbyHud.showChest(self: LobbyHud, result: Protocol.ChestResult)
	local item = Catalog.byId[result.item]
	if not item then
		return
	end
	local reveal = self.reveal
	clearReveal(self)
	self.open = nil
	self:render()
	self.revealChest:set("Emblems", "Chest", finishChest(result.chest), "?", result.chest)
	self.revealChest.frame.Visible = true
	self.revealChest.speed = 0.4
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 45
	flash.Parent = reveal
	task.spawn(function()
		for step = 1, 12 do
			self.revealChest.wobble = step * 0.012
			if step % 3 == 1 then
				Sounds.play("ChestShake", { volume = 0.6 + step * 0.04 })
			end
			task.wait(0.11)
		end
		Sounds.play("ChestOpen")
		task.delay(0.25, function()
			Sounds.play(if result.refund then "Coins" else `Reveal{item.rarity}`)
		end)
		self.revealChest.wobble = 0
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		self.revealChest.frame.Visible = false
		presentPrize(self, {
			color = Catalog.RARITY_COLORS[item.rarity],
			itemId = item.id,
			kicker = `{string.upper(item.rarity)} {string.upper(Catalog.KIND_NAMES[item.kind])}`,
			title = item.name,
			blurb = item.blurb,
			extra = if result.refund then `Already yours, so it's {Stats.commas(result.refund)} coins instead!` else nil,
			equip = if result.refund then nil else item.id,
		})
	end)
end

-- Celebrates a claimed challenge: what it was for and everything it paid.
function LobbyHud.showReward(self: LobbyHud, view: Protocol.RewardView)
	if view.notice then
		self:notice(view.notice)
		return
	end
	clearReveal(self)
	local item = if view.item then Catalog.byId[view.item] else nil
	Sounds.play("Claim")
	if item and (item.rarity == "Legendary" or item.rarity == "Epic") then
		task.delay(0.4, function()
			Sounds.play(`Reveal{item.rarity}`)
		end)
	end
	local paid = {}
	if view.coins then
		table.insert(paid, `{Stats.commas(view.coins)} coins`)
	end
	if view.key then
		table.insert(paid, `{view.key} Chest key`)
	end
	if item then
		table.insert(paid, `{item.name} ({item.rarity} {string.lower(Catalog.KIND_NAMES[item.kind])})`)
	end
	presentPrize(self, {
		color = if item then Catalog.RARITY_COLORS[item.rarity] else GOLD,
		itemId = if item then item.id else nil,
		glyph = if view.key then "Key" else "Coins",
		kicker = string.upper(`{view.source} complete!`),
		title = view.title,
		blurb = table.concat(paid, "  +  "),
		equip = if item then item.id else nil,
	})
end

return LobbyHud
