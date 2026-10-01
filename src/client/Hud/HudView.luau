--!strict
-- The on-screen HUD. Each screen is its own view under Views/; this decides what each one shows for
-- a snapshot and carries the local player's clicks to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local CardFace = require(script.Parent.CardFace)
local CardQueue = require(script.Parent.CardQueue)
local DeedModel = require(script.Parent.DeedModel)
local HudModel = require(script.Parent.HudModel)
local Layout = require(script.Parent.Layout)
local LogFormat = require(script.Parent.LogFormat)
local Theme = require(script.Parent.Theme)
local TradeBuilder = require(script.Parent.TradeBuilder)
local Ui = require(script.Parent.Ui)
local ActionBar = require(script.Parent.Views.ActionBar)
local CardReveal = require(script.Parent.Views.CardReveal)
local DeedCard = require(script.Parent.Views.DeedCard)
local Lobby = require(script.Parent.Views.Lobby)
local LogFeed = require(script.Parent.Views.LogFeed)
local OfferCard = require(script.Parent.Views.OfferCard)
local PlayerList = require(script.Parent.Views.PlayerList)
local PropertiesPanel = require(script.Parent.Views.PropertiesPanel)
local Results = require(script.Parent.Views.Results)
local Toasts = require(script.Parent.Views.Toasts)
local TradeWindow = require(script.Parent.Views.TradeWindow)
local TurnBanner = require(script.Parent.Views.TurnBanner)

local CARD_SECONDS = 5
local ACTION_LOCK_SECONDS = 2 -- the server always answers; this only covers a lost reply
-- Even after the answer, a double-click's second half must not land on the button drawn in the same spot.
local MIN_CLICK_GAP = 0.35
local CONFIRM_WIDTH = 220
local ABOVE_BAR = ActionBar.MARGIN + ActionBar.HEIGHT + 8 -- where panels that sit on the action bar start
local OFFER_ROOM = 200 -- toasts clear the offer card (its height varies with the offer) when one is up

export type Callbacks = {
	onAction: (action: { [string]: any }) -> (),
	onStart: (seats: number, settings: MatchSettings.Settings) -> (),
	onReturnToLobby: () -> (),
}

local HudView = {}
HudView.__index = HudView

export type HudView = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		root: Frame,
		rootScale: UIScale,
		callbacks: Callbacks,
		lobby: Lobby.Lobby,
		playerList: PlayerList.PlayerList,
		actionBar: ActionBar.ActionBar,
		logFeed: LogFeed.LogFeed,
		toasts: Toasts.Toasts,
		results: Results.Results,
		propertiesPanel: PropertiesPanel.PropertiesPanel,
		tradeWindow: TradeWindow.TradeWindow,
		offerCard: OfferCard.OfferCard,
		turnBanner: TurnBanner.TurnBanner,
		cardReveal: CardReveal.CardReveal,
		deedCard: DeedCard.DeedCard,
		deed: DeedModel.Deed?, -- what the deed card should show when no card is in the way
		deedNote: string?,
		deedClosable: boolean,
		inspected: number?, -- a deed the player opened from their properties
		tumbleNext: boolean, -- a roll just arrived: the dice tumble on the next render
		cards: CardQueue.Queue,
		propertiesOpen: boolean,
		tradeOpen: boolean,
		trade: TradeBuilder.Builder,
		snapshot: Protocol.Snapshot?,
		localId: string,
		wasDebtor: boolean,
		statusText: string,
		statusColor: Color3,
		narrow: boolean,
		sentAt: number?, -- when the last action went out
		answered: boolean, -- whether the server has answered since
		connections: { RBXScriptConnection },
	},
	HudView
))

-- The board's empty centre holds one thing at a time: a drawn card, else the deed in question.
local function updateCentre(self: HudView)
	local card = CardQueue.current(self.cards, os.clock())
	self.cardReveal:show(if card then card.face else nil)
	self.deedCard:render(if card then nil else self.deed, self.deedNote, self.deedClosable)
end

