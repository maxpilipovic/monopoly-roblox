--!strict
-- The trade window: pick a partner, put deeds, cash and jail cards on each side, send the offer.
-- TradeBuilder holds the working offer and TradeRules says whether it may be sent; this only draws it.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local TradeBuilder = require(script.Parent.Parent.TradeBuilder)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local TradeWindow = {}
TradeWindow.__index = TradeWindow

local CASH_STEPS = { -100, -10, 10, 100 }
-- Fits between the player list and the log, and above the action bar, on the design canvas.
local SIZE = Vector2.new(630, 480)
local BAR_ROOM = 124 -- the action bar and its margin: the window centres in what is left above it

export type Hooks = {
	send: (action: { [string]: any }) -> boolean, -- whether the offer went out
	close: () -> (), -- the window should close and the draft be dropped
	changed: () -> (), -- the draft changed: draw it again
}

export type TradeWindow = typeof(setmetatable({} :: { frame: Frame, hooks: Hooks, key: string? }, TradeWindow))

function TradeWindow.new(parent: Instance, hooks: Hooks): TradeWindow
	local frame = Ui.panel("Trade", UDim2.fromOffset(SIZE.X, SIZE.Y), UDim2.new(0.5, 0, 0.5, -BAR_ROOM / 2), Vector2.new(0.5, 0.5), parent)
	frame.Visible = false
	frame.ZIndex = 10
	return setmetatable({ frame = frame, hooks = hooks, key = nil }, TradeWindow)
end

local function chipColor(position: number): Color3?
	local group = Tiles.at(position).group
	return if group then ColorGroups[group].color else nil
end

