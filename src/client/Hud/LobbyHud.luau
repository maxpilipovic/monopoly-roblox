--!strict
-- The lobby's screen: your stats card (Elo, wins, streaks), a dock (Play, Pieces, Chests), and the
-- panels those open: the casual games browser (list, create, your room), your pieces and rent
-- effects, and the chest shop with its opening reveal. Hidden while you're at a board.
-- Nothing here goes under a ClipsDescendants frame where a 3D preview is shown: Roblox doesn't
-- draw ViewportFrames there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Chests = require(ReplicatedStorage.Shared.Store.Chests)
local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local PieceLook = require(ReplicatedStorage.Shared.Cosmetics.PieceLook)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local ModelView = require(script.Parent.ModelView)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local LobbyHud = {}
LobbyHud.__index = LobbyHud

LobbyHud.GUI_NAME = "LobbyHud"

local GOLD = Color3.fromRGB(222, 190, 110)
local EFFECT_GLYPHS = {
	CoinBurst = "🪙",
	ConfettiPop = "🎉",
	MoneyRain = "💸",
	GoldenAura = "✨",
	Lightning = "⚡",
	Fireworks = "🎆",
	BlackHole = "🕳️",
}
local CHEST_LOOKS = {
	Silver = { Body = { Color3.fromRGB(58, 62, 72), Enum.Material.SmoothPlastic }, Trim = { Color3.fromRGB(210, 214, 224), Enum.Material.Metal } },
	Gold = { Body = { Color3.fromRGB(46, 30, 18), Enum.Material.Wood }, Trim = { Color3.fromRGB(230, 184, 70), Enum.Material.Metal } },
	Diamond = { Body = { Color3.fromRGB(26, 36, 70), Enum.Material.SmoothPlastic }, Trim = { Color3.fromRGB(150, 230, 255), Enum.Material.Glass } },
}