-- Works out which deed (if any) the snapshot calls for: the tile being bought or auctioned, else
-- one the player opened themselves.
local function chooseDeed(self: HudView, snapshot: Protocol.Snapshot?)
	self.deed, self.deedNote, self.deedClosable = nil, nil, false
	if not snapshot or snapshot.phase == "GameOver" or self.tradeOpen then
		return
	end
	local focus = HudModel.deedFocus(snapshot)
	local position = focus or self.inspected
	if not position then
		return
	end
	self.deed = DeedModel.of(position, snapshot)
	self.deedClosable = focus == nil
	local auction = snapshot.auction
	if focus and auction then
		local names = HudModel.names(snapshot)
		self.deedNote = if auction.highBidder
			then `High bid ${auction.highBid} — {names[auction.highBidder] or auction.highBidder}`
			else "No bids yet"
	end
end

-- The countdown and match line change every second between server updates.
local function refreshTimers(self: HudView)
	local snapshot = self.snapshot
	if not snapshot then
		return
	end
	local now = workspace:GetServerTimeNow()
	local countdown, urgent = HudModel.countdown(snapshot, now)
	self.actionBar:setStatus(
		if countdown then `{self.statusText} · {countdown}` else self.statusText,
		if urgent then Theme.color.danger else self.statusColor
	)
	self.actionBar:setTimer(HudModel.timerFraction(snapshot, now), urgent)
	self.playerList:setMatchLine(HudModel.matchLine(snapshot, now))
end