function TradeWindow.render(
	self: TradeWindow,
	open: boolean,
	snapshot: Protocol.Snapshot,
	localId: string,
	builder: TradeBuilder.Builder
)
	local window = self.frame
	Ui.setVisible(window, open)
	TradeBuilder.prune(builder, snapshot, localId)
	local ok, reason = TradeBuilder.check(snapshot, localId, builder)
	local holdings = {}
	for _, player in snapshot.players do
		holdings[player.id] = { player.money, player.jailCards }
	end
	-- Rebuild only when something shown changed, so bot moves don't reset the scroll or eat clicks.
	local key = HttpService:JSONEncode({
		open = open,
		partners = TradeBuilder.partners(snapshot, localId),
		builder = builder,
		give = TradeBuilder.rows(snapshot, localId, builder.give),
		get = if builder.partner then TradeBuilder.rows(snapshot, builder.partner, builder.get) else {},
		ok = ok,
		reason = reason,
		holdings = holdings,
	})
	if key == self.key then
		return
	end
	self.key = key
	Ui.clear(window)
	if not open then
		return
	end
	local changed = self.hooks.changed

	local players = {}
	for _, player in snapshot.players do
		players[player.id] = player
	end

	-- Top: who to trade with.
	local heading = Ui.label("Heading", window, UDim2.fromOffset(120, 40), Theme.textSize.heading, Theme.font.display)
	heading.Position = UDim2.fromOffset(16, 12)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = "Trade with"
	local partnerRow = Ui.frame("Partners", UDim2.new(1, -152, 0, 40), window)
	partnerRow.Position = UDim2.fromOffset(140, 12)
	Ui.list(partnerRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	local partners = TradeBuilder.partners(snapshot, localId)
	for order, partner in partners do
		local picked = builder.partner == partner.id
		local button = Ui.button(partner.name, partnerRow, function()
			TradeBuilder.setPartner(builder, partner.id)
			changed()
		end, if picked then "accent" else "secondary")
		-- Up to five partners share the row.
		button.Size = UDim2.fromOffset(math.min(130, (SIZE.X - 152 - 6 * (#partners - 1)) // #partners), 36)
		button.LayoutOrder = order
		Ui.setTextSize(button, 15)
	end

	-- One column per side: whose it is, their deeds as chips, then cash and jail cards.
	local function column(sideName: TradeBuilder.SideName, ownerId: string?, x: number)
		local surface = Ui.surface(sideName, UDim2.new(0.5, -22, 1, -134), window)
		surface.Position = UDim2.new(x, if x == 0 then 16 else 6, 0, 62)

		local title = Ui.label("Title", surface, UDim2.fromOffset(110, 30), 18, Theme.font.display)
		title.Position = UDim2.fromOffset(12, 6)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Theme.color.accent
		title.Text = if sideName == "give" then "You give" else "You get"
		local owner = if ownerId then players[ownerId] else nil
		if not owner then
			local hint = Ui.label("Pick", surface, UDim2.new(1, -24, 0, 60), 16, Theme.font.body)
			hint.Position = UDim2.fromOffset(12, 60)
			hint.TextColor3 = Theme.color.textDim
			hint.Text = "Pick a player above to see what they could give you."
			return
		end

		-- Whose side this is and what they have to give.
		local who = Ui.frame("Owner", UDim2.new(1, -134, 0, 30), surface)
		who.Position = UDim2.fromOffset(122, 6)
		Ui.list(who, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
		local dot = Ui.dot(who, TokenLayout.SEAT_COLORS[owner.seat], 14)
		dot.LayoutOrder = 1
		local name = Ui.label("Name", who, UDim2.fromOffset(0, 30), 14)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.TextWrapped = false
		name.Text = `{owner.name} · ${owner.money}`
		name.TextColor3 = Theme.color.textDim
		name.LayoutOrder = 2

		local frame = Instance.new("ScrollingFrame")
		frame.Name = "Rows"
		frame.Size = UDim2.new(1, -16, 1, -128)
		frame.Position = UDim2.fromOffset(10, 40)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ScrollBarThickness = 6
		frame.ScrollBarImageColor3 = Theme.color.textDim
		frame.CanvasSize = UDim2.new()
		frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		frame.Parent = surface
		Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.xs, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
		Ui.padding(frame, { top = 2, bottom = 2, left = 2, right = 8 })

		local side = builder[sideName]
		local rows = TradeBuilder.rows(snapshot, ownerId :: string, side)
		if #rows == 0 then
			local none = Ui.label("None", frame, UDim2.new(1, 0, 0, 30), 14, Theme.font.body)
			none.TextColor3 = Theme.color.textDim
			none.TextXAlignment = Enum.TextXAlignment.Left
			none.Text = "No properties"
		end
		for order, row in rows do
			local name = if row.mortgaged then `{row.name} (mortgaged)` else row.name
			local label = if row.tradable then name else `{name} — {row.reason}`
			local state: Ui.ChipState = if row.selected then "selected" elseif not row.tradable then "disabled" else "normal"
			local chip = Ui.chip(label, frame, chipColor(row.position), state, function()
				-- A deed already in the offer can always come back out, even once it can't be traded.
				if TradeBuilder.canToggle(row) then
					TradeBuilder.toggle(builder, sideName, row.position)
					changed()
				end
			end)
			chip.LayoutOrder = order
		end

		-- Cash: the amount on the table and steps to change it.
		local extras = Ui.frame("Extras", UDim2.new(1, -20, 0, 80), surface)
		extras.AnchorPoint = Vector2.new(0, 1)
		extras.Position = UDim2.new(0, 10, 1, -6)
		Ui.list(extras, Enum.FillDirection.Vertical, Theme.space.xs, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)

		local cashRow = Ui.frame("Cash", UDim2.new(1, 0, 0, 34), extras)
		cashRow.LayoutOrder = 2
		Ui.list(cashRow, Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left)
		local amount = Ui.label("Amount", cashRow, UDim2.fromOffset(64, 30), 20, Theme.font.display)
		amount.Text = `${side.cash}`
		amount.TextColor3 = if side.cash > 0 then Theme.color.moneyUp else Theme.color.textDim
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.LayoutOrder = 0
		for i, step in CASH_STEPS do
			local button = Ui.button(if step > 0 then `+{step}` else `{step}`, cashRow, function()
				TradeBuilder.stepCash(builder, sideName, step, owner.money)
				changed()
			end, "secondary")
			button.Size = UDim2.fromOffset(46, 30)
			button.LayoutOrder = i
			Ui.setTextSize(button, 12)
		end

		if owner.jailCards > 0 then
			local cardRow = Ui.frame("JailCards", UDim2.new(1, 0, 0, 34), extras)
			cardRow.LayoutOrder = 1
			Ui.list(cardRow, Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left)
			local count = Ui.label("Count", cardRow, UDim2.fromOffset(170, 30), 15)
			count.TextXAlignment = Enum.TextXAlignment.Left
			count.Text = `Jail cards: {side.jailCards} of {owner.jailCards}`
			count.LayoutOrder = 0
			for i, step in { -1, 1 } do
				local button = Ui.button(if step > 0 then "+" else "−", cardRow, function()
					TradeBuilder.stepJailCards(builder, sideName, step, owner.jailCards)
					changed()
				end, "secondary")
				button.Size = UDim2.fromOffset(34, 30)
				button.LayoutOrder = i
			end
		end
	end
	column("give", localId, 0)
	column("get", builder.partner, 0.5)

	-- Footer: why it can't be sent, or Send; Cancel always.
	local footer = Ui.frame("Footer", UDim2.new(1, -32, 0, 48), window)
	footer.Position = UDim2.new(0, 16, 1, -60)
	Ui.list(footer, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	local hint = Ui.label("Hint", footer, UDim2.fromOffset(SIZE.X - 32 - 2 * 150 - 16, 44), 15, Theme.font.body)
	hint.TextColor3 = Theme.color.moneyDown
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = if ok then "" else ((reason or ""):gsub("^%l", string.upper))
	hint.LayoutOrder = 1
	local cancel = Ui.button("Cancel", footer, function()
		self.hooks.close()
	end, "secondary")
	cancel.LayoutOrder = 2
	local send = Ui.button("Send offer", footer, function()
		-- A swallowed click keeps the window and the offer, so nothing is lost.
		if TradeBuilder.check(snapshot, localId, builder) and self.hooks.send({ type = "ProposeTrade", offer = TradeBuilder.offer(builder) }) then
			self.hooks.close()
		end
	end, if ok then "primary" else "disabled")
	send.LayoutOrder = 3
end

-- Forgets what was drawn and hides (back to the lobby).
function TradeWindow.reset(self: TradeWindow)
	self.key = nil
	self.frame.Visible = false
end

return TradeWindow