export type Callbacks = {
	onLobby: (request: { [string]: any }) -> (),
	onStore: (request: { [string]: any }) -> (),
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
		piecesTab: string,
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

local function finishPiece(id: string): (Model) -> ()
	return function(model: Model)
		PieceLook.apply(model, id)
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
	local row = Ui.frame(label, UDim2.new(1, 0, 0, 40), parent)
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
		piecesTab = "Pieces",
		toast = nil :: any,
		reveal = nil :: any,
		revealChest = nil :: any,
		revealItem = nil :: any,
	}, LobbyHud)

	-- Stats card, top left.
	local card = Ui.panel("StatsCard", UDim2.fromOffset(330, 168), UDim2.fromOffset(16, 16), Vector2.zero, root)
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
	local eloCaption = Ui.label("EloCaption", card, UDim2.fromOffset(60, 18), 13, Theme.font.bodyBold)
	eloCaption.Position = UDim2.fromOffset(100, 50)
	eloCaption.TextXAlignment = Enum.TextXAlignment.Left
	eloCaption.TextColor3 = Theme.color.textDim
	eloCaption.Text = "ELO"
	local elo = Ui.label("Elo", card, UDim2.fromOffset(160, 34), 32, Theme.font.display)
	elo.Position = UDim2.fromOffset(100, 64)
	elo.TextXAlignment = Enum.TextXAlignment.Left
	elo.TextColor3 = GOLD
	elo.Text = "1000"
	self.statLabels.elo = elo
	local stats = Ui.frame("Stats", UDim2.new(1, -32, 0, 52), card)
	stats.Position = UDim2.fromOffset(16, 104)
	Ui.list(stats, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for index, info in { { "wins", "Total wins" }, { "bestStreak", "Best streak" }, { "streak", "Streak" }, { "games", "Games" } } do
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

	-- The dock, bottom centre.
	local dock = Ui.frame("Dock", UDim2.fromOffset(500, 64), root)
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -20)
	Ui.list(dock, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	self.dock = dock
	for index, info in { { "Play", "primary" }, { "Pieces", "secondary" }, { "Chests", "accent" } } do
		local button = Ui.button(info[1], dock, function()
			self:toggle(if info[1] == "Play" then "Games" else info[1])
		end, info[2] :: Ui.Style)
		button.Size = UDim2.fromOffset(150, 58)
		button.LayoutOrder = index
		Ui.setTextSize(button, 22)
	end

	panel(self, "Games", Vector2.new(560, 580))
	panel(self, "Pieces", Vector2.new(640, 520))
	panel(self, "Chests", Vector2.new(720, 470))

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
	reveal.Size = UDim2.fromScale(1, 1)
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

	self:render()
	return self
end

function LobbyHud.notice(self: LobbyHud, text: string)
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
	self.open = nil
	self.creating = false
	self:render()
end

function LobbyHud.toggle(self: LobbyHud, name: string)
	if self.open == name then
		self:close()
	else
		self.open = name
		self.creating = false
		self:render()
	end
end

function LobbyHud.openPanel(self: LobbyHud, name: string)
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

local function roomById(self: LobbyHud, id: number?): any
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

-- The settings form, editable (each change goes through `onChange`) or read-only.
local function settingsForm(parent: Instance, settings: RoomSettings.Settings, editable: boolean, onChange: (RoomSettings.Settings) -> ())
	local form = Ui.frame("Settings", UDim2.new(1, 0, 0, 8 * 44), parent)
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
	cycle(8, "Map", settings.map, "map", MatchSettings.nextMap(settings.map))
end

local function footer(parent: Instance): Frame
	local bar = Ui.frame("Footer", UDim2.new(1, 0, 0, 52), parent)
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	Ui.list(bar, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	return bar
end

local function renderBrowse(self: LobbyHud, content: Frame)
	local list = Instance.new("ScrollingFrame")
	list.Name = "Rooms"
	list.Size = UDim2.new(1, 0, 1, -64)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Ui.list(list, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local rooms = if self.rooms then self.rooms.rooms else {}
	if #rooms == 0 then
		local empty = Ui.label("Empty", list, UDim2.new(1, 0, 0, 120), 18, Theme.font.body)
		empty.TextColor3 = Theme.color.textDim
		empty.Text = "No games yet.\nCreate one and others can join!"
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
		sub.Text = `{room.players}/{room.maxPlayers} players · {room.status}`
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
	Ui.button("Create game", bar, function()
		self.creating = true
		self.draft = RoomSettings.validate(nil)
		self:render()
	end, "primary").Size = UDim2.fromOffset(190, 50)
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
		self.callbacks.onLobby({ type = "Create", settings = self.draft })
	end, "primary")
	create.LayoutOrder = 2
end

local function renderRoom(self: LobbyHud, content: Frame, room: any)
	local isHost = self.rooms ~= nil and self.rooms.hostOf == room.id
	local members = Ui.frame("Members", UDim2.new(1, 0, 0, 30), content)
	Ui.list(members, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for index, member in room.members do
		local pill = Ui.pill(if index == 1 then `★ {member.name}` else member.name, members, Theme.color.surfaceHigh)
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
	local start = Ui.button(if isHost then "Start game" else "Host starts", bar, function()
		if isHost then
			self.callbacks.onLobby({ type = "Start" })
		end
	end, if isHost then "primary" else "disabled")
	start.LayoutOrder = 2
	start.Size = UDim2.fromOffset(180, 50)
end

local function renderGames(self: LobbyHud)
	local frame = self.panels.Games
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	local mine = roomById(self, if self.rooms then self.rooms.mine else nil)
	heading(if mine then mine.name elseif self.creating then "Create a game" else "Casual games", frame)
	local content = body(frame, 64)
	if mine then
		renderRoom(self, content, mine)
	elseif self.creating then
		renderCreate(self, content)
	else
		renderBrowse(self, content)
	end
end

local function itemTile(self: LobbyHud, parent: Instance, order: number, item: Catalog.Item?, owned: number, equipped: boolean)
	local tile = Instance.new("TextButton")
	tile.Name = if item then item.id else "None"
	tile.LayoutOrder = order
	tile.BackgroundColor3 = if equipped then Theme.color.surfaceHigh else Theme.color.surface
	tile.AutoButtonColor = owned > 0
	tile.Text = ""
	tile.Parent = parent
	Ui.corner(tile, Theme.radius.surface)
	if equipped then
		Ui.stroke(tile, GOLD, 2, 0)
	end
	local rarityColor = if item then Catalog.RARITY_COLORS[item.rarity] else Theme.color.textDim
	local bar = Instance.new("Frame")
	bar.Name = "Rarity"
	bar.Size = UDim2.new(1, -16, 0, 4)
	bar.Position = UDim2.fromOffset(8, 6)
	bar.BackgroundColor3 = rarityColor
	bar.BorderSizePixel = 0
	bar.Parent = tile
	Ui.corner(bar, 2)
	if item and item.kind == "Piece" then
		local view = ModelView.new("Preview", tile, UDim2.new(1, 0, 0, 78))
		view.frame.Position = UDim2.fromOffset(0, 12)
		view:set("Pieces", item.id, finishPiece(item.id), "?")
	else
		local glyph = Ui.label("Glyph", tile, UDim2.new(1, 0, 0, 70), 44, Theme.font.display)
		glyph.Position = UDim2.fromOffset(0, 14)
		glyph.Text = if item then EFFECT_GLYPHS[item.id] or "★" else "—"
	end
	local name = Ui.label("Name", tile, UDim2.new(1, -8, 0, 20), 14, Theme.font.bodyBold)
	name.Position = UDim2.fromOffset(4, 92)
	name.Text = if item then item.name else "No effect"
	local status = Ui.label("Status", tile, UDim2.new(1, -8, 0, 18), 12, Theme.font.bodyBold)
	status.Position = UDim2.fromOffset(4, 112)
	status.TextColor3 = if equipped then GOLD elseif owned > 0 then Theme.color.textDim else Theme.color.moneyDown
	status.Text = if equipped then "EQUIPPED" elseif owned > 1 then `Owned ×{owned}` elseif owned > 0 then (if item then item.rarity else "") else "Locked"
	if owned <= 0 then
		tile.BackgroundTransparency = 0.35
	end
	tile.Activated:Connect(function()
		if owned <= 0 then
			self:notice("Win this from a chest")
		elseif item then
			self.callbacks.onStore({ type = "Equip", item = item.id })
		else
			self.callbacks.onStore({ type = "UnequipEffect" })
		end
	end)
end

local function renderPieces(self: LobbyHud)
	local frame = self.panels.Pieces
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	heading("Your collection", frame)
	local tabs = Ui.frame("Tabs", UDim2.fromOffset(330, 40), frame)
	tabs.Position = UDim2.fromOffset(20, 58)
	Ui.list(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for index, tab in { "Pieces", "Rent effects" } do
		local button = Ui.button(tab, tabs, function()
			self.piecesTab = tab
			self:render()
		end, if self.piecesTab == tab then "accent" else "secondary")
		button.Size = UDim2.fromOffset(150, 38)
		button.LayoutOrder = index
		Ui.setTextSize(button, 16)
	end
	local grid = Ui.frame("Grid", UDim2.new(1, -40, 1, -120), frame)
	grid.Position = UDim2.fromOffset(20, 106)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(110, 134)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local profile = self.profile
	local inventory = if profile then profile.inventory else {}
	local equipped = if profile then profile.equipped else { piece = Catalog.DEFAULT_PIECE, rentEffect = nil }
	local kind = if self.piecesTab == "Pieces" then "Piece" else "RentEffect"
	local order = 0
	if kind == "RentEffect" then
		order += 1
		itemTile(self, grid, order, nil, 1, equipped.rentEffect == nil)
	end
	for _, item in Catalog.ITEMS do
		if item.kind == kind then
			order += 1
			local owned = if item.default then 1 else inventory[item.id] or 0
			local isOn = if kind == "Piece" then equipped.piece == item.id else equipped.rentEffect == item.id
			itemTile(self, grid, order, item, owned, isOn)
		end
	end
end

local function renderChests(self: LobbyHud)
	local frame = self.panels.Chests
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	heading("Chests", frame)
	local note = Ui.label("Note", frame, UDim2.new(1, -40, 0, 18), 13, Theme.font.body)
	note.Position = UDim2.fromOffset(20, 50)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextColor3 = Theme.color.textDim
	note.Text = "Win new pieces and rent effects. Odds are shown on each chest."
	local row = Ui.frame("Row", UDim2.new(1, -40, 1, -90), frame)
	row.Position = UDim2.fromOffset(20, 78)
	Ui.list(row, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for index, chest in Chests.LIST do
		local card = Ui.surface(chest.id, UDim2.fromOffset(212, 372), row)
		card.LayoutOrder = index
		local view = ModelView.new("Preview", card, UDim2.new(1, 0, 0, 120))
		view:set("Emblems", "Chest", finishChest(chest.id), "?")
		local title = Ui.label("Name", card, UDim2.new(1, 0, 0, 28), 20, Theme.font.display)
		title.Position = UDim2.fromOffset(0, 120)
		title.Text = chest.name
		local blurb = Ui.label("Blurb", card, UDim2.new(1, -20, 0, 40), 13, Theme.font.body)
		blurb.Position = UDim2.fromOffset(10, 148)
		blurb.TextColor3 = Theme.color.textDim
		blurb.Text = chest.blurb
		local odds = Ui.frame("Odds", UDim2.new(1, -24, 0, 92), card)
		odds.Position = UDim2.fromOffset(12, 192)
		Ui.list(odds, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
		for line, text in Chests.oddsLines(chest) do
			local rarity = Catalog.RARITIES[line]
			local label = Ui.label(rarity, odds, UDim2.new(1, 0, 0, 20), 14, Theme.font.bodyBold)
			label.LayoutOrder = line
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Catalog.RARITY_COLORS[rarity]
			label.Text = text
		end
		local live = chest.productId ~= 0
		local buy = Ui.button(if live then `R$ {chest.price}` elseif RunService:IsStudio() then "Test open" else "Coming soon", card, function()
			self.callbacks.onStore({ type = if live then "Buy" else "TestOpen", chest = chest.id })
		end, if live or RunService:IsStudio() then "accent" else "disabled")
		buy.Size = UDim2.new(1, -24, 0, 50)
		buy.Position = UDim2.new(0, 12, 1, -62)
	end
end

function LobbyHud.render(self: LobbyHud)
	local profile = self.profile
	if profile then
		self.statLabels.elo.Text = tostring(math.floor(profile.stats.elo))
		for _, key in { "wins", "bestStreak", "streak", "games" } do
			self.statLabels[key].Text = tostring(math.floor((profile.stats :: any)[key]))
		end
	end
	for name, frame in self.panels do
		if name == self.open then
			if name == "Games" then
				renderGames(self)
			elseif name == "Pieces" then
				renderPieces(self)
			else
				renderChests(self)
			end
			Ui.show(frame)
		else
			Ui.hide(frame)
		end
	end
end

-- Plays the chest opening: the chest shakes harder and harder, bursts, and the prize appears.
function LobbyHud.showChest(self: LobbyHud, result: Protocol.ChestResult)
	local item = Catalog.byId[result.item]
	if not item then
		return
	end
	local reveal = self.reveal
	Ui.clear(reveal, function(child)
		return child == self.revealChest.frame or child == self.revealItem.frame
	end)
	reveal.Visible = true
	self.open = nil
	self:render()
	self.revealChest:set("Emblems", "Chest", finishChest(result.chest), "?")
	self.revealChest.frame.Visible = true
	self.revealItem.frame.Visible = false
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
			task.wait(0.11)
		end
		self.revealChest.wobble = 0
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		self.revealChest.frame.Visible = false
		local color = Catalog.RARITY_COLORS[item.rarity]
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.Size = UDim2.fromOffset(320, 320)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.38)
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 0.55
		glow.ZIndex = 41
		glow.Parent = reveal
		Ui.corner(glow, 160)
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = glow
		if item.kind == "Piece" then
			self.revealItem:set("Pieces", item.id, finishPiece(item.id), "★")
			self.revealItem.frame.Visible = true
			self.revealItem.speed = 1.2
		else
			local glyph = Ui.label("Glyph", reveal, UDim2.fromOffset(240, 200), 120, Theme.font.display)
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.38)
			glyph.ZIndex = 42
			glyph.Text = EFFECT_GLYPHS[item.id] or "★"
		end
		local rarity = Ui.label("Rarity", reveal, UDim2.fromOffset(400, 30), 22, Theme.font.display)
		rarity.AnchorPoint = Vector2.new(0.5, 0)
		rarity.Position = UDim2.fromScale(0.5, 0.58)
		rarity.TextColor3 = color
		rarity.ZIndex = 43
		rarity.Text = `{string.upper(item.rarity)} {if item.kind == "Piece" then "PIECE" else "RENT EFFECT"}`
		local title = Ui.label("Title", reveal, UDim2.fromOffset(500, 50), 42, Theme.font.display)
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0.58, 30)
		title.ZIndex = 43
		title.Text = item.name .. (if result.count > 1 then ` ×{result.count}` else "")
		local blurb = Ui.label("Blurb", reveal, UDim2.fromOffset(500, 26), 18, Theme.font.body)
		blurb.AnchorPoint = Vector2.new(0.5, 0)
		blurb.Position = UDim2.new(0.5, 0, 0.58, 84)
		blurb.TextColor3 = Theme.color.textDim
		blurb.ZIndex = 43
		blurb.Text = item.blurb
		local buttons = Ui.frame("Buttons", UDim2.fromOffset(340, 56), reveal)
		buttons.AnchorPoint = Vector2.new(0.5, 0)
		buttons.Position = UDim2.new(0.5, 0, 0.58, 124)
		buttons.ZIndex = 43
		Ui.list(buttons, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local equip = Ui.button("Equip", buttons, function()
			self.callbacks.onStore({ type = "Equip", item = item.id })
			reveal.Visible = false
		end, "accent")
		equip.LayoutOrder = 1
		local done = Ui.button("Nice!", buttons, function()
			reveal.Visible = false
		end, "secondary")
		done.LayoutOrder = 2
	end)
end

return LobbyHud