function HudView.new(playerGui: Instance, callbacks: Callbacks): HudView
	local gui = Instance.new("ScreenGui")
	gui.Name = "MonopolyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Everything is laid out on a fixed canvas inside this frame and scaled as one (see applyViewport).
	local root = Ui.frame("Root", UDim2.fromScale(1, 1), gui)
	local rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	local self: HudView
	local function rerender()
		self:render(self.snapshot, self.localId)
	end

	self = setmetatable({
		gui = gui,
		root = root,
		rootScale = rootScale,
		callbacks = callbacks,
		lobby = Lobby.new(root, callbacks.onStart),
		playerList = PlayerList.new(root),
		actionBar = ActionBar.new(root),
		logFeed = LogFeed.new(root),
		toasts = Toasts.new(root, ABOVE_BAR),
		results = Results.new(root, callbacks.onReturnToLobby),
		propertiesPanel = nil :: any,
		tradeWindow = nil :: any,
		offerCard = OfferCard.new(root, ABOVE_BAR),
		turnBanner = TurnBanner.new(root),
		cardReveal = nil :: any,
		deedCard = nil :: any,
		deed = nil,
		deedNote = nil,
		deedClosable = false,
		inspected = nil,
		tumbleNext = false,
		cards = CardQueue.new(CARD_SECONDS),
		propertiesOpen = false,
		tradeOpen = false,
		trade = TradeBuilder.new(),
		snapshot = nil,
		localId = "",
		wasDebtor = false,
		statusText = "",
		statusColor = Theme.color.text,
		narrow = false,
		sentAt = nil,
		answered = true,
		connections = {},
	}, HudView)

	self.propertiesPanel = PropertiesPanel.new(root, function(action)
		self:send(action)
	end, function(position)
		self:inspect(position)
	end)
	self.tradeWindow = TradeWindow.new(root, {
		send = function(action)
			return self:send(action)
		end,
		close = function()
			self.tradeOpen = false
			self.trade = TradeBuilder.new()
			rerender()
		end,
		changed = rerender,
	})

	self.deedCard = DeedCard.new(root, function()
		self:inspect(nil)
	end)
	self.cardReveal = CardReveal.new(root, function()
		self:dismissCard()
	end)

	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function()
			self:tick()
		end)
	)

	-- Fit the screen now and whenever it changes (rotation, window resize, a replaced camera).
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			self:applyViewport(camera.ViewportSize)
		end
	end
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		end
		fit()
	end
	table.insert(self.connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
	watchCamera()
	gui.Destroying:Connect(function()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	self.playerList.frame.Visible = false
	self.actionBar.frame.Visible = false
	return self
end

-- Scales the HUD to the screen and tells the camera how much of it the action bar covers.
function HudView.applyViewport(self: HudView, viewport: Vector2)
	local scale = Layout.scale(viewport)
	self.rootScale.Scale = scale
	-- The root is scaled too, so size it to cover the whole screen once scaled.
	self.root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	self.narrow = Layout.isNarrow(viewport)
	self.logFeed.frame.Visible = not self.narrow and self.snapshot ~= nil
	self.gui:SetAttribute("BottomInset", Layout.bottomInset(ActionBar.HEIGHT, ActionBar.MARGIN, scale, viewport.Y))
end

function HudView.destroy(self: HudView)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.gui:Destroy()
end

-- What changes between server updates: the card on show, the countdown, the match clock.
function HudView.tick(self: HudView)
	updateCentre(self)
	refreshTimers(self)
end

-- Queues a drawn card; it appears at `notBefore` (os.clock time) or after the cards ahead of it.
function HudView.showCard(self: HudView, cardId: string, drawer: string, notBefore: number)
	local face = CardFace.of(cardId, drawer)
	if face then
		CardQueue.push(self.cards, face.deck, face.text, notBefore, face)
	end
end

-- Sends the card on show away early.
function HudView.dismissCard(self: HudView)
	CardQueue.dismiss(self.cards, os.clock())
	updateCentre(self)
end

-- A roll just arrived: the dice tumble into it on the next render.
function HudView.diceRolled(self: HudView)
	self.tumbleNext = true
end

-- Pins the deed of a property the player wants to look at (nil unpins).
function HudView.inspect(self: HudView, position: number?)
	self.inspected = position
	chooseDeed(self, self.snapshot)
	updateCentre(self)
end

-- `players` names whose names to colour; defaults to the game on screen.
function HudView.log(self: HudView, lines: { string }, players: { Protocol.PlayerView }?)
	players = players or (if self.snapshot then self.snapshot.players else {})
	local rich = {}
	for _, line in lines do
		table.insert(rich, LogFormat.rich(line, players))
	end
	self.logFeed:push(rich)
end

-- Why the server refused the local player's last action.
function HudView.notice(self: HudView, message: string)
	self.toasts:show(message)
end

-- Sends one action, then ignores further clicks until the server answers, so a double-click can't
-- act twice (e.g. roll again after doubles).
-- Returns whether it went out.
function HudView.send(self: HudView, action: { [string]: any }): boolean
	local sentAt = self.sentAt
	if sentAt then
		local elapsed = os.clock() - sentAt
		if elapsed < MIN_CLICK_GAP or (not self.answered and elapsed < ACTION_LOCK_SECONDS) then
			return false
		end
	end
	self.sentAt = os.clock()
	self.answered = false
	self.callbacks.onAction(action)
	return true
end

-- A server update arrived: clicks count again (once MIN_CLICK_GAP has passed).
function HudView.unlock(self: HudView)
	self.answered = true
end

function HudView.toggleProperties(self: HudView)
	self.propertiesOpen = not self.propertiesOpen
	self:render(self.snapshot, self.localId)
end

function HudView.toggleTrade(self: HudView)
	self.tradeOpen = not self.tradeOpen
	if not self.tradeOpen then
		self.trade = TradeBuilder.new()
	end
	self:render(self.snapshot, self.localId)
end

local function actionEntries(self: HudView, snapshot: Protocol.Snapshot, localId: string): { ActionBar.Entry }
	local entries: { ActionBar.Entry } = {}
	for order, entry in HudModel.buttons(snapshot, localId) do
		local confirm = entry.confirm
		table.insert(entries, {
			label = entry.label,
			-- The first action is the one the game is waiting for; confirm-style ones are dangerous.
			style = if confirm then "danger" elseif order == 1 then "primary" else "secondary",
			order = order,
			width = if confirm then CONFIRM_WIDTH else nil,
			onClick = function(button)
				if confirm and button.Text ~= confirm then
					Ui.setText(button, confirm) -- first click only arms it; any re-render disarms it
					return
				end
				self:send(entry.action)
			end,
		})
	end
	if HudModel.showsPropertiesToggle(snapshot) then
		table.insert(entries, {
			label = if self.propertiesOpen then "Hide properties" else "Properties",
			style = "secondary",
			order = 100,
			onClick = function()
				self:toggleProperties()
			end,
		})
	end
	if HudModel.canTrade(snapshot, localId) then
		table.insert(entries, {
			label = if self.tradeOpen then "Close trade" else "Trade",
			style = "secondary",
			order = 101,
			onClick = function()
				self:toggleTrade()
			end,
		})
	end
	return entries
end

function HudView.render(self: HudView, snapshot: Protocol.Snapshot?, localId: string)
	local previous = self.snapshot
	self.snapshot = snapshot
	self.localId = localId
	Ui.setVisible(self.lobby.frame, snapshot == nil)
	self.playerList.frame.Visible = snapshot ~= nil
	self.actionBar.frame.Visible = snapshot ~= nil
	self.logFeed.frame.Visible = snapshot ~= nil and not self.narrow
	if not snapshot then
		table.clear(self.cards.items) -- back in the lobby: drop cards still waiting
		self.inspected = nil
		chooseDeed(self, nil)
		updateCentre(self)
		self.actionBar.dice:show(nil, false)
		self.tumbleNext = false
		self.propertiesOpen = false
		self.propertiesPanel:reset()
		self.logFeed:clear() -- the next game starts with a fresh log
		self.toasts:clear()
		self.turnBanner:hide()
		self.playerList:reset()
		self.actionBar:setTimer(nil, false)
		self.wasDebtor = false
		self.results:render(nil, {})
		self.tradeOpen = false
		self.trade = TradeBuilder.new()
		self.tradeWindow:reset()
		self.offerCard:render(nil)
		self.actionBar:setButtons({})
		return
	end

	self.playerList:render(HudModel.playerRows(snapshot, localId), HudModel.moneyDeltas(previous, snapshot))
	if HudModel.becameMyTurn(previous, snapshot, localId) then
		self.turnBanner:play()
	end

	self.actionBar.dice:show(snapshot.lastRoll, self.tumbleNext)
	self.tumbleNext = false
	self.statusText = HudModel.status(snapshot, localId)
	local debtor = HudModel.isDebtor(snapshot, localId)
	self.statusColor = if debtor then Theme.color.moneyDown else Theme.color.text
	refreshTimers(self)

	if debtor and not self.wasDebtor then
		self.propertiesOpen = true -- raising cash happens in the panel
	end
	-- A trade made while in debt pauses the debt; it isn't a new one, so don't re-open the panel after it.
	if snapshot.phase ~= "Trade" then
		self.wasDebtor = debtor
	end
	if snapshot.phase == "GameOver" then
		self.propertiesOpen = false
	end
	if self.tradeOpen and not HudModel.canTrade(snapshot, localId) then
		self.tradeOpen = false -- the moment passed (the turn moved on, or an offer is open)
		self.trade = TradeBuilder.new()
	end

	self.actionBar:setButtons(actionEntries(self, snapshot, localId))
	self.propertiesPanel:render(
		self.propertiesOpen,
		HudModel.propertyGroups(HudModel.propertyRows(snapshot, localId)),
		HudModel.noPropertiesText(snapshot, localId)
	)
	self.tradeWindow:render(self.tradeOpen, snapshot, localId, self.trade)

	local offer = HudModel.tradeOffer(snapshot, localId)
	self.offerCard:render(offer)
	-- Toasts sit on whatever is stacked above the action bar.
	self.toasts.frame.Position = UDim2.new(0.5, 0, 1, -(ABOVE_BAR + if offer then OFFER_ROOM else 0))

	if snapshot.phase == "GameOver" then
		self.inspected = nil
	end
	chooseDeed(self, snapshot)
	updateCentre(self)

	if snapshot.phase == "GameOver" then
		self.results:render(HudModel.status(snapshot, localId), HudModel.standings(snapshot))
	else
		self.results:render(nil, {})
	end
end

return HudView
